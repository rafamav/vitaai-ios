import Foundation

// MARK: - List / Stats

struct SimuladoListResponse: Decodable {
    var attempts: [SimuladoAttemptEntry] = []
    var stats: SimuladoStats = .init()
    var bySubject: [SubjectSummary] = []
    var bySemester: [SemesterSummary] = []
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

struct FinishSimuladoResponse: Decodable {
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
