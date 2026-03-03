import Foundation
import SwiftData

// MARK: - AppContainer
// Dependency injection root. Constructs and owns all app-level singletons.
// The SwiftData ModelContainer is created here with the full schema so that
// it is shared across the app (single source of truth for the persistent store).

@MainActor
final class AppContainer: ObservableObject {

    // MARK: - Core services

    let tokenStore: TokenStore
    let httpClient: HTTPClient
    let api: VitaAPI
    let chatClient: VitaChatClient
    let authManager: AuthManager

    // MARK: - Billing / Subscription

    let subscriptionStatus: SubscriptionStatusProvider

    // MARK: - Notes persistence

    /// The shared SwiftData container.  Exposed so VitaAIApp can attach the
    /// .modelContainer() modifier if child views need direct @Query access.
    let modelContainer: ModelContainer

    let notebookStore: NotebookStore
    let mindMapStore: MindMapStore

    // MARK: - Init

    init() {
        // --- Network stack ---
        let tokenStore = TokenStore()
        let httpClient = HTTPClient(tokenStore: tokenStore)
        let api = VitaAPI(client: httpClient)
        let chatClient = VitaChatClient(tokenStore: tokenStore)
        let authManager = AuthManager(tokenStore: tokenStore)

        self.tokenStore = tokenStore
        self.httpClient = httpClient
        self.api = api
        self.chatClient = chatClient
        self.authManager = authManager
        self.subscriptionStatus = SubscriptionStatusProvider(api: api)

        // --- SwiftData ModelContainer ---
        // Schema covers all three persistent entity types.
        // isStoredInMemoryOnly = false → on-disk SQLite (default path managed by SwiftData).
        let schema = Schema([
            NotebookEntity.self,
            PageEntity.self,
            AnnotationEntity.self,
            MindMapEntity.self,
            LocalAssignmentEntity.self,
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            self.modelContainer = container
        } catch {
            // If the store is corrupted we recreate it — data loss is acceptable
            // over a crash loop.  A production app should attempt migration first.
            let fallbackConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true
            )
            // swiftlint:disable:next force_try
            self.modelContainer = try! ModelContainer(for: schema, configurations: [fallbackConfig])
        }

        // --- NotebookStore backed by SwiftData ---
        // mainContext is the @MainActor ModelContext — safe to use here since
        // AppContainer itself is @MainActor.
        let repository = NotebookRepository(
            context: self.modelContainer.mainContext,
            strokeStorage: StrokeFileStorage()
        )
        self.notebookStore = NotebookStore(repository: repository)

        // --- MindMapStore backed by SwiftData ---
        let mindMapRepository = MindMapRepository(context: self.modelContainer.mainContext)
        self.mindMapStore = MindMapStore(repository: mindMapRepository)
    }
}
