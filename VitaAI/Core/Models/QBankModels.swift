import Foundation

// MARK: - Filters

struct QBankFiltersResponse: Decodable {
    var lens: String? = nil
    var groups: [QBankGroup] = []
    var institutions: [QBankInstitution] = []
    var topics: [QBankTopic] = []
    var years: [Int] = []
    var difficulties: [QBankDifficultyStat] = []
    var totalQuestions: Int = 0
    var disciplines: [QBankDiscipline] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lens = try? c.decode(String.self, forKey: .lens)
        groups = (try? c.decode([QBankGroup].self, forKey: .groups)) ?? []
        institutions = (try? c.decode([QBankInstitution].self, forKey: .institutions)) ?? []
        topics = (try? c.decode([QBankTopic].self, forKey: .topics)) ?? []
        years = (try? c.decode([Int].self, forKey: .years)) ?? []
        difficulties = (try? c.decode([QBankDifficultyStat].self, forKey: .difficulties)) ?? []
        totalQuestions = (try? c.decode(Int.self, forKey: .totalQuestions)) ?? 0
        disciplines = (try? c.decode([QBankDiscipline].self, forKey: .disciplines)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case lens, groups, institutions, topics, years, difficulties, totalQuestions, disciplines
    }
}

/// Grupo de Q conforme lente (Tradicional/PBL/CNRM-Areas). Schema novo
/// adicionado em 2026-04-28 — `slug` + `name` + `count` é o mínimo. Icon
/// e displayOrder são opcionais e preservam ordenação canônica do backend.
struct QBankGroup: Identifiable, Hashable, Decodable {
    var slug: String
    var name: String
    var count: Int
    var icon: String?
    var displayOrder: Int?

    var id: String { slug }

    private enum CodingKeys: String, CodingKey {
        case slug, name, count, icon, displayOrder
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slug = (try? c.decode(String.self, forKey: .slug)) ?? ""
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        count = (try? c.decode(Int.self, forKey: .count)) ?? 0
        icon = try? c.decode(String.self, forKey: .icon)
        displayOrder = try? c.decode(Int.self, forKey: .displayOrder)
    }
}

// MARK: - QBank Preview (count dinâmico)

struct QBankPreviewBody: Encodable {
    var lens: String?
    var groupSlugs: [String]?
    var institutionIds: [Int]?
    var topicIds: [Int]?
    var years: QBankPreviewYears?
    var difficulties: [String]?
    var format: [String]?
    var hideAnswered: Bool?
    var hideAnnulled: Bool?
    var hideReviewed: Bool?
    var excludeNoExplanation: Bool?
    var includeSynthetic: Bool?
}

struct QBankPreviewYears: Encodable {
    var min: Int?
    var max: Int?
}

struct QBankPreviewResp: Decodable {
    var total: Int = 0
    var byDifficulty: [String: Int] = [:]
    var appliedJourneyBoost: String? = nil

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        total = (try? c.decode(Int.self, forKey: .total)) ?? 0
        byDifficulty = (try? c.decode([String: Int].self, forKey: .byDifficulty)) ?? [:]
        appliedJourneyBoost = try? c.decode(String.self, forKey: .appliedJourneyBoost)
    }

    private enum CodingKeys: String, CodingKey {
        case total, byDifficulty, appliedJourneyBoost
    }
}

struct QBankDiscipline: Identifiable, Hashable {
    var id: Int = 0
    var title: String = ""
    var slug: String? = nil
    var parentId: Int? = nil
    var level: Int = 0
    var questionCount: Int = 0
    var children: [QBankDiscipline] = []
}

extension QBankDiscipline: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, title, name, slug, parentId, level, questionCount, children
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        slug = try? c.decode(String.self, forKey: .slug)
        // Backend new payload sends {slug, name, ...} without `id`; derive a stable
        // per-session hash so Set<Int> and Identifiable still work.
        if let rawId = try? c.decode(Int.self, forKey: .id) {
            id = rawId
        } else if let s = slug {
            id = abs(s.hashValue)
        }
        // Backend uses `name`, legacy payload uses `title`. Accept either.
        title = (try? c.decode(String.self, forKey: .title))
            ?? (try? c.decode(String.self, forKey: .name))
            ?? ""
        parentId = try? c.decode(Int.self, forKey: .parentId)
        level = (try? c.decode(Int.self, forKey: .level)) ?? 0
        questionCount = (try? c.decode(Int.self, forKey: .questionCount)) ?? 0
        children = (try? c.decode([QBankDiscipline].self, forKey: .children)) ?? []
    }
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
    var disciplineSlug: String? = nil
    /// Self-ref pra hierarquia 4 níveis (ÁREA-DISCIPLINA-TEMA-CONTEÚDO).
    /// nil = root (ÁREA). Backend retorna desde 2026-04-26.
    var parentTopicId: Int? = nil
    var name: String?
    var disciplineName: String?
    var count: Int?
    var iconSlug: String?

    var displayTitle: String { name ?? (title.isEmpty ? "Tópico \(id)" : title) }
}

extension QBankTopic: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, title, disciplineId, disciplineSlug, parentTopicId, name, disciplineName, count, iconSlug
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(Int.self, forKey: .id)) ?? 0
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        disciplineId = try? c.decode(Int.self, forKey: .disciplineId)
        disciplineSlug = try? c.decode(String.self, forKey: .disciplineSlug)
        parentTopicId = try? c.decode(Int.self, forKey: .parentTopicId)
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
    /// MedSimple catalog slugs derived from the selected enrolled/catalog disciplines.
    /// Backend uses this (via qbank_topics.disciplineSlug) to filter questions; the Int
    /// `disciplineIds` are local synthetic IDs and are ignored server-side.
    let disciplineSlugs: [String]?
    let onlyResidence: Bool?
    let onlyUnanswered: Bool?
    let title: String?
    let status: String?
    /// Quality filter — drop questions com explanation NULL ou length<=50.
    /// Default true client-side (Rafael 2026-04-27): "questões boas têm gabarito".
    let excludeNoExplanation: Bool?
    /// Quality filter — when false, drop LLM-generated questions
    /// (isSynthetic=true, year>=2025, source=medsimple). Default true (only oficiais).
    let includeSynthetic: Bool?
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
    /// "global" when totals reflect the whole catalogue (stage-scoped), "enrolled" when the
    /// request was filtered by `disciplineSlugs[]`. Added 2026-04-17b.
    var scope: String? = nil
    /// Echo of the slugs the server used to scope this response (empty for "global").
    var scopedSlugs: [String]? = nil
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
    /// Display labels for the disciplines this session was scoped to.
    /// Used as a fallback when `title` is nil; also feeds the chips on the session card.
    var disciplineTitles: [String]? = nil

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
