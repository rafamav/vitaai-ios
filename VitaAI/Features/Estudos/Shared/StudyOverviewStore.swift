import Foundation
import Observation

/// Session-scoped cache for `GET /api/study/overview`.
///
/// The four StudySuite screens (Flashcards, QBank, Simulados, Transcrição)
/// all need the same hero counters and subject chips. Fetching on each
/// `onAppear` would triple-hit the backend when the user bounces between
/// tabs. This store loads once, exposes a `refresh()` for pull-to-refresh,
/// and publishes the snapshot via `@Observable` so views update in place.
///
/// Owned by `AppContainer` so every screen reads from the same instance.
@Observable
@MainActor
final class StudyOverviewStore {
    private(set) var snapshot: StudyOverviewResponse?
    private(set) var isLoading = false
    private(set) var lastError: String?

    private let api: VitaAPI
    private var lastLoadedAt: Date?

    init(api: VitaAPI) {
        self.api = api
    }

    /// Load once per session unless the cached snapshot is older than the TTL.
    /// Call from screen `.task`.
    func loadIfNeeded(maxAgeSeconds: TimeInterval = 90) async {
        if let last = lastLoadedAt,
           Date().timeIntervalSince(last) < maxAgeSeconds,
           snapshot != nil {
            return
        }
        await refresh()
    }

    /// Force a reload (pull-to-refresh, post-action).
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await api.getStudyOverview()
            lastError = nil
            lastLoadedAt = Date()
        } catch {
            lastError = String(describing: error)
            print("[StudyOverviewStore] load error: \(error)")
        }
    }
}
