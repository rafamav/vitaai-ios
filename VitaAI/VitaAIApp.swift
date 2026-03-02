import SwiftUI
import SwiftData

@main
struct VitaAIApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            AppRouter(authManager: container.authManager)
                .environment(\.appContainer, container)
                .environment(\.subscriptionStatus, container.subscriptionStatus)
                // Attach the shared ModelContainer so child views that use
                // @Query or @Environment(\.modelContext) receive the same store.
                .modelContainer(container.modelContainer)
                .preferredColorScheme(.dark)
        }
    }
}
