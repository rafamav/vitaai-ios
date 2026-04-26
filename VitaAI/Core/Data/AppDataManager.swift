import Foundation
import Observation

/// Centralized shared data store for portal-sourced data (grades, schedule, events).
/// Injected via environment. All tabs read from here. One place to refresh.
@MainActor
@Observable
final class AppDataManager {
    private let api: VitaAPI

    // MARK: - Shared state

    var profile: ProfileResponse?
    var gradesResponse: GradesCurrentResponse?
    var classSchedule: [AgendaClassBlock] = []
    var academicEvaluations: [AgendaEvaluation] = []
    var dashboardSubjects: [DashboardSubject] = []
    /// Canonical list of what the student is enrolled in RIGHT NOW — the
    /// single source of truth for every screen that shows discipline chips
    /// (QBank, Flashcards, Simulados, Transcrição, Estudos). Backed by
    /// `GET /api/subjects?status=in_progress` and enriched server-side with
    /// disciplineSlug + canonicalName + area + icon. Screens MUST read from
    /// here instead of fetching `/api/subjects` on their own.
    var enrolledDisciplines: [AcademicSubject] = []

    /// Prefetched secondary data — loaded in background on launch so tapping
    /// Flashcards/QBank/Simulados/Transcrição/Trabalhos in Estudos opens
    /// instantly with cache (SWR pattern). Each screen refetches silently on
    /// appear to pick up changes. Rafael (2026-04-24): "como apps grandes
    /// fazem isso, carregar enquanto o user ta em outra pagina".
    var flashcardDecks: [FlashcardDeckEntry] = []
    var qbankProgress: QBankProgressResponse?
    var simuladosList: SimuladoListResponse?
    var transcricoesList: [TranscricaoEntry] = []
    var trabalhosResponse: TrabalhosResponse?

    /// Per-discipline prefetched data — populated on boot via
    /// `prewarmDisciplines(ids:)`. Disciplina aberta consome desses caches em
    /// vez de bater na API. Rafael (2026-04-26): "paginas individuais ainda
    /// demoram pra abrir, nao colocamos tudo no SSE wrapper goldstandard".
    var progress: ProgressResponse?
    var documentsBySubject: [String: [VitaDocument]] = [:]
    var foldersBySubject: [String: [MaterialFolder]] = [:]

    /// Subjects sorted by VitaScore descending (highest risk first)
    var subjectsByPriority: [DashboardSubject] {
        dashboardSubjects.sorted { ($0.vitaScore ?? 0) > ($1.vitaScore ?? 0) }
    }

    var isLoading = false
    private var lastRefresh: Date = .distantPast
    private var pollingTask: Task<Void, Never>?

    init(api: VitaAPI) {
        self.api = api
    }

    // MARK: - Continuous foreground polling (gold-standard freshness)
    //
    // Apps modernos não esperam o user ir pra dashboard pra refetch — refrescam
    // dados continuamente em background enquanto o app está aberto, então cada
    // tela que o user abre já encontra cache fresco. silentRefresh() respeita
    // throttle de 60s, então rodar a cada 30s só gasta network metade do tempo
    // (alterna sleep-then-fetch). scenePhase=.active liga, scenePhase=.background
    // desliga (em VitaAIApp.swift).

