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

/// Session mode — Prática: 1 by 1 with immediate feedback (study).
/// Simulado: exam-style, no feedback until final submit, optional timer.
enum QBankMode: String, CaseIterable {
    case pratica
    case simulado
    var displayName: String { self == .pratica ? "Prática" : "Simulado" }
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

    /// Backend catalog of ALL available disciplines (47 slugs). Kept separate
    /// from `filters.disciplines` (which holds the student's enrolled subjects).
    /// Powers the "Outras Disciplinas" collapsible section.
    var catalogDisciplines: [QBankDiscipline] = []
    var otherDisciplinesExpanded: Bool = false
    var disciplineSearch: String = ""

    // Session mode (Prática by default, Simulado for exam-style)
    var mode: QBankMode = .pratica
    /// Optional time limit in seconds (Simulado only). nil = no limit.
    var timeLimitSeconds: Int? = nil
    /// Question IDs the user has flagged to revisit during Simulado.
    var markedForReview: Set<Int> = []

    // Theme picker UI state (inline expansion on config)
    var themeExpanded: Bool = false

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

    /// "Suas Disciplinas" — enrolled subjects, optionally filtered by search.
    var enrolledDisciplinesFiltered: [QBankDiscipline] {
        let list = filters.disciplines
        guard !disciplineSearch.isEmpty else { return list }
        let q = disciplineSearch.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR")).lowercased()
        return list.filter { d in
            d.title.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR")).lowercased().contains(q)
        }
    }

