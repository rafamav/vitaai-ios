import Foundation

// MARK: - Quick Actions API Models
// Backend: GET /api/chat/quick-actions
// Schema SOT: vitaai-web/openapi.yaml (commit d4a627a+)
// Cache: ttlSeconds (server-side), stored in QuickActionsResponse

struct QuickActionsResponse: Decodable {
    let suggestions: [QuickAction]
    let studyTools: [QuickAction]
    let aboutYou: [QuickAction]
    let connectors: [ConnectorBlock]
    let attachments: [AttachmentAction]
    let ttlSeconds: Int
}

struct QuickAction: Decodable, Identifiable {
    let id: String
    let label: String
    let sublabel: String?
    let icon: String          // SF Symbol name
    let prompt: String
    let toolHint: String?
    let badge: String?
    let needsSelector: NeedsSelector?

    enum NeedsSelector: String, Decodable {
        case subject
        case document
        case note
        case topic
    }
}

struct ConnectorBlock: Decodable {
    let provider: String
    let displayName: String
    let connected: Bool
    let actions: [QuickAction]
}

struct AttachmentAction: Decodable, Identifiable {
    let id: String
    let label: String
    let icon: String
    let kind: AttachmentKind

    enum AttachmentKind: String, Decodable {
        case photo
        case camera
        case file
        case audio
        case document
        case note
    }
}
