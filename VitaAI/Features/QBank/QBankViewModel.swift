import Foundation
import Observation

// MARK: - UI State

enum QBankScreen {
    case home
    case disciplines
    case config
    case session
    case result
}

struct QBankUiState {
    // Navigation
    var activeScreen: QBankScreen = .home

    // Home
    var progress: QBankProgressResponse = .init()
    var progressLoading = true
    var recentSessions: [QBankSessionSummary] = []
    var isCreatingSmartSession = false

    // Config
    var filters: QBankFiltersResponse = .init()
    var filtersLoading = true

    // Discipline selection (progressive step)
    var disciplinePath: [QBankDiscipline] = []
    var selectedDisciplineIds: Set<Int> = []

    // Config selections
    var selectedInstitutionIds: Set<Int> = []
    var selectedYears: Set<Int> = []
    var selectedDifficulties: Set<String> = []
    var selectedTopicIds: Set<Int> = []
    var onlyResidence = false
    var onlyUnanswered = false
    var questionCount = 20

    // Session
    var session: QBankSession? = nil
    var sessionLoading = false
    var currentQuestionDetail: QBankQuestionDetail? = nil
    var questionLoading = false
    var currentQuestionIndex = 0

    // Per-question state
    var selectedAlternativeId: Int? = nil
    var answerResult: QBankAnswerResponse? = nil
    var showFeedback = false
    var questionStartDate = Date()

    // Timer
    var elapsedSeconds = 0

    // Result
    var sessionAnswers: [Int: QBankAnswerResponse] = [:]   // questionId -> answer
    var sessionDetails: [Int: QBankQuestionDetail] = [:]   // questionId -> detail

    // Error
    var error: String? = nil

    // MARK: - Computed

    var currentQuestion: QBankQuestionDetail? { currentQuestionDetail }

    var totalInSession: Int { session?.questionIds.count ?? 0 }

    var progress1Based: Int { currentQuestionIndex + 1 }

    var sessionProgress: Double {
        totalInSession > 0 ? Double(currentQuestionIndex) / Double(totalInSession) : 0
    }

    var correctCount: Int {
        sessionAnswers.values.filter { $0.isCorrect }.count
    }

    var accuracy: Double {
        let total = sessionAnswers.count
        return total > 0 ? Double(correctCount) / Double(total) : 0
    }

    var isLastQuestion: Bool {
        guard let session else { return false }
        return currentQuestionIndex >= session.questionIds.count - 1
    }

    var hasActiveFilters: Bool {
        !selectedInstitutionIds.isEmpty || !selectedYears.isEmpty ||
        !selectedDifficulties.isEmpty || !selectedTopicIds.isEmpty ||
        onlyResidence || onlyUnanswered
    }

    /// Current disciplines to display based on drill-down path
    var currentDisciplines: [QBankDiscipline] {
        if disciplinePath.isEmpty {
            return filters.disciplines
        }
        return disciplinePath.last?.children ?? []
    }

