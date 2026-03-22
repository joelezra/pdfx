import SwiftUI

struct DocumentEditorView: View {
    @Environment(DocumentStore.self) private var store
    @Environment(PaywallManager.self) private var paywallManager
    @Environment(\.dismiss) private var dismiss

    let document: PDFDocumentModel
    @State private var currentPageIndex: Int = 0
    @State private var textRegions: [TextRegion] = []
    @State private var selectedRegion: TextRegion?
    @State private var editText: String = ""
    @State private var isProcessingOCR: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var showPaywall: Bool = false
    @State private var saveHaptic: Int = 0
    @State private var showSavedCheck: Bool = false

    private let ocrService = OCRService()
    private let pdfService = PDFService()

    private var currentImage: UIImage? {
        let images = document.pageImages
        guard currentPageIndex < images.count else { return nil }
        return images[currentPageIndex]
    }

    var body: some View {
        ZStack {
            Theme.offWhite.ignoresSafeArea()

            VStack(spacing: 0) {
                documentViewer

                if document.pageImages.count > 1 {
                    pageIndicator
                }
            }

            if isProcessingOCR {
                ocrOverlay
            }

            if showSavedCheck {
                savedCheckmark
            }

            if selectedRegion != nil {
                editOverlay
            }
        }
        .navigationTitle(document.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.navy, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
                    .foregroundStyle(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Share", systemImage: "square.and.arrow.up") {
                    showShareSheet = true
                }
                .foregroundStyle(.white)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let _ = currentImage {
                ShareSheet(items: shareItems())
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sensoryFeedback(.success, trigger: saveHaptic)
        .task {
            await runOCR()
        }
    }

    private var documentViewer: some View {
        GeometryReader { geo in
            ScrollView {
                if let image = currentImage {
                    let aspectRatio = image.size.width / image.size.height
                    let displayWidth = geo.size.width
                    let displayHeight = displayWidth / aspectRatio

                    ZStack {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: displayWidth)

                        ForEach(textRegions) { region in
                            let rect = convertToViewRect(region.boundingBox, displaySize: CGSize(width: displayWidth, height: displayHeight))
                            Button {
                                handleRegionTap(region)
                            } label: {
                                Rectangle()
                                    .fill(region.editedText != nil ? Theme.electricBlue.opacity(0.1) : Color.clear)
                                    .border(selectedRegion?.id == region.id ? Theme.electricBlue : Color.clear, width: 2)
                            }
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                        }
                    }
                    .frame(width: displayWidth, height: displayHeight)
                }
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<document.pageImages.count, id: \.self) { index in
                Button {
                    withAnimation(.snappy) {
                        currentPageIndex = index
                    }
                    Task { await runOCR() }
                } label: {
                    Circle()
                        .fill(index == currentPageIndex ? Theme.electricBlue : Theme.warmGray.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Theme.offWhite)
    }

    private var ocrOverlay: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(Theme.electricBlue)
            Text("Recognizing text...")
                .font(.subheadline)
                .foregroundStyle(Theme.warmGray)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 16))
    }

    private var savedCheckmark: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 60))
            .foregroundStyle(Theme.electricBlue)
            .padding(24)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
            .transition(.scale.combined(with: .opacity))
    }

    private var editOverlay: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                HStack {
                    Text("Edit Text")
                        .font(.headline)
                        .foregroundStyle(Theme.navy)
                    Spacer()
                    Button {
                        withAnimation(.snappy) { selectedRegion = nil }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Theme.warmGray)
                    }
                }

                TextField("Edit text", text: $editText)
                    .font(.body)
                    .padding(12)
                    .background(Theme.lightGray, in: .rect(cornerRadius: 10))
                    .autocorrectionDisabled()

                Button {
                    applyEdit()
                } label: {
                    Text("Apply")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.electricBlue, in: .rect(cornerRadius: 12))
                }
            }
            .padding(20)
            .background(.white, in: .rect(topLeadingRadius: 20, topTrailingRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 20, y: -5)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func handleRegionTap(_ region: TextRegion) {
        if paywallManager.shouldShowPaywall {
            showPaywall = true
            return
        }
        editText = region.displayText
        withAnimation(.snappy) {
            selectedRegion = region
        }
    }

    private func applyEdit() {
        guard let region = selectedRegion else { return }
        if let idx = textRegions.firstIndex(where: { $0.id == region.id }) {
            textRegions[idx].editedText = editText
        }

        paywallManager.recordEdit()

        if let image = currentImage {
            let rendered = pdfService.renderEditedImage(original: image, regions: textRegions, imageSize: image.size)
            store.updateDocument(document, editedImage: rendered, pageIndex: currentPageIndex)
        }

        saveHaptic += 1
        withAnimation(.snappy) {
            selectedRegion = nil
            showSavedCheck = true
        }
        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAnimation(.smooth) {
                showSavedCheck = false
            }
        }
    }

    private func runOCR() async {
        guard let image = currentImage else { return }
        isProcessingOCR = true
        textRegions = await ocrService.recognizeText(in: image)
        isProcessingOCR = false
    }

    private func convertToViewRect(_ visionBox: CGRect, displaySize: CGSize) -> CGRect {
        CGRect(
            x: visionBox.origin.x * displaySize.width,
            y: (1 - visionBox.origin.y - visionBox.height) * displaySize.height,
            width: visionBox.width * displaySize.width,
            height: visionBox.height * displaySize.height
        )
    }

    private func shareItems() -> [Any] {
        var items: [Any] = []
        if let pdfData = pdfService.generatePDF(from: document.pageImages) {
            let tempURL = URL.temporaryDirectory.appendingPathComponent("\(document.name).pdf")
            try? pdfData.write(to: tempURL)
            items.append(tempURL)
        }
        return items
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
