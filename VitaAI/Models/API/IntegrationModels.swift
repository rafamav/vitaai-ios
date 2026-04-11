import Foundation

// MARK: - Unified Integrations API Models

struct IntegrationsResponse: Decodable {
    let academic: [AcademicConnectorInfo]
    let productivity: [ProductivityConnectorInfo]
}

struct AcademicConnectorInfo: Decodable {
    let id: String
    let provider: String
    let name: String
    let instanceUrl: String?
    let status: String
    let lastSyncAt: String?
    let connectedAt: String?
}

struct ProductivityConnectorInfo: Decodable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let description: String
    let capabilities: [String]
    let authType: String
    let status: String
    let lastSyncAt: String?
    let connectedAt: String?
}

struct IntegrationOAuthResponse: Decodable {
    let authUrl: String?
}
