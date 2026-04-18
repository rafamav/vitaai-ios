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

    /// Silent (content-available) push handler — app is woken in the background
    /// with a ~30s window to run work.
    ///
    /// Portal-agnostic contract (backend: /api/cron/portal-silent-sync):
    ///   type: "portal_sync"
    ///   strategy: "webview-bridge" | "oauth-replay"
    ///   connectionId, portalType, instanceUrl
    ///
    /// Legacy type-specific pushes are still accepted for rollout compat:
    ///   - `canvas_reauth` (→ oauth-replay)
    ///   - `mannesoft_sync` (→ webview-bridge)
    /// Will be removed once backend fully emits `portal_sync` only.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let type = userInfo["type"] as? String ?? ""
        NSLog("[PushBG] Silent push received: type=%@", type)

        switch type {
        case "portal_sync":
            let strategy = userInfo["strategy"] as? String ?? "webview-bridge"
            let instanceUrl = userInfo["instanceUrl"] as? String ?? ""
            let portalType = userInfo["portalType"] as? String ?? "?"
            NSLog("[PushBG] portal_sync portalType=%@ strategy=%@", portalType, strategy)
            Task { @MainActor in
                let api = VitaAPI(client: HTTPClient(tokenStore: TokenStore()))
                switch strategy {
                case "oauth-replay":
                    guard !instanceUrl.isEmpty else {
                        completionHandler(.noData)
                        return
                    }
                    let ok = await CanvasSilentReauth.shared.forceReauth(
                        instanceUrl: instanceUrl,
                        api: api
                    )
                    NSLog("[PushBG] oauth-replay result: %@", ok ? "success" : "failed")
                    completionHandler(ok ? .newData : .failed)
                default: // "webview-bridge"
                    SilentPortalSync.shared.resetThrottle()
                    SilentPortalSync.shared.syncIfNeeded(api: api)
                    try? await Task.sleep(for: .seconds(25))
                    NSLog("[PushBG] webview-bridge window ending")
                    completionHandler(.newData)
                }
            }

        // Legacy type-specific silent pushes (pre-issue #59). Kept during rollout.
        case "canvas_reauth":
            guard let instanceUrl = userInfo["instanceUrl"] as? String, !instanceUrl.isEmpty else {
                completionHandler(.noData)
                return
            }
            Task { @MainActor in
                let api = VitaAPI(client: HTTPClient(tokenStore: TokenStore()))
                let success = await CanvasSilentReauth.shared.forceReauth(
                    instanceUrl: instanceUrl,
                    api: api
                )
                NSLog("[PushBG] Canvas reauth result: %@", success ? "success" : "failed")
                completionHandler(success ? .newData : .failed)
            }

        case "mannesoft_sync":
            NSLog("[PushBG] Mannesoft silent sync triggered by server")
            Task { @MainActor in
                let api = VitaAPI(client: HTTPClient(tokenStore: TokenStore()))
                SilentPortalSync.shared.resetThrottle()
                SilentPortalSync.shared.syncIfNeeded(api: api)
                // Give sync up to 25s (iOS allows ~30s for silent push)
                try? await Task.sleep(for: .seconds(25))
                NSLog("[PushBG] Mannesoft sync window ending")
                completionHandler(.newData)
            }

        default:
            completionHandler(.noData)
        }
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

    // Handle notification tap — navigate via deep link
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Backend sends "deepLink": "vitaai://trabalho/{id}" in push payload
        if let deepLinkStr = userInfo["deepLink"] as? String,
           let url = URL(string: deepLinkStr) {
            Task { @MainActor in
                // Post via onOpenURL handler already wired in AppRouter
                UIApplication.shared.open(url)
            }
        }
        completionHandler()
    }
}

@main
struct VitaAIApp: App {
    @UIApplicationDelegateAdaptor(VitaAppDelegate.self) var appDelegate
    @StateObject private var container = AppContainer()

    init() {
        // Make scroll views transparent so VitaAmbientBackground shows through content gaps
        UIScrollView.appearance().backgroundColor = .clear

        // Initialize Sentry for crash reporting and performance monitoring.
        // No-op in DEBUG builds. Requires SENTRY_DSN in Info.plist.
        SentryConfig.initialize()

        #if DEBUG
        bootstrapLaunchState()
        #endif
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            AppRouter(authManager: container.authManager)
                .environment(\.appContainer, container)
                .environment(\.appData, container.dataManager)
                .environment(\.subscriptionStatus, container.subscriptionStatus)
                // SwiftData (iOS 17+) - notes/mindmaps local persistence
                .modifier(ModelContainerModifier(container: container))
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                SilentPortalSync.shared.syncIfNeeded(api: container.api)
            }
        }
    }
}

private extension VitaAIApp {
    func bootstrapLaunchState() {
        let defaults = UserDefaults.standard
        let keychain = KeychainHelper.shared

        if AppConfig.shouldResetOnboarding {
            AppConfig.setOnboardingComplete(false, in: defaults)
        }

        if let injected = AppConfig.injectedSession {
            keychain.save(key: "vita_session_token", value: injected.token)
            if let name = injected.name { defaults.set(name, forKey: "vita_user_name") }
            if let email = injected.email { defaults.set(email, forKey: "vita_user_email") }
            if let image = injected.image { defaults.set(image, forKey: "vita_user_image") }
        }
    }
}

// MARK: - SwiftData Compatibility (iOS 17+)
struct ModelContainerModifier: ViewModifier {
    let container: AppContainer

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.modelContainer(container.modelContainer)
        } else {
            content // SwiftData not available on iOS 16
        }
    }
}
