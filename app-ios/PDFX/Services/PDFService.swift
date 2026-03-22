import Foundation
import UIKit
import PDFKit

@MainActor
class PDFService {
    func generatePDF(from images: [UIImage]) -> Data? {
        let pdfDocument = PDFDocument()
        for (index, image) in images.enumerated() {
            guard let page = PDFPage(image: image) else { continue }
            pdfDocument.insert(page, at: index)
        }
        return pdfDocument.dataRepresentation()
    }

    func renderEditedImage(original: UIImage, regions: [TextRegion], imageSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: original.size)
        return renderer.image { context in
            original.draw(in: CGRect(origin: .zero, size: original.size))

            guard let cgImage = original.cgImage else { return }

            for region in regions {
                guard region.editedText != nil else { continue }

                let visionBox = region.boundingBox
                let rect = CGRect(
                    x: visionBox.origin.x * original.size.width,
                    y: (1 - visionBox.origin.y - visionBox.height) * original.size.height,
                    width: visionBox.width * original.size.width,
                    height: visionBox.height * original.size.height
                )

                // Sample background color from area just above the text region
                let bgColor = sampleColor(from: cgImage, at: rect, position: .background, imageSize: original.size)
                // Sample text color from the darkest pixels in the region
                let textColor = sampleColor(from: cgImage, at: rect, position: .text, imageSize: original.size)

                bgColor.setFill()
                context.fill(rect.insetBy(dx: -2, dy: -2))

                let fontSize = rect.height * 0.75
                let font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .left
                paragraphStyle.lineBreakMode = .byClipping

                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor,
                    .paragraphStyle: paragraphStyle
                ]

                let text = region.displayText
                let textRect = rect.insetBy(dx: 2, dy: (rect.height - fontSize) / 2)
                text.draw(in: textRect, withAttributes: attrs)
            }
        }
    }

    enum SamplePosition { case background, text }

    /// Samples the background or text color from the image around a text region
    private func sampleColor(from cgImage: CGImage, at rect: CGRect, position: SamplePosition, imageSize: CGSize) -> UIColor {
        let width = cgImage.width
        let height = cgImage.height
        let scaleX = CGFloat(width) / imageSize.width
        let scaleY = CGFloat(height) / imageSize.height

        // Convert rect to pixel coordinates
        let pixelRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )

        // Define sample area
        let sampleRect: CGRect
        switch position {
        case .background:
            // Sample a strip just above the text region
            let stripHeight = max(pixelRect.height * 0.3, 4)
            sampleRect = CGRect(
                x: pixelRect.origin.x,
                y: max(0, pixelRect.origin.y - stripHeight),
                width: pixelRect.width,
                height: stripHeight
            ).intersection(CGRect(x: 0, y: 0, width: width, height: height))
        case .text:
            // Sample within the text region
            sampleRect = pixelRect.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        }

        guard !sampleRect.isEmpty,
              let cropped = cgImage.cropping(to: sampleRect) else {
            return position == .background ? .white : .black
        }

        // Draw the cropped area into a small bitmap to get pixel data
        let sampleSize = 8 // Downsample to 8x8 for averaging
        let bytesPerPixel = 4
        let bytesPerRow = sampleSize * bytesPerPixel
        var pixelData = [UInt8](repeating: 0, count: sampleSize * sampleSize * bytesPerPixel)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                data: &pixelData,
                width: sampleSize,
                height: sampleSize,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return position == .background ? .white : .black
        }

        ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))

        // Collect all pixel colors with their brightness
        struct PixelColor {
            let r: CGFloat, g: CGFloat, b: CGFloat
            var brightness: CGFloat { (r + g + b) / 3.0 }
        }

        var pixels: [PixelColor] = []
        for i in 0..<(sampleSize * sampleSize) {
            let offset = i * bytesPerPixel
            let r = CGFloat(pixelData[offset]) / 255.0
            let g = CGFloat(pixelData[offset + 1]) / 255.0
            let b = CGFloat(pixelData[offset + 2]) / 255.0
            pixels.append(PixelColor(r: r, g: g, b: b))
        }

        switch position {
        case .background:
            // Use the brightest pixels (background is typically lighter)
            let sorted = pixels.sorted { $0.brightness > $1.brightness }
            let top = sorted.prefix(max(sorted.count / 2, 1))
            let avgR = top.map(\.r).reduce(0, +) / CGFloat(top.count)
            let avgG = top.map(\.g).reduce(0, +) / CGFloat(top.count)
            let avgB = top.map(\.b).reduce(0, +) / CGFloat(top.count)
            return UIColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0)

        case .text:
            // Use the darkest pixels (text is typically darker)
            let sorted = pixels.sorted { $0.brightness < $1.brightness }
            let top = sorted.prefix(max(sorted.count / 4, 1))
            let avgR = top.map(\.r).reduce(0, +) / CGFloat(top.count)
            let avgG = top.map(\.g).reduce(0, +) / CGFloat(top.count)
            let avgB = top.map(\.b).reduce(0, +) / CGFloat(top.count)
            return UIColor(red: avgR, green: avgG, blue: avgB, alpha: 1.0)
        }
    }

    func importPDF(from url: URL) -> [UIImage]? {
        guard url.startAccessingSecurityScopedResource() else { return nil }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let pdfDocument = PDFDocument(url: url) else { return nil }
        var images: [UIImage] = []

        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i) else { continue }
            let pageRect = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0
            let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

            let renderer = UIGraphicsImageRenderer(size: scaledSize)
            let image = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: scaledSize))
                ctx.cgContext.translateBy(x: 0, y: scaledSize.height)
                ctx.cgContext.scaleBy(x: scale, y: -scale)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }
            images.append(image)
        }

        return images.isEmpty ? nil : images
    }
}
