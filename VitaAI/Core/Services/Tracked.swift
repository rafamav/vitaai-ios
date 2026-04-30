import Foundation

// MARK: - tracked
//
// Helper to wrap any async throwing call in a try/catch that ALWAYS emits a
// PostHog event when the catch fires. Stops silent failures (was the root
// cause documented in incidents/vitaai/2026-04-30_silent-tool-catches.md).
//
// Usage:
//   let result: PKDrawing? = await tracked("mlkit", "recognize") {
//       try await MLKitDigitalInkBridge.recognize(strokes: strokes, model: .textPtBR)
//   }
//
// On error, PostHog gets:
//   event: tool_error
//   props: { tool, stage, error, error_type, file, line }
//
// Returns nil on error so caller can continue with default fallback.

@discardableResult
func tracked<T>(_ tool: String,
                _ stage: String,
                file: String = #fileID,
                line: Int = #line,
                _ block: () async throws -> T) async -> T? {
    do {
        return try await block()
    } catch {
        PostHogTracker.shared.event(.toolError, properties: [
            "tool": tool,
            "stage": stage,
            "error": error.localizedDescription,
            "error_type": String(describing: type(of: error)),
            "file": file,
            "line": line,
        ])
        SentrySDKWrapper.captureCatch(error: error, context: ["tool": tool, "stage": stage])
        return nil
    }
}

/// Sync variant for non-throwing-async paths.
@discardableResult
func trackedSync<T>(_ tool: String,
                    _ stage: String,
                    file: String = #fileID,
                    line: Int = #line,
                    _ block: () throws -> T) -> T? {
    do {
        return try block()
    } catch {
        PostHogTracker.shared.event(.toolError, properties: [
            "tool": tool,
            "stage": stage,
            "error": error.localizedDescription,
            "error_type": String(describing: type(of: error)),
            "file": file,
            "line": line,
        ])
        SentrySDKWrapper.captureCatch(error: error, context: ["tool": tool, "stage": stage])
        return nil
    }
}

/// Manually emit a tool_error event when the failure is NOT a thrown error
/// (e.g. an early `return nil` from a guard let). Use sparingly; tracked()
/// is the preferred path.
func trackToolFailure(tool: String,
                      stage: String,
                      reason: String,
                      extraProps: [String: Any] = [:],
                      file: String = #fileID,
                      line: Int = #line) {
    var props: [String: Any] = [
        "tool": tool,
        "stage": stage,
        "reason": reason,
        "file": file,
        "line": line,
    ]
    props.merge(extraProps) { _, new in new }
    PostHogTracker.shared.event(.toolError, properties: props)
}

/// Thin wrapper so tracked() can call SentrySDK without forcing the import on
/// callers, and handle the case where Sentry SDK isn't initialized in some
/// targets.
enum SentrySDKWrapper {
    static func captureCatch(error: Error, context: [String: Any]) {
        SentryConfig.capture(error: error, context: context)
    }
}
