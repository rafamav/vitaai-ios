import Foundation

enum Route: Hashable {
    case login
    case onboarding
    case home
    case estudos
    case faculdade
    case progresso
    case trabalhos
    case trabalhoDetail(id: String)
    case agenda
    case insights
    case profile
    case portalConnect(type: String)

    // Legacy aliases — redirect to portalConnect(type:) in AppRouter
    case canvasConnect
    case webalunoConnect
    case googleCalendarConnect
    case googleDriveConnect
    case vitaChat(prompt: String? = nil)
    case notebookList
    case notebookEditor(notebookId: String)
    case mindMapList
    case mindMapEditor(id: String)
    case flashcardHome(subjectId: String? = nil)
    case flashcardTopics(deckId: String, deckTitle: String)
    case flashcardSession(deckId: String, tagFilter: String? = nil)
    case flashcardSettings
    case flashcardStats
    case pdfViewer(url: String, title: String? = nil)

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
    case configuracoes
    case disciplinasConfig

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

    // MARK: - Transcrição (audio recording + AI transcription)
    case transcricao

    // MARK: - Achievements (full badges page — BYM-1135)
    case achievements

    // MARK: - Planner (daily study plan — BYM-1152)
    case planner

    // MARK: - Faculdade subpages (dashboard + push navigation)
    case faculdadeDisciplinas
    case faculdadeMaterias
    case faculdadeDocumentos
    case faculdadeProfessores

    // MARK: - Material folder drill-down
    /// Lista de documentos dentro de uma pasta de materiais (Slides/Provas/etc).
    /// Aberto via DisciplineDetail ao tocar num card de pasta.
    case materialFolderDetail(folderId: String, folderName: String, folderIcon: String)
}
