import Foundation

// MARK: - Push Preferences
// Mirrors Android: com.bymav.medcoach.data.model.PushPreferences
// Endpoint: GET/POST push/preferences

struct PushPreferences: Codable {
    var studyReminders: Bool
    var reviewReminders: Bool
    var deadlineReminders: Bool
    var updates: Bool
}
