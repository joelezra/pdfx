import Foundation

@Observable
@MainActor
class PaywallManager {
    var editCount: Int {
        get { UserDefaults.standard.integer(forKey: "pdfx_edit_count") }
        set { UserDefaults.standard.set(newValue, forKey: "pdfx_edit_count") }
    }

    var isPro: Bool {
        get { UserDefaults.standard.bool(forKey: "pdfx_is_pro") }
        set { UserDefaults.standard.set(newValue, forKey: "pdfx_is_pro") }
    }

    var shouldShowPaywall: Bool {
        !isPro && editCount >= 3
    }

    func recordEdit() {
        editCount += 1
    }

    func simulatePurchase() {
        isPro = true
    }
}