    /// "Outras Disciplinas" — full backend catalog minus the slugs already in
    /// Suas Disciplinas, optionally filtered by search.
    var otherDisciplinesFiltered: [QBankDiscipline] {
        let enrolledSlugs = Set(filters.disciplines.compactMap { $0.slug })
        let base = catalogDisciplines.filter { d in
            guard let slug = d.slug else { return true }
            return !enrolledSlugs.contains(slug)
        }
        guard !disciplineSearch.isEmpty else { return base }
        let q = disciplineSearch.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR")).lowercased()
        return base.filter { d in
            d.title.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR")).lowercased().contains(q)
        }
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

// MARK: - ViewModel

@Observable
@MainActor
final class QBankViewModel {

    var state = QBankUiState()
    private let api: VitaAPI
    private let gamificationEvents: GamificationEventManager
    private let dataManager: AppDataManager

    /// Public accessor so views can sort by VitaScore without exposing AppDataManager.
    func vitaScore(forTitle title: String) -> Double {
        dataManager.vitaScore(for: title)
    }

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
                print("[QBank] loadHomeData failed: \(error)")
                state.progress = .init()
                state.recentSessions = []
                state.error = nil
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
                // Persist the full backend catalog separately — the UI needs it for
                // "Outras Disciplinas" (search/browse beyond the enrolled set).
                // Give each catalog entry a stable synthetic Int id in a distinct
                // range (10_000+) so it never collides with the enrolled block.
                let rawCatalog = filters.disciplines
                state.catalogDisciplines = rawCatalog.enumerated().map { index, d in
                    QBankDiscipline(
                        id: 10_000 + index,
                        title: d.title,
                        slug: d.slug,
                        parentId: nil,
                        level: 0,
                        questionCount: d.questionCount,
                        children: []
                    )
                }
                // ALWAYS overlay the discipline list with the student's actually enrolled
                // subjects (from dashboard). The backend catalog (47 disciplines) is useful
                // only for resolving slug/questionCount per subject — the UI must show what
                // the student is STUDYING first.
                if let dashboard = try? await api.getDashboard(),
                   let subjects = dashboard.subjects, !subjects.isEmpty {
                    state.filters.disciplines = subjects.enumerated().map { index, subject in
                        let subjectName = subject.name ?? ""
                        let matched = matchCatalog(subjectName: subjectName, catalog: rawCatalog)
                        return QBankDiscipline(
                            id: index + 1,
                            title: subjectName,
                            slug: matched?.slug,
                            parentId: nil,
                            level: 0,
                            questionCount: matched?.questionCount ?? 0,
                            children: []
                        )
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
                            slug: nil,
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

    /// Fuzzy-match an enrolled subject name to the backend discipline catalog.
    /// Uses diacritic-insensitive substring matching on both directions — the
    /// catalog names are short ("Patologia") and enrolled subjects often have
    /// qualifiers ("PATOLOGIA MÉDICA"), so either may contain the other.
    private func matchCatalog(subjectName: String, catalog: [QBankDiscipline]) -> QBankDiscipline? {
        let normalize: (String) -> String = {
            $0.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
              .lowercased()
        }
        let target = normalize(subjectName)
        guard !target.isEmpty else { return nil }
        // First pass: direct containment
        if let hit = catalog.first(where: {
            let n = normalize($0.title)
            return !n.isEmpty && (target.contains(n) || n.contains(target))
        }) {
            return hit
        }
        // Second pass: word overlap — take the longest word (> 3 chars) from the
        // subject name and look for it in any catalog title.
        let words = target.split(separator: " ").map(String.init).filter { $0.count > 3 }
        for word in words.sorted(by: { $0.count > $1.count }) {
            if let hit = catalog.first(where: { normalize($0.title).contains(word) }) {
                return hit
            }
        }
        return nil
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

    func setDisciplineSearch(_ query: String) {
        state.disciplineSearch = query
        // If the user is searching, auto-expand "Outras Disciplinas" so matches
        // outside their enrolled set are visible.
        if !query.isEmpty { state.otherDisciplinesExpanded = true }
    }

    func toggleOtherDisciplinesExpanded() {
        state.otherDisciplinesExpanded.toggle()
    }

    // MARK: - Mode (Simulado vs Prática)

    func setMode(_ mode: QBankMode) {
        state.mode = mode
        // Simulado default: 3 minutes per question (ENARE pace).
        if mode == .simulado, state.timeLimitSeconds == nil {
            state.timeLimitSeconds = state.questionCount * 180
        }
    }

    func setTimeLimitSeconds(_ seconds: Int?) {
        state.timeLimitSeconds = seconds
    }

    // MARK: - Theme expansion

    func toggleThemeExpanded() {
        state.themeExpanded.toggle()
    }

    func selectAllTopics() {
        state.selectedTopicIds = Set(state.filters.topics.map(\.id))
        scheduleCountRefresh()
    }

    func deselectAllTopics() {
        state.selectedTopicIds = []
        scheduleCountRefresh()
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
                // Resolve slugs from selected discipline rows (enrolled subjects
                // enriched via matchCatalog). The backend's preferred filter key is
                // `disciplineSlugs` — Int `disciplineIds` is kept nil to avoid mixing.
                let allDisc = QBankUiState.flattenDisciplines(state.filters.disciplines)
                    + state.catalogDisciplines
                let selectedSlugs = state.selectedDisciplineIds.compactMap { id in
                    allDisc.first(where: { $0.id == id })?.slug
                }
                let req = QBankCreateSessionRequest(
                    questionCount: state.questionCount,
                    institutionIds: state.selectedInstitutionIds.isEmpty ? nil : Array(state.selectedInstitutionIds),
                    years: state.selectedYears.isEmpty ? nil : Array(state.selectedYears).sorted(),
                    difficulties: state.selectedDifficulties.isEmpty ? nil : Array(state.selectedDifficulties),
                    topicIds: state.selectedTopicIds.isEmpty ? nil : Array(state.selectedTopicIds),
                    disciplineIds: nil,
                    disciplineSlugs: selectedSlugs.isEmpty ? nil : selectedSlugs,
                    onlyResidence: state.onlyResidence ? true : nil,
                    onlyUnanswered: {
                        if state.selectedStatus == "unanswered" { return true }
                        if state.onlyUnanswered { return true }
                        return nil
                    }(),
                    title: nil,
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
            // Try up to 2 times (initial + 1 retry)
            for attempt in 0..<2 {
                do {
                    result = try await api.answerQBankQuestion(id: question.id, request: request)
                    break
                } catch {
                    if attempt == 0 {
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                }
            }
            if let result {
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
                // Fallback to local calculation
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
        // Collect topic IDs for selected disciplines. The new backend payload
        // keys topics by `disciplineSlug` (String), so match via the resolved slug
        // on each selected discipline. Fall back to Int disciplineId for any
        // legacy payload.
        let allDisc = QBankUiState.flattenDisciplines(state.filters.disciplines)
            + state.catalogDisciplines
        let selectedSlugs = Set(
            state.selectedDisciplineIds.compactMap { id in
                allDisc.first(where: { $0.id == id })?.slug
            }
        )
        var topicIds = Set<Int>()
        for topic in state.filters.topics {
            if let slug = topic.disciplineSlug, selectedSlugs.contains(slug) {
                topicIds.insert(topic.id)
                continue
            }
            if let did = topic.disciplineId,
               state.selectedDisciplineIds.contains(did) {
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
