import Foundation

// MARK: - SentryConfig
//
// Crash reporting configuration for VitaAI iOS.
// Mirrors Android SentryConfig exactly:
//   - Skipped entirely in DEBUG builds
//   - tracesSampleRate = 1.0
//   - environment = "production"
//   - Only WARNING-level diagnostics and above
//
// Integration: call SentryConfig.initialize() at the top of VitaAIApp.init()
// before any other subsystem.
//
// Add the Sentry SDK via SPM: https://github.com/getsentry/sentry-cocoa
// When the SDK is available, uncomment the import and the SentrySDK block.

// import Sentry  ← uncomment once Sentry SPM package is added

enum SentryConfig {

    // MARK: - DSN
    // Add your DSN from the Sentry project settings.
    // Recommended: read from Info.plist so it is not hardcoded in source.
    private static var dsn: String {
        Bundle.main.infoDictionary?["SENTRY_DSN"] as? String ?? ""
    }

    // MARK: - Initialize

    /// Bootstraps Sentry SDK. No-op in DEBUG builds.
    static func initialize() {
        #if DEBUG
        // Skip Sentry entirely in debug builds — matches Android behaviour.
        return
        #else
        guard !dsn.isEmpty else {
            // DSN not configured yet — safe to skip.
            return
        }

        // Uncomment the block below once the Sentry SPM package is added to the project.
        //
        // SentrySDK.start { options in
        //     options.dsn = dsn
        //     options.tracesSampleRate = 1.0
        //     options.environment = "production"
        //     options.enableAppHangTracking = true         // equivalent to ANR detection
        //     options.enableCrashHandler = true
        //     options.diagnosticLevel = .warning           // mirrors SentryLevel.WARNING
        //     options.enableAutoPerformanceTracing = true
        //     options.attachStacktrace = true
        // }
        #endif
    }

    // MARK: - Capture Helpers

    /// Captures a non-fatal error manually (e.g. network errors, unexpected states).
    /// No-op if Sentry is not initialized.
    static func capture(error: Error, context: [String: Any]? = nil) {
        #if !DEBUG
        // SentrySDK.capture(error: error)
        _ = context  // suppress unused-variable warning until SDK is wired up
        #endif
    }

    /// Captures a message at WARNING level.
    static func capture(message: String) {
        #if !DEBUG
        // SentrySDK.capture(message: message)
        _ = message
        #endif
    }

    /// Sets the authenticated user context so events are attributed correctly.
    static func setUser(id: String, email: String?) {
        #if !DEBUG
        // let user = User(userId: id)
        // user.email = email
        // SentrySDK.setUser(user)
        _ = id; _ = email
        #endif
    }

    /// Clears the user context on logout.
    static func clearUser() {
        #if !DEBUG
        // SentrySDK.setUser(nil)
        #endif
    }
}
