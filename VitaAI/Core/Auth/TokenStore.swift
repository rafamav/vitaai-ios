import Foundation
import Security

actor TokenStore {
    private let keychain = KeychainHelper.shared
    private let defaults = UserDefaults.standard

    // MARK: - Keys
    private enum Keys {
        static let sessionToken = "vita_session_token"
        static let userName = "vita_user_name"
        static let userEmail = "vita_user_email"
        static let userImage = "vita_user_image"
        static let isOnboarded = "vita_is_onboarded"
        static let onboardingNickname = "vita_onboarding_nickname"
        static let onboardingUniversity = "vita_onboarding_university"
        static let onboardingState = "vita_onboarding_state"
        static let onboardingSemester = "vita_onboarding_semester"
        static let onboardingSubjects = "vita_onboarding_subjects"
        static let onboardingGoals = "vita_onboarding_goals"
        static let onboardingDailyMinutes = "vita_onboarding_daily_minutes"
        static let fcmToken = "vita_fcm_token"
    }

    // MARK: - Token

    var token: String? {
        #if DEBUG
        // CI mode: xcrun simctl launch --env VITA_CI_TOKEN=xxx injects env var into the process
        if let ciToken = ProcessInfo.processInfo.environment["VITA_CI_TOKEN"] { return ciToken }
        #endif
        return keychain.read(key: Keys.sessionToken)
    }

    var isLoggedIn: Bool {
        token != nil
    }

    var isOnboarded: Bool {
        #if DEBUG
        if ProcessInfo.processInfo.environment["VITA_CI_TOKEN"] != nil { return true }
        #endif
        return defaults.bool(forKey: Keys.isOnboarded)
    }

    // MARK: - User Info

    var userName: String? {
        defaults.string(forKey: Keys.userName)
    }

    var userEmail: String? {
        defaults.string(forKey: Keys.userEmail)
    }

    var userImage: String? {
        defaults.string(forKey: Keys.userImage)
    }

    // MARK: - Session Management

    func saveSession(token: String, name: String?, email: String?, image: String?) {
        keychain.save(key: Keys.sessionToken, value: token)
        if let name { defaults.set(name, forKey: Keys.userName) }
        if let email { defaults.set(email, forKey: Keys.userEmail) }
        if let image { defaults.set(image, forKey: Keys.userImage) }
    }

    func saveDemoUser() {
        keychain.save(key: Keys.sessionToken, value: "demo")
        defaults.set("Estudante", forKey: Keys.userName)
        defaults.set("demo@medcoach.app", forKey: Keys.userEmail)
    }

    func clearSession() {
        let fcm = defaults.string(forKey: Keys.fcmToken)
        keychain.delete(key: Keys.sessionToken)
        let keysToRemove = [
            Keys.userName, Keys.userEmail, Keys.userImage,
            Keys.isOnboarded, Keys.onboardingNickname, Keys.onboardingUniversity,
            Keys.onboardingState, Keys.onboardingSemester, Keys.onboardingSubjects,
            Keys.onboardingGoals, Keys.onboardingDailyMinutes
        ]
        keysToRemove.forEach { defaults.removeObject(forKey: $0) }
        // Preserve FCM token across logouts
        if let fcm { defaults.set(fcm, forKey: Keys.fcmToken) }
    }

    // MARK: - Onboarding

    func saveOnboardingData(_ data: OnboardingData) {
        defaults.set(true, forKey: Keys.isOnboarded)
        defaults.set(data.nickname, forKey: Keys.onboardingNickname)
        defaults.set(data.universityName, forKey: Keys.onboardingUniversity)
        defaults.set(data.universityState, forKey: Keys.onboardingState)
        defaults.set(data.semester, forKey: Keys.onboardingSemester)
        if let subjectsData = try? JSONEncoder().encode(data.subjects) {
            defaults.set(subjectsData, forKey: Keys.onboardingSubjects)
        }
        if let goalsData = try? JSONEncoder().encode(data.goals) {
            defaults.set(goalsData, forKey: Keys.onboardingGoals)
        }
        defaults.set(data.dailyStudyMinutes, forKey: Keys.onboardingDailyMinutes)
    }

    func getOnboardingData() -> OnboardingData? {
        guard let nickname = defaults.string(forKey: Keys.onboardingNickname) else { return nil }
        let subjects: [String] = (defaults.data(forKey: Keys.onboardingSubjects))
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        let goals: [String] = (defaults.data(forKey: Keys.onboardingGoals))
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        return OnboardingData(
            nickname: nickname,
            universityName: defaults.string(forKey: Keys.onboardingUniversity) ?? "",
            universityState: defaults.string(forKey: Keys.onboardingState) ?? "",
            semester: defaults.integer(forKey: Keys.onboardingSemester),
            subjects: subjects,
            goals: goals,
            dailyStudyMinutes: defaults.integer(forKey: Keys.onboardingDailyMinutes)
        )
    }

    // MARK: - FCM

    func saveFcmToken(_ token: String) {
        defaults.set(token, forKey: Keys.fcmToken)
    }

    var fcmToken: String? {
        defaults.string(forKey: Keys.fcmToken)
    }
}

// MARK: - Keychain Helper

final class KeychainHelper {
    static let shared = KeychainHelper()
    private init() {}

    func save(key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
