import Foundation

struct ScaleFile: Codable {
    var id: String
    var name: String
    var brand: String?
    var detail: String
    var readWaitSeconds: Int
    var analytes: [AnalyteFile]
}

struct AnalyteFile: Codable {
    var id: String
    var name: String
    var abbreviation: String
    var levels: [LevelFile]
}

struct LevelFile: Codable {
    var valueText: String
    var r: Int
    var g: Int
    var b: Int
    var isTypical: Bool
}

public enum ScaleCodec {
    public static func decode(_ data: Data) throws -> StripTemplate {
        let file = try JSONDecoder().decode(ScaleFile.self, from: data)
        return template(from: file)
    }

    public static func decode(from url: URL) throws -> StripTemplate {
        try decode(Data(contentsOf: url))
    }

    public static func encode(_ template: StripTemplate) throws -> Data {
        let file = ScaleFile(
            id: template.id,
            name: template.name,
            brand: template.brand,
            detail: template.detail,
            readWaitSeconds: template.readWaitSeconds,
            analytes: template.analytes.map { analyte in
                AnalyteFile(
                    id: analyte.id,
                    name: analyte.name,
                    abbreviation: analyte.abbreviation,
                    levels: analyte.levels.map { level in
                        LevelFile(
                            valueText: level.valueText,
                            r: Int((level.rgb.r * 255).rounded()),
                            g: Int((level.rgb.g * 255).rounded()),
                            b: Int((level.rgb.b * 255).rounded()),
                            isTypical: level.isTypical
                        )
                    }
                )
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    static func template(from file: ScaleFile) -> StripTemplate {
        let analytes = file.analytes.map { analyte in
            let levels = analyte.levels.enumerated().map { index, level in
                ColorLevel(
                    id: "\(analyte.id)-\(index)",
                    valueText: level.valueText,
                    rgb: RGB(bytes: level.r, level.g, level.b),
                    isTypical: level.isTypical
                )
            }
            return Analyte(
                id: analyte.id,
                name: analyte.name,
                abbreviation: analyte.abbreviation,
                levels: levels
            )
        }
        return StripTemplate(
            id: file.id,
            name: file.name,
            brand: file.brand,
            detail: file.detail,
            readWaitSeconds: max(0, file.readWaitSeconds),
            analytes: analytes
        )
    }
}
