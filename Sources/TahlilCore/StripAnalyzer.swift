import CoreGraphics
import Foundation

public enum StripAnalyzer {
    public static func analyze(
        stripImage: CGImage,
        template: StripTemplate,
        reversed: Bool,
        source: ReadingSource,
        guide: CGRect
    ) -> StripReading {
        let analytes = template.ordered(reversed: reversed)
        let pads = analytes.enumerated().map { index, analyte in
            padResult(image: stripImage, analyte: analyte, index: index, count: analytes.count)
        }

        let readable = pads.filter(\.isReadable)
        let meanLightness: Double
        if readable.isEmpty {
            meanLightness = pads
                .map { ColorScience.lightness($0.sampled) }
                .reduce(0, +) / Double(max(pads.count, 1))
        } else {
            meanLightness = readable
                .map { ColorScience.lightness($0.sampled) }
                .reduce(0, +) / Double(readable.count)
        }

        var warnings: [String] = []
        if readable.isEmpty {
            warnings.append("Ped renkleri güvenilir okunamadı. Çubuğu çerçeveye yeniden hizalayıp çekin.")
        } else if pads.filter({ !$0.isReadable }).count > 0 {
            warnings.append("Bazı pedler düşük güven nedeniyle yazılmadı. Yeniden çekmeyi deneyin.")
        }
        if meanLightness < 20 {
            warnings.append("Görüntü çok karanlık. Çubuğu daha aydınlık ve gölgesiz bir yere alın.")
        } else if meanLightness > 90 {
            warnings.append("Görüntü çok parlak. Parlamayı azaltıp yeniden çekin.")
        }
        if source == .photo {
            warnings.append("Fotoğrafta ıslatma bekleme süresi doğrulanamaz.")
        }

        return StripReading(
            templateID: template.id,
            templateName: template.displayName,
            reversed: reversed,
            source: source,
            guide: NormalizedGuide(guide),
            pads: pads,
            lightingWarning: warnings.isEmpty ? nil : warnings.joined(separator: " ")
        )
    }

    private static func padResult(
        image: CGImage,
        analyte: Analyte,
        index: Int,
        count: Int
    ) -> PadResult {
        let bandHeight = 1.0 / Double(count)
        let insetX = 0.18
        let insetY = 0.22
        let rect = CGRect(
            x: insetX,
            y: (Double(index) * bandHeight) + (bandHeight * insetY),
            width: 1 - (insetX * 2),
            height: bandHeight * (1 - (insetY * 2))
        )

        guard
            let crop = ImageOps.cropping(image, toNormalized: rect),
            let sample = ImageOps.averageColor(crop),
            let match = ColorScience.nearest(to: sample, in: analyte.levels)
        else {
            let fallback = analyte.levels.first?.rgb ?? RGB(bytes: 0, 0, 0)
            return PadResult(
                analyteID: analyte.id,
                name: analyte.name,
                abbreviation: analyte.abbreviation,
                valueText: "Okunamadı",
                isTypical: true,
                isReadable: false,
                confidence: 0,
                deltaE: 999,
                sampled: fallback,
                matched: fallback
            )
        }

        let confidence = ColorScience.confidence(forDeltaE: match.deltaE)
        let confident = ColorScience.isConfident(confidence)

        return PadResult(
            analyteID: analyte.id,
            name: analyte.name,
            abbreviation: analyte.abbreviation,
            valueText: confident ? match.level.valueText : "Okunamadı",
            isTypical: confident ? match.level.isTypical : true,
            isReadable: confident,
            confidence: confidence,
            deltaE: match.deltaE,
            sampled: sample,
            matched: match.level.rgb
        )
    }
}
