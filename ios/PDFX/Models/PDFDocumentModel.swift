import Foundation
import UIKit

nonisolated struct PDFDocumentModel: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
    let pageImageFileNames: [String]
    var editedPageImageFileNames: [String]

    @MainActor
    var fileSize: Int64 {
        let fm = FileManager.default
        var total: Int64 = 0
        for fileName in editedPageImageFileNames.isEmpty ? pageImageFileNames : editedPageImageFileNames {
            let url = Self.storageDirectory.appendingPathComponent(fileName)
            if let attrs = try? fm.attributesOfItem(atPath: url.path),
               let size = attrs[.size] as? Int64 {
                total += size
            }
        }
        return total
    }

    @MainActor
    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDate: String {
        updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    @MainActor
    var thumbnailImage: UIImage? {
        let fileName = editedPageImageFileNames.first ?? pageImageFileNames.first
        guard let fileName else { return nil }
        let url = Self.storageDirectory.appendingPathComponent(fileName)
        return UIImage(contentsOfFile: url.path)
    }

    @MainActor
    var pageImages: [UIImage] {
        let fileNames = editedPageImageFileNames.isEmpty ? pageImageFileNames : editedPageImageFileNames
        return fileNames.compactMap { fileName in
            let url = Self.storageDirectory.appendingPathComponent(fileName)
            return UIImage(contentsOfFile: url.path)
        }
    }

    @MainActor
    static var storageDirectory: URL {
        let dir = URL.documentsDirectory.appendingPathComponent("PDFXDocuments", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: PDFDocumentModel, rhs: PDFDocumentModel) -> Bool {
        lhs.id == rhs.id
    }
}
