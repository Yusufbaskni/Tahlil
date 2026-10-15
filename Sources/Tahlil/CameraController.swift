import AppKit
import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo

struct CameraDevice: Identifiable, Equatable {
    let id: String
    let name: String
}

final class CameraController: NSObject, ObservableObject {
    @Published var preview: NSImage?
    @Published var devices: [CameraDevice] = []
    @Published var selectedDeviceID: String?
    @Published var authorization: AVAuthorizationStatus = .notDetermined
    @Published var isRunning = false
    @Published var errorMessage: String?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "com.tahlil.camera")
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let latestLock = NSLock()
    private var latest: CGImage?
    private var lastPreviewTime = 0.0
    private var active = false
    private var generation = 0

    func prepare() {
        if isActive { return }
        setActive(true)
        generation += 1
        let token = generation
        authorization = AVCaptureDevice.authorizationStatus(for: .video)
        switch authorization {
        case .authorized:
            startSession(token: token)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    self.authorization = granted ? .authorized : .denied
                    if granted {
                        self.startSession(token: token)
                    } else {
                        self.setActive(false)
                        self.errorMessage = "Kamera izni verilmedi."
                    }
                }
            }
        case .denied:
            setActive(false)
            errorMessage = "Kamera izni kapalı. Sistem Ayarları’ndan Tahlil için kamerayı açın."
        case .restricted:
            setActive(false)
            errorMessage = "Kamera bu hesapta kısıtlı."
        @unknown default:
            setActive(false)
            errorMessage = "Kamera durumu okunamadı."
        }
    }

    deinit {
        setActive(false)
        let session = self.session
        sessionQueue.async {
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    private func startSession(token: Int) {
        setActive(true)
        let preferredID = selectedDeviceID
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.configureSession(preferredID: preferredID)
            if !self.session.isRunning {
                self.session.startRunning()
            }
            let running = self.session.isRunning
            DispatchQueue.main.async {
                guard self.generation == token else {
                    if self.session.isRunning {
                        self.sessionQueue.async {
                            if self.session.isRunning {
                                self.session.stopRunning()
                            }
                        }
                    }
                    return
                }
                self.isRunning = running
            }
        }
    }

    func selectDevice(id: String) {
        selectedDeviceID = id
        guard isActive else { return }
        let token = generation
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            self.configureSession(preferredID: id)
            self.session.startRunning()
            let running = self.session.isRunning
            DispatchQueue.main.async {
                guard self.generation == token else { return }
                self.isRunning = running
            }
        }
    }

    func captureImage() -> CGImage? {
        latestLock.lock()
        defer { latestLock.unlock() }
        return latest
    }

    func openSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Camera",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera",
        ]
        for candidate in candidates {
            guard let url = URL(string: candidate) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    private var isActive: Bool {
        latestLock.lock()
        defer { latestLock.unlock() }
        return active
    }

    private func setActive(_ value: Bool) {
        latestLock.lock()
        active = value
        latestLock.unlock()
    }

    private func configureSession(preferredID: String?) {
        let found = Self.discoverDevices()
        DispatchQueue.main.async {
            self.devices = found.map { CameraDevice(id: $0.uniqueID, name: $0.localizedName) }
        }

        let device = found.first { $0.uniqueID == preferredID }
            ?? found.first { $0.deviceType == .builtInWideAngleCamera }
            ?? found.first

        session.beginConfiguration()
        session.sessionPreset = .high
        for input in session.inputs {
            session.removeInput(input)
        }

        guard let device else {
            session.commitConfiguration()
            DispatchQueue.main.async {
                self.errorMessage = "Kamera bulunamadı."
                self.isRunning = false
            }
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                throw CameraError.cannotAddInput
            }
            session.addInput(input)

            if session.outputs.isEmpty {
                output.alwaysDiscardsLateVideoFrames = true
                output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                output.setSampleBufferDelegate(self, queue: sessionQueue)
                guard session.canAddOutput(output) else {
                    throw CameraError.cannotAddOutput
                }
                session.addOutput(output)
            } else {
                output.setSampleBufferDelegate(self, queue: sessionQueue)
            }

            if let connection = output.connection(with: .video), connection.isVideoMirroringSupported {
                connection.isVideoMirrored = false
            }

            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            device.unlockForConfiguration()

            DispatchQueue.main.async {
                self.selectedDeviceID = device.uniqueID
                self.errorMessage = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = "Kamera açılamadı."
            }
        }

        session.commitConfiguration()
    }

    private static func discoverDevices() -> [AVCaptureDevice] {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        ).devices
    }

    private func store(image: CGImage) {
        latestLock.lock()
        latest = image
        let shouldPreview = active
        latestLock.unlock()
        guard shouldPreview else { return }

        let now = CACurrentMediaTime()
        guard now - lastPreviewTime > (1.0 / 8.0) else { return }
        lastPreviewTime = now

        let display = downscaled(image, maxPixelSize: 960)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isActive else { return }
            self.preview = NSImage(
                cgImage: display,
                size: NSSize(width: display.width, height: display.height)
            )
        }
    }

    private func downscaled(_ image: CGImage, maxPixelSize: Int) -> CGImage {
        let largest = max(image.width, image.height)
        guard largest > maxPixelSize else { return image }
        let scale = CGFloat(maxPixelSize) / CGFloat(largest)
        let scaled = CIImage(cgImage: image).transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return ciContext.createCGImage(scaled, from: scaled.extent) ?? image
    }

    private enum CameraError: Error {
        case cannotAddInput
        case cannotAddOutput
    }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(image, from: image.extent) else { return }
        store(image: cgImage)
    }
}
