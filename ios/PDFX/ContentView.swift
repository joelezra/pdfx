import SwiftUI

struct ContentView: View {
    @Environment(DocumentStore.self) private var store

    var body: some View {
        NavigationStack {
            ScannerView()
                .navigationDestination(for: String.self) { value in
                    if value == "library" {
                        DocumentLibraryView()
                    }
                }
        }
        .tint(Theme.electricBlue)
    }
}
