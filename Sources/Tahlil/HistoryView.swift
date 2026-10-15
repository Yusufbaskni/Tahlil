import SwiftUI
import TahlilCore

struct HistoryView: View {
    @EnvironmentObject private var history: HistoryStore
    let onBack: () -> Void
    let onOpen: (StripReading) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BackButton(action: onBack)

            Text("Geçmiş")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.ink)

            if history.readings.isEmpty {
                Text("Henüz kayıtlı okuma yok. Kamerayla veya örnek şeritle bir okuma yaptığınızda burada durur.")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: 460, alignment: .leading)
                Spacer()
            } else {
                List {
                    ForEach(history.readings) { reading in
                        HStack(spacing: 12) {
                            Button {
                                onOpen(reading)
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(reading.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .foregroundStyle(Theme.ink)
                                        Text("\(reading.templateName) · \(reading.summaryText)")
                                            .foregroundStyle(Theme.muted)
                                    }
                                    Spacer()
                                    if reading.source == .sample {
                                        Text("Örnek")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Theme.teal)
                                    } else if reading.source == .photo {
                                        Text("Fotoğraf")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Theme.teal)
                                    }
                                    if reading.outsideTypicalCount > 0 {
                                        Text("\(reading.outsideTypicalCount)")
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                            .frame(width: 22, height: 22)
                                            .background(Theme.coral, in: Circle())
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            Button(role: .destructive) {
                                history.delete(reading)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(Theme.muted)
                            }
                            .buttonStyle(.borderless)
                            .help("Okumayı sil")
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
