import Foundation
import SafariServices
import UIKit

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
// Strategy: server-side Stripe checkout (same as Android Custom Tab approach).
// Opens Stripe checkout URL in SFSafariViewController for a seamless in-app experience.

@Observable
@MainActor
final class PaywallViewModel {
    private(set) var state = BillingState()
    private let api: VitaAPI

    init(api: VitaAPI) {
        self.api = api
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
    }

    func startCheckout() async {
        state.isLoading = true
        state.error = nil
        defer { state.isLoading = false }
        do {
            let response = try await api.getCheckoutUrl(plan: "pro")
            openCheckoutURL(response.url)
        } catch {
            state.error = "Nao foi possivel iniciar a assinatura. Tente novamente."
        }
    }

    /// Restore purchase = re-check status from server.
    /// Mirrors Android: PaywallViewModel.restorePurchase() which calls loadStatus().
    func restorePurchase() async {
        await loadStatus()
    }

    // MARK: - Private

    private func openCheckoutURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        // Open Stripe checkout in SFSafariViewController (equivalent to Android Custom Tab).
        // Present over the key window's root view controller.
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first?.rootViewController
        else { return }

        let safari = SFSafariViewController(url: url)
        safari.preferredControlTintColor = UIColor(VitaColors.accent)
        safari.dismissButtonStyle = .close
        root.present(safari, animated: true)
    }
}
