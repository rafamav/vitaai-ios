import Foundation
import OSLog
import Sentry

// MARK: - SentryConfig
//
// Crash reporting and performance monitoring for VitaAI iOS.
//
// Configuration:
//   - ACTIVE in BOTH Debug and Release builds (so dev bugs reach Rafael's dashboard)
//     Environment tag distinguishes them: "development" vs "production"
//   - tracesSampleRate: 1.0 in debug (catch everything), 0.2 in release
//   - profilesSampleRate = 0.1 (10% of traced transactions in release)
//   - App hang tracking enabled (equivalent to ANR detection on Android)
//   - Screenshot attachment enabled for crash context
//
// DSN comes from Info.plist key `SENTRY_DSN`, set in project.yml.
// If DSN is missing in Release, we crash the boot (assertionFailure) —
// silently running without observability bit us multiple times (incident 2026-04-20).

enum SentryConfig {

    private static let logger = Logger(subsystem: "com.bymav.vitaai", category: "sentry")

    // MARK: - DSN
    // Read from Info.plist so it is never hardcoded in source.
    private static var dsn: String {
        Bundle.main.infoDictionary?["SENTRY_DSN"] as? String ?? ""
    }

    // MARK: - Initialize

    /// Bootstraps Sentry SDK. Active in ALL build configurations.
    static func initialize() {
        guard !dsn.isEmpty else {
            #if DEBUG
            logger.error("SENTRY_DSN missing from Info.plist — observability disabled in debug. Fix project.yml.")
            return
            #else
            // In release this is a shipping-blocker: crash fast so it gets noticed.
            assertionFailure("SENTRY_DSN missing from Info.plist in Release build")
            return
            #endif
        }

        #if DEBUG
        let environment = "development"
        let tracesRate: Float = 1.0    // catch everything in dev
        let profilesRate: Float = 0.5
        #else
        let environment = "production"
        let tracesRate: Float = 0.2
        let profilesRate: Float = 0.1
        #endif

        SentrySDK.start { options in
            options.dsn = dsn
            options.environment = environment

            // Performance Monitoring
            options.tracesSampleRate = NSNumber(value: tracesRate)
            options.profilesSampleRate = NSNumber(value: profilesRate)

            // TTID/TTFD for SwiftUI screens (gold standard 2026) — opt-in globally
            // so SentryTracedView(waitForFullDisplay:) measures real load time.
            // Paired with SentrySDK.reportFullyDisplayed() inside .task{} on
            // every tracked screen.
            options.enableTimeToFullDisplayTracing = true

            // Distributed tracing: inject `sentry-trace` + `baggage` headers
            // in outbound URLSession requests matching these hosts, so the
            // backend (@sentry/nextjs) continues the same trace ID. Result:
            // one waterfall iOS → Next.js → Drizzle → DB.
            options.tracePropagationTargets = [
                "monstro.tail7e98e6.ts.net",
                "vita-ai.cloud",
                "app.vita-ai.cloud"
            ]

            // Crash & hang detection
            options.enableCrashHandler = true
            options.enableAppHangTracking = true
            options.appHangTimeoutInterval = 2.0  // 2 seconds

            // Stack traces & breadcrumbs
            options.attachStacktrace = true
            options.enableSwizzling = true
            options.enableAutoBreadcrumbTracking = true

            // Auto performance tracing (view controllers, HTTP requests)
            options.enableAutoPerformanceTracing = true

            // Session tracking
            options.enableAutoSessionTracking = true

            // Screenshots for crash context
            options.attachScreenshot = true

            // User interaction tracing
            options.enableUserInteractionTracing = true

            // MetricKit — Apple-native launch histograms + hang reports,
            // delivered daily to Sentry. Covers cold-launch and disk writes
            // that the in-process SDK cannot instrument (iOS 15+).
            options.enableMetricKit = true

            // Session Replay (Sentry 8.36+) — record the screen when something
            // breaks. 0% replay for healthy sessions; 100% when the session has
            // an error so Rafael sees the broken UI without reproducing it.
            options.sessionReplay.sessionSampleRate = 0.0
            options.sessionReplay.onErrorSampleRate = 1.0

            // Diagnostics
            #if DEBUG
            // Sentry SDK prints "transaction created/sampled/finished/dropped"
            // in Xcode console. Only active in Debug so TestFlight stays clean.
            options.debug = true
            options.diagnosticLevel = .debug
            #else
            options.diagnosticLevel = .warning
            #endif
        }

        logger.info("Sentry initialized (env=\(environment, privacy: .public))")
    }

    // MARK: - Capture Helpers

    /// Captures a non-fatal error manually (e.g. network errors, unexpected states).
    static func capture(error: Error, context: [String: Any]? = nil) {
        SentrySDK.capture(error: error) { scope in
            if let context = context {
                scope.setContext(value: context, key: "custom")
            }
        }
    }

    /// Captures a message at a given severity level.
    static func capture(message: String) {
        SentrySDK.capture(message: message)
    }

    // MARK: - User Context

    /// Sets the authenticated user so Sentry events are attributed correctly.
    static func setUser(id: String, email: String?) {
        let user = User(userId: id)
        user.email = email
        SentrySDK.setUser(user)
    }

    /// Clears the user context on logout.
    static func clearUser() {
        SentrySDK.setUser(nil)
    }

    // MARK: - Breadcrumbs

    /// Adds a breadcrumb for debugging context.
    static func addBreadcrumb(message: String, category: String, data: [String: Any]? = nil) {
        let crumb = Breadcrumb(level: .info, category: category)
        crumb.message = message
        crumb.data = data
        SentrySDK.addBreadcrumb(crumb)
    }
}
