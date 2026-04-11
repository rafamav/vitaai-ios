import Foundation

// MIGRATION: No compatible generated equivalents for Activity models.
// Generated types use JSONValue instead of typed fields and Date instead of String.
// Generated LeaderboardEntry lacks Identifiable/computed id. Kept manual.

// MARK: - Activity Log

struct LogActivityRequest: Encodable {
    let action: String
    let metadata: [String: String]?
}

struct LogActivityResponse: Decodable {
    var xpAwarded: Int = 0
    var totalXp: Int = 0
    var level: Int = 0
    var currentLevelXp: Int = 0
    var xpToNextLevel: Int = 0
    var newBadges: [NewBadge] = []
    var tier: String = ""
    var cycle: String = ""
    var iconPath: String = ""
    var streakDays: Int = 0
    var streakUpdated: Bool = false
    var totalStudyHours: Double = 0

    private enum CodingKeys: String, CodingKey {
        case xpAwarded, totalXp, level, currentLevelXp, xpToNextLevel
        case newBadges, tier, cycle, iconPath, streakDays, streakUpdated, totalStudyHours
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        xpAwarded = (try? c.decode(Int.self, forKey: .xpAwarded)) ?? 0
        totalXp = (try? c.decode(Int.self, forKey: .totalXp)) ?? 0
        level = (try? c.decode(Int.self, forKey: .level)) ?? 0
        currentLevelXp = (try? c.decode(Int.self, forKey: .currentLevelXp)) ?? 0
        xpToNextLevel = (try? c.decode(Int.self, forKey: .xpToNextLevel)) ?? 0
        newBadges = (try? c.decode([NewBadge].self, forKey: .newBadges)) ?? []
        tier = (try? c.decode(String.self, forKey: .tier)) ?? ""
        cycle = (try? c.decode(String.self, forKey: .cycle)) ?? ""
        iconPath = (try? c.decode(String.self, forKey: .iconPath)) ?? ""
        streakDays = (try? c.decode(Int.self, forKey: .streakDays)) ?? 0
        streakUpdated = (try? c.decode(Bool.self, forKey: .streakUpdated)) ?? false
        totalStudyHours = (try? c.decode(Double.self, forKey: .totalStudyHours)) ?? 0
    }
}

struct NewBadge: Decodable {
    var id: String = ""
    var name: String = ""
}

// MARK: - Gamification Stats

struct GamificationStatsResponse: Decodable {
    // Fields that exist in the real API
    var totalXp: Int = 0
    var level: Int = 0
    var currentLevelXp: Int = 0
    var xpToNextLevel: Int = 0
    var streakDays: Int = 0
    var achievements: [BadgeWithStatus] = []

    // Aliases / defaults for fields the API doesn't return but code references
    var currentStreak: Int { streakDays }
    var longestStreak: Int { streakDays }
    var streakFreezes: Int { 0 }
    var totalCardsReviewed: Int { 0 }
    var totalQuestionsAnswered: Int { 0 }
    var totalChatMessages: Int { 0 }
    var totalNotesCreated: Int { 0 }
    var dailyXp: Int { 0 }
    var badges: [BadgeWithStatus] { achievements }
}

struct BadgeWithStatus: Decodable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: String
    var rarity: String = "common"
    // API returns "unlocked" not "earned", and "unlockedAt" as ISO string not Int
    var unlocked: Bool = false
    var unlockedAt: String?

    var earned: Bool { unlocked }
    var earnedAt: Int? {
        guard let str = unlockedAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: str).map { Int($0.timeIntervalSince1970 * 1000) }
    }
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
    var id: String { oderId ?? "\(rank)-\(name)" }
    var oderId: String?
    var rank: Int = 0
    var name: String = ""
    var xp: Int = 0
    var streak: Int = 0
    var level: Int?
    var isCurrentUser: Bool = false
    var initials: String = ""

    // Compat
    var displayName: String { name }
    var isMe: Bool { isCurrentUser }

    private enum CodingKeys: String, CodingKey {
        case oderId = "userId"
        case rank, name, xp, streak, level, isCurrentUser, initials
    }
}
