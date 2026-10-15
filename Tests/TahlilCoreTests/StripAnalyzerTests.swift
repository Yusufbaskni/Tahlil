import CoreGraphics
import XCTest
import TahlilCore

final class StripAnalyzerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        StripCatalog.reload()
    }

    func testTopBandIsTheColorDrawnAtTheTop() throws {
        let image = try XCTUnwrap(ImageOps.makeImage(width: 80, height: 200) { context in
            ImageOps.fill(context, CGRect(x: 0, y: 0, width: 80, height: 100), RGB(bytes: 220, 30, 30))
            ImageOps.fill(context, CGRect(x: 0, y: 100, width: 80, height: 100), RGB(bytes: 30, 40, 210))
        })

        let top = try XCTUnwrap(ImageOps.cropping(image, toNormalized: CGRect(x: 0, y: 0, width: 1, height: 0.2)))
        let bottom = try XCTUnwrap(ImageOps.cropping(image, toNormalized: CGRect(x: 0, y: 0.8, width: 1, height: 0.2)))
        let topColor = try XCTUnwrap(ImageOps.averageColor(top))
        let bottomColor = try XCTUnwrap(ImageOps.averageColor(bottom))

        XCTAssertGreaterThan(topColor.r, 0.75)
        XCTAssertLessThan(topColor.b, 0.2)
        XCTAssertGreaterThan(bottomColor.b, 0.75)
        XCTAssertLessThan(bottomColor.r, 0.2)
    }

    func testIdenticalColorsHaveNoDistance() {
        let color = RGB(bytes: 10, 20, 30)
        XCTAssertEqual(ColorScience.deltaE(color, color), 0, accuracy: 0.0001)
        XCTAssertEqual(ColorScience.confidence(forDeltaE: 0), 1, accuracy: 0.0001)
    }

    func testDemoStripMatchesChosenLevels() throws {
        let template = StripCatalog.standard10
        let guide = StripGuide.normalized(widthFraction: 0.22, heightFraction: 0.86)
        let made = try XCTUnwrap(SampleStrip.make(template: template, reversed: false, guide: guide))

        XCTAssertEqual(made.reading.pads.count, 10)
        XCTAssertEqual(made.reading.pads.first?.analyteID, "glu")
        XCTAssertNil(made.reading.lightingWarning)
        XCTAssertGreaterThan(SampleStrip.demoChoices.values.filter { $0 > 0 }.count, 3)

        for analyte in template.analytes {
            let index = try XCTUnwrap(SampleStrip.demoChoices[analyte.id])
            let expected = analyte.levels[index].valueText
            let pad = made.reading.pads.first { $0.analyteID == analyte.id }
            XCTAssertEqual(pad?.valueText, expected, analyte.name)
            XCTAssertGreaterThan(pad?.confidence ?? 0, 0.8, analyte.name)
            XCTAssertTrue(pad?.isReadable ?? false, analyte.name)
            XCTAssertFalse(pad?.isLowConfidence ?? true, analyte.name)
        }

        XCTAssertTrue(made.reading.pads.first { $0.analyteID == "glu" }?.showsOutsideTypical ?? false)
        XCTAssertFalse(made.reading.pads.first { $0.analyteID == "bil" }?.showsOutsideTypical ?? true)
        XCTAssertTrue(made.reading.reportText.contains(Copy.disclaimer))
        XCTAssertEqual(made.reading.outsideTypicalCount, 4)
    }

    func testLowConfidenceDoesNotWriteALevel() throws {
        let levels = [
            ColorLevel(id: "a-0", valueText: "Negatif", rgb: RGB(bytes: 240, 230, 200), isTypical: true),
            ColorLevel(id: "a-1", valueText: "Pozitif", rgb: RGB(bytes: 200, 80, 120), isTypical: false),
        ]
        let analyte = Analyte(id: "a", name: "Test", abbreviation: "T", levels: levels)
        let template = StripTemplate(
            id: "low-conf",
            name: "Low",
            detail: "test",
            readWaitSeconds: 30,
            analytes: [analyte]
        )
        let image = try XCTUnwrap(ImageOps.makeImage(width: 40, height: 80) { context in
            ImageOps.fill(context, CGRect(x: 0, y: 0, width: 40, height: 80), RGB(bytes: 20, 40, 180))
        })
        let reading = StripAnalyzer.analyze(
            stripImage: image,
            template: template,
            reversed: false,
            source: .camera,
            guide: CGRect(x: 0, y: 0, width: 1, height: 1)
        )
        let pad = try XCTUnwrap(reading.pads.first)
        XCTAssertFalse(pad.isReadable)
        XCTAssertEqual(pad.valueText, "Okunamadı")
        XCTAssertLessThan(pad.confidence, ColorScience.minimumConfidence)
        XCTAssertTrue(pad.isLowConfidence)
        XCTAssertTrue(reading.needsRecapture)
    }

    func testPhotoSourceAddsTimingDisclaimer() throws {
        let template = StripCatalog.standard10
        let guide = StripGuide.normalized(widthFraction: 0.22, heightFraction: 0.86)
        let photo = try XCTUnwrap(SampleStrip.demoPhoto(template: template, reversed: false, guide: guide))
        let strip = try XCTUnwrap(ImageOps.cropping(photo, toNormalized: guide))
        let reading = StripAnalyzer.analyze(
            stripImage: strip,
            template: template,
            reversed: false,
            source: .photo,
            guide: guide
        )
        XCTAssertEqual(reading.source, .photo)
        XCTAssertTrue(reading.lightingWarning?.contains("bekleme") ?? false)
        XCTAssertTrue(reading.reportText.contains("Fotoğraf"))
    }

    func testReversedOrderReadsTheBottomAnalyteFirst() throws {
        let template = StripCatalog.standard10
        let guide = StripGuide.normalized(widthFraction: 0.22, heightFraction: 0.86)
        let made = try XCTUnwrap(SampleStrip.make(template: template, reversed: true, guide: guide))
        XCTAssertEqual(made.reading.pads.first?.analyteID, "leu")
        XCTAssertEqual(made.reading.pads.last?.analyteID, "glu")
        XCTAssertEqual(made.reading.pads.first?.valueText, "125")
    }

    func testAspectFitCentersAWideImage() {
        let rect = GuideGeometry.aspectFit(
            container: CGSize(width: 100, height: 100),
            image: CGSize(width: 200, height: 100)
        )
        XCTAssertEqual(rect, CGRect(x: 0, y: 25, width: 100, height: 50))
    }

    func testCaptureTimingGate() {
        XCTAssertFalse(CaptureTiming.isReady(waitSeconds: 60, startedAt: nil))
        XCTAssertEqual(
            CaptureTiming.remainingSeconds(waitSeconds: 60, startedAt: nil),
            nil
        )

        let started = Date().addingTimeInterval(-10)
        XCTAssertEqual(
            CaptureTiming.remainingSeconds(waitSeconds: 60, startedAt: started),
            50
        )
        XCTAssertFalse(CaptureTiming.isReady(waitSeconds: 60, startedAt: started))

        let done = Date().addingTimeInterval(-90)
        XCTAssertEqual(CaptureTiming.remainingSeconds(waitSeconds: 60, startedAt: done), 0)
        XCTAssertTrue(CaptureTiming.isReady(waitSeconds: 60, startedAt: done))
        XCTAssertTrue(CaptureTiming.isReady(waitSeconds: 60, startedAt: nil, skipWait: true))
        XCTAssertTrue(CaptureTiming.isReady(waitSeconds: 0, startedAt: nil))
    }

    func testBundledCatalogLoadsWaitSecondsAndBrand() {
        let template = StripCatalog.standard10
        XCTAssertEqual(template.id, "standard10")
        XCTAssertEqual(template.readWaitSeconds, 60)
        XCTAssertEqual(template.brand, "Yaklaşık referans")
        XCTAssertEqual(template.analytes.count, 10)
        XCTAssertTrue(StripCatalog.all.map(\.id).contains("compact4"))
        XCTAssertEqual(StripCatalog.compact4.readWaitSeconds, 60)
        XCTAssertEqual(StripCatalog.compact4.analytes.map(\.id), ["glu", "pro", "ph", "ket"])
    }

    func testScaleCodecRoundTripAndUserOverride() throws {
        let original = StripCatalog.standard10
        let data = try ScaleCodec.encode(original)
        let decoded = try ScaleCodec.decode(data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.readWaitSeconds, original.readWaitSeconds)
        XCTAssertEqual(decoded.analytes.count, original.analytes.count)
        XCTAssertEqual(decoded.analytes.first?.levels.first?.valueText, "Negatif")

        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("tahlil-scales-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let override = StripTemplate(
            id: "standard10",
            name: "10 parametre",
            brand: "Test Marka",
            detail: "override",
            readWaitSeconds: 45,
            analytes: original.analytes
        )
        try ScaleCodec.encode(override).write(to: folder.appendingPathComponent("standard10.json"))

        // Simulate catalog merge order: bundled then user
        let fromUser = try ScaleCodec.decode(from: folder.appendingPathComponent("standard10.json"))
        XCTAssertEqual(fromUser.brand, "Test Marka")
        XCTAssertEqual(fromUser.readWaitSeconds, 45)
    }

    func testArchiveRoundTrip() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("tahlil-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let guide = StripGuide.normalized(widthFraction: 0.22, heightFraction: 0.86)
        let made = try XCTUnwrap(SampleStrip.make(template: StripCatalog.standard10, reversed: false, guide: guide))
        let file = folder.appendingPathComponent("history.json")
        ReadingArchive.save([made.reading], to: file)
        ReadingArchive.saveImage(made.photo, id: made.reading.id, directory: folder)

        let loaded = try XCTUnwrap(ReadingArchive.load(from: file).first)
        XCTAssertEqual(loaded.id, made.reading.id)
        XCTAssertEqual(loaded.pads.map(\.valueText), made.reading.pads.map(\.valueText))
        XCTAssertEqual(loaded.templateName, made.reading.templateName)
        XCTAssertEqual(
            loaded.createdAt.timeIntervalSince1970,
            made.reading.createdAt.timeIntervalSince1970,
            accuracy: 1
        )
        let image = try XCTUnwrap(ReadingArchive.loadImage(id: made.reading.id, directory: folder))
        XCTAssertGreaterThan(image.width, 100)
        XCTAssertGreaterThan(image.height, 100)
    }
}
