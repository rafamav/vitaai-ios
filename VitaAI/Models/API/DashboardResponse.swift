import Foundation

struct DashboardResponse: Decodable {
    var greeting: String = ""
    var subtitle: String = ""
    var hero: [DashboardHeroCard] = []
    var subjects: [DashboardSubject] = []
    var agenda: [DashboardAgendaItem] = []
    var flashcardsDueTotal: Int = 0
    var xp: DashboardXP?

    // Legacy compat
    var exams: [DashboardExam]?
    var studyRecommendations: [DashboardRecommendation]?
    var todayReviewed: Int?
}

struct DashboardHeroCard: Decodable, Identifiable {
    var id: String { "\(type)-\(title)" }
    var type: String = ""
    var title: String = ""
    var subtitle: String?
    var pills: [DashboardPill] = []
    var action: DashboardAction?
    var urgency: Int?
}

struct DashboardPill: Decodable {
    var icon: String = ""
    var text: String = ""
}

struct DashboardAction: Decodable {
    var type: String = ""
    var target: String = ""
    var id: String?
}

struct DashboardExam: Decodable, Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    var subject: String = ""
    var daysUntil: Int = 0
    var description: String?
    var conceptCards: Int = 0
    var practiceCards: Int = 0
}

struct DashboardSubject: Decodable, Identifiable {
    var name: String = ""
    var shortName: String?
    var difficulty: String?
    var vitaScore: Double?
    var vitaTier: String?

    var id: String { name }
}

struct DashboardAgendaItem: Decodable {
    var type: String = ""
    var title: String = ""
    var daysUntil: Int = 0
    var date: String = ""
}

struct DashboardRecommendation: Decodable {
    var title: String = ""
    var dueCount: Int = 0
    var deckId: String = ""
}

struct DashboardXP: Decodable {
    var total: Int = 0
    var level: Int = 0
}
