import AppKit
import SwiftUI
import TahlilCore
import UniformTypeIdentifiers

struct CaptureView: View {
    let onClose: () -> Void
    let onComplete: (StripReading, CGImage) -> Void
    var openPhotoOnAppear: Bool = false

    @StateObject private var camera = CameraController()
    @State private var templateID = "standard10"
    @State private var reversed = false
    @State private var widthFraction = 0.20
    @State private var heightFraction = 0.86
    @State private var captureError: String?
    @State private var waitStartedAt: Date?
    @State private var skipWait = false
    @State private var stillImage: CGImage?
    @State private var didAutoOpenPhoto = false

    private var template: StripTemplate {
        StripCatalog.template(id: templateID)
    }

    private var guide: CGRect {
        StripGuide.normalized(widthFraction: widthFraction, heightFraction: heightFraction)
    }

    private var orderedAnalytes: [Analyte] {
        template.ordered(reversed: reversed)
    }

    private var usingPhoto: Bool {
        stillImage != nil
    }

    private var waitReady: Bool {
        usingPhoto || CaptureTiming.isReady(
            waitSeconds: template.readWaitSeconds,
            startedAt: waitStartedAt,
            skipWait: skipWait
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            stage
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            controls
                .frame(width: 320)
                .padding(20)
                .background(Theme.rail.opacity(0.45))
        }
        .onAppear {
            camera.prepare()
            if openPhotoOnAppear && !didAutoOpenPhoto {
                didAutoOpenPhoto = true
                DispatchQueue.main.async { importPhoto() }
            }
        }
        .onChange(of: templateID) { _, _ in
            waitStartedAt = nil
            skipWait = false
        }
    }

