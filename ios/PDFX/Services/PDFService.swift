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

            for region in regions {
                guard region.editedText != nil else { continue }

                let visionBox = region.boundingBox
                let rect = CGRect(
                    x: visionBox.origin.x * original.size.width,
                    y: (1 - visionBox.origin.y - visionBox.height) * original.size.height,
                    width: visionBox.width * original.size.width,
                    height: visionBox.height * original.size.height
                )

                UIColor.white.setFill()
                context.fill(rect.insetBy(dx: -2, dy: -2))

                let fontSize = rect.height * 0.75
                let font = UIFont.systemFont(ofSize: fontSize, weight: .regular)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .left
                paragraphStyle.lineBreakMode = .byClipping

                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.black,
                    .paragraphStyle: paragraphStyle
                ]

                let text = region.displayText
                let textRect = rect.insetBy(dx: 2, dy: (rect.height - fontSize) / 2)
                text.draw(in: textRect, withAttributes: attrs)
            }
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
