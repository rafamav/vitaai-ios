import SwiftUI
import SwiftData

@main
struct VitaAIApp: App {
    @StateObject private var container = AppContainer()

    init() {
        // Initialize Sentry for crash reporting and performance monitoring.
        // No-op in DEBUG builds. Requires SENTRY_DSN in Info.plist.
        SentryConfig.initialize()

        #if DEBUG
        // CI screenshot mode: inject demo session before AppContainer boots
        // so AuthManager finds a valid token on first checkLoginStatus().
        // Launch via: xcrun simctl launch <device> com.bymav.vitaai --vita-demo-login
        if CommandLine.arguments.contains("--vita-demo-login") {
            KeychainHelper.shared.save(key: "vita_session_token", value: "demo-ci-token")
            UserDefaults.standard.set("Estudante CI", forKey: "vita_user_name")
            UserDefaults.standard.set("ci@vitaai.app", forKey: "vita_user_email")
            UserDefaults.standard.set(true, forKey: "vita_is_onboarded")
        }
        #endif
    }

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