    private var stage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.92))

            if let still = stillImage {
                FramedPhoto(
                    image: NSImage(cgImage: still, size: NSSize(width: still.width, height: still.height)),
                    guide: guide
                ) {
                    GuideChrome(analytes: orderedAnalytes)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else if let preview = camera.preview {
                FramedPhoto(image: preview, guide: guide) {
                    GuideChrome(analytes: orderedAnalytes)
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(camera.errorMessage ?? "Kamera açılıyor")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                }
                .padding(24)
            }
        }
    }

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    BackButton(action: onClose)
                    Spacer()
                    Text("Çekim")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                }

                if usingPhoto {
                    Label("Fotoğraf", systemImage: "photo")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.teal)
                } else if camera.isRunning {
                    Label("Canlı", systemImage: "circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.coral)
                        .symbolRenderingMode(.monochrome)
                }

                if !usingPhoto, camera.devices.count > 1 {
                    Picker("Kamera", selection: Binding(
                        get: { camera.selectedDeviceID ?? "" },
                        set: { camera.selectDevice(id: $0) }
                    )) {
                        ForEach(camera.devices) { device in
                            Text(device.name).tag(device.id)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Picker("Çubuk", selection: $templateID) {
                    ForEach(StripCatalog.all) { item in
                        Text(item.name).tag(item.id)
                    }
                }
                .pickerStyle(.segmented)

                if let brand = template.brand {
                    Text(brand)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.teal)
                }

                Text(template.detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                timingBlock

                Toggle("Ped sırasını ters çevir", isOn: $reversed)
                    .font(.system(size: 13))
                    .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Çerçeve genişliği")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                    Slider(value: $widthFraction, in: 0.12...0.36)
                    Text("Çerçeve yüksekliği")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                    Slider(value: $heightFraction, in: 0.62...0.94)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Üstten alta")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                    ForEach(Array(orderedAnalytes.enumerated()), id: \.element.id) { index, analyte in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.teal)
                                .frame(width: 16, alignment: .leading)
                            Text(analyte.name)
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Text(analyte.abbreviation)
                                .foregroundStyle(Theme.muted)
                        }
                        .font(.system(size: 12))
                    }
                }
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.line, lineWidth: 1)
                )

                if let message = captureError ?? camera.errorMessage {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.coral)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if camera.authorization == .denied || camera.authorization == .restricted, !usingPhoto {
                    Button("Sistem Ayarlarını Aç") {
                        camera.openSettings()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Button(action: capture) {
                    Label(usingPhoto ? "Fotoğrafı oku" : "Çek ve oku", systemImage: "viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!canCapture)
                .keyboardShortcut(.defaultAction)

                Button(action: importPhoto) {
                    Label(usingPhoto ? "Başka fotoğraf seç" : "Fotoğraftan oku", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())

                if usingPhoto {
                    Button("Kameraya dön") {
                        stillImage = nil
                        captureError = nil
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Button(action: useSample) {
                    Text("Örnek şeritle dene")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }

    private var timingBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bekleme")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.muted)

            if usingPhoto {
                Text("Fotoğrafta ıslatma süresi doğrulanamaz. Çerçeveyi hizalayıp okuyun.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                TimelineView(.periodic(from: .now, by: 0.25)) { context in
                    let text = CaptureTiming.statusText(
                        waitSeconds: template.readWaitSeconds,
                        startedAt: waitStartedAt,
                        now: context.date,
                        skipWait: skipWait
                    )
                    Text(text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(waitReady ? Theme.good : Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 8) {
                    Button("Islattım, sayacı başlat") {
                        waitStartedAt = Date()
                        skipWait = false
                        captureError = nil
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(template.readWaitSeconds <= 0)

                    if waitStartedAt != nil {
                        Button("Sıfırla") {
                            waitStartedAt = nil
                            skipWait = false
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(Theme.muted)
                    }
                }

                Toggle("Beklemeyi atla (yalnızca test)", isOn: $skipWait)
                    .font(.system(size: 12))
                    .toggleStyle(.switch)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private var canCapture: Bool {
        if usingPhoto {
            return stillImage != nil
        }
        return camera.preview != nil && waitReady
    }

    private func capture() {
        if !usingPhoto && !waitReady {
            captureError = "Önce ıslatma beklemesini tamamlayın veya test için atlayın."
            return
        }

        let image: CGImage?
        let source: ReadingSource
        if let still = stillImage {
            image = still
            source = .photo
        } else {
            image = camera.captureImage()
            source = .camera
        }

        guard let image else {
            captureError = "Kare alınamadı."
            return
        }
        guard let strip = ImageOps.cropping(image, toNormalized: guide) else {
            captureError = "Çerçeve okunamadı."
            return
        }
        captureError = nil
        let reading = StripAnalyzer.analyze(
            stripImage: strip,
            template: template,
            reversed: reversed,
            source: source,
            guide: guide
        )
        onComplete(reading, image)
    }

    private func importPhoto() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = PhotoImport.allowedTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Okunacak çubuk fotoğrafını seçin"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let image = PhotoImport.loadImage(from: url) else {
                DispatchQueue.main.async {
                    self.captureError = "Fotoğraf açılamadı."
                }
                return
            }
            DispatchQueue.main.async {
                self.stillImage = image
                self.skipWait = true
                self.waitStartedAt = nil
                self.captureError = nil
            }
        }
    }

    private func useSample() {
        let sampleGuide = StripGuide.normalized(widthFraction: 0.22, heightFraction: 0.86)
        guard let made = SampleStrip.make(template: template, reversed: reversed, guide: sampleGuide) else {
            captureError = "Örnek şerit üretilemedi."
            return
        }
        onComplete(made.reading, made.photo)
    }
}

struct FramedPhoto<Overlay: View>: View {
    let image: NSImage
    let guide: CGRect
    @ViewBuilder var overlay: () -> Overlay

    var body: some View {
        GeometryReader { geo in
            let content = GuideGeometry.aspectFit(container: geo.size, image: image.size)
            let hole = GuideGeometry.map(guide, within: content)
            Image(nsImage: image)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fit)
                .frame(width: geo.size.width, height: geo.size.height)
                .overlay {
                    HoleDimmer(hole: hole)
                }
                .overlay(alignment: .topLeading) {
                    overlay()
                        .frame(width: max(hole.width, 1), height: max(hole.height, 1))
                        .offset(x: hole.minX, y: hole.minY)
                }
        }
    }
}

private struct HoleDimmer: View {
    let hole: CGRect

    var body: some View {
        GeometryReader { geo in
            Path { path in
                path.addRect(CGRect(origin: .zero, size: geo.size))
                path.addRoundedRect(
                    in: hole,
                    cornerSize: CGSize(width: 14, height: 14)
                )
            }
            .fill(Color.black.opacity(0.42), style: FillStyle(eoFill: true))
            .allowsHitTesting(false)
        }
    }
}

struct GuideChrome: View {
    let analytes: [Analyte]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(analytes.enumerated()), id: \.element.id) { index, _ in
                ZStack(alignment: .topLeading) {
                    Color.clear
                    if index > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.9))
                            .frame(height: 1)
                    }
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Theme.teal.opacity(0.92), in: Capsule())
                        .padding(4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.teal, lineWidth: 2)
        )
        .allowsHitTesting(false)
    }
}
