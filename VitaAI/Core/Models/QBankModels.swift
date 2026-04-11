import Foundation

// MARK: - Filters

struct QBankFiltersResponse: Decodable {
    var institutions: [QBankInstitution] = []
    var topics: [QBankTopic] = []
    var years: [Int] = []
    var difficulties: [QBankDifficultyStat] = []
    var totalQuestions: Int = 0
    var disciplines: [QBankDiscipline] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        institutions = (try? c.decode([QBankInstitution].self, forKey: .institutions)) ?? []
        topics = (try? c.decode([QBankTopic].self, forKey: .topics)) ?? []
        years = (try? c.decode([Int].self, forKey: .years)) ?? []
        difficulties = (try? c.decode([QBankDifficultyStat].self, forKey: .difficulties)) ?? []
        totalQuestions = (try? c.decode(Int.self, forKey: .totalQuestions)) ?? 0
        disciplines = (try? c.decode([QBankDiscipline].self, forKey: .disciplines)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case institutions, topics, years, difficulties, totalQuestions, disciplines
    }
}

struct QBankDiscipline: Decodable, Identifiable, Hashable {
    var id: Int = 0
    var title: String = ""
    var parentId: Int? = nil
    var level: Int = 0
    var questionCount: Int = 0
    var children: [QBankDiscipline] = []
}

struct QBankInstitution: Identifiable, Hashable {
    var id: Int = 0
    var name: String = ""
    var slug: String = ""
    var state: String? = nil
    var isResidence: Bool = false
    var count: Int?
}

extension QBankInstitution: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, name, slug, state, isResidence, count
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        slug = (try? c.decode(String.self, forKey: .slug)) ?? ""
        state = try? c.decode(String.self, forKey: .state)
        isResidence = (try? c.decode(Bool.self, forKey: .isResidence)) ?? false
        count = try? c.decode(Int.self, forKey: .count)
    }
}

struct QBankTopic: Identifiable, Hashable {
    var id: Int = 0
    var title: String = ""
    var disciplineId: Int? = nil
    var name: String?
    var disciplineName: String?
    var count: Int?
    var iconSlug: String?

    var displayTitle: String { name ?? (title.isEmpty ? "Tópico \(id)" : title) }
}

extension QBankTopic: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, title, disciplineId, name, disciplineName, count, iconSlug
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        disciplineId = try? c.decode(Int.self, forKey: .disciplineId)
        name = try? c.decode(String.self, forKey: .name)
        disciplineName = try? c.decode(String.self, forKey: .disciplineName)
        count = try? c.decode(Int.self, forKey: .count)
        iconSlug = try? c.decode(String.self, forKey: .iconSlug)
    }
}

struct QBankDifficultyStat: Decodable, Identifiable {
    var difficulty: String = ""
    var label: String = ""
    var count: Int = 0
    var id: String { difficulty }

    /// Display label: use API-provided label if available, else localize the key
    var displayLabel: String {
        if !label.isEmpty { return label }
        return difficulty.difficultyLabel
    }
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

struct QBankQuestionDetail: Identifiable {
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

extension QBankQuestionDetail: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, statement, explanation, difficulty, year, isResidence, isCancelled
        case isDiscursive, isOutdated, institutionName, alternatives, images, topics
        case statistics, userAnswer
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        statement = (try? c.decode(String.self, forKey: .statement)) ?? ""
        explanation = try? c.decode(String.self, forKey: .explanation)
        difficulty = (try? c.decode(String.self, forKey: .difficulty)) ?? ""
        year = try? c.decode(Int.self, forKey: .year)
        isResidence = (try? c.decode(Bool.self, forKey: .isResidence)) ?? false
        isCancelled = (try? c.decode(Bool.self, forKey: .isCancelled)) ?? false
        isDiscursive = (try? c.decode(Bool.self, forKey: .isDiscursive)) ?? false
        isOutdated = (try? c.decode(Bool.self, forKey: .isOutdated)) ?? false
        institutionName = try? c.decode(String.self, forKey: .institutionName)
        alternatives = (try? c.decode([QBankAlternative].self, forKey: .alternatives)) ?? []
        images = (try? c.decode([QBankImage].self, forKey: .images)) ?? []
        topics = (try? c.decode([QBankTopic].self, forKey: .topics)) ?? []
        statistics = (try? c.decode([QBankStatistic].self, forKey: .statistics)) ?? []
        userAnswer = try? c.decode(QBankUserAnswer.self, forKey: .userAnswer)
    }
}

struct QBankAlternative: Identifiable {
    var id: Int = 0
    var text: String = ""
    var isCorrect: Bool = false
    var sortOrder: Int = 0
}

extension QBankAlternative: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, text, description, isCorrect, sortOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        // API returns "text", legacy model used "description"
        text = (try? c.decode(String.self, forKey: .text))
            ?? (try? c.decode(String.self, forKey: .description))
            ?? ""
        isCorrect = (try? c.decode(Bool.self, forKey: .isCorrect)) ?? false
        sortOrder = (try? c.decode(Int.self, forKey: .sortOrder)) ?? 0
    }
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
    // API returns accuracy as 0-100 (percentage). UI code expects 0.0-1.0 (fraction).
    var normalizedAccuracy: Double { accuracy > 1.0 ? accuracy / 100.0 : accuracy }
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

    init() {}

    init(from decoder: Decoder) throws {
        // API may return bare array or {"sessions": [...]}
        if let c = try? decoder.container(keyedBy: CodingKeys.self) {
            sessions = (try? c.decode([QBankSessionSummary].self, forKey: .sessions)) ?? []
        } else if let arr = try? decoder.singleValueContainer().decode([QBankSessionSummary].self) {
            sessions = arr
        }
    }

    private enum CodingKeys: String, CodingKey { case sessions }
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
