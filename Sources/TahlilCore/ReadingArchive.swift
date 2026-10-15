import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum ReadingArchive {
    public static func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Tahlil", isDirectory: true)
    }

    public static func load(from url: URL? = nil) -> [StripReading] {
        let file = url ?? readingsURL(in: directory())
        guard let data = try? Data(contentsOf: file) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([StripReading].self, from: data)) ?? []
    }

    public static func save(_ readings: [StripReading], to url: URL? = nil) {
        let folder = directory()
        let file = url ?? readingsURL(in: folder)
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(readings) else { return }
        try? data.write(to: file, options: .atomic)
    }

    public static func saveImage(_ image: CGImage, id: UUID, directory: URL? = nil) {
        let folder = directory ?? self.directory()
        let images = folder.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        guard let data = jpegData(image) else { return }
        try? data.write(to: images.appendingPathComponent("\(id.uuidString).jpg"), options: .atomic)
    }

    public static func loadImage(id: UUID, directory: URL? = nil) -> CGImage? {
        let folder = directory ?? self.directory()
        let url = folder
            .appendingPathComponent("images", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).jpg")
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    public static func deleteImage(id: UUID, directory: URL? = nil) {
        let folder = directory ?? self.directory()
        let url = folder
            .appendingPathComponent("images", isDirectory: true)
            .appendingPathComponent("\(id.uuidString).jpg")
        try? FileManager.default.removeItem(at: url)
    }

    private static func readingsURL(in folder: URL) -> URL {
        folder.appendingPathComponent("history.json")
    }

    private static func jpegData(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.82
        ]
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
