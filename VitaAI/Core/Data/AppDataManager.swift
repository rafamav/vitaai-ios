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
    var studyEvents: [StudyEventEntry] = []
    var dashboardSubjects: [DashboardSubject] = []
    /// Canonical list of what the student is enrolled in RIGHT NOW — the
    /// single source of truth for every screen that shows discipline chips
    /// (QBank, Flashcards, Simulados, Transcrição, Estudos). Backed by
    /// `GET /api/subjects?status=in_progress` and enriched server-side with
    /// disciplineSlug + canonicalName + area + icon. Screens MUST read from
    /// here instead of fetching `/api/subjects` on their own.
    var enrolledDisciplines: [AcademicSubject] = []

    /// Subjects sorted by VitaScore descending (highest risk first)
    var subjectsByPriority: [DashboardSubject] {
        dashboardSubjects.sorted { ($0.vitaScore ?? 0) > ($1.vitaScore ?? 0) }
    }

    var isLoading = false
    private var lastRefresh: Date = .distantPast

    init(api: VitaAPI) {
        self.api = api
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
    /// cache immediately on success so UI reflects the rename without a
    /// full refresh. Sync never touches this field (backend + iOS both).
    /// Pass nil or empty to reset to portal-canonical name.
    func renameSubject(id: String, displayName: String?) async {
        let trimmed = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = (trimmed?.isEmpty == true) ? nil : trimmed
        guard let updated = try? await api.renameSubject(id: id, displayName: payload) else {
            return
        }
        if let idx = enrolledDisciplines.firstIndex(where: { $0.id == id }) {
            enrolledDisciplines[idx].displayName = updated.displayName
        }
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
        async let e: () = refreshEvents()
        async let d: () = refreshDashboard()
        async let en: () = refreshEnrolled()
        _ = await (p, g, s, e, d, en)
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

    private func refreshEvents() async {
        // Fetch a wide window so the monthly calendar (Faculdade tab) can show
        // provas/trabalhos for the current month and adjacent ones, while the
        // weekly views still get their slice from the same in-memory list.
        let calendar = Calendar.current
        let today = Date()
        let from = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let to = calendar.date(byAdding: .day, value: 60, to: today) ?? today
        let fmt = ISO8601DateFormatter()
        if let resp = try? await api.getStudyEvents(from: fmt.string(from: from), to: fmt.string(from: to)) {
            studyEvents = resp.events
        }
    }
}
