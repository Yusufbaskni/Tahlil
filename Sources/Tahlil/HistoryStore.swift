import AppKit
import Foundation
import TahlilCore

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var readings: [StripReading] = []

    init() {
        readings = ReadingArchive.load()
    }

    func add(_ reading: StripReading, image: CGImage?) {
        readings.insert(reading, at: 0)
        if readings.count > 100 {
            for dropped in readings.suffix(from: 100) {
                ReadingArchive.deleteImage(id: dropped.id)
            }
            readings = Array(readings.prefix(100))
        }
        if let image {
            ReadingArchive.saveImage(image, id: reading.id)
        }
        ReadingArchive.save(readings)
    }

    func delete(_ reading: StripReading) {
        readings.removeAll { $0.id == reading.id }
        ReadingArchive.deleteImage(id: reading.id)
        ReadingArchive.save(readings)
    }

    func image(for reading: StripReading) -> NSImage? {
        guard let cgImage = ReadingArchive.loadImage(id: reading.id) else { return nil }
        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }
}
