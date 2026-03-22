import Foundation
import UIKit

@Observable
@MainActor
class DocumentStore {
    var documents: [PDFDocumentModel] = []
    private let metadataURL = URL.documentsDirectory.appendingPathComponent("pdfx_metadata.json")

    init() {
        loadMetadata()
    }

    @discardableResult
    func addDocument(from images: [UIImage], name: String? = nil) -> PDFDocumentModel {
        let id = UUID()
        var fileNames: [String] = []

        for (index, image) in images.enumerated() {
            let fileName = "\(id.uuidString)_page\(index).jpg"
            let url = PDFDocumentModel.storageDirectory.appendingPathComponent(fileName)
            if let data = image.jpegData(compressionQuality: 0.85) {
                try? data.write(to: url)
            }
            fileNames.append(fileName)
        }

        let docName = name ?? "Document \(documents.count + 1)"
        let doc = PDFDocumentModel(
            id: id,
            name: docName,
            createdAt: .now,
            updatedAt: .now,
            pageImageFileNames: fileNames,
            editedPageImageFileNames: []
        )
        documents.insert(doc, at: 0)
        saveMetadata()
        return doc
    }

    func updateDocument(_ document: PDFDocumentModel, editedImage: UIImage, pageIndex: Int) {
        guard let idx = documents.firstIndex(where: { $0.id == document.id }) else { return }

        var doc = documents[idx]
        var editedNames = doc.editedPageImageFileNames
        if editedNames.isEmpty {
            editedNames = doc.pageImageFileNames
        }

        let fileName = "\(doc.id.uuidString)_edited_page\(pageIndex).jpg"
        let url = PDFDocumentModel.storageDirectory.appendingPathComponent(fileName)
        if let data = editedImage.jpegData(compressionQuality: 0.9) {
            try? data.write(to: url)
        }

        if pageIndex < editedNames.count {
            editedNames[pageIndex] = fileName
        }

        doc.editedPageImageFileNames = editedNames
        doc.updatedAt = .now
        documents[idx] = doc
        saveMetadata()
    }

    func deleteDocument(_ document: PDFDocumentModel) {
        let allFiles = document.pageImageFileNames + document.editedPageImageFileNames
        for fileName in allFiles {
            let url = PDFDocumentModel.storageDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
        }
        documents.removeAll { $0.id == document.id }
        saveMetadata()
    }

    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([PDFDocumentModel].self, from: data) else { return }
        documents = decoded
    }

    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(documents) else { return }
        try? data.write(to: metadataURL)
    }
}
