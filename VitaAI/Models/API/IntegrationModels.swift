import Foundation

// MARK: - Unified Integrations API Models

// Backend canonical shape (vitaai-web /api/integrations/route.ts):
//   { providers: [{ name, displayName, connected, status, providerAccountEmail, lastSyncAt }] }
// Updated 2026-04-26 — iOS used to expect { academic, productivity }, which
// the backend stopped returning. Decoder failed silently → connectors stayed
// "Conectar" forever even after OAuth tokens were saved in vita.user_integrations.
struct IntegrationsResponse: Decodable {
    let providers: [IntegrationProviderInfo]
}

struct IntegrationProviderInfo: Decodable, Identifiable {
    let name: String
    let displayName: String
    let connected: Bool
    let status: String
    let providerAccountEmail: String?
    let lastSyncAt: String?

    var id: String { name }
}

struct IntegrationOAuthResponse: Decodable {
    let authUrl: String?
}
