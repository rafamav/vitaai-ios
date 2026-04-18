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

    // Status filter: "unanswered" | "wrong" | "correct" | nil
    var selectedStatus: String? = nil

    // Home chip selection. nil => all enrolled disciplines (default scope).
    // Holds the StudyOverviewSubject.id so UI and VM agree without embedding
    // the full subject name in state.
    var selectedSubjectId: String? = nil
    var selectedSubjectName: String? = nil

    // Search (client-side)
    var institutionSearch: String = ""
    var topicSearch: String = ""

    // Dynamic available count
    var availableCount: Int? = nil
    var isLoadingCount = false

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

    // Error -- scoped per concern so filter errors don't leak to home screen
    var error: String? = nil
    var filterError: String? = nil
    var answerError: String? = nil

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
        onlyResidence || onlyUnanswered || selectedStatus != nil
    }

    /// Display count: dynamic or fallback to totalQuestions from filters
    var displayAvailableCount: Int {
        availableCount ?? filters.totalQuestions
    }

    /// Institutions filtered by local search
    var filteredInstitutions: [QBankInstitution] {
        if institutionSearch.isEmpty { return filters.institutions }
        let query = institutionSearch.lowercased()
        return filters.institutions.filter { inst in
            inst.name.lowercased().contains(query) ||
            (inst.state?.lowercased().contains(query) ?? false)
        }
    }

    /// Topics filtered by local search
    var filteredTopics: [QBankTopic] {
        if topicSearch.isEmpty { return filters.topics }
        let query = topicSearch.lowercased()
        return filters.topics.filter { $0.title.lowercased().contains(query) }
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

    /// Summary of selected disciplines
    var selectedDisciplineSummary: String {
        if selectedDisciplineIds.isEmpty { return "" }
        let allDisc = QBankUiState.flattenDisciplines(filters.disciplines)
        let names = allDisc.filter { selectedDisciplineIds.contains($0.id) }.map(\.title)
        let preview = names.prefix(3).joined(separator: ", ")
        return names.count > 3 ? "\(preview) +\(names.count - 3)" : preview
    }

    /// Recursively flatten a discipline tree
    static func flattenDisciplines(_ disciplines: [QBankDiscipline]) -> [QBankDiscipline] {
        var result: [QBankDiscipline] = []
        for d in disciplines {
            result.append(d)
            result.append(contentsOf: flattenDisciplines(d.children))
        }
        return result
    }
}

