import Foundation

@Observable
@MainActor
class PaywallManager {
    var editCount: Int {
        didSet { UserDefaults.standard.set(editCount, forKey: "pdfx_edit_count") }
    }

    var isPro: Bool {
        didSet { UserDefaults.standard.set(isPro, forKey: "pdfx_is_pro") }
    }

    var shouldShowPaywall: Bool {
        !isPro && editCount >= 3
    }

    init() {
        self.editCount = UserDefaults.standard.integer(forKey: "pdfx_edit_count")
        self.isPro = UserDefaults.standard.bool(forKey: "pdfx_is_pro")
    }

    func recordEdit() {
        editCount += 1
    }

    func simulatePurchase() {
        isPro = true
    }
}
