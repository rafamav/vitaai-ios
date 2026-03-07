import Foundation
import SwiftUI

// MARK: - UserProgress
// Port of Android GamificationModels.kt > UserProgress

struct UserProgress {
    var totalXp: Int = 0
    var level: Int = 1
    var currentLevelXp: Int = 0      // XP earned in current level
    var xpToNextLevel: Int = 100     // XP gap to reach next level
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActivityDate: String?
    var streakFreezes: Int = 1
    var badges: [VitaBadge] = []
    var totalCardsReviewed: Int = 0
    var totalChatMessages: Int = 0
    var totalNotesCreated: Int = 0
    var dailyXp: Int = 0
    var dailyGoal: Int = 50
    var dailyLoginClaimed: Bool = false

    /// Progress ratio [0,1] through the current level.
    var levelProgress: Double {
        let total = currentLevelXp + xpToNextLevel
        guard total > 0 else { return 1.0 }
        return Double(currentLevelXp) / Double(total)
    }

    /// Daily goal completion ratio [0,1].
    var dailyProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(dailyXp) / Double(dailyGoal), 1.0)
    }
}

// MARK: - VitaBadge

struct VitaBadge: Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String          // SF Symbol name
    let earnedAt: Date?       // nil = locked
    let category: BadgeCategory

    var isEarned: Bool { earnedAt != nil }
}

// MARK: - BadgeCategory

enum BadgeCategory: String, CaseIterable {
    case streak    = "Sequência"
    case cards     = "Flashcards"
    case study     = "Estudo"
    case social    = "Social"
    case milestone = "Marco"

    var color: Color {
        switch self {
        case .streak:    return VitaColors.dataAmber
        case .cards:     return VitaColors.accent
        case .study:     return VitaColors.dataGreen
        case .social:    return VitaColors.dataBlue
        case .milestone: return VitaColors.dataAmber
        }
    }

    var sfSymbol: String {
        switch self {
        case .streak:    return "flame.fill"
        case .cards:     return "rectangle.stack.fill"
        case .study:     return "book.fill"
        case .social:    return "person.2.fill"
        case .milestone: return "star.fill"
        }
    }
}

// MARK: - XP Event (for toast display)

struct XpEvent {
    let amount: Int
    let source: XpSource
    var label: String { source.label }
}

// MARK: - XpSource

/// XP reward sources — mirrors Android XpSource enum.
enum XpSource {
    case flashcardReview
    case flashcardEasy
    case chatMessage
    case noteCreated
    case pdfAnnotated
    case dailyLogin
    case deckComplete

    var label: String {
        switch self {
        case .flashcardReview: return "Flashcard"
        case .flashcardEasy:   return "Flashcard"
        case .chatMessage:     return "Chat"
        case .noteCreated:     return "Nota"
        case .pdfAnnotated:    return "PDF"
        case .dailyLogin:      return "Login diário"
        case .deckComplete:    return "Deck completo"
        }
    }

    var xp: Int {
        switch self {
        case .flashcardReview: return 10
        case .flashcardEasy:   return 15
        case .chatMessage:     return 5
        case .noteCreated:     return 20
        case .pdfAnnotated:    return 15
        case .dailyLogin:      return 25
        case .deckComplete:    return 50
        }
    }
}

// MARK: - Level Thresholds
// Mirrors Android LevelThresholds + server gamification.ts — 30 levels.

enum LevelThresholds {
    static let thresholds: [Int] = [
        0, 100, 250, 500, 1_000, 2_000, 3_500, 5_500, 8_000, 11_000,      // 1-10
        15_000, 20_000, 26_000, 33_000, 41_000, 50_000, 60_000, 72_000,    // 11-18
        85_000, 100_000, 120_000, 142_000, 168_000, 198_000, 232_000,      // 19-25
        270_000, 315_000, 365_000, 420_000, 500_000,                        // 26-30
    ]

    static func level(for totalXp: Int) -> Int {
        var currentLevel = 1
        for i in stride(from: thresholds.count - 1, through: 0, by: -1) {
            if totalXp >= thresholds[i] {
                currentLevel = i + 1
                break
            }
        }
        return currentLevel
    }

    static func xpForLevel(_ level: Int) -> Int {
        let idx = max(0, min(level - 1, thresholds.count - 1))
        return thresholds[idx]
    }

    static func xpToNextLevel(_ level: Int) -> Int {
        let currentIdx = max(0, min(level - 1, thresholds.count - 1))
        let nextIdx = min(currentIdx + 1, thresholds.count - 1)
        return currentIdx == nextIdx ? 10_000 : thresholds[nextIdx] - thresholds[currentIdx]
    }

    static func currentLevelXp(totalXp: Int, level: Int) -> Int {
        return totalXp - xpForLevel(level)
    }
}
