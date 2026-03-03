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

// MARK: - Apple IAP Verification Models

struct VerifyAppleReceiptRequest: Codable {
    let transactionId: String
    let productId: String
    let bundleId: String
}

struct VerifyAppleReceiptResponse: Codable {
    let ok: Bool
    let plan: String?
    let error: String?
}
