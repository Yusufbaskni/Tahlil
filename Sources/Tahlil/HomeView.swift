import SwiftUI
import TahlilCore

struct HomeView: View {
    let readings: [StripReading]
    let onCapture: () -> Void
    let onPhoto: () -> Void
    let onSample: () -> Void
    let onOpen: (StripReading) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("KAMERADAN ÇUBUK")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.1)
                        .foregroundStyle(Theme.teal)
                    Text("Çubuğu çerçeveye alın,\nrengi okuyun.")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Her pedin rengi, yerleşik referans skalasındaki en yakın basamakla eşleşir. Görüntü bu bilgisayardan çıkmaz.")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: 560, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button(action: onCapture) {
                        Label("Kamerayla oku", systemImage: "camera")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .keyboardShortcut(.defaultAction)

                    Button(action: onPhoto) {
                        Label("Fotoğraftan oku", systemImage: "photo")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Button(action: onSample) {
                        Label("Örnek şeritle dene", systemImage: "rectangle.split.3x1")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                HStack(alignment: .top, spacing: 12) {
                    note("1", "Işık", "Gün ışığına yakın, gölgesiz ve düz bir zemin kullanın.")
                    note("2", "Bekle", "Islattıktan sonra şablonun süresini bekleyin; erken çekim sonucu bozar.")
                    note("3", "Sonuç", "Düşük güven yazılmaz. Seviye bir tanı değildir.")
                }

                if !readings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Son okumalar")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                        ForEach(readings.prefix(4)) { reading in
                            Button {
                                onOpen(reading)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(reading.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .foregroundStyle(Theme.ink)
                                        Text(reading.summaryText)
                                            .foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    if reading.source == .sample {
                                        badge("Örnek")
                                    } else if reading.source == .photo {
                                        badge("Fotoğraf")
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Theme.muted)
                                }
                                .font(.system(size: 13))
                                .padding(12)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Theme.line, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: 640, alignment: .leading)
                }
            }
            .padding(36)
            .frame(maxWidth: 860, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func note(_ index: String, _ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(index)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.teal)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.ink)
            Text(body)
                .font(.system(size: 13))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.line, lineWidth: 1)
        )
    }

    private func badge(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.teal)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.teal.opacity(0.12), in: Capsule())
    }
}
