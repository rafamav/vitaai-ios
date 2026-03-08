import Foundation

// MARK: - AppConfigResponse
// Port of GET /api/config/app — single source of truth for all app configuration.
// All platforms (Web, Android, iOS) consume this endpoint.
// Cache: UserDefaults with 1-hour TTL.

struct AppConfigResponse: Codable {
    let gamification: GamificationConfig
}

// MARK: - GamificationConfig

struct GamificationConfig: Codable {
    let levels: LevelConfig
    let xpRewards: [String: Int]
    let streakBonus: StreakBonusConfig
    let badges: [AppBadgeConfig]
    let dailyGoal: Int

    // MARK: - Default fallback (matches server gamification.ts)
    // Used when offline or before first fetch completes.
    static let fallback = GamificationConfig(
        levels: LevelConfig(
            maxLevel: 1000,
            formula: "floor(50 * n^1.5)"
        ),
        xpRewards: [
            "question_answered": 8,
            "question_answered_wrong": 3,
            "flashcard_review": 8,
            "flashcard_easy": 12,
            "simulado_complete": 80,
            "qbank_session_complete": 30,
            "deck_complete": 40,
            "osce_completed": 50,
            "note_created": 15,
            "note_edited": 3,
            "pdf_annotated": 10,
            "document_opened": 2,
            "studio_generated": 10,
            "study_session_end": 8,
            "simulado_start": 3,
            "chat_message": 4,
            "daily_login": 20,
        ],
        streakBonus: StreakBonusConfig(threshold: 7, bonusXp: 15),
        badges: [],
        dailyGoal: 50
    )
}

// MARK: - LevelConfig

struct LevelConfig: Codable {
    let maxLevel: Int
    let formula: String
}

// MARK: - StreakBonusConfig

struct StreakBonusConfig: Codable {
    let threshold: Int
    let bonusXp: Int
}

// MARK: - AppBadgeConfig

struct AppBadgeConfig: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String
    let category: String
    let xpReward: Int?
}
