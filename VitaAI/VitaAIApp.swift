import SwiftUI
import SwiftData
import UserNotifications

// MARK: - AppDelegate (Push Notifications)

class VitaAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushManager.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushManager.shared.didFailToRegisterForRemoteNotifications(error: error)
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show push banners while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            PushManager.shared.willPresent(notification, completionHandler: completionHandler)
        }
    }
}

@main
struct VitaAIApp: App {
    @UIApplicationDelegateAdaptor(VitaAppDelegate.self) var appDelegate
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