    /// Breadcrumb labels for discipline navigation
    var disciplineBreadcrumb: [String] {
        ["Todas"] + disciplinePath.map(\.title)
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class QBankViewModel {

    var state = QBankUiState()
    private let api: VitaAPI

    init(api: VitaAPI) {
        self.api = api
    }

    // MARK: - Home

    func loadHomeData() {
        Task {
            state.progressLoading = true
            do {
                async let progressTask = api.getQBankProgress()
                async let sessionsTask = api.getQBankSessions(limit: 5)
                state.progress = try await progressTask
                let sessionsResponse = try? await sessionsTask
                state.recentSessions = sessionsResponse?.sessions ?? []
                state.error = nil
            } catch {
                state.error = "Erro ao carregar progresso"
            }
            state.progressLoading = false
        }
    }

    func startSmartStudy() {
        Task {
            state.isCreatingSmartSession = true
            state.error = nil
            do {
                let req = QBankCreateSessionRequest(
                    questionCount: 40,
                    institutionIds: nil,
                    years: nil,
                    difficulties: nil,
                    topicIds: nil,
                    disciplineIds: nil,
                    onlyResidence: nil,
                    onlyUnanswered: true,
                    title: nil,
                    status: "wrong"
                )
                let session = try await api.createQBankSession(request: req)
                state.session = session
                state.currentQuestionIndex = 0
                state.sessionAnswers = [:]
                state.sessionDetails = [:]
                state.selectedAlternativeId = nil
                state.answerResult = nil
                state.showFeedback = false
                state.questionStartDate = Date()
                state.elapsedSeconds = 0
                state.activeScreen = .session
                await loadCurrentQuestion()
            } catch {
                state.error = "Erro ao criar sessão inteligente: \(error.localizedDescription)"
            }
            state.isCreatingSmartSession = false
        }
    }

    // MARK: - Config

    func loadFilters() {
        Task {
            state.filtersLoading = true
            do {
                state.filters = try await api.getQBankFilters()
                state.error = nil
            } catch {
                state.error = "Erro ao carregar filtros"
            }
            state.filtersLoading = false
        }
    }

    func toggleInstitution(_ id: Int) {
        if state.selectedInstitutionIds.contains(id) {
            state.selectedInstitutionIds.remove(id)
        } else {
            state.selectedInstitutionIds.insert(id)
        }
    }

    func toggleYear(_ year: Int) {
        if state.selectedYears.contains(year) {
            state.selectedYears.remove(year)
        } else {
            state.selectedYears.insert(year)
        }
    }

    func toggleDifficulty(_ diff: String) {
        if state.selectedDifficulties.contains(diff) {
            state.selectedDifficulties.remove(diff)
        } else {
            state.selectedDifficulties.insert(diff)
        }
    }

    func toggleTopic(_ id: Int) {
        if state.selectedTopicIds.contains(id) {
            state.selectedTopicIds.remove(id)
        } else {
            state.selectedTopicIds.insert(id)
        }
    }

    func setOnlyResidence(_ val: Bool) { state.onlyResidence = val }
    func setOnlyUnanswered(_ val: Bool) { state.onlyUnanswered = val }
    func setQuestionCount(_ val: Int) { state.questionCount = val }

    func clearFilters() {
        state.selectedInstitutionIds = []
        state.selectedYears = []
        state.selectedDifficulties = []
        state.selectedTopicIds = []
        state.onlyResidence = false
        state.onlyUnanswered = false
        state.questionCount = 20
    }

    // MARK: - Create Session

    func createSession() {
        Task {
            state.sessionLoading = true
            state.error = nil
            do {
                let req = QBankCreateSessionRequest(
                    questionCount: state.questionCount,
                    institutionIds: state.selectedInstitutionIds.isEmpty ? nil : Array(state.selectedInstitutionIds),
                    years: state.selectedYears.isEmpty ? nil : Array(state.selectedYears).sorted(),
                    difficulties: state.selectedDifficulties.isEmpty ? nil : Array(state.selectedDifficulties),
                    topicIds: state.selectedTopicIds.isEmpty ? nil : Array(state.selectedTopicIds),
                    disciplineIds: state.selectedDisciplineIds.isEmpty ? nil : Array(state.selectedDisciplineIds),
                    onlyResidence: state.onlyResidence ? true : nil,
                    onlyUnanswered: state.onlyUnanswered ? true : nil,
                    title: nil,
                    status: nil
                )
                let session = try await api.createQBankSession(request: req)
                state.session = session
                state.currentQuestionIndex = 0
                state.sessionAnswers = [:]
                state.sessionDetails = [:]
                state.selectedAlternativeId = nil
                state.answerResult = nil
                state.showFeedback = false
                state.questionStartDate = Date()
                state.elapsedSeconds = 0
                state.activeScreen = .session
                // Load first question
                await loadCurrentQuestion()
            } catch {
                state.error = "Erro ao criar sessão. Tente novamente."
            }
            state.sessionLoading = false
        }
    }

    // MARK: - Session

    private func loadCurrentQuestion() async {
        guard let session = state.session,
              session.questionIds.indices.contains(state.currentQuestionIndex) else { return }
        let questionId = session.questionIds[state.currentQuestionIndex]
        // Use cached detail if available
        if let cached = state.sessionDetails[questionId] {
            state.currentQuestionDetail = cached
            return
        }
        state.questionLoading = true
        do {
            let detail = try await api.getQBankQuestion(id: questionId)
            state.sessionDetails[questionId] = detail
            state.currentQuestionDetail = detail
        } catch {
            state.error = "Erro ao carregar questão"
        }
        state.questionLoading = false
    }

    func selectAlternative(id: Int) {
        guard !state.showFeedback else { return }
        state.selectedAlternativeId = id
    }

    func confirmAnswer() {
        guard let question = state.currentQuestionDetail,
              let alternativeId = state.selectedAlternativeId,
              !state.showFeedback else { return }

        let responseTimeMs = Int64(Date().timeIntervalSince(state.questionStartDate) * 1000)

        Task {
            do {
                let result = try await api.answerQBankQuestion(
                    id: question.id,
                    request: QBankAnswerRequest(
                        alternativeId: alternativeId,
                        responseTimeMs: responseTimeMs,
                        sessionId: state.session?.id
                    )
                )
                state.answerResult = result
                state.sessionAnswers[question.id] = result
                state.showFeedback = true
            } catch {
                // Compute locally as fallback
                let isCorrect = question.alternatives.first(where: { $0.id == alternativeId })?.isCorrect ?? false
                let fallback = QBankAnswerResponse(isCorrect: isCorrect, answerId: 0)
                state.answerResult = fallback
                state.sessionAnswers[question.id] = fallback
                state.showFeedback = true
            }
        }
    }

    func nextQuestion() {
        guard let session = state.session else { return }
        let next = state.currentQuestionIndex + 1
        if next >= session.questionIds.count {
            state.activeScreen = .result
            return
        }
        state.currentQuestionIndex = next
        state.selectedAlternativeId = nil
        state.answerResult = nil
        state.showFeedback = false
        state.questionStartDate = Date()
        state.currentQuestionDetail = nil
        Task { await loadCurrentQuestion() }
    }

    func finishSession() {
        state.activeScreen = .result
    }

    // MARK: - Result navigation

    func goToHome() {
        state.activeScreen = .home
        state.session = nil
        state.sessionAnswers = [:]
        state.sessionDetails = [:]
        state.currentQuestionDetail = nil
        loadHomeData()
    }

    // MARK: - Disciplines (progressive step)

    func goToDisciplines() {
        state.activeScreen = .disciplines
        state.disciplinePath = []
        state.selectedDisciplineIds = []
        loadFilters()
    }

    func selectDiscipline(_ discipline: QBankDiscipline) {
        if discipline.children.isEmpty {
            toggleDisciplineSelection(discipline.id)
        } else {
            state.disciplinePath.append(discipline)
        }
    }

    func toggleDisciplineSelection(_ id: Int) {
        if state.selectedDisciplineIds.contains(id) {
            state.selectedDisciplineIds.remove(id)
        } else {
            state.selectedDisciplineIds.insert(id)
        }
    }

    func goBackDiscipline() {
        if state.disciplinePath.isEmpty {
            state.activeScreen = .home
        } else {
            state.disciplinePath.removeLast()
        }
    }

    func goBackBreadcrumb(to index: Int) {
        if index < 0 {
            state.disciplinePath = []
        } else {
            state.disciplinePath = Array(state.disciplinePath.prefix(index + 1))
        }
    }

    func proceedFromDisciplines() {
        state.activeScreen = .config
    }

    func goToConfig() {
        state.activeScreen = .disciplines
        state.disciplinePath = []
        state.selectedDisciplineIds = []
        loadFilters()
    }

    func startNewSession() {
        clearFilters()
        state.activeScreen = .disciplines
        state.disciplinePath = []
        state.selectedDisciplineIds = []
        state.session = nil
        state.sessionAnswers = [:]
        state.sessionDetails = [:]
        state.currentQuestionDetail = nil
        state.elapsedSeconds = 0
        loadFilters()
    }

    func resumeSession(_ summary: QBankSessionSummary) {
        // Convert summary to a session and start it
        let session = QBankSession(
            id: summary.id,
            title: summary.title,
            questionIds: [], // will be loaded
            totalQuestions: summary.totalQuestions,
            currentIndex: summary.currentIndex,
            correctCount: summary.correctCount,
            createdAt: summary.createdAt
        )
        state.session = session
        state.currentQuestionIndex = summary.currentIndex
        state.sessionAnswers = [:]
        state.sessionDetails = [:]
        state.selectedAlternativeId = nil
        state.answerResult = nil
        state.showFeedback = false
        state.questionStartDate = Date()
        state.elapsedSeconds = 0
        state.activeScreen = .session
        // For now, go to config to start a new session instead
        // since we'd need the full question IDs to resume
        goToDisciplines()
    }

    func clearError() { state.error = nil }

    // MARK: - Timer tick (called externally by the View)

    func tickTimer() {
        state.elapsedSeconds += 1
    }
}

// MARK: - Difficulty helpers

extension String {
    var difficultyLabel: String {
        switch self {
        case "easy":   return "Fácil"
        case "medium": return "Médio"
        case "hard":   return "Difícil"
        default:       return self.capitalized
        }
    }
}
