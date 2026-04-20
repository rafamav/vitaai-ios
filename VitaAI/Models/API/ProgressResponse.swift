import Foundation

// MIGRATION: Progress/Flashcard models kept manual.
// Generated UserProgress has only 6 of 18 fields in ProgressResponse.
// Generated Grade, Exam, FlashcardStats, FlashcardDeck, Flashcard all lack significant fields.
// Manual types match actual API responses more closely than OpenAPI spec.

struct ProgressResponse: Codable {
    var streakDays: Int = 0
    var totalStudyHours: Double = 0.0
    var avgAccuracy: Double = 0.0
    var flashcardsDue: Int = 0
    var totalCards: Int = 0
    var learnedCards: Int = 0
    var totalAnswered: Int = 0
    var todayCompleted: Int = 0
    var todayTotal: Int = 0
    var todayStudyMinutes: Int = 0
    var subjects: [SubjectProgress] = []
    var weekGrades: [GradeEntry] = []
    var upcomingExams: [ExamEntry] = []
    var heatmap: [Int] = []
    var weeklyHours: [Double] = Array(repeating: 0, count: 7)
    var weeklyGoalHours: Double = 0
    var weeklyActualHours: Double = 0
    var dailyStudyGoalMinutes: Int = 120

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        streakDays = (try? c.decode(Int.self, forKey: .streakDays)) ?? 0
        totalStudyHours = (try? c.decode(Double.self, forKey: .totalStudyHours)) ?? 0
        avgAccuracy = (try? c.decode(Double.self, forKey: .avgAccuracy)) ?? 0
        flashcardsDue = (try? c.decode(Int.self, forKey: .flashcardsDue)) ?? 0
        totalCards = (try? c.decode(Int.self, forKey: .totalCards)) ?? 0
        learnedCards = (try? c.decode(Int.self, forKey: .learnedCards)) ?? 0
        totalAnswered = (try? c.decode(Int.self, forKey: .totalAnswered)) ?? 0
        todayCompleted = (try? c.decode(Int.self, forKey: .todayCompleted)) ?? 0
        todayTotal = (try? c.decode(Int.self, forKey: .todayTotal)) ?? 0
        todayStudyMinutes = (try? c.decode(Int.self, forKey: .todayStudyMinutes)) ?? 0
        subjects = (try? c.decode([SubjectProgress].self, forKey: .subjects)) ?? []
        weekGrades = (try? c.decode([GradeEntry].self, forKey: .weekGrades)) ?? []
        upcomingExams = (try? c.decode([ExamEntry].self, forKey: .upcomingExams)) ?? []
        heatmap = (try? c.decode([Int].self, forKey: .heatmap)) ?? []
        weeklyHours = (try? c.decode([Double].self, forKey: .weeklyHours)) ?? Array(repeating: 0, count: 7)
        weeklyGoalHours = (try? c.decode(Double.self, forKey: .weeklyGoalHours)) ?? 0
        weeklyActualHours = (try? c.decode(Double.self, forKey: .weeklyActualHours)) ?? 0
        dailyStudyGoalMinutes = (try? c.decode(Int.self, forKey: .dailyStudyGoalMinutes)) ?? 120
    }
}

struct SubjectProgress: Codable {
    var subjectId: String = ""
    var name: String = ""
    var accuracy: Double = 0.0
    var hoursSpent: Double = 0.0
    var cardsDue: Int = 0
    var questionCount: Int = 0
}

struct GradeEntry: Codable, Identifiable {
    var id: String = ""
    var userId: String = ""
    var subjectId: String = ""
    var label: String = ""
    var value: Double = 0.0
    var maxValue: Double = 10.0
    var notes: String?
    var date: String?
}

