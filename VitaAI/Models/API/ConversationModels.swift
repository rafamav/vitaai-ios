import Foundation

struct ConversationEntry: Codable, Identifiable {
    var id: String = ""
    var title: String?
    var updatedAt: String?
    var messagePreview: String?
}

struct ConversationMessagesResponse: Codable {
    var messages: [ConversationMessage] = []
}

struct ConversationMessage: Codable, Identifiable {
    var id: String = ""
    var role: String = ""
    var content: String = ""
    var createdAt: String?
}

struct FeedbackRequest: Codable {
    var feedback: Int = 0
}

struct PushTokenRequest: Codable {
    var token: String
    var platform: String
}

struct ChatRequest: Codable {
    var message: String
    var conversationId: String?
    /// Signals voice mode to the backend — matches Android's voiceMode flag.
    var voiceMode: Bool?
}
