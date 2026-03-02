import Foundation

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
        /// URL could not be mapped to a known route.
        case unknown(URL)
        /// No deep link data present.
        case none
    }

    // MARK: - Parse

    func parse(url: URL?) -> DeepLinkResult {
        guard let url else { return .none }
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

        // Main tabs
        case "home":       return .navigate(.home)
        case "estudos":    return .navigate(.estudos)
        case "trabalhos":  return .navigate(.trabalhos)
        case "agenda":     return .navigate(.agenda)
        case "insights":   return .navigate(.insights)
        case "profile":    return .navigate(.profile)
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

        // Settings sub-screens
        case "settings":
            switch pathSegments.first {
            case "about":         return .navigate(.about)
            case "appearance":    return .navigate(.appearance)
            case "notifications": return .navigate(.notifications)
            default:              return .navigate(.profile)
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
