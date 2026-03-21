import SwiftUI

@main
struct PDFXApp: App {
    @State private var store = DocumentStore()
    @State private var paywallManager = PaywallManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(paywallManager)
        }
    }
}
