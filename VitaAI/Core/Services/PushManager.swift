import Foundation
import UserNotifications
import UIKit

// MARK: - PushManager
//
// Handles APNs registration and device token management.
// Mirrors Android VitaMessagingService + TokenStore FCM flow.
//
// Usage:
//   1. Call PushManager.shared.requestPermission() on app launch / first login.
//   2. Forward UIApplicationDelegate callbacks via the static forwardDidRegister / forwardDidFailToRegister.
//   3. PushManager automatically persists and uploads the token via VitaAPI.

@MainActor
final class PushManager: NSObject, ObservableObject {

    static let shared = PushManager()
    var api: VitaAPI?
    private override init() { super.init() }

    // MARK: - Published State

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published private(set) var deviceToken: String? = nil
    @Published var unreadNotificationCount: Int = 0
    /// Cached notifications from last fetch — used by popout for instant display
    @Published private(set) var cachedNotifications: [VitaNotification] = []

    // MARK: - UserDefaults key (non-sensitive — mirrors Android saveFcmToken)
    private let tokenDefaultsKey = "vita_apns_device_token"

    // MARK: - Request Permission

    /// Requests notification authorization from the system and registers for remote notifications.
    /// Safe to call multiple times — will only prompt if `.notDetermined`.
    func requestPermission() async {
        // Simulator can't receive APNs pushes anyway; skip the prompt so every
        // fresh boot doesn't interrupt the user with a dialog we can't honor.
        #if targetEnvironment(simulator)
        authorizationStatus = .authorized
        return
        #else
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus

        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
                authorizationStatus = granted ? .authorized : .denied
                if granted {
                    await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
                }
            } catch {
                // Permission request failed — non-fatal
                print("[PushManager] requestAuthorization error: \(error)")
            }

        case .authorized, .provisional, .ephemeral:
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }

        case .denied:
            break // Nothing to do; user may open Settings manually.

        @unknown default:
            break
        }
        #endif
    }

    // MARK: - Token Handling

    /// Call from `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`.
    func didRegisterForRemoteNotifications(deviceToken data: Data) {
        let token = data.map { String(format: "%02.2hhx", $0) }.joined()
        deviceToken = token
        UserDefaults.standard.set(token, forKey: tokenDefaultsKey)

        Task { await uploadToken(token) }
    }

    /// Call from `application(_:didFailToRegisterForRemoteNotificationsWithError:)`.
    func didFailToRegisterForRemoteNotifications(error: Error) {
        print("[PushManager] Failed to register for remote notifications: \(error)")
    }

    // MARK: - Notification Received (foreground)

    /// Call from `userNotificationCenter(_:willPresent:withCompletionHandler:)`.
    func willPresent(
        _ notification: UNNotification,
        completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
        Task { await refreshUnreadCount() }
    }

    /// Fetch notifications from backend, cache them, and update unread count.
    func refreshUnreadCount() async {
        guard let api else { return }
        do {
            let items = try await api.getNotifications()
            let count = items.filter { !$0.read }.count
            await MainActor.run {
                cachedNotifications = items
                unreadNotificationCount = count
            }
        } catch {
            // Non-fatal
        }
    }

    /// Update cached notifications locally (e.g. after mark-read)
    func updateCachedNotifications(_ items: [VitaNotification]) {
        cachedNotifications = items
        unreadNotificationCount = items.filter { !$0.read }.count
    }

    // MARK: - Stored Token

    var storedToken: String? {
        UserDefaults.standard.string(forKey: tokenDefaultsKey) ?? deviceToken
    }

    // MARK: - Upload

    private func uploadToken(_ token: String) async {
        // Attempt to register token with backend; failure is non-fatal.
        do {
            try await api?.registerPushToken(token: token)
            print("[PushManager] APNs token registered with backend: \(token.prefix(10))...")
        } catch {
            print("[PushManager] Failed to register APNs token with backend: \(error)")
        }
    }

    // MARK: - Authorization Refresh

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Open System Settings

    func openSystemNotificationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
