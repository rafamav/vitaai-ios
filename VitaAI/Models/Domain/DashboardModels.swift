import Foundation
import SwiftUI

struct DashboardProgress {
    var progressPercent: Double
    var streak: Int
    var flashcardsDue: Int
    var accuracy: Double
    var studyMinutes: Int
}

struct UpcomingExam: Identifiable {
    let id: String
    let subject: String
    let type: String
    let date: Date
    let daysUntil: Int
}

struct WeekDay: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let events: [String]
    let isToday: Bool
}

struct StudyModule: Identifiable {
    let id = UUID()
    let name: String
    let icon: String // SF Symbol name
    let count: Int
    let color: Color
}

struct VitaSuggestion: Identifiable {
    let id = UUID()
    let label: String
    let prompt: String
}

// MARK: - Hero Card Model

struct ContinueStudyingItem {
    let subject: String        // ex: "Anatomia Humana II"
    let sessionType: String    // ex: "Flashcards"
    let progress: Double       // 0.0 – 1.0
    let cardsDone: Int
    let cardsTotal: Int
    let streakDays: Int
    let daysUntilExam: Int?    // nil = sem prova proxima
    let studyInsight: String   // insight personalizado
}
