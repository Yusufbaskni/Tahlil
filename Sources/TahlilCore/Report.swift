import Foundation

extension StripReading {
    public var reportText: String {
        let formatter = ISO8601DateFormatter()
        var lines: [String] = []
        lines.append("Tahlil okuma")
        lines.append("Tarih: \(formatter.string(from: createdAt))")
        lines.append("Şablon: \(templateName)")
        lines.append("Kaynak: \(sourceLabel)")
        if reversed {
            lines.append("Ped sırası ters çevrildi.")
        }
        lines.append("")
        lines.append(summaryText)
        if let lightingWarning {
            lines.append(lightingWarning)
        }
        lines.append("")
        for pad in pads {
            let confidence = Int((pad.confidence * 100).rounded())
            let trust: String
            if !pad.isReadable {
                trust = pad.isLowConfidence ? "düşük güven — yazılmadı" : "okunamadı"
            } else if pad.showsOutsideTypical {
                trust = "tipik aralık dışı"
            } else {
                trust = "tipik aralık"
            }
            let label = pad.isReadable ? pad.valueText : "Okunamadı"
            lines.append("\(pad.name) (\(pad.abbreviation)): \(label) — %\(confidence), \(trust)")
        }
        lines.append("")
        lines.append(Copy.disclaimer)
        return lines.joined(separator: "\n")
    }

    private var sourceLabel: String {
        switch source {
        case .camera: "Kamera"
        case .sample: "Örnek şerit"
        case .photo: "Fotoğraf"
        }
    }
}
