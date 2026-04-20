import Foundation
import OSLog
import PostHog

// MARK: - VitaPostHogConfig
//
// Product analytics and session replay for VitaAI iOS.
//
// Configuration:
//   - ACTIVE in BOTH Debug and Release builds.
//     Debug events carry property `$environment = "development"` so Rafael
//     can filter dev vs prod in PostHog dashboards.
//   - Session replay enabled with masked text inputs
//   - Host: PostHog US cloud
//
// Silent DEBUG gating was removed 2026-04-20 after we discovered zero iOS
// events had reached PostHog since 2026-04-17 (incident: PDF viewer debug
// session. Agents had no observability to diagnose. Sentry had the same
// issue — fixed in the same pass).

enum VitaPostHogConfig {

    private static let logger = Logger(subsystem: "com.bymav.vitaai", category: "posthog")

    // MARK: - Keys

    private static let apiKey = "phc_Lp1EkqO9t2IRymz41phAJUAP3Jm0opa9RyGQfvcsy2t"
    private static let host = "https://us.i.posthog.com"

    // MARK: - Initialize

    /// Bootstraps PostHog SDK. Active in ALL build configurations.
    static func initialize() {
        let config = PostHog.PostHogConfig(apiKey: apiKey, host: host)

        // Session replay
        config.sessionReplay = true
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.maskAllImages = false

        // Capture application lifecycle events (app open, background, etc.)
        config.captureApplicationLifecycleEvents = true

        // Capture screen views automatically
        config.captureScreenViews = true

        // Flush more aggressively in dev so events show up quickly
        #if DEBUG
        config.flushAt = 1
        #else
        config.flushAt = 20
        #endif

        PostHogSDK.shared.setup(config)

        // Tag every event with environment so Rafael can filter dev vs prod
        #if DEBUG
        let env = "development"
        #else
        let env = "production"
        #endif
        PostHogSDK.shared.register(["$environment": env, "platform": "ios"])

        logger.info("PostHog initialized (env=\(env, privacy: .public))")
    }

    // MARK: - User Identification

    /// Identifies the current user for analytics attribution.
    static func identify(userId: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.identify(userId, userProperties: properties)
    }

    /// Resets user identity on logout.
    static func reset() {
        PostHogSDK.shared.reset()
    }

    // MARK: - Events

    /// Captures a custom analytics event.
    static func capture(event: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.capture(event, properties: properties)
    }

    /// Captures a screen view event.
    static func screen(name: String, properties: [String: Any]? = nil) {
        PostHogSDK.shared.screen(name, properties: properties)
    }

    // MARK: - Feature Flags

    /// Checks if a feature flag is enabled.
    static func isFeatureEnabled(_ flag: String) -> Bool {
        PostHogSDK.shared.isFeatureEnabled(flag)
    }

    /// Reloads feature flags from PostHog.
    static func reloadFeatureFlags() {
        PostHogSDK.shared.reloadFeatureFlags()
    }
}
