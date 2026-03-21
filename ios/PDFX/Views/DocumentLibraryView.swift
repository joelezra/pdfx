import SwiftUI

struct DocumentLibraryView: View {
    @Environment(DocumentStore.self) private var store
    @State private var searchText: String = ""
    @State private var selectedDocument: PDFDocumentModel?
    @State private var documentToDelete: PDFDocumentModel?
    @State private var showDeleteAlert: Bool = false

    private var filteredDocuments: [PDFDocumentModel] {
        guard !searchText.isEmpty else { return store.documents }
        return store.documents.filter { $0.name.localizedStandardContains(searchText) }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ZStack {
            Theme.offWhite.ignoresSafeArea()

            if store.documents.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredDocuments) { doc in
                            DocumentCard(document: doc) {
                                selectedDocument = doc
                            } onDelete: {
                                documentToDelete = doc
                                showDeleteAlert = true
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .searchable(text: $searchText, prompt: "Search documents")
            }
        }
        .navigationTitle("Library")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(Theme.offWhite, for: .navigationBar)
        .alert("Delete Document?", isPresented: $showDeleteAlert, presenting: documentToDelete) { doc in
            Button("Delete", role: .destructive) {
                withAnimation(.snappy) {
                    store.deleteDocument(doc)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: { doc in
            Text("This will permanently delete \"\(doc.name)\".")
        }
        .fullScreenCover(item: $selectedDocument) { doc in
            NavigationStack {
                DocumentEditorView(document: doc)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Documents", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Scan or import a document to get started.")
        }
    }
}

struct DocumentCard: View {
    let document: PDFDocumentModel
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Color(.secondarySystemBackground)
                    .aspectRatio(0.75, contentMode: .fit)
                    .overlay {
                        if let thumbnail = document.thumbnailImage {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .allowsHitTesting(false)
                        } else {
                            Image(systemName: "doc.text")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.warmGray)
                        }
                    }
                    .clipShape(.rect(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 3) {
                    Text(document.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.navy)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(document.formattedDate)
                        Text("·")
                        Text(document.formattedFileSize)
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.warmGray)
                }
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Open", systemImage: "doc") { onTap() }
            Button("Delete", systemImage: "trash", role: .destructive) { onDelete() }
        }
    }
}
