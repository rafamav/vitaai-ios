import Foundation
import SwiftUI

// MARK: - SubscriptionStatusProvider
// Observable singleton that any screen can read to gate premium features.
// Injected via EnvironmentKey so children don't need AppContainer directly.
//
// Usage in any view:
//   @Environment(\.subscriptionStatus) private var subStatus
//   if subStatus.isPro { ... }

@Observable
@MainActor
final class SubscriptionStatusProvider {
    private(set) var isPro: Bool = false
    private(set) var plan: String = "free"
    private(set) var periodEnd: String? = nil
    private(set) var isLoaded: Bool = false

    private let api: VitaAPI

    init(api: VitaAPI) {
        self.api = api
    }

    func refresh() async {
        do {
            let status = try await api.getBillingStatus()
            isPro = status.isActive && status.plan != "free"
            plan = status.plan
            periodEnd = status.periodEnd
            isLoaded = true
        } catch {
            // Network error — preserve current state, do not reset to false
            // (give user benefit of the doubt if offline)
            isLoaded = true
        }
    }
}

// MARK: - Environment Key

private struct SubscriptionStatusKey: EnvironmentKey {
    @MainActor static let defaultValue: SubscriptionStatusProvider = SubscriptionStatusProvider(
        api: VitaAPI(client: HTTPClient(tokenStore: TokenStore()))
    )
}

extension EnvironmentValues {
    var subscriptionStatus: SubscriptionStatusProvider {
        get { self[SubscriptionStatusKey.self] }
        set { self[SubscriptionStatusKey.self] = newValue }
    }
}
