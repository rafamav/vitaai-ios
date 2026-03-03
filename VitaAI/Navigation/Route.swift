import Foundation

enum Route: Hashable {
    case login
    case onboarding
    case home
    case estudos
    case trabalhos
    case agenda
    case insights
    case profile
    case canvasConnect
    case webalunoConnect
    case vitaChat(prompt: String? = nil)
    case notebookList
    case notebookEditor(notebookId: String)
    case mindMapList
    case mindMapEditor(id: String)
    case flashcardSession(deckId: String)
    case flashcardStats
    case pdfViewer(url: String)

    // MARK: - Simulado
    case simuladoHome
    case simuladoConfig
    case simuladoSession(attemptId: String)
    case simuladoResult(attemptId: String)
    case simuladoReview(attemptId: String)
    case simuladoDiagnostics

    // MARK: - Settings sub-screens
    case about
    case appearance
    case notifications

    // MARK: - Billing
    case paywall
}
