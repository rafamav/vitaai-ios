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

        // Session replay — screenshotMode OBRIGATÓRIO em SwiftUI
        // (sem isso views aparecem mascaradas integral no replay, útil=0).
        // Ref: agent-brain observability canon §3.6 "Session Replay iOS SwiftUI".
        config.sessionReplay = true
        config.sessionReplayConfig.screenshotMode = true
        config.sessionReplayConfig.maskAllTextInputs = true
        config.sessionReplayConfig.maskAllImages = false
        config.sessionReplayConfig.captureNetworkTelemetry = true

        // LGPD — estudantes BR. IP é resolvido server-side pelo PostHog
        // (US/EU ingest). Desligado em project settings UI, não no SDK iOS.
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

    /// Canonical feature flags for VitaAI. Defined in PostHog dashboard.
    /// Ref: agent-brain observability canon §3.6 "Top-5 feature flags".
    enum Flag: String {
        /// Kill switch for PDF scanner (iOS Vision API). Flip to false if
        /// Vision latency spikes or Apple changes the API.
        case pdfScannerEnabled = "pdf_scanner_enabled"

        /// AI coach model selector. Multivariate:
        ///   - `haiku-max` → Claude Haiku via OAuth Max (default)
        ///   - `sonnet-max` → Claude Sonnet via OAuth Max (premium test)
        ///   - `local-vllm` → Qwen3.5-35B-A3B self-hosted
        /// NUNCA adicionar Anthropic API key — só OAuth Max.
        case aiCoachModel = "ai_coach_model"

        /// Portal extractor version selector for safe rollout:
        ///   - `v1-legacy` → hardcoded parsers (deprecated)
        ///   - `v2-fingerprint` → fingerprint-based parseWithMap
        ///   - `v3-teacher` → Haiku teacher generates fingerprints
        case portalExtractorVersion = "portal_extractor_version"

        /// Pricing plan variant for A/B (BRL):
        ///   - `49-99-149` (control)
        ///   - `39-79-119` (aggressive)
        case pricingPlanVariant = "pricing_plan_variant"

        /// Onboarding v2 — dogfood before 100% rollout. 10% initially.
        case newOnboardingV2 = "new_onboarding_v2"
    }

    /// Checks if a typed feature flag is enabled.
    static func isEnabled(_ flag: Flag) -> Bool {
        PostHogSDK.shared.isFeatureEnabled(flag.rawValue)
    }

    /// Gets a multivariate flag's string payload (for `aiCoachModel`, etc.).
    static func variant(_ flag: Flag) -> String? {
        PostHogSDK.shared.getFeatureFlag(flag.rawValue) as? String
    }

    /// Raw flag check (legacy — prefer `isEnabled(_:)` with Flag enum).
    static func isFeatureEnabled(_ flag: String) -> Bool {
        PostHogSDK.shared.isFeatureEnabled(flag)
    }

    /// Reloads feature flags from PostHog.
    static func reloadFeatureFlags() {
        PostHogSDK.shared.reloadFeatureFlags()
    }
}
