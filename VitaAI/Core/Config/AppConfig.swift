import Foundation
import OSLog

enum AppEnvironment {
    case development
    case production
}

enum AppConfig {
    private static let cfgLogger = Logger(subsystem: "com.bymav.vitaai", category: "config")

    #if DEBUG
    static let environment: AppEnvironment = .development
    #else
    static let environment: AppEnvironment = .production
    #endif

    static let onboardingKey = "vita_is_onboarded"
    static let legacyOnboardingKey = "vita_onboarding_done"

    // DEBUG builds hit the dev server on monstro via Tailscale (hot-reload backend).
    // Release builds (TestFlight / App Store) hit production vita-ai.cloud — the
    // tester's device cannot depend on Rafael's PC being online / Tailscale connected.
    #if DEBUG
    private static let defaultAPIBaseURL = "http://monstro.tail7e98e6.ts.net:3110/api"
    private static let defaultAuthBaseURL = "http://monstro.tail7e98e6.ts.net:3110"
    #else
    private static let defaultAPIBaseURL = "https://vita-ai.cloud/api"
    private static let defaultAuthBaseURL = "https://vita-ai.cloud"
    #endif

    struct InjectedSession {
        let token: String
        let name: String?
        let email: String?
        let image: String?
    }

    private static func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    }

    private static func truthy(_ value: String?) -> Bool {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            return false
        }
        return ["1", "true", "yes", "on"].contains(value)
    }

    private static func hasLaunchFlag(_ flag: String, defaultsKey: String? = nil, envKey: String? = nil) -> Bool {
        if ProcessInfo.processInfo.arguments.contains(flag) {
            return true
        }
        if let defaultsKey, UserDefaults.standard.object(forKey: defaultsKey) != nil {
            return UserDefaults.standard.bool(forKey: defaultsKey)
        }
        if let envKey {
            return truthy(ProcessInfo.processInfo.environment[envKey])
        }
        return false
    }

    private static func overrideValue(envKey: String, defaultsKey: String) -> String? {
        if let env = ProcessInfo.processInfo.environment[envKey], !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return normalized(env)
        }
        if let defaults = UserDefaults.standard.string(forKey: defaultsKey), !defaults.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return normalized(defaults)
        }
        return nil
    }

    private static var apiOverrideValue: String? {
        overrideValue(envKey: "VITA_API_BASE_URL", defaultsKey: "vita_api_base_url")
    }

    private static var authOverrideValue: String? {
        overrideValue(envKey: "VITA_AUTH_BASE_URL", defaultsKey: "vita_auth_base_url")
    }

    private static func launchArgumentValue(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let idx = arguments.firstIndex(of: flag), idx + 1 < arguments.count else {
            return nil
        }
        return arguments[idx + 1]
    }

    private static func authBaseURL(from apiBaseURL: String) -> String {
        let normalizedAPI = normalized(apiBaseURL)
        if normalizedAPI.hasSuffix("/api") {
            return String(normalizedAPI.dropLast(4))
        }
        return normalizedAPI
    }

    static var apiBaseURL: String {
        if let override = apiOverrideValue {
            cfgLogger.notice("[APICFG.apiBaseURL] OVERRIDE path used: \(override, privacy: .public) (env=\(ProcessInfo.processInfo.environment["VITA_API_BASE_URL"] ?? "nil", privacy: .public), defaults=\(UserDefaults.standard.string(forKey: "vita_api_base_url") ?? "nil", privacy: .public))")
            return override
        }
        #if DEBUG
        let branch = "DEBUG"
        #else
        let branch = "RELEASE"
        #endif
        cfgLogger.notice("[APICFG.apiBaseURL] DEFAULT path used: \(defaultAPIBaseURL, privacy: .public) (compile branch=\(branch, privacy: .public))")
        return defaultAPIBaseURL
    }

    static var authBaseURL: String {
        if let override = authOverrideValue {
            cfgLogger.notice("[APICFG.authBaseURL] OVERRIDE: \(override, privacy: .public)")
            return override
        }
        if let apiOverride = apiOverrideValue {
            let derived = authBaseURL(from: apiOverride)
            cfgLogger.notice("[APICFG.authBaseURL] derived from API override: \(derived, privacy: .public)")
            return derived
        }
        cfgLogger.notice("[APICFG.authBaseURL] DEFAULT: \(defaultAuthBaseURL, privacy: .public)")
        return defaultAuthBaseURL
    }

    static var shouldResetOnboarding: Bool {
        hasLaunchFlag("--reset-onboarding", defaultsKey: "vita_reset_onboarding", envKey: "VITA_RESET_ONBOARDING")
    }

    static var injectedSession: InjectedSession? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let idx = arguments.firstIndex(of: "--vita-inject-token"),
              idx + 1 < arguments.count
        else {
            return nil
        }

        return InjectedSession(
            token: arguments[idx + 1],
            name: idx + 2 < arguments.count ? arguments[idx + 2] : nil,
            email: idx + 3 < arguments.count ? arguments[idx + 3] : nil,
            image: idx + 4 < arguments.count ? arguments[idx + 4] : nil
        )
    }

    static var ciToken: String? {
        guard let token = ProcessInfo.processInfo.environment["VITA_CI_TOKEN"],
              !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return token
    }

    static var localForwardedHostHeader: String? {
        let candidate = authOverrideValue ?? apiOverrideValue
        guard let candidate,
              let url = URL(string: candidate),
              url.scheme?.lowercased() == "http" else {
            return nil
        }
        if let explicit = overrideValue(envKey: "VITA_FORWARDED_HOST", defaultsKey: "vita_forwarded_host") {
            return explicit
        }
        return url.host
    }

    static func isOnboardingComplete(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: onboardingKey) || defaults.bool(forKey: legacyOnboardingKey)
    }

    static func setOnboardingComplete(_ value: Bool, in defaults: UserDefaults = .standard) {
        defaults.set(value, forKey: onboardingKey)
        defaults.set(value, forKey: legacyOnboardingKey)
    }

    static var sessionCookieName: String {
        // __Secure- prefix only works over HTTPS
        if authBaseURL.hasPrefix("https") {
            return "__Secure-better-auth.session_token"
        }
        return "better-auth.session_token"
    }
    static let deepLinkScheme = "vitaai"
    static let appName = "VitaAI"
    static let bundleId = "com.bymav.vitaai"
}
