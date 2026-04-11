import Foundation
import Observation

/// Centralized shared data store for portal-sourced data (grades, schedule, events).
/// Injected via environment. All tabs read from here. One place to refresh.
@MainActor
@Observable
final class AppDataManager {
    private let api: VitaAPI

    // MARK: - Shared state

    var gradesResponse: GradesCurrentResponse?
    var classSchedule: [AgendaClassBlock] = []
    var academicEvaluations: [AgendaEvaluation] = []
    var studyEvents: [StudyEventEntry] = []
    var dashboardSubjects: [DashboardSubject] = []

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
        guard gradesResponse == nil && classSchedule.isEmpty else { return }
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

    // MARK: - Private

    private func refreshAll() async {
        lastRefresh = Date()
        async let g: () = refreshGrades()
        async let s: () = refreshSchedule()
        async let e: () = refreshEvents()
        _ = await (g, s, e)
    }

    private func refreshGrades() async {
        if let resp = try? await api.getGradesCurrent() {
            gradesResponse = resp
        }
    }

    private func refreshSchedule() async {
        // Wide window so the monthly calendar can show evaluations across the
        // current month and adjacent months without re-fetching on every nav.
        let cal = Calendar.current
        let today = Date()
        let from = cal.date(byAdding: .day, value: -45, to: today) ?? today
        let to = cal.date(byAdding: .day, value: 90, to: today) ?? today
        let fmt = ISO8601DateFormatter()
        if let resp = try? await api.getAgenda(from: fmt.string(from: from), to: fmt.string(from: to)) {
            classSchedule = resp.schedule
            academicEvaluations = resp.evaluations
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
