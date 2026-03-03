import Foundation

struct ProgressResponse: Codable {
    var streakDays: Int = 0
    var totalStudyHours: Double = 0.0
    var avgAccuracy: Double = 0.0
    var flashcardsDue: Int = 0
    var totalCards: Int = 0
    var todayCompleted: Int = 0
    var todayTotal: Int = 0
    var todayStudyMinutes: Int = 0
    var subjects: [SubjectProgress] = []
    var weekGrades: [GradeEntry] = []
    var upcomingExams: [ExamEntry] = []
}

struct SubjectProgress: Codable {
    var subjectId: String = ""
    var accuracy: Double = 0.0
    var hoursSpent: Double = 0.0
    var cardsDue: Int = 0
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
    var subjectName: String = ""
    var examType: String = ""
    var date: String = ""
    var notes: String?
    var daysUntil: Int = 0
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
    var updatedAt: String?
    var cards: [FlashcardEntry] = []
}

struct FlashcardEntry: Codable, Identifiable {
    var id: String = ""
    var front: String = ""
    var back: String = ""
    var nextReviewAt: String?
    var easeFactor: Double = 2.5
    var interval: Int = 0
    var repetitions: Int = 0
}
