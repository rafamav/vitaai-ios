import Foundation

// MIGRATION: Partial migration to OpenAPI generated types.
// PushTokenRequest → RegisterPushTokenRequest (generated, compatible)
// ConversationEntry — generated Conversation lacks messagePreview, kept manual
// ConversationMessage — generated uses timestamp:Date instead of createdAt:String, kept manual
// FeedbackRequest — generated SubmitCoachFeedbackRequest has different shape, kept manual
// ChatRequest — generated VitaChatRequest lacks conversationId/voiceMode, kept manual
// PushPreferencesRequest — no generated equivalent, kept manual

typealias PushTokenRequest = RegisterPushTokenRequest

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
    var conversationId: String
    var messageId: String
    var feedback: String  // "up" or "down"
}

struct PushPreferencesRequest: Codable {
    var flashcardReminders: Bool
    var streakAlerts: Bool
    var studyReminders: Bool
    var reminderTime: String
}

struct ChatRequest: Codable {
    var message: String
    var conversationId: String?
    var voiceMode: Bool?
}

// MARK: - Notification Preferences (from GET /api/notifications/preferences)

struct NotificationPreferencesChannel: Codable {
    var push: Bool?
    var email: Bool?
    var whatsapp: Bool?
}

struct NotificationPreferencesType: Codable {
    var key: String?
    var label: String?
    var channels: NotificationPreferencesChannel?
}

struct NotificationPreferencesTiming: Codable {
    var digestTime: String?
    var briefingHoursBefore: Int?
    var quietStart: String?
    var quietEnd: String?
}

struct NotificationPreferencesResponse: Codable {
    var types: [NotificationPreferencesType]?
    var timing: NotificationPreferencesTiming?
}
