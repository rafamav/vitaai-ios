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
        static let legacyIsOnboarded = "vita_onboarding_done"
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
        if let ciToken = AppConfig.ciToken { return ciToken }
        #endif
        return keychain.read(key: Keys.sessionToken)
    }

    var isLoggedIn: Bool {
        token != nil
    }

    var isOnboarded: Bool {
        #if DEBUG
        if AppConfig.ciToken != nil { return true }
        #endif
        return AppConfig.isOnboardingComplete(in: defaults)
    }

    // MARK: - User Info (Keychain-backed)

    var userName: String? {
        keychain.read(key: Keys.userName) ?? defaults.string(forKey: Keys.userName)
    }

    var userEmail: String? {
        keychain.read(key: Keys.userEmail) ?? defaults.string(forKey: Keys.userEmail)
    }

    var userImage: String? {
        keychain.read(key: Keys.userImage) ?? defaults.string(forKey: Keys.userImage)
    }

    // MARK: - Session Management

    func updateToken(_ token: String) {
        keychain.save(key: Keys.sessionToken, value: token)
    }

    func saveSession(token: String, name: String?, email: String?, image: String?) {
        keychain.save(key: Keys.sessionToken, value: token)
        if let name { keychain.save(key: Keys.userName, value: name) }
        if let email { keychain.save(key: Keys.userEmail, value: email) }
        if let image { keychain.save(key: Keys.userImage, value: image) }
        // Clean up legacy UserDefaults data
        defaults.removeObject(forKey: Keys.userName)
        defaults.removeObject(forKey: Keys.userEmail)
        defaults.removeObject(forKey: Keys.userImage)
    }

    func clearSession() {
        let fcm = defaults.string(forKey: Keys.fcmToken)
        // Clear Keychain credentials
        keychain.delete(key: Keys.sessionToken)
        keychain.delete(key: Keys.userName)
        keychain.delete(key: Keys.userEmail)
        keychain.delete(key: Keys.userImage)
        // Clear UserDefaults (onboarding + legacy)
        let keysToRemove = [
            Keys.userName, Keys.userEmail, Keys.userImage,
            Keys.isOnboarded, Keys.legacyIsOnboarded, Keys.onboardingNickname, Keys.onboardingUniversity,
            Keys.onboardingState, Keys.onboardingSemester, Keys.onboardingSubjects,
            Keys.onboardingGoals, Keys.onboardingDailyMinutes
        ]
        keysToRemove.forEach { defaults.removeObject(forKey: $0) }
        // Preserve FCM token across logouts
        if let fcm { defaults.set(fcm, forKey: Keys.fcmToken) }
    }

    // MARK: - Onboarding

    func saveOnboardingData(_ data: OnboardingData) {
        AppConfig.setOnboardingComplete(true, in: defaults)
        defaults.set(data.nickname, forKey: Keys.onboardingNickname)
        defaults.set(data.universityName, forKey: Keys.onboardingUniversity)
        defaults.set(data.universityState, forKey: Keys.onboardingState)
        defaults.set(data.semester, forKey: Keys.onboardingSemester)
        if let subjectsData = try? JSONEncoder().encode(data.subjects) {
            defaults.set(subjectsData, forKey: Keys.onboardingSubjects)
        }
        if let diffData = try? JSONEncoder().encode(data.subjectDifficulties) {
            defaults.set(diffData, forKey: Keys.onboardingGoals) // reuse key
        }
    }

    func getOnboardingData() -> OnboardingData? {
        guard let nickname = defaults.string(forKey: Keys.onboardingNickname) else { return nil }
        let subjects: [String] = (defaults.data(forKey: Keys.onboardingSubjects))
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
        let difficulties: [String: String] = (defaults.data(forKey: Keys.onboardingGoals))
            .flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
        return OnboardingData(
            nickname: nickname,
            universityName: defaults.string(forKey: Keys.onboardingUniversity) ?? "",
            universityState: defaults.string(forKey: Keys.onboardingState) ?? "",
            semester: defaults.integer(forKey: Keys.onboardingSemester),
            subjects: subjects,
            subjectDifficulties: difficulties
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
