import Foundation

// MARK: - AppConfigService
// Fetches and caches GET /api/config/app.
// Cache strategy: UserDefaults with 1-hour TTL.
// Fallback: GamificationConfig.fallback (hardcoded constants matching server).
//
// Usage (async, from @MainActor context):
//   await AppConfigService.shared.loadIfNeeded(api: container.api)
//
// Usage (sync, from any context — e.g. XpSource.xp):
//   let xp = AppConfigService.xpRewards["daily_login"] ?? 20
//   let xp = AppConfigService.xp(for: .dailyLogin)

@MainActor
@Observable
final class AppConfigService {

    // MARK: - Singleton
    static let shared = AppConfigService()

    // MARK: - Thread-safe XP snapshot
    // Updated whenever config is loaded. Used by XpSource.xp (non-isolated context).
    // nonisolated(unsafe) is safe here: reads are idempotent, worst case is a stale value.
    nonisolated(unsafe) static var xpRewards: [String: Int] = GamificationConfig.fallback.xpRewards
    nonisolated(unsafe) static var currentDailyGoal: Int = GamificationConfig.fallback.dailyGoal

    // MARK: - State
    private(set) var config: AppConfigResponse = AppConfigResponse(
        gamification: .fallback
    )
    private(set) var isLoaded = false
    private(set) var lastError: Error?

    // MARK: - Cache keys
    private enum CacheKey {
        static let data = "AppConfigService.cachedData"
        static let timestamp = "AppConfigService.cachedAt"
    }
    private let ttl: TimeInterval = 3600 // 1 hour

    // MARK: - Init
    private init() {
        loadFromCache()
    }

    // MARK: - Public API

    /// Loads config from server if cache is stale or empty.
    /// Safe to call multiple times — no-op if fresh.
    func loadIfNeeded(api: VitaAPI) async {
        if isLoaded && !isCacheStale() { return }
        await fetch(api: api)
    }

    /// Force-refreshes from server regardless of cache age.
    func refresh(api: VitaAPI) async {
        await fetch(api: api)
    }

    /// XP reward for a given action key (actor-isolated).
    func xp(for action: XpRewardKey) -> Int {
        config.gamification.xpRewards[action.rawValue] ?? action.fallbackXp
    }

    /// XP reward for a given action key — callable from any context.
    nonisolated static func xp(for action: XpRewardKey) -> Int {
        xpRewards[action.rawValue] ?? action.fallbackXp
    }

    // MARK: - Private

    private func fetch(api: VitaAPI) async {
        do {
            let fetched: AppConfigResponse = try await api.fetchAppConfig()
            config = fetched
            isLoaded = true
            lastError = nil
            saveToCache(fetched)
            // Update thread-safe snapshot
            AppConfigService.xpRewards = fetched.gamification.xpRewards
            AppConfigService.currentDailyGoal = fetched.gamification.dailyGoal
        } catch {
            // Keep existing config (cache or fallback) on network error
            lastError = error
            if !isLoaded {
                isLoaded = true // mark loaded so UI doesn't spin forever
            }
        }
    }

    // MARK: - Cache

    private func loadFromCache() {
        guard
            let data = UserDefaults.standard.data(forKey: CacheKey.data),
            let decoded = try? JSONDecoder().decode(AppConfigResponse.self, from: data)
        else { return }

        config = decoded
        isLoaded = true
        // Sync thread-safe snapshot from cache
        AppConfigService.xpRewards = decoded.gamification.xpRewards
        AppConfigService.currentDailyGoal = decoded.gamification.dailyGoal
    }

    private func saveToCache(_ config: AppConfigResponse) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        UserDefaults.standard.set(data, forKey: CacheKey.data)
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: CacheKey.timestamp)
    }

    private func isCacheStale() -> Bool {
        let savedAt = UserDefaults.standard.double(forKey: CacheKey.timestamp)
        guard savedAt > 0 else { return true }
        return Date().timeIntervalSince1970 - savedAt > ttl
    }
}

// MARK: - XpRewardKey
// Typed keys matching the server's xpRewards map.
// Provides fallback values so callers are never left with 0 XP.

enum XpRewardKey: String {
    case questionAnswered       = "question_answered"
    case questionAnsweredWrong  = "question_answered_wrong"
    case flashcardReview        = "flashcard_review"
    case flashcardEasy          = "flashcard_easy"
    case simuladoComplete       = "simulado_complete"
    case qbankSessionComplete   = "qbank_session_complete"
    case deckComplete           = "deck_complete"
    case osceCompleted          = "osce_completed"
    case noteCreated            = "note_created"
    case noteEdited             = "note_edited"
    case pdfAnnotated           = "pdf_annotated"
    case documentOpened         = "document_opened"
    case studioGenerated        = "studio_generated"
    case studySessionEnd        = "study_session_end"
    case simuladoStart          = "simulado_start"
    case chatMessage            = "chat_message"
    case dailyLogin             = "daily_login"

    /// Fallback XP to use when server config is unavailable.
    /// Matches GamificationConfig.fallback values.
    var fallbackXp: Int {
        switch self {
        case .questionAnswered:      return 8
        case .questionAnsweredWrong: return 3
        case .flashcardReview:       return 8
        case .flashcardEasy:         return 12
        case .simuladoComplete:      return 80
        case .qbankSessionComplete:  return 30
        case .deckComplete:          return 40
        case .osceCompleted:         return 50
        case .noteCreated:           return 15
        case .noteEdited:            return 3
        case .pdfAnnotated:          return 10
        case .documentOpened:        return 2
        case .studioGenerated:       return 10
        case .studySessionEnd:       return 8
        case .simuladoStart:         return 3
        case .chatMessage:           return 4
        case .dailyLogin:            return 20
        }
    }
}