extension QBankViewModel {
    /// Inverse of backend `humanizeSlug`: "Patologia Geral" → "patologia-geral".
    /// Strips diacritics, lowercases, drops non-alphanumerics, joins words with dashes.
    static func slugifyDisciplineTitle(_ title: String) -> String {
        let folded = title.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
        let lower = folded.lowercased()
        let cleaned = lower.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
            return " "
        }
        let str = String(cleaned)
        return str
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: "-")
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class QBankViewModel {

    var state = QBankUiState()
    private let api: VitaAPI
    private let gamificationEvents: GamificationEventManager
    private let dataManager: AppDataManager

    /// Debounce task for dynamic count refresh
    private var countTask: Task<Void, Never>?

    /// Track session start for duration calculation
    private var sessionStartDate = Date()

    init(api: VitaAPI, gamificationEvents: GamificationEventManager, dataManager: AppDataManager) {
        self.api = api
        self.gamificationEvents = gamificationEvents
        self.dataManager = dataManager
    }

    /// Disciplines sorted by VitaScore (highest risk first)
    var sortedDisciplines: [QBankDiscipline] {
        state.currentDisciplines.sorted { dataManager.vitaScore(for: $0.title) > dataManager.vitaScore(for: $1.title) }
    }

    // MARK: - Home

    /// Slugify enrolled subject names into discipline slugs that the backend
    /// resolves (exact / alias / token-trim) against qbank_topics.disciplineSlug.
    /// e.g. "Patologia Medica" -> "patologia-medica" -> canonical "patologia-geral".
    var enrolledDisciplineSlugs: [String] {
        let all = (dataManager.gradesResponse?.current ?? []) + (dataManager.gradesResponse?.completed ?? [])
        let slugs = all.map { Self.slugifyDisciplineTitle($0.subjectName) }.filter { !$0.isEmpty }
        return Array(Set(slugs)).sorted()
    }

    func loadHomeData() {
        Task {
            state.progressLoading = true
            do {
                let slugs = scopedSlugsForHome()
                async let progressTask = api.getQBankProgress(disciplineSlugs: slugs)
                async let sessionsTask = api.getQBankSessions(limit: 5)
                state.progress = try await progressTask
                let sessionsResponse = try? await sessionsTask
                state.recentSessions = sessionsResponse?.sessions ?? []
                state.error = nil
            } catch {
                print("[QBank] loadHomeData failed: \(error)")
                state.progress = .init()
                state.recentSessions = []
                state.error = nil
            }
            state.progressLoading = false
        }
    }

    /// Home chip selection: scope progress to one enrolled subject, or clear
    /// to show all enrolled. Recent sessions are filtered client-side in the
    /// view so a single slug lookup is enough here.
    func setSelectedSubject(id: String?, name: String?) {
        state.selectedSubjectId = id
        state.selectedSubjectName = name
        loadHomeData()
    }

    /// Slugs to send to `/api/qbank/progress`. One slug when a chip is
    /// selected, all enrolled slugs otherwise. Empty array = backend falls
    /// back to global scope which we intentionally avoid here.
    private func scopedSlugsForHome() -> [String] {
        if let name = state.selectedSubjectName, !name.isEmpty {
            let slug = Self.slugifyDisciplineTitle(name)
            if !slug.isEmpty { return [slug] }
        }
        return enrolledDisciplineSlugs
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
                    disciplineSlugs: nil,
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
                sessionStartDate = Date()
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
            state.filterError = nil
            do {
                let filters = try await api.getQBankFilters()
                state.filters = filters
                state.availableCount = filters.totalQuestions
                // If API returned no disciplines, fallback to user's enrolled subjects
                if filters.disciplines.isEmpty {
                    let dashboard = try? await api.getDashboard()
                    if let subjects = dashboard?.subjects, !subjects.isEmpty {
                        state.filters.disciplines = subjects.enumerated().map { index, subject in
                            QBankDiscipline(
                                id: index + 1,
                                title: subject.name ?? "",
                                parentId: nil,
                                level: 0,
                                questionCount: 0,
                                children: []
                            )
                        }
                    }
                }
                state.filterError = nil
            } catch {
                print("[QBank] loadFilters failed: \(error)")
                if let dashboard = try? await api.getDashboard(),
                   !(dashboard.subjects ?? []).isEmpty {
                    state.filters.disciplines = (dashboard.subjects ?? []).enumerated().map { index, subject in
                        QBankDiscipline(
                            id: index + 1,
                            title: subject.name ?? "",
                            parentId: nil,
                            level: 0,
                            questionCount: 0,
                            children: []
                        )
                    }
                } else {
                    state.filters = .init()
                    state.filterError = "Filtros indisponiveis no momento."
                    dismissFilterErrorAfterDelay()
                }
            }
            state.filtersLoading = false
        }
    }

    func retryLoadFilters() {
        loadFilters()
    }

    func dismissFilterError() {
        state.filterError = nil
    }

    private func dismissFilterErrorAfterDelay() {
        Task {
            try? await Task.sleep(for: .seconds(4))
            state.filterError = nil
        }
    }

    // MARK: - Dynamic Available Count (debounced)

    private func scheduleCountRefresh() {
        countTask?.cancel()
        countTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.loadAvailableCount()
        }
    }

    private func loadAvailableCount() async {
        state.isLoadingCount = true
        do {
            let response = try await api.getQBankQuestions(
                page: 1,
                limit: 1,
                institutionIds: Array(state.selectedInstitutionIds),
                years: Array(state.selectedYears),
                difficulties: Array(state.selectedDifficulties),
                topicIds: Array(state.selectedTopicIds),
                status: state.selectedStatus,
                onlyResidence: state.onlyResidence
            )
            state.availableCount = response.pagination.total
        } catch {
            print("[QBank] loadAvailableCount failed: \(error)")
        }
        state.isLoadingCount = false
    }

    // MARK: - Filter Toggles

    func toggleInstitution(_ id: Int) {
        if state.selectedInstitutionIds.contains(id) {
            state.selectedInstitutionIds.remove(id)
        } else {
            state.selectedInstitutionIds.insert(id)
        }
        scheduleCountRefresh()
    }

    func toggleYear(_ year: Int) {
        if state.selectedYears.contains(year) {
            state.selectedYears.remove(year)
        } else {
            state.selectedYears.insert(year)
        }
        scheduleCountRefresh()
    }

    func toggleDifficulty(_ diff: String) {
        if state.selectedDifficulties.contains(diff) {
            state.selectedDifficulties.remove(diff)
        } else {
            state.selectedDifficulties.insert(diff)
        }
        scheduleCountRefresh()
    }

    func toggleTopic(_ id: Int) {
        if state.selectedTopicIds.contains(id) {
            state.selectedTopicIds.remove(id)
        } else {
            state.selectedTopicIds.insert(id)
        }
        scheduleCountRefresh()
    }

    func setOnlyResidence(_ val: Bool) {
        state.onlyResidence = val
        scheduleCountRefresh()
    }

    func setOnlyUnanswered(_ val: Bool) {
        state.onlyUnanswered = val
    }

    func setQuestionCount(_ val: Int) { state.questionCount = val }

    // MARK: - Status filter (unanswered / wrong / correct)

    func setStatus(_ status: String) {
        if state.selectedStatus == status {
            state.selectedStatus = nil
            state.onlyUnanswered = false
        } else {
            state.selectedStatus = status
            state.onlyUnanswered = (status == "unanswered")
        }
        scheduleCountRefresh()
    }

    // MARK: - Search

    func setInstitutionSearch(_ query: String) {
        state.institutionSearch = query
    }

    func setTopicSearch(_ query: String) {
        state.topicSearch = query
    }

    // MARK: - Year Range

    func setYearRange(start: Int, end: Int) {
        let allYears = state.filters.years
        guard let minYear = allYears.min(), let maxYear = allYears.max() else { return }
        if start <= minYear && end >= maxYear {
            state.selectedYears = []
        } else {
            state.selectedYears = Set(allYears.filter { $0 >= start && $0 <= end })
        }
        scheduleCountRefresh()
    }

    func clearYears() {
        state.selectedYears = []
        scheduleCountRefresh()
    }

    // MARK: - Clear All

    func clearFilters() {
        state.selectedInstitutionIds = []
        state.selectedYears = []
        state.selectedDifficulties = []
        state.selectedTopicIds = []
        state.selectedDisciplineIds = []
        state.disciplinePath = []
        state.onlyResidence = false
        state.onlyUnanswered = false
        state.selectedStatus = nil
        state.institutionSearch = ""
        state.topicSearch = ""
        state.questionCount = 20
        scheduleCountRefresh()
    }

    // MARK: - Create Session

    func createSession() {
        Task {
            state.sessionLoading = true
            state.error = nil
            do {
                // Resolve selected synthetic discipline IDs → catalog slugs.
                // Backend filters by slug through qbank_topics.disciplineSlug; the Int
                // `disciplineIds` are iOS-synthetic and intentionally not sent.
                // Slug is derived from title (strip accents + lowercase + dash-join)
                // to match backend's humanizeSlug() inverse.
                let allDisc = QBankUiState.flattenDisciplines(state.filters.disciplines)
                let selectedSlugs = state.selectedDisciplineIds
                    .compactMap { id in allDisc.first(where: { $0.id == id })?.title }
                    .map { Self.slugifyDisciplineTitle($0) }
                    .filter { !$0.isEmpty }
                let req = QBankCreateSessionRequest(
                    questionCount: state.questionCount,
                    institutionIds: state.selectedInstitutionIds.isEmpty ? nil : Array(state.selectedInstitutionIds),
                    years: state.selectedYears.isEmpty ? nil : Array(state.selectedYears).sorted(),
                    difficulties: state.selectedDifficulties.isEmpty ? nil : Array(state.selectedDifficulties),
                    topicIds: state.selectedTopicIds.isEmpty ? nil : Array(state.selectedTopicIds),
                    disciplineIds: nil, // synthetic IDs are iOS-only; backend ignores
                    disciplineSlugs: selectedSlugs.isEmpty ? nil : selectedSlugs,
                    onlyResidence: state.onlyResidence ? true : nil,
                    onlyUnanswered: {
                        if state.selectedStatus == "unanswered" { return true }
                        if state.onlyUnanswered { return true }
                        return nil
                    }(),
                    title: nil, // backend auto-derives from disciplineSlugs when nil
                    status: state.selectedStatus
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
                sessionStartDate = Date()
                await loadCurrentQuestion()
            } catch {
                let msg = "\(error)".contains("404") || "\(error)".contains("No questions")
                    ? "Nenhuma questão encontrada com esses filtros. Tente ampliar os criterios."
                    : "Erro ao criar sessão. Tente novamente."
                state.error = msg
            }
            state.sessionLoading = false
        }
    }

    // MARK: - Session

    private func loadCurrentQuestion() async {
        guard let session = state.session,
              session.questionIds.indices.contains(state.currentQuestionIndex) else { return }
        let questionId = session.questionIds[state.currentQuestionIndex]
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
            let request = QBankAnswerRequest(
                alternativeId: alternativeId,
                responseTimeMs: responseTimeMs,
                sessionId: state.session?.id
            )
            var result: QBankAnswerResponse?
            var lastError: Error?
            // Try up to 2 times (initial + 1 retry)
            for attempt in 0..<2 {
                do {
                    result = try await api.answerQBankQuestion(id: question.id, request: request)
                    lastError = nil
                    break
                } catch {
                    lastError = error
                    if attempt == 0 {
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                }
            }
            if let result {
                state.answerError = nil
                state.answerResult = result
                state.sessionAnswers[question.id] = result
                state.showFeedback = true
                let action = result.isCorrect ? "question_answered" : "question_answered_wrong"
                Task { [api, gamificationEvents] in
                    if let actResult = try? await api.logActivity(action: action) {
                        gamificationEvents.handleActivityResponse(actResult, previousLevel: nil)
                    }
                }
            } else {
                // Surface the real error to the UI instead of silently faking success.
                // Local fallback keeps the session moving but we flag it so the student
                // knows the answer didn't reach the server (progress won't persist).
                print("[QBank] confirmAnswer failed after retry: \(String(describing: lastError))")
                state.answerError = "N\u{e3}o consegui registrar sua resposta no servidor. Sua sess\u{e3}o continua, mas esta quest\u{e3}o pode n\u{e3}o aparecer no progresso."
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
            logSessionComplete()
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
        logSessionComplete()
    }

    private func logSessionComplete() {
        guard let session = state.session else { return }
        let correctCount = state.sessionAnswers.values.filter { $0.isCorrect }.count
        let totalAnswered = state.sessionAnswers.count
        let durationMinutes = Int(Date().timeIntervalSince(sessionStartDate) / 60)

        Task { [api, gamificationEvents] in
            // POST finish to backend
            _ = try? await api.finishQBankSession(
                id: session.id,
                correctCount: correctCount,
                totalAnswered: totalAnswered
            )
            // Log activity for gamification
            if let result = try? await api.logActivity(
                action: "qbank_session_complete",
                metadata: [
                    "durationMinutes": String(durationMinutes),
                    "correctCount": String(correctCount),
                    "totalAnswered": String(totalAnswered),
                ]
            ) {
                gamificationEvents.handleActivityResponse(result, previousLevel: nil)
            }
        }
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
        // Collect topic IDs for selected disciplines
        let allDisc = QBankUiState.flattenDisciplines(state.filters.disciplines)
        var topicIds = Set<Int>()
        for discId in state.selectedDisciplineIds {
            guard let disc = allDisc.first(where: { $0.id == discId }) else { continue }
            let descIds = collectDescendantIds(disc)
            for topic in state.filters.topics where descIds.contains(topic.disciplineId ?? -1) {
                topicIds.insert(topic.id)
            }
        }
        state.selectedTopicIds = topicIds
        state.activeScreen = .config
        scheduleCountRefresh()
    }

    private func collectDescendantIds(_ discipline: QBankDiscipline) -> Set<Int> {
        var ids: Set<Int> = [discipline.id]
        for child in discipline.children {
            ids.formUnion(collectDescendantIds(child))
        }
        return ids
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
        Task {
            state.sessionLoading = true
            state.error = nil
            do {
                let session = try await api.getQBankSessionDetail(id: summary.id)
                state.session = session
                state.currentQuestionIndex = session.currentIndex
                state.sessionAnswers = [:]
                state.sessionDetails = [:]
                state.selectedAlternativeId = nil
                state.answerResult = nil
                state.showFeedback = false
                state.questionStartDate = Date()
                state.elapsedSeconds = 0
                sessionStartDate = Date()
                state.activeScreen = .session
                await loadCurrentQuestion()
            } catch {
                state.error = "Erro ao retomar sessão: \(error.localizedDescription)"
            }
            state.sessionLoading = false
        }
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
        case "medium": return "Medio"
        case "hard":   return "Difícil"
        default:       return self.capitalized
        }
    }
}
