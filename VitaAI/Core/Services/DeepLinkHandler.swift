import Foundation

extension Notification.Name {
    /// Posted when an integration OAuth flow completes via deep link callback.
    /// Object is the provider name string (e.g. "google_calendar").
    static let integrationOAuthCompleted = Notification.Name("integrationOAuthCompleted")
}

// MARK: - DeepLinkHandler
//
// Parses incoming vitaai:// URLs and maps them to app Routes.
//
// Supported deep links (mirrors Android DeepLinkHandler):
//   vitaai://home              -> .home
//   vitaai://estudos           -> .estudos
//   vitaai://trabalhos         -> .trabalhos
//   vitaai://agenda            -> .agenda
//   vitaai://insights          -> .insights
//   vitaai://profile           -> .profile
//   vitaai://chat              -> .vitaChat(prompt: nil)
//   vitaai://chat?prompt=X     -> .vitaChat(prompt: X)
//   vitaai://flashcard/{id}    -> .flashcardSession(deckId: id)
//   vitaai://notebooks         -> .notebookList
//   vitaai://notebook/{id}     -> .notebookEditor(notebookId: id)
//   vitaai://trabalho/{id}     -> .trabalhoDetail(id: id)
//   vitaai://auth/callback     -> .authCallback (handled by AuthManager)
//   vitaai://settings/about         -> .about
//   vitaai://settings/appearance    -> .appearance
//   vitaai://settings/notifications -> .notifications

@MainActor
final class DeepLinkHandler {

    static let shared = DeepLinkHandler()
    private init() {}

    private let scheme = "vitaai"

    // MARK: - Result

    enum DeepLinkResult {
        /// A resolved app route ready for navigation.
        case navigate(Route)
        /// Auth callback — handled separately by AuthManager.
        case authCallback
        /// Integration OAuth callback — provider connected successfully.
        case integrationCallback(provider: String)
        /// App Store reviewer token redeem — logs into pre-seeded demo account.
        /// vitaai://review?token=<APPLE_REVIEW_TOKEN>
        case reviewToken(String)
        /// URL could not be mapped to a known route.
        case unknown(URL)
        /// No deep link data present.
        case none
        /// Referral code captured (Universal Link /r/CODE OR vitaai://r/CODE).
        /// Stored in UserDefaults pra ser consumido após auth + onboarding.
        case referralCode(code: String, source: String)
    }

    // MARK: - Parse

    func parse(url: URL?) -> DeepLinkResult {
        guard let url else { return .none }

        // Universal Link https://vita-ai.cloud/r/CODE — captura referral
        // ANTES de qualquer scheme check (universal link usa https, não vitaai://).
        if let host = url.host, host.contains("vita-ai.cloud"),
           url.pathComponents.count >= 3, url.pathComponents[1] == "r" {
            let code = url.pathComponents[2].uppercased()
            return .referralCode(code: code, source: "universal_link")
        }

        guard url.scheme == scheme else {
            return .unknown(url)
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else {
            return .unknown(url)
        }

        let pathSegments = url.pathComponents.filter { $0 != "/" }
        let queryItems = components.queryItems ?? []

        func queryValue(_ name: String) -> String? {
            queryItems.first(where: { $0.name == name })?.value
        }

        switch host {

        // Auth callback
        case "auth":
            return .authCallback

        // App Store Review token redeem
        case "review":
            if let token = queryValue("token"), !token.isEmpty {
                return .reviewToken(token)
            }
            return .unknown(url)

        // Integration OAuth callback: vitaai://integrations/callback?provider=google_calendar&status=success
        case "integrations":
            if pathSegments.first == "callback", let provider = queryValue("provider") {
                return .integrationCallback(provider: provider)
            }
            return .navigate(.connections)

        // Main tabs
        case "home":       return .navigate(.home)
        case "estudos":    return .navigate(.estudos)
        case "trabalhos":  return .navigate(.trabalhos)
        case "agenda":     return .navigate(.agenda)
        case "insights":   return .navigate(.insights)
        case "profile":    return .navigate(.profile)
        case "paywall":    return .navigate(.paywall)
        case "progresso":  return .navigate(.progresso)
        case "notebooks":  return .navigate(.notebookList)

        // Chat with optional prompt
        case "chat":
            let prompt = queryValue("prompt")
            return .navigate(.vitaChat(prompt: prompt?.isEmpty == false ? prompt : nil))

        // Flashcard session: vitaai://flashcard/{deckId}
        case "flashcard":
            guard let deckId = pathSegments.first, !deckId.isEmpty else {
                return .unknown(url)
            }
            return .navigate(.flashcardSession(deckId: deckId))

        // Notebook editor: vitaai://notebook/{notebookId}
        case "notebook":
            if let notebookId = pathSegments.first, !notebookId.isEmpty {
                return .navigate(.notebookEditor(notebookId: notebookId))
            }
            return .navigate(.notebookList)

        // Trabalho detail: vitaai://trabalho/{id}
        case "trabalho":
            if let id = pathSegments.first, !id.isEmpty {
                return .navigate(.trabalhoDetail(id: id))
            }
            return .navigate(.trabalhos)

        // Atlas 3D
        case "atlas": return .navigate(.atlas3D)

        // Connections / Conectores
        case "connections": return .navigate(.connections)

        // Referral via custom scheme: vitaai://r/CODE
        case "r":
            guard let codeRaw = pathSegments.first else { return .navigate(.referral) }
            return .referralCode(code: codeRaw.uppercased(), source: "universal_link")

        // Settings sub-screens
        case "settings":
            switch pathSegments.first {
            case "about":         return .navigate(.about)
            case "appearance":    return .navigate(.appearance)
            case "notifications": return .navigate(.notifications)
            case "privacy":       return .navigate(.privacyDocuments)
            case "export":        return .navigate(.exportData)
            case "feedback":      return .navigate(.feedback)
            case nil, "":         return .navigate(.configuracoes)
            default:              return .navigate(.configuracoes)
            }

        default:
            return .unknown(url)
        }
    }

    // MARK: - Convenience

    /// Returns true when the URL is an auth callback.
    func isAuthCallback(_ url: URL) -> Bool {
        if case .authCallback = parse(url: url) { return true }
        return false
    }
}
