import AppKit
import SwiftUI
import TahlilCore

enum Theme {
    static let paper = dynamic(light: 0xF3F1EB, dark: 0x12161B)
    static let rail = dynamic(light: 0xE7E1D6, dark: 0x0E1216)
    static let card = dynamic(light: 0xFFFCF8, dark: 0x1B2128)
    static let ink = dynamic(light: 0x1C2430, dark: 0xF3F0EA)
    static let muted = dynamic(light: 0x5C6B7A, dark: 0xA7B1BD)
    static let line = dynamic(light: 0xE3DDD2, dark: 0x2C343D)
    static let teal = dynamic(light: 0x0E6B66, dark: 0x2AABB0)
    static let button = dynamic(light: 0x0E6B66, dark: 0x148F89)
    static let coral = dynamic(light: 0xB94A38, dark: 0xE07A68)
    static let good = dynamic(light: 0x2E7D4F, dark: 0x7DCEA0)

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return NSColor(hex: match == .darkAqua ? dark : light)
        }))
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension RGB {
    var color: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Theme.button.opacity(configuration.isPressed ? 0.82 : 1),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Theme.card.opacity(configuration.isPressed ? 0.7 : 1),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.line, lineWidth: 1)
            )
    }
}

struct BackButton: View {
    var title: String = "Geri"
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "chevron.backward")
        }
        .buttonStyle(SecondaryButtonStyle())
        .keyboardShortcut(.cancelAction)
        .help(title)
    }
}
