import CoreGraphics
import Foundation

public struct RGB: Equatable, Codable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = min(max(r, 0), 1)
        self.g = min(max(g, 0), 1)
        self.b = min(max(b, 0), 1)
    }

    public init(bytes r: Int, _ g: Int, _ b: Int) {
        self.init(
            r: Double(r) / 255,
            g: Double(g) / 255,
            b: Double(b) / 255
        )
    }
}

public struct ColorLevel: Equatable, Identifiable {
    public let id: String
    public let valueText: String
    public let rgb: RGB
    public let isTypical: Bool

    public init(id: String, valueText: String, rgb: RGB, isTypical: Bool) {
        self.id = id
        self.valueText = valueText
        self.rgb = rgb
        self.isTypical = isTypical
    }
}

public struct Analyte: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let abbreviation: String
    public let levels: [ColorLevel]

    public init(id: String, name: String, abbreviation: String, levels: [ColorLevel]) {
        self.id = id
        self.name = name
        self.abbreviation = abbreviation
        self.levels = levels
    }
}

public struct StripTemplate: Equatable, Identifiable {
    public let id: String
    public let name: String
    public let brand: String?
    public let detail: String
    /// Islatma sonrası kamera çekimi için beklenmesi gereken saniye.
    public let readWaitSeconds: Int
    public let analytes: [Analyte]

    public init(
        id: String,
        name: String,
        brand: String? = nil,
        detail: String,
        readWaitSeconds: Int = 60,
        analytes: [Analyte]
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.detail = detail
        self.readWaitSeconds = readWaitSeconds
        self.analytes = analytes
    }

    public var displayName: String {
        if let brand, !brand.isEmpty {
            return "\(name) · \(brand)"
        }
        return name
    }

    public func ordered(reversed: Bool) -> [Analyte] {
        reversed ? Array(analytes.reversed()) : analytes
    }
}

public struct NormalizedGuide: Equatable, Codable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(_ rect: CGRect) {
        self.init(x: rect.origin.x, y: rect.origin.y, width: rect.width, height: rect.height)
    }

    public var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

public enum ReadingSource: String, Equatable, Codable {
    case camera
    case sample
    case photo
}

public struct PadResult: Equatable, Identifiable, Codable {
    public let analyteID: String
    public let name: String
    public let abbreviation: String
    public let valueText: String
    public let isTypical: Bool
    public let isReadable: Bool
    public let confidence: Double
    public let deltaE: Double
    public let sampled: RGB
    public let matched: RGB

    public var id: String { analyteID }

    public var isLowConfidence: Bool {
        !isReadable && deltaE < 900 && confidence < ColorScience.minimumConfidence
    }

    /// Düşük güvenli eşleşmeler aralık dışı diye işaretlenmez; fotoğraf
    /// bozukken yanlış alarm üretmemek için.
    public var showsOutsideTypical: Bool {
        isReadable && !isTypical
    }

    public init(
        analyteID: String,
        name: String,
        abbreviation: String,
        valueText: String,
        isTypical: Bool,
        isReadable: Bool,
        confidence: Double,
        deltaE: Double,
        sampled: RGB,
        matched: RGB
    ) {
        self.analyteID = analyteID
        self.name = name
        self.abbreviation = abbreviation
        self.valueText = valueText
        self.isTypical = isTypical
        self.isReadable = isReadable
        self.confidence = confidence
        self.deltaE = deltaE
        self.sampled = sampled
        self.matched = matched
    }
}

public struct StripReading: Equatable, Identifiable, Codable {
    public let id: UUID
    public let createdAt: Date
    public let templateID: String
    public let templateName: String
    public let reversed: Bool
    public let source: ReadingSource
    public let guide: NormalizedGuide
    public let pads: [PadResult]
    public let lightingWarning: String?

    public var outsideTypicalCount: Int {
        pads.filter(\.showsOutsideTypical).count
    }

    public var unreadCount: Int {
        pads.filter { !$0.isReadable }.count
    }

    public var needsRecapture: Bool {
        unreadCount > 0 && unreadCount * 2 >= pads.count
    }

    public var summaryText: String {
        if needsRecapture {
            return "Çoğu ped okunamadı. Yeniden çekin."
        }
        let count = outsideTypicalCount
        if count == 0 {
            return "Tipik aralık dışında güvenilir eşleşme yok."
        }
        if count == 1 {
            return "1 ped tipik aralığın dışında."
        }
        return "\(count) ped tipik aralığın dışında."
    }

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        templateID: String,
        templateName: String,
        reversed: Bool,
        source: ReadingSource,
        guide: NormalizedGuide,
        pads: [PadResult],
        lightingWarning: String?
    ) {
        self.id = id
        self.createdAt = createdAt
        self.templateID = templateID
        self.templateName = templateName
        self.reversed = reversed
        self.source = source
        self.guide = guide
        self.pads = pads
        self.lightingWarning = lightingWarning
    }
}

public enum Copy {
    public static let disclaimer = "Bu uygulama klinik tanı koymaz. Sonuç bir renk eşleşmesidir; aydınlatmaya ve çubuk markasına göre değişir. Sağlık kararı için laboratuvar testi ve hekim değerlendirmesi gerekir."
}