    func startForegroundPolling(interval: TimeInterval = 30) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if Task.isCancelled { break }
                await self?.silentRefresh()
            }
        }
    }

    func stopForegroundPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Realtime SSE event handler (gold-standard 2026 — etapa 5)
    //
    // Recebe Event do RealtimeStream (Core/Realtime/RealtimeStream.swift) e
    // dispara refetch do dominio afetado. Patch in-place via payload eh
    // optimization futura — por agora "refetch domain afetado" entrega
    // freshness em ms (o domain refresh leva 100-200ms warm).
    //
    // Stream conecta em scenePhase=.active (etapa 6 wire-up no VitaAIApp).

    func applyEvent(_ event: RealtimeStream.Event) {
        NSLog("[AppData] event domain=%@ op=%@ recordId=%@",
              event.domain, event.op, event.recordId ?? "?")

        Task { @MainActor [weak self] in
            guard let self else { return }
            switch event.domain {
            case "subjects":
                await self.refreshEnrolled()
                await self.refreshDashboard()  // hero cards depend on subjects
            case "evaluations", "schedule":
                await self.refreshSchedule()
                await self.refreshDashboard()
            case "grades":
                await self.refreshGrades()
                await self.refreshDashboard()
            case "flashcards":
                await self.refreshFlashcards()
                await self.refreshDashboard()
            case "qbank":
                await self.refreshQBankProgress()
            case "simulados":
                await self.refreshSimulados()
            case "transcricoes":
                await self.refreshTranscricoes()
            case "dashboard":
                await self.refreshDashboard()
            case "profile":
                await self.refreshProfile()
            case "calendar":
                await self.refreshSchedule()
            case "achievements", "notifications", "portal_status", "vita_chat", "mindmaps", "voice", "documents":
                // Sem refresh dedicado em AppDataManager hoje — telas owners
                // (NotificationsScreen, AchievementsScreen, etc) refetcham on-appear.
                // No-op aqui: log ja foi emitido acima, telas pegam quando abrir.
                break
            default:
                // Unknown domain — refetch tudo defensivamente
                await self.silentRefresh()
            }
        }
    }

    // MARK: - Full load (shows spinner)

    func loadIfNeeded() async {
        guard gradesResponse == nil && classSchedule.isEmpty && enrolledDisciplines.isEmpty else { return }
        isLoading = true
        await refreshAll()
        isLoading = false
    }

    // MARK: - Silent refresh (no spinner, 60s throttle)

    func silentRefresh() async {
        guard Date().timeIntervalSince(lastRefresh) > 60 else { return }
        await refreshAll()
    }

    // MARK: - Force refresh (pull-to-refresh, ignores throttle)

    func forceRefresh() async {
        await refreshAll()
    }

    /// Set or clear a subject's user-ownable display name. Updates local
    /// cache + refreshes grades so UI reflects the rename immediately.
    /// Sync never touches this field (backend + iOS both). Pass nil or
    /// empty to reset to portal-canonical name.
    func renameSubject(id: String, displayName: String?) async {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = (trimmed?.isEmpty == true) ? nil : trimmed
        guard let updated = try? await api.renameSubject(id: id, displayName: payload) else {
            NSLog("[rename] PATCH failed for subject \(id)")
            return
        }
        // In-place cache patch (cheap, triggers @Observable for any View reading
        // enrolledDisciplines).
        if let idx = enrolledDisciplines.firstIndex(where: { $0.id == id }) {
            enrolledDisciplines[idx].displayName = updated.displayName
        }
        // FaculdadeDisciplinasScreen reads gradesResponse (GradeSubject list),
        // not AcademicSubject directly — force a refresh so any view layer
        // picks up the change immediately regardless of which collection it
        // binds to.
        await refreshEnrolled()
    }

    // MARK: - Private

    /// VitaScore lookup by subject name (case/diacritics insensitive)
    func vitaScore(for subjectName: String) -> Double {
        let key = subjectName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return dashboardSubjects.first(where: {
            ($0.name ?? "").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == key
        })?.vitaScore ?? 0
    }

    private func refreshAll() async {
        lastRefresh = Date()
        async let p: () = refreshProfile()
        async let g: () = refreshGrades()
        async let s: () = refreshSchedule()
        async let d: () = refreshDashboard()
        async let en: () = refreshEnrolled()
        // Secondary prefetch — Estudos tabs abrem instant
        async let fc: () = refreshFlashcards()
        async let qb: () = refreshQBankProgress()
        async let si: () = refreshSimulados()
        async let tr: () = refreshTranscricoes()
        async let tb: () = refreshTrabalhos()
        async let pr: () = refreshProgress()
        _ = await (p, g, s, d, en, fc, qb, si, tr, tb, pr)
        // Tertiary prefetch — disciplinas individuais. Depende de enrolled
        // já estar populado, daí roda DEPOIS do gather acima.
        await prewarmDisciplines(ids: enrolledDisciplines.map { $0.id })
    }

    private func refreshProgress() async {
        if let resp = try? await api.getProgress() {
            progress = resp
        }
    }

    /// Prewarmiza docs + folders pra cada disciplina passada (paralelo).
    /// Chamado uma vez no boot com ids do semestre atual; DisciplineDetail
    /// abre instant lendo `documentsBySubject[id]` + `foldersBySubject[id]`.
    /// Boot cost: ~8 disciplinas × 2 endpoints = 16 requests paralelos.
    func prewarmDisciplines(ids: [String]) async {
        guard !ids.isEmpty else { return }
        await withTaskGroup(of: (String, [VitaDocument]?, [MaterialFolder]?).self) { group in
            for id in ids {
                group.addTask { [api] in
                    async let docs: [VitaDocument]? = try? await api.getDocuments(subjectId: id)
                    async let folders: [MaterialFolder]? = try? await api.listSubjectFolders(subjectId: id)
                    return (id, await docs, await folders)
                }
            }
            for await (id, docs, folders) in group {
                if let docs { documentsBySubject[id] = docs }
                if let folders { foldersBySubject[id] = folders }
            }
        }
    }

    private func refreshFlashcards() async {
        if let resp = try? await api.getFlashcardDecks(deckLimit: 1000, summary: true) {
            flashcardDecks = resp
        }
    }

    private func refreshQBankProgress() async {
        if let resp = try? await api.getQBankProgress() {
            qbankProgress = resp
        }
    }

    private func refreshSimulados() async {
        if let resp = try? await api.listSimulados() {
            simuladosList = resp
        }
    }

    private func refreshTranscricoes() async {
        if let resp = try? await api.getTranscricoes() {
            transcricoesList = resp
        }
    }

    private func refreshTrabalhos() async {
        if let resp = try? await api.getTrabalhos() {
            trabalhosResponse = resp
        }
    }

    private func refreshEnrolled() async {
        if let resp = try? await api.getSubjects(status: "in_progress") {
            enrolledDisciplines = resp.subjects
        }
    }

    private func refreshProfile() async {
        if let resp = try? await api.getProfile() {
            profile = resp
        }
    }

    private func refreshGrades() async {
        if let resp = try? await api.getGradesCurrent() {
            gradesResponse = resp
        }
    }

    private func refreshSchedule() async {
        // Wide window: -180d includes overdue trabalhos from the whole semester
        // (student needs to see late work, can submit past due). +90d covers
        // the monthly calendar plus next term's early evaluations.
        let cal = Calendar.current
        let today = Date()
        let from = cal.date(byAdding: .day, value: -180, to: today) ?? today
        let to = cal.date(byAdding: .day, value: 90, to: today) ?? today
        let fmt = ISO8601DateFormatter()
        if let resp = try? await api.getAgenda(from: fmt.string(from: from), to: fmt.string(from: to)) {
            classSchedule = resp.schedule
            academicEvaluations = resp.evaluations
        }
    }

    private func refreshDashboard() async {
        if let resp = try? await api.getDashboard() {
            dashboardSubjects = resp.subjects ?? []
        }
    }

}
