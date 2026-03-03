import Foundation

// MARK: - Billing API Models
// Mirrors Android: com.bymav.medcoach.data.model.ApiModels
// Endpoints: GET billing/status, POST billing/checkout

struct BillingStatus: Decodable {
    let plan: String
    let isActive: Bool
    let periodEnd: String?
}

struct CheckoutResponse: Decodable {
    let url: String
}

struct CheckoutRequest: Encodable {
    let plan: String
}
