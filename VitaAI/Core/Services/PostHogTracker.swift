import Foundation
import PostHog

// MARK: - VitaEvent
//
// Canonical product analytics events for VitaAI iOS.
//
// Why an enum instead of raw strings:
//   - Single source of truth for event names → no typos drifting across views
//   - Refactor-safe (Xcode rename works)
//   - Audit-friendly: `grep VitaEvent.` finds every emitter
//   - PostHog dashboards use the rawValue verbatim
//
// When adding a new event:
//   1. Add a `case` here with the snake_case rawValue
//   2. Emit via `PostHogTracker.shared.event(.newCase, properties: [...])`
//   3. (optional) Pre-create the event in PostHog UI for faster dashboards
//
// Naming convention: `<noun>_<verb_past>` (e.g. `subscription_started`).
// Reserved names (`$pageview`, `$identify`, etc.) are emitted automatically
// by the SDK — never duplicate them here.

enum VitaEvent: String {
    // Cross-cutting tool error (instrumented via tracked() helper).
    // See Tracked.swift + incidents/vitaai/2026-04-30_silent-tool-catches.md.
    case toolError = "tool_error"
    case handwritingConverted = "handwriting_converted"
    case shapeSnapped = "shape_snapped"

    // Auth lifecycle
    case userSignedUp = "user_signed_up"
    case userLoggedIn = "user_logged_in"
    case userLoggedOut = "user_logged_out"

    // Onboarding funnel
    case onboardingStepViewed = "onboarding_step_viewed"
    case onboardingCompleted = "onboarding_completed"

    // Monetization
    case paywallShown = "paywall_shown"
    case subscriptionStarted = "subscription_started"
    case subscriptionCanceled = "subscription_canceled"

    // Study features
    case studySessionCompleted = "study_session_completed"
    case simuladoStarted = "simulado_started"
    case simuladoCompleted = "simulado_completed"
    case flashcardReviewCompleted = "flashcard_review_completed"
    case qbankQuestionAnswered = "qbank_question_answered"

    // Portal connectors
    case portalConnectStarted = "portal_connect_started"
    case portalConnectSucceeded = "portal_connect_succeeded"
    case portalConnectFailed = "portal_connect_failed"

    // AI / content
    case aiChatMessageSent = "ai_chat_message_sent"
    case documentUploaded = "document_uploaded"
}

// MARK: - PostHogTracker
//
// Tipo facade fina por cima do PostHog SDK. Toda emissão de evento de
// produto vai por aqui. Mantém os call sites curtos e auditáveis:
//
//     PostHogTracker.shared.event(.userLoggedIn, properties: ["method": "google"])
//
// Para identify/reset use `VitaPostHogConfig.identify` / `.reset` direto —
// auth state mora lá. Esta facade é só para EVENTS.

final class PostHogTracker {
    static let shared = PostHogTracker()

    private init() {}

    /// Emits a typed product event. Use `VitaEvent` enum to keep the
    /// dashboard taxonomy clean. `properties` may include any JSON-encodable
    /// values; PostHog converts them server-side.
    func event(_ name: VitaEvent, properties: [String: Any] = [:]) {
        PostHogSDK.shared.capture(name.rawValue, properties: properties)
    }
}
