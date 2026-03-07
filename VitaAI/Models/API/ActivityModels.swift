import Foundation

// MARK: - Activity Log

struct LogActivityRequest: Encodable {
    let action: String
    let metadata: [String: String]?
}

struct LogActivityResponse: Decodable {
    let xpAwarded: Int
    let totalXp: Int
    let level: Int
    let newBadges: [NewBadge]
    let streakUpdated: Bool
}

struct NewBadge: Decodable {
    let id: String
    let name: String
    let description: String
    let icon: String
}

// MARK: - Gamification Stats

struct GamificationStatsResponse: Decodable {
    let totalXp: Int
    let level: Int
    let currentStreak: Int
    let longestStreak: Int
    let streakFreezes: Int
    let totalCardsReviewed: Int
    let totalQuestionsAnswered: Int
    let totalChatMessages: Int
    let totalNotesCreated: Int
    let dailyXp: Int
    let currentLevelXp: Int
    let xpToNextLevel: Int
    let badges: [BadgeWithStatus]
}

struct BadgeWithStatus: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: String
    let earned: Bool
    let earnedAt: Int?
}

// MARK: - Activity Feed

struct ActivityFeedItem: Decodable, Identifiable {
    let id: String
    let action: String
    let xpAwarded: Int
    let createdAt: String
}

// MARK: - Leaderboard

struct LeaderboardEntry: Decodable, Identifiable {
    var id: String { oderId }
    let oderId: String
    let rank: Int
    let displayName: String
    let xp: Int
    let level: Int?

    private enum CodingKeys: String, CodingKey {
        case oderId = "userId"
        case rank, displayName, xp, level
    }
}
