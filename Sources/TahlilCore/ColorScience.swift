import Foundation

public enum ColorScience {
    /// Bu eşiğin altındaki eşleşmeler seviye yazmaz; "Okunamadı" döner.
    public static let minimumConfidence = 0.45

    public static func deltaE(_ lhs: RGB, _ rhs: RGB) -> Double {
        let a = lab(lhs)
        let b = lab(rhs)
        let dL = a.L - b.L
        let da = a.a - b.a
        let db = a.b - b.b
        return (dL * dL + da * da + db * db).squareRoot()
    }

    public static func lightness(_ rgb: RGB) -> Double {
        lab(rgb).L
    }

    /// CIE76. 0 aynı renk, yaklaşık 45 birbirinden belirgin biçimde uzak.
    public static func confidence(forDeltaE deltaE: Double) -> Double {
        min(1, max(0, 1 - (deltaE / 45)))
    }

    public static func nearest(to sample: RGB, in levels: [ColorLevel]) -> (level: ColorLevel, deltaE: Double)? {
        guard let first = levels.first else { return nil }
        var best = first
        var bestDistance = deltaE(sample, first.rgb)
        for level in levels.dropFirst() {
            let distance = deltaE(sample, level.rgb)
            if distance < bestDistance {
                best = level
                bestDistance = distance
            }
        }
        return (best, bestDistance)
    }

    public static func isConfident(_ confidence: Double) -> Bool {
        confidence >= minimumConfidence
    }

    private static func lab(_ rgb: RGB) -> (L: Double, a: Double, b: Double) {
        func linearize(_ channel: Double) -> Double {
            if channel <= 0.04045 {
                return channel / 12.92
            }
            return pow((channel + 0.055) / 1.055, 2.4)
        }

        let red = linearize(rgb.r)
        let green = linearize(rgb.g)
        let blue = linearize(rgb.b)

        var x = red * 0.4124564 + green * 0.3575761 + blue * 0.1804375
        let y = red * 0.2126729 + green * 0.7151522 + blue * 0.0721750
        var z = red * 0.0193339 + green * 0.1191920 + blue * 0.9503041

        x /= 0.95047
        z /= 1.08883

        func pivot(_ t: Double) -> Double {
            if t > 0.008856 {
                return pow(t, 1.0 / 3.0)
            }
            return (7.787 * t) + (16.0 / 116.0)
        }

        let fx = pivot(x)
        let fy = pivot(y)
        let fz = pivot(z)
        return (116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz))
    }
}
