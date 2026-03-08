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
    // dailyGoal: populated from server (GamificationStatsResponse or AppConfigService).
    // Default 50 matches server gamification.ts fallback.
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
/// XP reward sources — matches server gamification.ts.
/// XP values are fetched from GET /api/config/app via AppConfigService.
/// Fallback constants are used offline or before first fetch.

enum XpSource {
    case flashcardReview
    case flashcardEasy
    case questionAnswered
    case questionAnsweredWrong
    case chatMessage
    case noteCreated
    case pdfAnnotated
    case dailyLogin
    case deckComplete
    case simuladoComplete
    case qbankSessionComplete
    case osceCompleted
    case studySessionEnd

    var label: String {
        switch self {
        case .flashcardReview:       return "Flashcard"
        case .flashcardEasy:         return "Flashcard"
        case .questionAnswered:      return "Questao"
        case .questionAnsweredWrong: return "Questao"
        case .chatMessage:           return "Chat"
        case .noteCreated:           return "Nota"
        case .pdfAnnotated:          return "PDF"
        case .dailyLogin:            return "Login diário"
        case .deckComplete:          return "Deck completo"
        case .simuladoComplete:      return "Simulado"
        case .qbankSessionComplete:  return "QBank"
        case .osceCompleted:         return "OSCE"
        case .studySessionEnd:       return "Sessao"
        }
    }

    /// Typed key for AppConfigService lookup.
    var rewardKey: XpRewardKey {
        switch self {
        case .flashcardReview:       return .flashcardReview
        case .flashcardEasy:         return .flashcardEasy
        case .questionAnswered:      return .questionAnswered
        case .questionAnsweredWrong: return .questionAnsweredWrong
        case .chatMessage:           return .chatMessage
        case .noteCreated:           return .noteCreated
        case .pdfAnnotated:          return .pdfAnnotated
        case .dailyLogin:            return .dailyLogin
        case .deckComplete:          return .deckComplete
        case .simuladoComplete:      return .simuladoComplete
        case .qbankSessionComplete:  return .qbankSessionComplete
        case .osceCompleted:         return .osceCompleted
        case .studySessionEnd:       return .studySessionEnd
        }
    }

    /// XP value from remote config (AppConfigService), with fallback to local constants.
    /// Callable from any concurrency context — reads the thread-safe static snapshot.
    /// NOTE: The server is the authoritative source. This value is only used for
    /// display/preview — actual XP awarded always comes from the server response
    /// (LogActivityResponse.xpAwarded).
    var xp: Int {
        AppConfigService.xp(for: rewardKey)
    }
}

// MARK: - Level Thresholds
// 1000 levels using formula floor(50 * n^1.5).
// Matches server gamification.ts — single source of truth.

enum LevelThresholds {
    static let maxLevel = 1000

    static func threshold(_ level: Int) -> Int {
        if level <= 1 { return 0 }
        return Int(floor(50.0 * pow(Double(level), 1.5)))
    }

    static func level(for totalXp: Int) -> Int {
        // Binary search for efficiency with 1000 levels
        var lo = 0
        var hi = maxLevel - 1
        while lo <= hi {
            let mid = (lo + hi) / 2
            if threshold(mid + 1) <= totalXp {
                lo = mid + 1
            } else {
                hi = mid - 1
            }
        }
        return max(1, lo + 1)
    }

    static func xpForLevel(_ level: Int) -> Int {
        return threshold(max(1, min(level, maxLevel)))
    }

    static func xpToNextLevel(_ level: Int) -> Int {
        let currentXp = xpForLevel(level)
        let nextLevel = min(level + 1, maxLevel)
        let nextXp = xpForLevel(nextLevel)
        return level >= maxLevel ? 10_000 : nextXp - currentXp
    }

    static func currentLevelXp(totalXp: Int, level: Int) -> Int {
        return totalXp - xpForLevel(level)
    }
}
