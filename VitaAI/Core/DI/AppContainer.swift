import Foundation
import SwiftData

// MARK: - AppContainer
// Dependency injection root. Constructs and owns all app-level singletons.

@MainActor
final class AppContainer: ObservableObject {

    // MARK: - Core services
    let tokenStore: TokenStore
    let httpClient: HTTPClient
    let api: VitaAPI
    let chatClient: VitaChatClient
    let osceSseClient: OsceSseClient
    let transcricaoClient: TranscricaoClient
    let authManager: AuthManager

    // MARK: - Billing / Subscription
    let subscriptionStatus: SubscriptionStatusProvider

    // MARK: - Notes persistence (SwiftData, iOS 17+)
    private var _modelContainer: Any?
    
    @available(iOS 17, *)
    var modelContainer: ModelContainer {
        _modelContainer as? ModelContainer ?? {
            fatalError("[AppContainer] ModelContainer not initialized — called on iOS < 17?")
        }()
    }

    private var _notebookStore: Any?
    private var _mindMapStore: Any?
    private var _noteSyncManager: Any?
    private var _mindMapSyncManager: Any?
    let gamificationEvents: GamificationEventManager
    let appConfigService: AppConfigService


    @available(iOS 17, *)
    var notebookStore: NotebookStore {
        guard let store = _notebookStore as? NotebookStore else {
            fatalError("[AppContainer] NotebookStore not initialized — called on iOS < 17?")
        }
        return store
    }
    @available(iOS 17, *)
    var mindMapStore: MindMapStore {
        guard let store = _mindMapStore as? MindMapStore else {
            fatalError("[AppContainer] MindMapStore not initialized — called on iOS < 17?")
        }
        return store
    }
    @available(iOS 17, *)
    var noteSyncManager: NoteSyncManager {
        guard let mgr = _noteSyncManager as? NoteSyncManager else {
            fatalError("[AppContainer] NoteSyncManager not initialized — called on iOS < 17?")
        }
        return mgr
    }
    @available(iOS 17, *)
    var mindMapSyncManager: MindMapSyncManager {
        guard let mgr = _mindMapSyncManager as? MindMapSyncManager else {
            fatalError("[AppContainer] MindMapSyncManager not initialized — called on iOS < 17?")
        }
        return mgr
    }

    // MARK: - Init
    init() {
        // --- Network stack ---
        let tokenStore = TokenStore()
        let httpClient = HTTPClient(tokenStore: tokenStore)
        let api = VitaAPI(client: httpClient)
        // SSE clients share the same TokenRefresher for serialized refresh.
        // They keep their own URLSession with longer resource timeouts (300s)
        // — HTTPClient's session has 60s which would kill long-lived SSE streams.
        let sharedRefresher = httpClient.tokenRefresher
        let chatClient = VitaChatClient(tokenStore: tokenStore, tokenRefresher: sharedRefresher)
        let osceSseClient = OsceSseClient(tokenStore: tokenStore, tokenRefresher: sharedRefresher)
        let transcricaoClient = TranscricaoClient(tokenStore: tokenStore, tokenRefresher: sharedRefresher)
        let authManager = AuthManager(tokenStore: tokenStore)

        self.tokenStore = tokenStore
        self.httpClient = httpClient
        self.api = api
        self.chatClient = chatClient
        self.osceSseClient = osceSseClient
        self.transcricaoClient = transcricaoClient
        self.authManager = authManager
        self.subscriptionStatus = SubscriptionStatusProvider(api: api)

        // Wire 401 interceptor → auto-logout on HTTPClient + all SSE clients
        let authMgr = authManager
        let logoutHandler: @Sendable @MainActor () -> Void = {
            authMgr.logout()
        }
        Task {
            await httpClient.setOnUnauthorized(logoutHandler)
            await chatClient.setOnUnauthorized(logoutHandler)
            await osceSseClient.setOnUnauthorized(logoutHandler)
            await transcricaoClient.setOnUnauthorized(logoutHandler)
        }

        // Wire PushManager with API for token registration
        PushManager.shared.api = api

        // --- SwiftData (iOS 17+) ---
        if #available(iOS 17, *) {
            let schema = Schema([
                NotebookEntity.self,
                PageEntity.self,
                AnnotationEntity.self,
                MindMapEntity.self,
                LocalAssignmentEntity.self,
            ])
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            let container: ModelContainer
            do {
                container = try ModelContainer(for: schema, configurations: [config])
            } catch {
                let fallbackConfig = ModelConfiguration(
                    schema: schema, isStoredInMemoryOnly: true, allowsSave: true
                )
                do {
                    container = try ModelContainer(for: schema, configurations: [fallbackConfig])
                } catch {
                    fatalError("[AppContainer] ModelContainer init failed even in-memory: \(error)")
                }
            }
            self._modelContainer = container

            let repository = NotebookRepository(
                context: container.mainContext,
                strokeStorage: StrokeFileStorage()
            )
            self._notebookStore = NotebookStore(repository: repository)

            let mindMapRepository = MindMapRepository(context: container.mainContext)
            self._mindMapStore = MindMapStore(repository: mindMapRepository)

            self._noteSyncManager = NoteSyncManager(api: api, repository: repository)
            self._mindMapSyncManager = MindMapSyncManager(api: api, repository: mindMapRepository)

            (self._notebookStore as? NotebookStore)?.syncManager = (self._noteSyncManager as? NoteSyncManager)
            (self._mindMapStore as? MindMapStore)?.syncManager = (self._mindMapSyncManager as? MindMapSyncManager)
        } else {
            self._modelContainer = nil
            self._notebookStore = nil
            self._mindMapStore = nil
            self._noteSyncManager = nil
            self._mindMapSyncManager = nil
        }

        self.gamificationEvents = GamificationEventManager()
        self.appConfigService = AppConfigService.shared

        Task { @MainActor in
            await AppConfigService.shared.loadIfNeeded(api: api)
        }

        if #available(iOS 17, *) {
            Task { @MainActor in
                await (self._noteSyncManager as? NoteSyncManager)?.pull()
                await (self._mindMapSyncManager as? MindMapSyncManager)?.pull()
            }
        }
    }
}
