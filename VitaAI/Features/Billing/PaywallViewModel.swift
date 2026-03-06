import Foundation
import StoreKit

// MARK: - BillingState
// Mirrors Android: com.bymav.medcoach.ui.screens.billing.BillingState

struct BillingState {
    var plan: String = "free"
    var periodEnd: String? = nil
    var isActive: Bool = false
    var isLoading: Bool = false
    var error: String? = nil

    var isPro: Bool { isActive && plan != "free" }
}

// MARK: - PaywallViewModel
// Mirrors Android: PaywallViewModel.kt
// Strategy: StoreKit 2 (Apple IAP) only. Stripe checkout removed for iOS.
// VitaPaywallScreen (the active paywall) uses StoreKitManager directly,
// but this ViewModel is kept for PaywallScreen compatibility with StoreKit 2.

@Observable
@MainActor
final class PaywallViewModel {
    private(set) var state = BillingState()
    private let api: VitaAPI
    let storeKit: StoreKitManager

    init(api: VitaAPI) {
        self.api = api
        self.storeKit = StoreKitManager()
    }

    func loadStatus() async {
        state.isLoading = true
        state.error = nil
        defer { state.isLoading = false }
        do {
            let status = try await api.getBillingStatus()
            state.plan = status.plan
            state.periodEnd = status.periodEnd
            state.isActive = status.isActive
        } catch {
            state.error = "Nao foi possivel carregar o status de assinatura"
        }
        // Also load StoreKit products
        await storeKit.loadProducts()
    }

    /// Purchase via StoreKit 2 (Apple IAP).
    func startCheckout() async {
        guard let product = storeKit.monthlyProduct ?? storeKit.annualProduct else {
            state.error = "Nao foi possivel carregar os planos disponiveis."
            return
        }
        await storeKit.purchase(product)
        // After purchase, refresh server-side status
        if storeKit.isSubscribed {
            await loadStatus()
        }
    }

    /// Restore purchase via StoreKit 2 AppStore.sync().
    func restorePurchase() async {
        await storeKit.restorePurchases()
        if storeKit.isSubscribed {
            await loadStatus()
        }
    }
}
