import Foundation

// MARK: - Filters

struct QBankFiltersResponse: Decodable {
    var institutions: [QBankInstitution] = []
    var topics: [QBankTopic] = []
    var years: [Int] = []
    var difficulties: [QBankDifficultyStat] = []
    var totalQuestions: Int = 0
    var disciplines: [QBankDiscipline] = []
}

struct QBankDiscipline: Decodable, Identifiable, Hashable {
    var id: Int = 0
    var title: String = ""
    var parentId: Int? = nil
    var level: Int = 0
    var questionCount: Int = 0
    var children: [QBankDiscipline] = []
}

struct QBankInstitution: Decodable, Identifiable, Hashable {
    var id: Int = 0
    var name: String = ""
    var slug: String = ""
    var state: String? = nil
    var isResidence: Bool = false
}

struct QBankTopic: Decodable, Identifiable, Hashable {
    var id: Int = 0
    var title: String = ""
}

struct QBankDifficultyStat: Decodable, Identifiable {
    var difficulty: String = ""
    var count: Int = 0
    var id: String { difficulty }
}

// MARK: - Questions List

struct QBankQuestionsResponse: Decodable {
    var questions: [QBankQuestionSummary] = []
    var pagination: QBankPagination = .init()
}

struct QBankQuestionSummary: Decodable, Identifiable {
    var id: Int = 0
    var statement: String = ""
    var difficulty: String = ""
    var year: Int? = nil
    var isResidence: Bool = false
    var isCancelled: Bool = false
    var institutionName: String? = nil
}

struct QBankPagination: Decodable {
    var page: Int = 1
    var limit: Int = 20
    var total: Int = 0
    var totalPages: Int = 0
}

// MARK: - Question Detail

struct QBankQuestionDetail: Decodable, Identifiable {
    var id: Int = 0
    var statement: String = ""
    var explanation: String? = nil
    var difficulty: String = ""
    var year: Int? = nil
    var isResidence: Bool = false
    var isCancelled: Bool = false
    var isDiscursive: Bool = false
    var isOutdated: Bool = false
    var institutionName: String? = nil
    var alternatives: [QBankAlternative] = []
    var images: [QBankImage] = []
    var topics: [QBankTopic] = []
    var statistics: [QBankStatistic] = []
    var userAnswer: QBankUserAnswer? = nil
}

struct QBankAlternative: Decodable, Identifiable {
    var id: Int = 0
    var description: String = ""
    var isCorrect: Bool = false
    var sortOrder: Int = 0
}

struct QBankImage: Decodable, Identifiable {
    var id: Int = 0
    var imageUrl: String = ""
    var caption: String? = nil
}

struct QBankStatistic: Decodable {
    var alternativeId: Int = 0
    var percentage: Double = 0
}

struct QBankUserAnswer: Decodable {
    var alternativeId: Int = 0
    var isCorrect: Bool = false
}

// MARK: - Answer

struct QBankAnswerRequest: Encodable {
    let alternativeId: Int
    let responseTimeMs: Int64?
    let sessionId: String?
}

struct QBankAnswerResponse: Decodable {
    var isCorrect: Bool = false
    var answerId: Int = 0
}

// MARK: - Session

struct QBankCreateSessionRequest: Encodable {
    let questionCount: Int
    let institutionIds: [Int]?
    let years: [Int]?
    let difficulties: [String]?
    let topicIds: [Int]?
    let disciplineIds: [Int]?
    let onlyResidence: Bool?
    let onlyUnanswered: Bool?
    let title: String?
    let status: String?
}

struct QBankSession: Decodable, Identifiable {
    var id: String = ""
    var title: String? = nil
    var questionIds: [Int] = []
    var totalQuestions: Int = 0
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var createdAt: String? = nil
}

// MARK: - Progress

struct QBankProgressResponse: Decodable {
    var totalAvailable: Int = 0
    var totalAnswered: Int = 0
    var totalCorrect: Int = 0
    var accuracy: Double = 0
    var byDifficulty: [QBankProgressByDifficulty] = []
    var byTopic: [QBankProgressByTopic] = []
}

struct QBankProgressByDifficulty: Decodable, Identifiable {
    var difficulty: String = ""
    var answered: Int = 0
    var correct: Int = 0
    var id: String { difficulty }

    var accuracy: Double {
        answered > 0 ? Double(correct) / Double(answered) : 0
    }
}

struct QBankProgressByTopic: Decodable, Identifiable {
    var topicId: Int = 0
    var topicTitle: String = ""
    var answered: Int = 0
    var correct: Int = 0
    var id: Int { topicId }

    var accuracy: Double {
        answered > 0 ? Double(correct) / Double(answered) : 0
    }
}

// MARK: - Sessions List

struct QBankSessionsResponse: Decodable {
    var sessions: [QBankSessionSummary] = []
}

struct QBankSessionSummary: Decodable, Identifiable {
    var id: String = ""
    var title: String? = nil
    var totalQuestions: Int = 0
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var completedAt: String? = nil
    var createdAt: String = ""

    var isActive: Bool { completedAt == nil }
}

// MARK: - Query Filters (ViewModel-side helper)

struct QBankQueryFilters {
    var institutionIds: [Int] = []
    var years: [Int] = []
    var difficulties: [String] = []
    var topicIds: [Int] = []
    var status: String? = nil      // "unanswered" | "correct" | "incorrect" | nil
    var onlyResidence: Bool = false
}
