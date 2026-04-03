import Foundation

// MARK: - List / Stats

struct SimuladoListResponse: Decodable {
    var attempts: [SimuladoAttemptEntry] = []
    var stats: SimuladoStats = .init()
    var bySubject: [SubjectSummary] = []
    var bySemester: [SemesterSummary] = []

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attempts = (try? c.decode([SimuladoAttemptEntry].self, forKey: .attempts)) ?? []
        stats = (try? c.decode(SimuladoStats.self, forKey: .stats)) ?? .init()
        bySubject = (try? c.decode([SubjectSummary].self, forKey: .bySubject)) ?? []
        bySemester = (try? c.decode([SemesterSummary].self, forKey: .bySemester)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case attempts, stats, bySubject, bySemester
    }
}

struct SimuladoStats: Decodable {
    var totalAttempts: Int = 0
    var completedAttempts: Int = 0
    var totalQuestions: Int = 0
    var totalCorrect: Int = 0
    var avgScore: Double = 0
}

struct SubjectSummary: Decodable, Identifiable {
    var subject: String = ""
    var totalAttempts: Int = 0
    var avgScore: Double = 0
    var totalQuestions: Int = 0
    var correctRate: Double = 0
    var id: String { subject }
}

struct SemesterSummary: Decodable, Identifiable {
    var label: String = ""
    var totalAttempts: Int = 0
    var avgScore: Double = 0
    var subjects: [String] = []
    var id: String { label }
}

struct SimuladoAttemptEntry: Decodable, Identifiable {
    var id: String = ""
    var title: String = ""
    var subject: String? = nil
    var difficulty: String = "medium"
    var mode: String = "immediate"
    var totalQ: Int = 0
    var correctQ: Int = 0
    var score: Double = 0
    var status: String = "in_progress"
    var startedAt: String? = nil
    var finishedAt: String? = nil
    var timeTakenMs: Int64? = nil
    var questions: [SimuladoQuestionEntry] = []

    private enum CodingKeys: String, CodingKey {
        case id, title, subject, difficulty, mode, totalQ, correctQ, score, status
        case startedAt, finishedAt, timeTakenMs, questions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? ""
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        subject = try? c.decode(String.self, forKey: .subject)
        difficulty = (try? c.decode(String.self, forKey: .difficulty)) ?? "medium"
        mode = (try? c.decode(String.self, forKey: .mode)) ?? "immediate"
        totalQ = (try? c.decode(Int.self, forKey: .totalQ)) ?? 0
        correctQ = (try? c.decode(Int.self, forKey: .correctQ)) ?? 0
        score = (try? c.decode(Double.self, forKey: .score)) ?? 0
        status = (try? c.decode(String.self, forKey: .status)) ?? "in_progress"
        startedAt = try? c.decode(String.self, forKey: .startedAt)
        finishedAt = try? c.decode(String.self, forKey: .finishedAt)
        timeTakenMs = try? c.decode(Int64.self, forKey: .timeTakenMs)
        questions = (try? c.decode([SimuladoQuestionEntry].self, forKey: .questions)) ?? []
    }
}

struct SimuladoQuestionEntry: Decodable, Identifiable {
    var id: String = ""
    var questionNo: Int = 0
    var statement: String = ""
    var options: String = "[]"
    var correctIdx: Int = 0
    var chosenIdx: Int? = nil
    var isCorrect: Bool = false
    var subject: String? = nil
    var topic: String? = nil
    var explanation: String? = nil
    var difficulty: String? = nil

    var parsedOptions: [String] {
        (try? JSONDecoder().decode([String].self, from: Data(options.utf8))) ?? []
    }
}

// MARK: - Generate

struct GenerateSimuladoRequest: Encodable {
    let subject: String
    let difficulty: String
    let questionCount: Int
    let mode: String
    let sourceDocumentIds: [String]?
    let courseId: String?
}

struct GenerateSimuladoResponse: Decodable {
    var id: String = ""
    var questions: [SimuladoQuestionEntry] = []
}

// MARK: - Answer

struct AnswerSimuladoRequest: Encodable {
    let questionId: String
    let chosenIdx: Int
    let responseTimeMs: Int64?
}

struct AnswerSimuladoResponse: Decodable {
    var id: String = ""
    var isCorrect: Bool = false
    var correctIdx: Int = 0
}

// MARK: - Finish

struct FinishSimuladoResponse: Decodable, Equatable {
    var id: String = ""
    var correctQ: Int = 0
    var totalQ: Int = 0
    var score: Double = 0
}

// MARK: - Explain

struct ExplainResponse: Decodable {
    var general: String = ""
    var perOption: [OptionExplanation] = []
}

struct OptionExplanation: Decodable, Identifiable {
    var index: Int = 0
    var text: String = ""
    var id: Int { index }
}

// MARK: - Diagnostics

struct SimuladoDiagnosticsResponse: Decodable {
    var overall: OverallStats = .init()
    var bySubject: [SubjectStat] = []
    var byDifficulty: [DifficultyStat] = []
    var recentHistory: [HistoryEntry] = []
    var weakTopics: [WeakTopic] = []
}

struct OverallStats: Decodable {
    var totalAttempts: Int = 0
    var avgScore: Double = 0
    var bestScore: Double = 0
    var totalQuestions: Int = 0
    var correctRate: Double = 0
}

struct SubjectStat: Decodable, Identifiable {
    var subject: String = ""
    var attempts: Int = 0
    var avgScore: Double = 0
    var correctRate: Double = 0
    var trend: String = "stable"
    var id: String { subject }
}

struct DifficultyStat: Decodable, Identifiable {
    var difficulty: String = ""
    var correctRate: Double = 0
    var id: String { difficulty }
}

struct HistoryEntry: Decodable, Identifiable {
    var attemptId: String = ""
    var date: String = ""
    var subject: String? = nil
    var score: Double = 0
    var mode: String = ""
    var id: String { attemptId }
}

struct WeakTopic: Decodable, Identifiable {
    var subject: String = ""
    var correctRate: Double = 0
    var suggestion: String = ""
    var id: String { subject }
}

// MARK: - Config Redesign

struct SimuladoDiscipline: Identifiable {
    let name: String
    let count: Int
    var id: String { name }

    // No hardcoded defaults — disciplines come from GET /api/subjects (source of truth)
    static let defaults: [SimuladoDiscipline] = []
}

struct SimuladoTemplate: Identifiable {
    let id: Int
    let name: String
    let count: Int
    let timed: Bool
    let timeLimitMinutes: Int?
    let disciplineName: String?
    let iconName: String

    static let defaults: [SimuladoTemplate] = [
        .init(id: 0, name: "Revisão Rápida",  count: 10, timed: true,  timeLimitMinutes: 20,  disciplineName: nil,           iconName: "bolt"),
        .init(id: 1, name: "Simulado Padrão", count: 25, timed: true,  timeLimitMinutes: 50,  disciplineName: nil,           iconName: "checkmark.square"),
        .init(id: 2, name: "Intensivo",        count: 50, timed: true,  timeLimitMinutes: 90,  disciplineName: nil,           iconName: "clock"),
        .init(id: 3, name: "Cardiologia P1",   count: 25, timed: false, timeLimitMinutes: nil, disciplineName: "Cardiologia", iconName: "heart"),
    ]
}
