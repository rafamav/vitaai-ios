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

// Evento de agenda do dia (usado no WeekAgendaSection)
struct AgendaEvent: Identifiable {
    let id = UUID()
    let title: String
    let time: String
    let colorTag: AgendaEventColor
}

enum AgendaEventColor {
    case green, blue, orange, gold
}

// Mini player — continuação de estudo ativo
struct MiniPlayerData {
    let subject: String       // "Anatomia"
    let tool: String          // "Flashcards"
    let completed: Int        // 34
    let total: Int            // 50
}

// Disciplina fraca — seção "Atenção Necessária"
struct WeakSubject: Identifiable {
    let id = UUID()
    let name: String
    let score: Double  // 0.0 – 1.0
}
