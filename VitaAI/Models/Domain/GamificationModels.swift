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
// Mirrors Android LevelThresholds — 16 tiers with cumulative XP.

enum LevelThresholds {
    static let thresholds: [Int: Int] = [
        1:  0,
        2:  100,
        3:  250,
        4:  500,
        5:  850,
        6:  1_300,
        7:  1_900,
        8:  2_650,
        9:  3_600,
        10: 4_750,
        11: 6_200,
        12: 8_000,
        13: 10_200,
        14: 13_000,
        15: 16_500,
        16: 20_000,
    ]
    static let maxLevelXp = 50_000

    static func level(for totalXp: Int) -> Int {
        var currentLevel = 1
        for level in 1...16 {
            guard let threshold = thresholds[level] else { break }
            if totalXp >= threshold { currentLevel = level }
        }
        return currentLevel
    }
}
