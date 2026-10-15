import CoreGraphics
import Foundation

public enum SampleStrip {
    public static let demoChoices: [String: Int] = [
        "glu": 3,
        "bil": 0,
        "ket": 0,
        "sg": 3,
        "blo": 0,
        "ph": 1,
        "pro": 2,
        "uro": 0,
        "nit": 1,
        "leu": 3,
    ]

    public static func choices(for template: StripTemplate) -> [String: Int] {
        var result: [String: Int] = [:]
        for analyte in template.analytes {
            let index = demoChoices[analyte.id] ?? 0
            result[analyte.id] = min(index, max(analyte.levels.count - 1, 0))
        }
        return result
    }

    public static func make(
        template: StripTemplate,
        reversed: Bool,
        guide: CGRect
    ) -> (photo: CGImage, reading: StripReading)? {
        guard let photo = demoPhoto(template: template, reversed: reversed, guide: guide),
              let strip = ImageOps.cropping(photo, toNormalized: guide) else {
            return nil
        }
        let reading = StripAnalyzer.analyze(
            stripImage: strip,
            template: template,
            reversed: reversed,
            source: .sample,
            guide: guide
        )
        return (photo, reading)
    }

    public static func demoPhoto(
        template: StripTemplate,
        reversed: Bool,
        guide: CGRect
    ) -> CGImage? {
        let width = 900
        let height = 1400
        let ordered = template.ordered(reversed: reversed)
        let choices = choices(for: template)

        return ImageOps.makeImage(width: width, height: height) { context in
            let canvas = CGRect(x: 0, y: 0, width: width, height: height)
            ImageOps.fill(context, canvas, RGB(bytes: 183, 177, 164))

            let guidePixels = CGRect(
                x: guide.origin.x * CGFloat(width),
                y: guide.origin.y * CGFloat(height),
                width: guide.width * CGFloat(width),
                height: guide.height * CGFloat(height)
            )

            let plastic = guidePixels.insetBy(dx: -18, dy: -22)
            let handleTop = max(12, guidePixels.minY - 140)
            let handle = CGRect(
                x: guidePixels.midX - guidePixels.width * 0.34,
                y: handleTop,
                width: guidePixels.width * 0.68,
                height: max(0, guidePixels.minY - handleTop - 8)
            )
            ImageOps.fill(context, handle, RGB(bytes: 236, 232, 224))
            ImageOps.fill(context, plastic, RGB(bytes: 244, 240, 232))

            let count = CGFloat(max(ordered.count, 1))
            let bandHeight = guidePixels.height / count
            for (index, analyte) in ordered.enumerated() {
                let levelIndex = choices[analyte.id] ?? 0
                guard analyte.levels.indices.contains(levelIndex) else { continue }
                let gap = bandHeight * 0.08
                let pad = CGRect(
                    x: guidePixels.minX,
                    y: guidePixels.minY + (CGFloat(index) * bandHeight) + gap,
                    width: guidePixels.width,
                    height: max(1, bandHeight - (gap * 2))
                )
                ImageOps.fill(context, pad, analyte.levels[levelIndex].rgb)
            }
        }
    }
}
