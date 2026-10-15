import CoreGraphics
import Foundation

public enum GuideGeometry {
    public static func aspectFit(container: CGSize, image: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0, container.width > 0, container.height > 0 else {
            return .zero
        }
        let scale = min(container.width / image.width, container.height / image.height)
        let width = image.width * scale
        let height = image.height * scale
        let x = (container.width - width) / 2
        let y = (container.height - height) / 2
        return CGRect(x: x, y: y, width: width, height: height)
    }

    public static func map(_ normalized: CGRect, within content: CGRect) -> CGRect {
        CGRect(
            x: content.origin.x + normalized.origin.x * content.width,
            y: content.origin.y + normalized.origin.y * content.height,
            width: normalized.width * content.width,
            height: normalized.height * content.height
        )
    }
}

public enum StripGuide {
    public static func normalized(widthFraction: Double, heightFraction: Double) -> CGRect {
        let width = min(max(widthFraction, 0.05), 0.8)
        let height = min(max(heightFraction, 0.2), 0.98)
        return CGRect(x: (1 - width) / 2, y: (1 - height) / 2, width: width, height: height)
    }
}

public enum ImageOps {
    /// Çizim kapanışı üst-sol orijin kullanır; y aşağı büyür.
    public static func makeImage(width: Int, height: Int, draw: (CGContext) -> Void) -> CGImage? {
        guard width > 1, height > 1 else { return nil }
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.interpolationQuality = .high
        draw(context)
        return context.makeImage()
    }

    public static func fill(_ context: CGContext, _ rect: CGRect, _ rgb: RGB) {
        context.setFillColor(CGColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1))
        context.fill(rect)
    }

    /// `normalized` üst-sol orijinlidir, y aşağı büyür.
    public static func cropping(_ image: CGImage, toNormalized normalized: CGRect) -> CGImage? {
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        guard width > 1, height > 1 else { return nil }

        let nx = min(max(normalized.origin.x, 0), 1)
        let ny = min(max(normalized.origin.y, 0), 1)
        let nw = min(max(normalized.width, 0), 1 - nx)
        let nh = min(max(normalized.height, 0), 1 - ny)

        let rect = CGRect(
            x: floor(nx * width),
            y: floor(ny * height),
            width: max(1, floor(nw * width)),
            height: max(1, floor(nh * height))
        )
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let crop = rect.intersection(bounds)
        guard crop.width >= 1, crop.height >= 1 else { return nil }
        return image.cropping(to: crop)
    }

    public static func averageColor(_ image: CGImage) -> RGB? {
        let width = max(1, min(image.width, 36))
        let height = max(1, min(image.height, 36))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let wrote = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard wrote else { return nil }

        func accumulate(skipExtremes: Bool) -> (RGB, Int)? {
            var red = 0.0
            var green = 0.0
            var blue = 0.0
            var count = 0
            for index in 0..<(width * height) {
                let offset = index * 4
                let alpha = Double(pixels[offset + 3]) / 255
                if alpha < 0.05 { continue }
                let r = Double(pixels[offset]) / 255 / alpha
                let g = Double(pixels[offset + 1]) / 255 / alpha
                let b = Double(pixels[offset + 2]) / 255 / alpha
                if skipExtremes {
                    let maxChannel = max(r, g, b)
                    let minChannel = min(r, g, b)
                    let lightness = (maxChannel + minChannel) / 2
                    if lightness > 0.985 || lightness < 0.02 { continue }
                }
                red += r
                green += g
                blue += b
                count += 1
            }
            guard count > 0 else { return nil }
            let divisor = Double(count)
            return (RGB(r: red / divisor, g: green / divisor, b: blue / divisor), count)
        }

        if let filtered = accumulate(skipExtremes: true) {
            return filtered.0
        }
        return accumulate(skipExtremes: false)?.0
    }
}
