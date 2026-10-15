import Foundation

public enum StripCatalog {
    private static let lock = NSLock()
    private static var cached: [StripTemplate]?

    public static var all: [StripTemplate] {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        let loaded = loadTemplates()
        cached = loaded
        return loaded
    }

    public static var standard10: StripTemplate {
        template(id: "standard10")
    }

    public static var compact4: StripTemplate {
        template(id: "compact4")
    }

    public static func template(id: String) -> StripTemplate {
        all.first { $0.id == id }
            ?? fallbackTemplates.first { $0.id == id }
            ?? fallbackStandard10
    }

    /// Test veya ölçek dosyası değişince önbelleği temizler.
    public static func reload() {
        lock.lock()
        cached = nil
        lock.unlock()
    }

    public static var userScalesDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Tahlil/scales", isDirectory: true)
    }

    private static func loadTemplates() -> [StripTemplate] {
        var byID: [String: StripTemplate] = [:]

        for url in bundledScaleURLs() {
            if let template = try? ScaleCodec.decode(from: url) {
                byID[template.id] = template
            }
        }

        let folder = userScalesDirectory
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if let urls = try? FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil
        ) {
            for url in urls where url.pathExtension.lowercased() == "json" {
                if let template = try? ScaleCodec.decode(from: url) {
                    byID[template.id] = template
                }
            }
        }

        let orderedIDs = ["standard10", "compact4"]
        var result: [StripTemplate] = []
        for id in orderedIDs {
            if let template = byID.removeValue(forKey: id) {
                result.append(template)
            }
        }
        result.append(contentsOf: byID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })

        if result.isEmpty {
            return fallbackTemplates
        }
        // JSON bulundu ama compact4 yoksa yerleşik yedeği ekle.
        if !result.contains(where: { $0.id == "compact4" }) {
            result.append(fallbackCompact4)
        }
        if !result.contains(where: { $0.id == "standard10" }) {
            result.insert(fallbackStandard10, at: 0)
        }
        return result
    }

    /// `Bundle.module` paketlenmiş .app içinde yoksa çöker; bu yüzden
    /// Resources ve SPM paket yolunu dosya sistemiyle arıyoruz.
    private static func bundledScaleURLs() -> [URL] {
        var roots: [URL] = []
        let bundleName = "Tahlil_TahlilCore.bundle"

        var bases: [URL] = []
        for bundle in Bundle.allBundles + [.main] {
            if let resources = bundle.resourceURL {
                bases.append(resources)
                roots.append(resources.appendingPathComponent("scales", isDirectory: true))
            }
            bases.append(bundle.bundleURL)
            if let nested = bundle.url(forResource: "Tahlil_TahlilCore", withExtension: "bundle") {
                bases.append(nested)
            }
        }

        // .app/Contents/MacOS → Contents/Resources; swift run komşu klasör
        let parent = Bundle.main.bundleURL.deletingLastPathComponent()
        bases.append(parent)
        bases.append(parent.appendingPathComponent("Resources", isDirectory: true))

        for base in bases {
            let bundleURL = base.appendingPathComponent(bundleName, isDirectory: true)
            roots.append(bundleURL.appendingPathComponent("Contents/Resources/scales", isDirectory: true))
            roots.append(bundleURL.appendingPathComponent("scales", isDirectory: true))
            if let bundle = Bundle(url: bundleURL), let resourceURL = bundle.resourceURL {
                roots.append(resourceURL.appendingPathComponent("scales", isDirectory: true))
            }
        }

        var files: [URL] = []
        var seen = Set<String>()
        for root in roots {
            guard
                let urls = try? FileManager.default.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: nil
                )
            else { continue }
            for url in urls where url.pathExtension.lowercased() == "json" {
                if seen.insert(url.lastPathComponent).inserted {
                    files.append(url)
                }
            }
        }
        return files.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// Kaynak paketi yoksa veya bozuksa kullanılan yerleşik yedekler.
    private static var fallbackTemplates: [StripTemplate] {
        [fallbackStandard10, fallbackCompact4]
    }

    private static var fallbackCompact4: StripTemplate {
        let order = ["glu", "pro", "ph", "ket"]
        let analytes = order.compactMap { id in
            fallbackStandard10.analytes.first { $0.id == id }
        }
        return StripTemplate(
            id: "compact4",
            name: "4 parametre",
            brand: "Yaklaşık referans",
            detail: "Sap üstteyken sıra: Glikoz, Protein, pH, Keton. Renkler yaklaşık referanstır.",
            readWaitSeconds: 60,
            analytes: analytes
        )
    }

    private static var fallbackStandard10: StripTemplate {
        StripTemplate(
            id: "standard10",
            name: "10 parametre",
            brand: "Yaklaşık referans",
            detail: "Sap üstteyken sıra, yaygın 10’lu idrar çubuğu düzenine göredir. Renkler yaklaşık referanstır.",
            readWaitSeconds: 60,
            analytes: [
                analyte("glu", "Glikoz", "GLU", [
                    ("Negatif", 158, 206, 196, true),
                    ("50 mg/dL", 176, 204, 140, false),
                    ("100 mg/dL", 150, 186, 92, false),
                    ("250 mg/dL", 124, 146, 58, false),
                    ("500 mg/dL", 96, 108, 42, false),
                    ("1000 mg/dL", 78, 70, 36, false),
                ]),
                analyte("bil", "Bilirubin", "BIL", [
                    ("Negatif", 246, 224, 170, true),
                    ("+", 228, 176, 146, false),
                    ("++", 196, 114, 124, false),
                    ("+++", 150, 72, 102, false),
                ]),
                analyte("ket", "Keton", "KET", [
                    ("Negatif", 240, 206, 156, true),
                    ("5 mg/dL", 236, 170, 148, true),
                    ("15 mg/dL", 214, 112, 136, false),
                    ("40 mg/dL", 168, 70, 114, false),
                    ("80 mg/dL", 112, 48, 92, false),
                ]),
                analyte("sg", "Dansite", "SG", [
                    ("1.000", 42, 96, 118, false),
                    ("1.005", 52, 128, 122, true),
                    ("1.010", 64, 156, 114, true),
                    ("1.015", 104, 176, 92, true),
                    ("1.020", 156, 184, 74, true),
                    ("1.025", 196, 186, 64, true),
                    ("1.030", 214, 176, 56, true),
                ]),
                analyte("blo", "Kan", "BLO", [
                    ("Negatif", 238, 198, 78, true),
                    ("Eser", 196, 170, 70, false),
                    ("25", 110, 158, 70, false),
                    ("80", 48, 124, 78, false),
                    ("200", 22, 86, 62, false),
                ]),
                analyte("ph", "pH", "pH", [
                    ("5.0", 232, 136, 48, true),
                    ("6.0", 236, 180, 56, true),
                    ("6.5", 214, 190, 64, true),
                    ("7.0", 170, 186, 78, true),
                    ("7.5", 110, 176, 96, true),
                    ("8.0", 64, 158, 118, true),
                    ("8.5", 46, 118, 138, false),
                    ("9.0", 36, 82, 138, false),
                ]),
                analyte("pro", "Protein", "PRO", [
                    ("Negatif", 236, 214, 96, true),
                    ("Eser", 206, 206, 90, true),
                    ("30 mg/dL", 150, 186, 96, false),
                    ("100 mg/dL", 72, 156, 112, false),
                    ("300 mg/dL", 36, 124, 124, false),
                    ("2000 mg/dL", 20, 86, 108, false),
                ]),
                analyte("uro", "Ürobilinojen", "URO", [
                    ("0.2 mg/dL", 246, 198, 156, true),
                    ("1 mg/dL", 232, 146, 136, false),
                    ("2 mg/dL", 206, 100, 120, false),
                    ("4 mg/dL", 168, 64, 104, false),
                    ("8 mg/dL", 124, 42, 86, false),
                ]),
                analyte("nit", "Nitrit", "NIT", [
                    ("Negatif", 246, 234, 206, true),
                    ("Pozitif", 236, 150, 164, false),
                    ("Güçlü pozitif", 196, 72, 112, false),
                ]),
                analyte("leu", "Lökosit", "LEU", [
                    ("Negatif", 240, 226, 186, true),
                    ("15", 236, 196, 176, false),
                    ("70", 214, 140, 156, false),
                    ("125", 176, 96, 140, false),
                    ("500", 132, 64, 120, false),
                ]),
            ]
        )
    }

    private static func analyte(
        _ id: String,
        _ name: String,
        _ abbreviation: String,
        _ rows: [(String, Int, Int, Int, Bool)]
    ) -> Analyte {
        let levels = rows.enumerated().map { index, row in
            ColorLevel(
                id: "\(id)-\(index)",
                valueText: row.0,
                rgb: RGB(bytes: row.1, row.2, row.3),
                isTypical: row.4
            )
        }
        return Analyte(id: id, name: name, abbreviation: abbreviation, levels: levels)
    }
}
