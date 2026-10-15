import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum PhotoImport {
    public static let allowedTypes: [UTType] = [.jpeg, .png, .heic, .tiff, .image]

    public static func loadImage(from url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
