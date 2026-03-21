import SwiftUI
import VisionKit
import PhotosUI

struct ScannerView: View {
    @Environment(DocumentStore.self) private var store
    @State private var showDocumentScanner = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false
    @State private var showImportOptions = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var navigateToDocument: PDFDocumentModel?
    @State private var scanHaptic: Int = 0

    var body: some View {
        ZStack {
            Theme.navy.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                cameraPlaceholder

                Spacer()

                bottomControls
            }
        }
        .sheet(isPresented: $showDocumentScanner) {
            DocumentScannerRepresentable { images in
                let doc = store.addDocument(from: images)
                scanHaptic += 1
                navigateToDocument = doc
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotos, maxSelectionCount: 10, matching: .images)
        .onChange(of: selectedPhotos) { _, newItems in
            Task { await importPhotos(newItems) }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.pdf], allowsMultipleSelection: false) { result in
            handleFileImport(result)
        }
        .confirmationDialog("Import Document", isPresented: $showImportOptions) {
            Button("Photo Library") { showPhotoPicker = true }
            Button("Files") { showFileImporter = true }
            Button("Cancel", role: .cancel) { }
        }
        .sensoryFeedback(.success, trigger: scanHaptic)
        .fullScreenCover(item: $navigateToDocument) { doc in
            NavigationStack {
                DocumentEditorView(document: doc)
            }
        }
    }

    private var cameraPlaceholder: some View {
        VStack(spacing: 32) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 280, height: 360)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Theme.electricBlue.opacity(0.3), lineWidth: 1.5)
                    }

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Theme.electricBlue.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "doc.viewfinder")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(Theme.electricBlue)
                    }

                    Text("Scan Document")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Point your camera at a document\nor import from your files")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            HStack(spacing: 40) {
                Button {
                    showImportOptions = true
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 56, height: 56)
                            Image(systemName: "folder")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Text("Import")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Button {
                    showDocumentScanner = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Theme.electricBlue)
                            .frame(width: 76, height: 76)
                            .shadow(color: Theme.electricBlue.opacity(0.4), radius: 12, y: 4)

                        Circle()
                            .fill(.white)
                            .frame(width: 64, height: 64)

                        Circle()
                            .fill(Theme.electricBlue)
                            .frame(width: 58, height: 58)

                        Image(systemName: "camera.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                    }
                }

                NavigationLink(value: "library") {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(.white.opacity(0.1))
                                .frame(width: 56, height: 56)
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 22))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Text("Library")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
        }
        .padding(.bottom, 40)
    }

    private func importPhotos(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }
        guard !images.isEmpty else { return }
        let doc = store.addDocument(from: images, name: "Imported Photo")
        scanHaptic += 1
        navigateToDocument = doc
        selectedPhotos = []
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        let pdfService = PDFService()
        if let images = pdfService.importPDF(from: url) {
            let name = url.deletingPathExtension().lastPathComponent
            let doc = store.addDocument(from: images, name: name)
            scanHaptic += 1
            navigateToDocument = doc
        }
    }
}

struct DocumentScannerRepresentable: UIViewControllerRepresentable {
    let completion: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let completion: ([UIImage]) -> Void

        init(completion: @escaping ([UIImage]) -> Void) {
            self.completion = completion
        }

        nonisolated func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            let capturedImages = images
            Task { @MainActor in
                self.completion(capturedImages)
                controller.dismiss(animated: true)
            }
        }

        nonisolated func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            Task { @MainActor in
                controller.dismiss(animated: true)
            }
        }

        nonisolated func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            Task { @MainActor in
                controller.dismiss(animated: true)
            }
        }
    }
}