struct ExamEntry: Codable, Identifiable {
    var id: String = ""
    var title: String = ""
    var subjectId: String?
    var subjectName: String?
    var examType: String?
    var date: String = ""
    var result: Double?
    var notes: String?
    var daysUntil: Int = 0
    var weight: Double?
    var pointsPossible: Double?
    var conceptCards: Int?
    var practiceCards: Int?
    var userId: String?
    var createdAt: String?
    var deletedAt: String?

    // Compat: display name from title or subjectName
    var displayName: String { title.isEmpty ? (subjectName ?? "Prova") : title }
}

struct ExamsResponse: Codable {
    var exams: [ExamEntry] = []
}

struct StudyEventsResponse: Codable {
    var events: [StudyEventEntry] = []
}

struct StudyEventEntry: Codable, Identifiable {
    var id: String = ""
    var title: String = ""
    var description: String?
    var eventType: String = ""
    var startAt: String = ""
    var endAt: String?
    var source: String?
    var courseName: String?
    var courseId: String?
}

// MARK: - Flashcard Stats API Response

struct FlashcardStatsResponse: Codable {
    var totalCards: Int = 0
    var newCards: Int = 0
    var youngCards: Int = 0
    var matureCards: Int = 0
    var totalReviews: Int = 0
    var retentionRate: Double = 0.0
    var streakDays: Int = 0
    var totalStudyMinutes: Int = 0
    var todayReviews: Int = 0
    var reviewsPerDay: [String: Int] = [:]
    var forecastNext7Days: [Int] = []
    var dailyRetention: [DailyRetentionEntry] = []
}

struct DailyRetentionEntry: Codable, Identifiable {
    var date: String = ""
    var count: Int = 0
    var retention: Double = 0.0
    var id: String { date }
}

struct FlashcardDeckEntry: Codable, Identifiable {
    var id: String = ""
    var title: String = ""
    var subjectId: String?
    var disciplineId: String?
    /// Canonical discipline slug (e.g. "farmacologia", "cardiologia"). Preferred
    /// over subjectId for matching with the user's enrolled disciplines, because
    /// most decks created by auto-seed have subjectId=null and only disciplineSlug.
    var disciplineSlug: String?
    var userId: String?
    var createdAt: String?
    var updatedAt: String?
    var deletedAt: String?
    var cards: [FlashcardEntry] = []
    var totalCards: Int?
    var dueCount: Int?

    /// Real card count — uses server-side totalCards when available, falls back to cards array length.
    var cardCount: Int { totalCards ?? cards.count }
}

struct FlashcardEntry: Codable, Identifiable {
    var id: String = ""
    var front: String = ""
    var back: String = ""
    var nextReviewAt: String?
    var lastReviewAt: String?
    var stability: Double?
    var difficulty: Double?
    var reps: Int = 0
    var lapses: Int = 0
    var state: String?
    var scheduledDays: Int?
    var tag: String?
    var deckId: String?
    var disciplineId: FlexString?
    var topicId: Int?
    var language: String?
    var sourceQuestionId: FlexString?
    var sourceNid: String?
    var createdAt: String?
    var updatedAt: String?
    var deletedAt: String?

    // Backwards compat
    var repetitions: Int { reps }
    var easeFactor: Double { difficulty ?? 2.5 }
    var interval: Int { scheduledDays ?? 0 }
}

/// Decodes both String and Int JSON values into a String
struct FlexString: Codable, Hashable {
    let value: String
    init(_ value: String) { self.value = value }
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let i = try? c.decode(Int.self) { value = String(i) }
        else if let d = try? c.decode(Double.self) { value = String(Int(d)) }
        else { value = "" }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}

struct FlashcardTopic: Decodable, Identifiable {
    var name: String = ""
    var totalCards: Int = 0
    var dueCount: Int = 0
    var tags: [String] = []
    var id: String { name }
}

struct FlashcardRecommended: Decodable, Identifiable {
    var id: String { deckId }
    var title: String = ""
    var dueCount: Int = 0
    var totalCards: Int = 0
    var deckId: String = ""
}
