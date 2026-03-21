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
    case googleCalendarConnect
    case googleDriveConnect
    case vitaChat(prompt: String? = nil)
    case notebookList
    case notebookEditor(notebookId: String)
    case mindMapList
    case mindMapEditor(id: String)
    case flashcardSession(deckId: String)
    case flashcardStats
    case pdfViewer(url: String)

    // MARK: - Atlas 3D
    case atlas3D

    // MARK: - OSCE
    case osce

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
    case connections

    // MARK: - Activity / Gamification
    case activityFeed
    case leaderboard

    // MARK: - Billing
    case paywall

    // MARK: - Course Detail
    case courseDetail(courseId: String, colorIndex: Int)

    // MARK: - Provas (Crowd)
    case provas

    // MARK: - QBank (Question Bank)
    case qbank

    // MARK: - Tool Manager
    case toolManager

    // MARK: - Discipline Detail
    case disciplineDetail(disciplineId: String, disciplineName: String)

    // MARK: - Transcricao (audio recording + AI transcription)
    case transcricao

    // MARK: - Achievements (full badges page — BYM-1135)
    case achievements

    // MARK: - Planner (daily study plan — BYM-1152)
    case planner
}
