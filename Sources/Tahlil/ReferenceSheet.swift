import SwiftUI
import TahlilCore

struct ReferenceSheet: View {
    let template: StripTemplate
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Referans skalası")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    if let brand = template.brand {
                        Text(brand)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.teal)
                    }
                    Text(template.detail)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Bekleme: \(template.readWaitSeconds) sn · ölçek klasörü: Application Support/Tahlil/scales")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                Button("Kapat") { dismiss() }
                    .buttonStyle(SecondaryButtonStyle())
                    .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(template.analytes) { analyte in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(analyte.name) · \(analyte.abbreviation)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.ink)
                            HStack(alignment: .top, spacing: 8) {
                                ForEach(analyte.levels) { level in
                                    VStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                                            .fill(level.rgb.color)
                                            .frame(width: 54, height: 28)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .strokeBorder(Theme.line, lineWidth: 1)
                                            )
                                        Text(level.valueText)
                                            .font(.system(size: 10))
                                            .foregroundStyle(Theme.muted)
                                            .multilineTextAlignment(.center)
                                            .frame(width: 64)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 520)
        .background(Theme.paper)
    }
}
