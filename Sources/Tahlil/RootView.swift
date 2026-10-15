import AppKit
import SwiftUI
import TahlilCore

@main
struct TahlilApp: App {
    @StateObject private var history = HistoryStore()

    init() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(history)
                .environment(\.locale, Locale(identifier: "tr_TR"))
                .frame(minWidth: 980, minHeight: 680)
                .onAppear { NSApp.activate() }
        }
        .defaultSize(width: 1180, height: 780)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var history: HistoryStore
    @State private var stage: Stage = .home
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var openPhotoOnCapture = false
    /// Sonuç ekranından geri: geçmişten açıldıysa geçmiş, değilse ana ekran.
    @State private var resultReturn: ResultReturn = .home

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 236, max: 280)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.paper)
        }
        .background(Theme.paper)
        .navigationTitle(title)
    }

    private var title: String {
        switch stage {
        case .home: "Tahlil"
        case .capture: "Çekim"
        case .history: "Geçmiş"
        case .result: "Sonuç"
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                StripMark()
                VStack(alignment: .leading, spacing: 1) {
                    Text("Tahlil")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("Çubuk okuyucu")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(.bottom, 12)

            sidebarButton("Yeni okuma", systemImage: "viewfinder", selected: stage == .home || stage == .capture) {
                stage = .home
            }
            sidebarButton("Geçmiş", systemImage: "clock", selected: stage == .history) {
                stage = .history
            }

            Spacer()

            Text(Copy.disclaimer)
                .font(.system(size: 11))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Text("Sürüm \(appVersion)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.muted)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.rail)
    }

    @ViewBuilder
    private var detail: some View {
        switch stage {
        case .home:
            HomeView(
                readings: history.readings,
                onCapture: {
                    openPhotoOnCapture = false
                    stage = .capture
                },
                onPhoto: {
                    openPhotoOnCapture = true
                    stage = .capture
                },
                onSample: { openSample(template: StripCatalog.standard10, reversed: false) },
                onOpen: { openReading($0, returnTo: .home) }
            )
        case .capture:
            CaptureView(
                onClose: {
                    openPhotoOnCapture = false
                    stage = .home
                },
                onComplete: { reading, image in
                    openPhotoOnCapture = false
                    history.add(reading, image: image)
                    resultReturn = .home
                    stage = .result(reading, nsImage(image))
                },
                openPhotoOnAppear: openPhotoOnCapture
            )
        case .history:
            HistoryView(
                onBack: { stage = .home },
                onOpen: { openReading($0, returnTo: .history) }
            )
        case .result(let reading, let image):
            ResultView(
                reading: reading,
                image: image,
                onBack: goBackFromResult,
                onNew: {
                    openPhotoOnCapture = false
                    stage = .capture
                }
            )
        }
    }

    private func openSample(template: StripTemplate, reversed: Bool) {
        let guide = StripGuide.normalized(widthFraction: 0.22, heightFraction: 0.86)
        guard let made = SampleStrip.make(template: template, reversed: reversed, guide: guide) else { return }
        history.add(made.reading, image: made.photo)
        resultReturn = .home
        stage = .result(made.reading, nsImage(made.photo))
    }

    private func openReading(_ reading: StripReading, returnTo: ResultReturn) {
        resultReturn = returnTo
        stage = .result(reading, history.image(for: reading))
    }

    private func goBackFromResult() {
        switch resultReturn {
        case .home:
            stage = .home
        case .history:
            stage = .history
        }
    }

    private func nsImage(_ image: CGImage) -> NSImage {
        NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    private func sidebarButton(
        _ title: String,
        systemImage: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .frame(width: 16)
                Text(title)
                Spacer()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(selected ? Theme.teal : Theme.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selected ? Theme.teal.opacity(0.14) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
}

private enum Stage: Equatable {
    case home
    case capture
    case history
    case result(StripReading, NSImage?)

    static func == (lhs: Stage, rhs: Stage) -> Bool {
        switch (lhs, rhs) {
        case (.home, .home), (.capture, .capture), (.history, .history):
            true
        case (.result(let left, _), .result(let right, _)):
            left == right
        default:
            false
        }
    }
}

private enum ResultReturn {
    case home
    case history
}

struct StripMark: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Theme.teal)
            .frame(width: 28, height: 36)
            .overlay {
                VStack(spacing: 2) {
                    pad(0x7C, 0x92, 0x3A)
                    pad(0xF6, 0xE0, 0xAA)
                    pad(0x68, 0xB0, 0x5C)
                    pad(0xEC, 0x96, 0xA4)
                    pad(0xB0, 0x60, 0x8C)
                }
                .padding(.vertical, 4)
            }
    }

    private func pad(_ r: UInt32, _ g: UInt32, _ b: UInt32) -> some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(Color(nsColor: NSColor(hex: (r << 16) | (g << 8) | b)))
            .frame(width: 16, height: 4)
    }
}
