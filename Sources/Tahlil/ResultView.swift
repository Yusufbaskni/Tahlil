import AppKit
import SwiftUI
import TahlilCore
import UniformTypeIdentifiers

struct ResultView: View {
    let reading: StripReading
    let image: NSImage?
    let onBack: () -> Void
    let onNew: () -> Void

    @State private var showReference = false

    private var template: StripTemplate {
        StripCatalog.template(id: reading.templateID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 20) {
                    photo
                    report
                }
                VStack(alignment: .leading, spacing: 20) {
                    photo
                    report
                }
            }
        }
        .padding(28)
        .sheet(isPresented: $showReference) {
            ReferenceSheet(template: template)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            BackButton(action: onBack)

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reading.summaryText)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("\(reading.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(reading.templateName)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Button("Renk skalası") { showReference = true }
                    .buttonStyle(SecondaryButtonStyle())
                Button(action: onNew) {
                    Label("Yeni okuma", systemImage: "camera")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let image {
            FramedPhoto(image: image, guide: reading.guide.cgRect) {
                GuideChrome(analytes: template.ordered(reversed: reading.reversed))
            }
            .frame(minWidth: 280, maxWidth: 460, minHeight: 360, maxHeight: 560)
            .background(Color.black, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var report: some View {
        VStack(alignment: .leading, spacing: 12) {
            if reading.needsRecapture {
                banner("Çoğu ped güvenilir okunamadı. Işık ve hizayı düzeltip yeniden çekin.", tint: Theme.coral)
            }
            if reading.source == .sample {
                banner("Bu sonuç yerleşik örnek şeritten üretildi.", tint: Theme.teal)
            } else if reading.source == .photo {
                banner("Bu sonuç bir fotoğraftan üretildi. Bekleme süresi doğrulanamaz.", tint: Theme.teal)
            }
            if let lightingWarning = reading.lightingWarning {
                banner(lightingWarning, tint: Theme.coral)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 0) {
                GridRow {
                    headerCell("Ped")
                    headerCell("Okunan / skala")
                    headerCell("Seviye")
                    headerCell("Güven")
                    headerCell("Durum")
                }
                .padding(.bottom, 6)

                ForEach(reading.pads) { pad in
                    GridRow {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(pad.name)
                                .foregroundStyle(Theme.ink)
                            Text(pad.abbreviation)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.muted)
                        }
                        HStack(spacing: 4) {
                            swatch(pad.sampled.color)
                            swatch(pad.matched.color)
                        }
                        Text(pad.isReadable ? pad.valueText : "Okunamadı")
                            .foregroundStyle(Theme.ink)
                        Text("%\(Int((pad.confidence * 100).rounded()))")
                            .foregroundStyle(Theme.muted)
                        status(pad)
                    }
                    .font(.system(size: 13))
                    .padding(.vertical, 7)
                    Divider()
                        .gridCellColumns(5)
                        .overlay(Theme.line)
                }
            }

            HStack(spacing: 8) {
                Button("Metni kaydet", action: saveReport)
                    .buttonStyle(SecondaryButtonStyle())
                Spacer()
            }

            Text(Copy.disclaimer)
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.line, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func headerCell(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.muted)
    }

    private func swatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color)
            .frame(width: 22, height: 16)
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
    }

    private func status(_ pad: PadResult) -> some View {
        let title: String
        let tint: Color
        if !pad.isReadable {
            title = pad.isLowConfidence ? "Yeniden çek" : "Okunamadı"
            tint = Theme.muted
        } else if pad.showsOutsideTypical {
            title = "Aralık dışı"
            tint = Theme.coral
        } else {
            title = "Tipik"
            tint = Theme.good
        }
        return Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tint)
    }

    private func banner(_ text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(Theme.ink)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func saveReport() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "tahlil.txt"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? reading.reportText.write(to: url, atomically: true, encoding: .utf8)
        }
    }
}
