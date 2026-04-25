import Foundation

actor VitaAPI {
    let client: HTTPClient // internal so feature extensions in separate files can access (Apr 2026)

    init(client: HTTPClient) {
        self.client = client
    }

    // ┌─────────────────────────────────────────────────┐
    // │  WORKING ENDPOINTS — backend route.ts exists    │
    // │  Validated by: scripts/lint-api-endpoints.sh    │
    // └─────────────────────────────────────────────────┘

    // MARK: - Dashboard

    func getDashboard() async throws -> DashboardResponse {
        try await client.get("dashboard")
    }

    // MARK: - Profile

    func getProfile() async throws -> ProfileResponse {
        try await client.get("profile")
    }

    // MARK: - Progress

    func getProgress() async throws -> ProgressResponse {
        try await client.get("progress")
    }

    // MARK: - Activity / Gamification

    func logActivity(action: String, metadata: [String: String]? = nil) async throws -> LogActivityResponse {
        try await client.post("activity", body: LogActivityRequest(action: action, metadata: metadata))
    }

    func getLeaderboard(period: String = "weekly", limit: Int = 20) async throws -> [LeaderboardEntry] {
        try await client.get("leaderboard", queryItems: [
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    // MARK: - Achievements

    func getAchievements() async throws -> [BadgeWithStatus] {
        try await client.get("achievements")
    }

    // MARK: - Notifications

    func getNotifications() async throws -> [VitaNotification] {
        try await client.get("notifications")
    }

    func markNotificationsRead(ids: [String]? = nil, markAll: Bool = false) async throws {
        struct Body: Encodable { let ids: [String]?; let markAll: Bool? }
        let _: EmptyResponse = try await client.post("notifications", body: Body(ids: ids, markAll: markAll ? true : nil))
    }

    func deleteNotifications(ids: [String]? = nil, deleteAllRead: Bool = false) async throws {
        struct Body: Encodable { let ids: [String]?; let deleteAllRead: Bool? }
        try await client.delete("notifications", body: Body(ids: ids, deleteAllRead: deleteAllRead ? true : nil))
    }

    // MARK: - Universities

    func getUniversities(query: String? = nil) async throws -> UniversitiesResponse {
        var items: [URLQueryItem] = [.init(name: "limit", value: "500")]
        if let query, !query.isEmpty { items.append(.init(name: "q", value: query)) }
        return try await client.get("universities", queryItems: items)
    }

    // MARK: - Server-Driven UI

    func getScreen(screenId: String) async throws -> ScreenResponse {
        try await client.get("screen/\(screenId)")
    }

    // MARK: - Flashcards

    func getMockupFlashcards(dueOnly: Bool = false) async throws -> [FlashcardDeckEntry] {
        var items: [URLQueryItem] = []
        if dueOnly { items.append(.init(name: "due", value: "true")) }
        return try await client.get("study/flashcards", queryItems: items.isEmpty ? nil : items)
    }

    func getFlashcardDecks(subjectId: String? = nil, dueOnly: Bool = false, tag: String? = nil, cardsLimit: Int? = nil, deckLimit: Int? = nil, summary: Bool = false, scope: String? = nil) async throws -> [FlashcardDeckEntry] {
        var items: [URLQueryItem] = []
        if let subjectId { items.append(.init(name: "subjectId", value: subjectId)) }
        if dueOnly { items.append(.init(name: "due", value: "true")) }
        if let tag { items.append(.init(name: "tag", value: tag)) }
        if let cardsLimit { items.append(.init(name: "cardsLimit", value: String(cardsLimit))) }
        if let deckLimit { items.append(.init(name: "deckLimit", value: String(deckLimit))) }
        if summary { items.append(.init(name: "summary", value: "true")) }
        if let scope { items.append(.init(name: "scope", value: scope)) }
        return try await client.get("study/flashcards", queryItems: items.isEmpty ? nil : items)
    }

    func getFlashcardTopics(deckId: String) async throws -> [FlashcardTopic] {
        try await client.get("study/flashcards", queryItems: [.init(name: "topics", value: deckId)])
    }

    func getFlashcardStats() async throws -> FlashcardStatsResponse {
        try await client.get("study/flashcards/stats")
    }

    func generateFlashcards(discipline: String, count: Int = 30) async throws -> [FlashcardDeckEntry] {
        struct Body: Encodable { let discipline: String; let count: Int }
        return try await client.post("study/flashcards/generate", body: Body(discipline: discipline, count: count))
    }

    @discardableResult
    func generateFlashcardsAutoSeed() async throws -> AutoSeedResponse {
        struct Body: Encodable { let autoSeed: Bool }
        return try await client.post("study/flashcards/generate", body: Body(autoSeed: true))
    }

    struct AutoSeedResponse: Decodable {
        var generated: Int?
        var totalCards: Int?
    }

    func reviewFlashcard(cardId: String, rating: Int, responseTimeMs: Int64) async throws {
        let _: EmptyResponse = try await client.post(
            "study/flashcards/\(cardId)/review",
            body: FlashcardReviewRequest(rating: rating, responseTimeMs: responseTimeMs)
        )
    }

    func suspendFlashcard(cardId: String) async throws {
        let _: EmptyResponse = try await client.post(
            "study/flashcards/\(cardId)/suspend",
            body: EmptyBody()
        )
    }

    func buryFlashcard(cardId: String) async throws {
        let _: EmptyResponse = try await client.post(
            "study/flashcards/\(cardId)/bury",
            body: EmptyBody()
        )
    }

    // MARK: - Grades

    func getGrades(subjectId: String? = nil, limit: Int = 20) async throws -> [GradeEntry] {
        var items: [URLQueryItem] = [.init(name: "limit", value: String(limit))]
        if let subjectId { items.append(.init(name: "subjectId", value: subjectId)) }
        return try await client.get("grades", queryItems: items)
    }

    // MARK: - AI Coach

    func getConversations() async throws -> [ConversationEntry] {
        try await client.get("ai/coach/conversations")
    }

    func getConversationMessages(conversationId: String) async throws -> ConversationMessagesResponse {
        try await client.get("ai/coach/conversations/\(conversationId)")
    }

    func sendFeedback(conversationId: String, messageId: String, feedback: String) async throws {
        let _: EmptyResponse = try await client.post("ai/coach/feedback", body: FeedbackRequest(conversationId: conversationId, messageId: messageId, feedback: feedback))
    }

    // MARK: - OSCE

    func startOsceCase(specialty: String) async throws -> OsceStartResponse {
        try await client.post("ai/osce", body: OsceStartRequest(specialty: specialty))
    }

    func getOsceSpecialties() async throws -> [String] {
        try await client.get("ai/osce/specialties")
    }

    // MARK: - Study Overview (hero stats + subjects for StudySuite screens)

    func getStudyOverview() async throws -> StudyOverviewResponse {
        try await client.get("study/overview")
    }

    // MARK: - Transcrição

    func getTranscricoes() async throws -> [TranscricaoEntry] {
        try await client.get("study/transcricao")
    }

    // MARK: - Studio (Transcription Detail + Outputs)

    func getStudioSourceDetail(id: String) async throws -> StudioSourceDetail {
        try await client.get("studio/sources/\(id)")
    }

    private struct RenameStudioSourceBody: Encodable { let title: String }

    func renameStudioSource(id: String, title: String) async throws {
        try await client.patch("studio/sources/\(id)", body: RenameStudioSourceBody(title: title))
    }

    /// PATCH /api/studio/sources/:id — update folder/favorite/disciplineSlug.
    /// `clearDiscipline`/`clearFolder = true` envia null no JSON pra remover.
    func updateStudioSource(
        id: String,
        disciplineSlug: String? = nil,
        clearDiscipline: Bool = false,
        folderId: String? = nil,
        clearFolder: Bool = false,
        favorite: Bool? = nil
    ) async throws {
        struct Body: Encodable {
            let disciplineSlug: String?
            let folderId: String?
            let favorite: Bool?
            var hasClearDiscipline: Bool
            var hasClearFolder: Bool
            func encode(to encoder: Encoder) throws {
                var c = encoder.container(keyedBy: CK.self)
                if hasClearDiscipline {
                    try c.encodeNil(forKey: .disciplineSlug)
                } else if let s = disciplineSlug {
                    try c.encode(s, forKey: .disciplineSlug)
                }
                if hasClearFolder {
                    try c.encodeNil(forKey: .folderId)
                } else if let s = folderId {
                    try c.encode(s, forKey: .folderId)
                }
                if let f = favorite { try c.encode(f, forKey: .favorite) }
            }
            enum CK: String, CodingKey { case disciplineSlug, folderId, favorite }
        }
        let body = Body(
            disciplineSlug: disciplineSlug,
            folderId: folderId,
            favorite: favorite,
            hasClearDiscipline: clearDiscipline,
            hasClearFolder: clearFolder
        )
        try await client.patch("studio/sources/\(id)", body: body)
    }

    // MARK: - Studio Folders (user-created folders)

    struct StudioFolder: Decodable, Identifiable {
        let id: String
        let name: String
        let color: String?
        let icon: String?
    }

    private struct StudioFoldersResponse: Decodable { let folders: [StudioFolder] }
    private struct StudioFolderResponse: Decodable { let folder: StudioFolder }

    func listStudioFolders() async throws -> [StudioFolder] {
        let resp: StudioFoldersResponse = try await client.get("studio/folders")
        return resp.folders
    }

    func createStudioFolder(name: String, color: String? = nil, icon: String? = nil) async throws -> StudioFolder {
        struct Body: Encodable { let name: String; let color: String?; let icon: String? }
        let resp: StudioFolderResponse = try await client.post(
            "studio/folders",
            body: Body(name: name, color: color, icon: icon)
        )
        return resp.folder
    }

    func deleteStudioFolder(id: String) async throws {
        try await client.delete("studio/folders/\(id)")
    }

    func deleteStudioSource(id: String) async throws {
        try await client.delete("studio/sources/\(id)")
    }

    func getStudioOutputs(sourceId: String) async throws -> StudioOutputsResponse {
        try await client.get("studio/outputs", queryItems: [
            URLQueryItem(name: "sourceId", value: sourceId),
        ])
    }

    private struct GenerateBody: Encodable {
        let sourceIds: [String]
        let type: String
    }

    func generateStudioOutput(sourceId: String, outputType: String) async throws -> StudioOutput {
        // Backend expects sourceIds array and "type" field at POST /api/studio/generate
        let backendType = Self.mapOutputType(outputType)
        let result: StudioOutput = try await client.post("studio/generate", body: GenerateBody(
            sourceIds: [sourceId],
            type: backendType
        ))
        return result
    }

    /// Map iOS output type names to backend enum values
    private static func mapOutputType(_ type: String) -> String {
        switch type {
        case "questions": return "quiz"
        case "concepts": return "summary" // concepts extracted as summary variant
        default: return type // summary, flashcards, mindmap pass through
        }
    }

    // MARK: - MindMaps

    func getMindMaps(limit: Int = 50) async throws -> [RemoteMindMap] {
        try await client.get("study/mindmaps", queryItems: [
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    // MARK: - Notes

    func getNotes(subjectId: String? = nil, limit: Int = 50) async throws -> [RemoteNote] {
        var items: [URLQueryItem] = [.init(name: "limit", value: String(limit))]
        if let subjectId { items.append(.init(name: "subjectId", value: subjectId)) }
        return try await client.get("notes", queryItems: items)
    }

    func createNote(title: String, content: String, subjectId: String? = nil) async throws -> RemoteNote {
        try await client.post("notes", body: CreateNoteRequest(title: title, content: content, subjectId: subjectId))
    }

    func updateNote(id: String, title: String? = nil, content: String? = nil, subjectId: String? = nil) async throws -> RemoteNote {
        try await client.patch("notes", body: UpdateNoteRequest(id: id, title: title, content: content, subjectId: subjectId))
    }

    func deleteNote(id: String) async throws {
        try await client.delete("notes", queryItems: [URLQueryItem(name: "id", value: id)])
    }

    // MARK: - Simulado

    func listSimulados() async throws -> SimuladoListResponse {
        try await client.get("simulados")
    }

    func answerSimuladoQuestion(attemptId: String, body: AnswerSimuladoRequest) async throws -> AnswerSimuladoResponse {
        try await client.post("simulados/\(attemptId)/answer", body: body)
    }

    func finishSimulado(attemptId: String, timeTakenMs: Int64) async throws -> FinishSimuladoResponse {
        struct FinishBody: Encodable { let timeTakenMs: Int64 }
        return try await client.post("simulados/\(attemptId)/finish", body: FinishBody(timeTakenMs: timeTakenMs))
    }

    func explainQuestion(attemptId: String, questionId: String) async throws -> ExplainResponse {
        struct ExplainRequest: Encodable { let questionId: String }
        return try await client.post(
            "simulados/\(attemptId)/explain",
            body: ExplainRequest(questionId: questionId)
        )
    }

    func deleteSimulado(attemptId: String) async throws {
        try await client.delete("simulados/\(attemptId)")
    }

    func archiveSimulado(attemptId: String) async throws {
        struct ArchiveBody: Encodable { let status: String }
        let _: EmptyResponse = try await client.patch(
            "simulados/\(attemptId)",
            body: ArchiveBody(status: "archived")
        )
    }

    func getSimuladoDiagnostics(subject: String = "all", period: String = "30d") async throws -> SimuladoDiagnosticsResponse {
        try await client.get("simulados/diagnostics", queryItems: [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "period", value: period),
        ])
    }

    // MARK: - QBank

    /// Fetches QBank progress. When `disciplineSlugs` is non-empty, the response is
    /// scoped to the enrolled subset (Hero "X/Y questões das suas matérias") instead of
    /// the global catalog.
    func getQBankProgress(disciplineSlugs: [String] = []) async throws -> QBankProgressResponse {
        if disciplineSlugs.isEmpty {
            return try await client.get("qbank/progress")
        }
        let items = disciplineSlugs.map { URLQueryItem(name: "disciplineSlugs[]", value: $0) }
        return try await client.get("qbank/progress", queryItems: items)
    }

    func getQBankFilters() async throws -> QBankFiltersResponse {
        try await client.get("qbank/filters")
    }

    func createQBankSession(request: QBankCreateSessionRequest) async throws -> QBankSession {
        try await client.post("qbank/sessions", body: request)
    }

    func getQBankQuestion(id: Int) async throws -> QBankQuestionDetail {
        try await client.get("qbank/questions/\(id)")
    }

    func answerQBankQuestion(id: Int, request: QBankAnswerRequest) async throws -> QBankAnswerResponse {
        try await client.post("qbank/questions/\(id)/answer", body: request)
    }

    func getQBankSessions(limit: Int = 5) async throws -> QBankSessionsResponse {
        try await client.get("qbank/sessions", queryItems: [
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    func getQBankSessionDetail(id: String) async throws -> QBankSession {
        try await client.get("qbank/sessions/\(id)")
    }

    func finishQBankSession(id: String, correctCount: Int, totalAnswered: Int) async throws -> QBankSession {
        try await client.post("qbank/sessions/\(id)/finish", body: [
            "correctCount": correctCount,
            "totalAnswered": totalAnswered,
        ])
    }

    func getQBankQuestions(
        page: Int = 1,
        limit: Int = 1,
        institutionIds: [Int] = [],
        years: [Int] = [],
        difficulties: [String] = [],
        topicIds: [Int] = [],
        status: String? = nil,
        onlyResidence: Bool = false
    ) async throws -> QBankQuestionsResponse {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        // Backend expects array-style repeated params (name[]=a&name[]=b), not CSV.
        for id in institutionIds {
            items.append(URLQueryItem(name: "institutionIds[]", value: String(id)))
        }
        for year in years {
            items.append(URLQueryItem(name: "years[]", value: String(year)))
        }
        for d in difficulties {
            items.append(URLQueryItem(name: "difficulties[]", value: d))
        }
        for id in topicIds {
            items.append(URLQueryItem(name: "topicIds[]", value: String(id)))
        }
        if let status {
            items.append(URLQueryItem(name: "status", value: status))
        }
        if onlyResidence {
            items.append(URLQueryItem(name: "onlyResidence", value: "true"))
        }
        return try await client.get("qbank/questions", queryItems: items)
    }

    // MARK: - Portal (extract + sync)

    func fetchPortalBridgeScript() async throws -> String {
        try await client.downloadText("portal/bridge")
    }

    func extractPortalPages(pages: [PortalExtractRequestPagesInner], instanceUrl: String, university: String, sessionCookie: String? = nil) async throws -> PortalExtract200Response {
        let encodedPages = pages.map { page -> [String: String] in
            let encodedHtml = page.html.flatMap { html in
                Data(html.utf8).base64EncodedString()
            }
            var dict: [String: String] = ["type": page.type ?? "unknown"]
            if let html = encodedHtml { dict["html"] = html }
            if let linkText = page.linkText { dict["linkText"] = linkText }
            return dict
        }
        var body: [String: Any] = [
            "pages": encodedPages,
            "instanceUrl": instanceUrl,
            "university": university,
        ]
        if let sessionCookie { body["sessionCookie"] = sessionCookie }
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        let result: PortalExtract200Response = try await client.postRaw("portal/extract", body: jsonData, timeoutInterval: 120)
        return result
    }

    func getSyncProgress(syncId: String) async throws -> SyncProgressResponse {
        try await client.get("portal/sync-progress", queryItems: [.init(name: "syncId", value: syncId)])
    }

    func getPortalStatus() async throws -> PortalStatusResponse {
        try await client.get("portal/status")
    }

    func disconnectPortal() async throws {
        try await client.delete("portal/disconnect?portalType=mannesoft")
    }

    // MARK: - Push Notifications

    func registerPushToken(token: String) async throws {
        let _: EmptyResponse = try await client.post("push/register", body: PushTokenRequest(token: token, platform: "ios"))
    }

    func unregisterPushToken(token: String) async throws {
        try await client.delete("push/unregister")
    }

    // MARK: - Onboarding

    func postOnboarding(_ body: OnboardingPostRequest) async throws {
        let _: EmptyResponse = try await client.post("onboarding", body: body)
    }

    func requestUniversity(name: String, city: String, state: String) async throws {
        let body = UniversityRequestBody(name: name, city: city, state: state)
        let _: EmptyResponse = try await client.post("universities/request", body: body)
    }

    // MARK: - Study Plan

    func getStudyPlan() async throws -> StudyPlanResponse {
        try await client.get("estudos/plan")
    }

    // MARK: - Trabalhos (assignments)

    func getTrabalhos() async throws -> TrabalhosResponse {
        try await client.get("study/trabalhos")
    }

    // MARK: - Documents (PDFs synced from portal + manual uploads)

    func getDocuments(subjectId: String? = nil) async throws -> [VitaDocument] {
        var items: [URLQueryItem] = []
        if let subjectId { items.append(.init(name: "subjectId", value: subjectId)) }
        return try await client.get("documents", queryItems: items.isEmpty ? nil : items)
    }

    func dismissTrabalho(id: String) async throws {
        let _: EmptyResponse = try await client.patch("study/trabalhos/\(id)/dismiss")
    }

    // MARK: - Trabalho Generate & Submit

    struct TrabalhoGenerateRequest: Encodable {
        var prompt: String?
        var existingContent: String?
    }

    struct TrabalhoGenerateResponse: Decodable {
        let content: String
        let wordCount: Int
    }

    func generateTrabalho(id: String, prompt: String?, existingContent: String?) async throws -> TrabalhoGenerateResponse {
        return try await client.post(
            "study/trabalhos/\(id)/generate",
            body: TrabalhoGenerateRequest(prompt: prompt, existingContent: existingContent)
        )
    }

    struct TrabalhoSubmitRequest: Encodable {
        var content: String?
        var contentHtml: String?
    }

    struct TrabalhoSubmitResponse: Decodable {
        let success: Bool
        let canvasSubmissionId: Int?
        let submittedAt: String?
    }

    func submitTrabalho(id: String, content: String) async throws -> TrabalhoSubmitResponse {
        return try await client.post(
            "study/trabalhos/\(id)/submit",
            body: TrabalhoSubmitRequest(content: content)
        )
    }

    // ┌──────────────────────────────────────────────────────────────────┐
    // │  NO BACKEND YET — endpoints below have NO route.ts on server   │
    // │  Features calling these get 404 → catch → empty/error state    │
    // │  DO NOT add new functions here. Build the backend route first.  │
    // └──────────────────────────────────────────────────────────────────┘

    // MARK: - Canvas (NO BACKEND: canvas/courses, canvas/files, canvas/assignments, canvas/connect, canvas/sync)

    func getCanvasStatus() async throws -> CanvasStatusResponse {
        try await client.get("portal/status")
    }

    // Backend só serve portal/*. Estas funções viram NO-OPs até as features
    // que dependem delas (CourseDetail, Estudos files picker, Simulado files
    // picker, conectores via cookies) serem migradas/removidas. NÃO bater
    // na rede: hits 404 anteriores estavam disparando logout em loop.

    func connectCanvas(accessToken: String, instanceUrl: String) async throws -> CanvasConnectResponse {
        return CanvasConnectResponse(success: false, error: "canvas_connect_legacy_disabled")
    }

    func syncCanvas() async throws -> CanvasSyncResponse {
        return CanvasSyncResponse()
    }

    func disconnectCanvas() async throws {
        try await client.delete("portal/disconnect?portalType=canvas")
    }

    func getCourses() async throws -> CoursesResponse {
        return CoursesResponse()
    }

    func getFiles(courseId: String? = nil) async throws -> FilesResponse {
        return FilesResponse()
    }

    func getAssignments(courseId: String? = nil) async throws -> AssignmentsResponse {
        return AssignmentsResponse()
    }

    func downloadFileData(fileId: String) async throws -> Data {
        throw APIError.serverError(404)
    }

    // MARK: - Subjects (NO BACKEND: subjects, subjects/manual)

    func getSubjects(status: String? = nil) async throws -> SubjectsResponse {
        var items: [URLQueryItem] = []
        if let status { items.append(.init(name: "status", value: status)) }
        return try await client.get("subjects", queryItems: items.isEmpty ? nil : items)
    }

    func createManualSubject(name: String, difficulty: String? = nil) async throws -> AcademicSubject {
        struct Body: Encodable { let name: String; let difficulty: String? }
        return try await client.post("subjects/manual", body: Body(name: name, difficulty: difficulty))
    }

    func updateSubjectDifficulty(id: String, difficulty: String?) async throws -> AcademicSubject {
        struct Body: Encodable { let difficulty: String? }
        return try await client.patch("subjects/\(id)", body: Body(difficulty: difficulty))
    }

    /// Set or clear the user-ownable display name for a subject. Empty/nil
    /// resets to the portal-canonical name (UI falls back to canonicalName ?? name).
    /// See vitaai-web#170 phase A.
    func renameSubject(id: String, displayName: String?) async throws -> AcademicSubject {
        struct Body: Encodable { let displayName: String? }
        return try await client.patch("subjects/\(id)", body: Body(displayName: displayName))
    }

    // MARK: - Grades

    func getGradesCurrent() async throws -> GradesCurrentResponse {
        try await client.get("grades/current")
    }

    func getAgenda(from: String? = nil, to: String? = nil) async throws -> AgendaResponse {
        var path = "agenda"
        var params: [String] = []
        if let from { params.append("from=\(from)") }
        if let to { params.append("to=\(to)") }
        if !params.isEmpty { path += "?" + params.joined(separator: "&") }
        return try await client.get(path)
    }

    // MARK: - Google Calendar (NO BACKEND: google/calendar/*)

    func getGoogleCalendarStatus() async throws -> GoogleCalendarStatusResponse {
        try await client.get("google/calendar/status")
    }

    func syncGoogleCalendar() async throws -> GoogleCalendarSyncResponse {
        try await client.post("google/calendar/sync")
    }

    func disconnectGoogleCalendar() async throws {
        try await client.delete("google/calendar/connect")
    }

    // MARK: - Google Drive (NO BACKEND: google/drive/*)

    func getGoogleDriveStatus() async throws -> GoogleDriveStatusResponse {
        try await client.get("google/drive/status")
    }

    func syncGoogleDrive() async throws -> GoogleDriveSyncResponse {
        try await client.post("google/drive/sync")
    }

    func disconnectGoogleDrive() async throws {
        try await client.delete("google/drive/connect")
    }

    // MARK: - Billing (NO BACKEND: billing/status, billing/checkout, billing/verify/apple)

    func getBillingStatus() async throws -> BillingStatus {
        try await client.get("billing/status")
    }

    func getCheckoutUrl(plan: String = "pro") async throws -> CheckoutResponse {
        try await client.post("billing/checkout", body: CheckoutRequest(plan: plan))
    }

    func verifyAppleReceipt(transactionId: String, productId: String) async throws -> VerifyAppleReceiptResponse {
        try await client.post(
            "billing/verify/apple",
            body: VerifyAppleReceiptRequest(
                transactionId: transactionId,
                productId: productId,
                bundleId: "com.bymav.vitaai"
            )
        )
    }

    // MARK: - Crowd / Provas (NO BACKEND: crowd/*)

    func getCrowdProfessors() async throws -> [CrowdProfessor] {
        try await client.get("crowd/professors")
    }

    func getCrowdExams() async throws -> [CrowdExamEntry] {
        try await client.get("crowd/exams")
    }

    func getCrowdExamDetail(_ examId: String) async throws -> CrowdExamDetail {
        try await client.get("crowd/exams/\(examId)")
    }

    func getCrowdUploads() async throws -> [CrowdUploadRecord] {
        try await client.get("crowd/upload")
    }

    func uploadExamImages(_ images: [(Data, String, String)]) async throws -> CrowdUploadResponse {
        try await client.uploadMultipart("crowd/upload", images: images)
    }

    // MARK: - Portal connect

    /// POST /api/portal/connect — registers a portal session with the backend.
    func startVitaCrawl(cookies: String, instanceUrl: String) async throws -> VitaCrawlResponse {
        let body = try JSONSerialization.data(withJSONObject: [
            "sessionCookie": cookies,
            "instanceUrl": instanceUrl,
        ])
        return try await client.postRaw("portal/connect", body: body)
    }

    /// POST /api/portal/ingest — sends Canvas data fetched on-device to backend for LLM processing.
    /// Uses postRaw to bypass .convertToSnakeCase encoder (payload keys must stay camelCase).
    func ingestCanvasData(_ payload: CanvasIngestPayload) async throws -> CanvasIngestResponse {
        let body = try payload.toJSONData()
        NSLog("[VitaAPI] ingestCanvasData: %d bytes", body.count)
        return try await client.postRaw("portal/ingest", body: body, timeoutInterval: 120)
    }

    /// POST /api/portal/filter-files — LLM classifies which files are planos de ensino.
    /// Called BEFORE downloading PDFs to avoid downloading irrelevant files.
    func filterFiles(_ files: [[String: Any]]) async throws -> FilterFilesResponse {
        let body = try JSONSerialization.data(withJSONObject: ["files": files])
        return try await client.postRaw("portal/filter-files", body: body, timeoutInterval: 30)
    }

    func getExams(upcoming: Bool = false) async throws -> ExamsResponse {
        var items: [URLQueryItem] = []
        if upcoming { items.append(.init(name: "upcoming", value: "true")) }
        return try await client.get("exams", queryItems: items.isEmpty ? nil : items)
    }

    // MARK: - Professor Intelligence

    func getProfessorProfile(subjectId: String) async throws -> ProfessorProfileResponse {
        try await client.get("subjects/\(subjectId)/professor-profile")
    }

    func analyzeExam(fileData: Data, fileName: String, mimeType: String, subjectId: String) async throws -> ExamAnalyzeResponse {
        try await client.uploadExamMultipart(
            "exams/analyze",
            fileData: fileData,
            fileName: fileName,
            mimeType: mimeType,
            subjectId: subjectId
        )
    }

    func getMockupFlashcardsRecommended() async throws -> [FlashcardRecommended] {
        try await client.get("study/flashcards/recommended")
    }

    func generateSimulado(_ body: GenerateSimuladoRequest) async throws -> GenerateSimuladoResponse {
        try await client.post("simulados/generate", body: body)
    }

    func fetchAppConfig() async throws -> AppConfigResponse {
        try await client.get("config/app")
    }

    func getGamificationStats() async throws -> GamificationStatsResponse {
        try await client.get("activity/stats")
    }

    func getActivityFeed(limit: Int = 50, offset: Int = 0) async throws -> [ActivityFeedItem] {
        try await client.get("activity", queryItems: [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
        ])
    }

    func getNotificationPreferences() async throws -> NotificationPreferencesResponse {
        try await client.get("notifications/preferences")
    }

    // MARK: - Unified Integrations

    func getIntegrations() async throws -> IntegrationsResponse {
        try await client.get("integrations")
    }

    func startIntegrationOAuth(_ provider: String) async throws -> IntegrationOAuthResponse {
        try await client.get("integrations/\(provider)")
    }

    func disconnectIntegration(_ provider: String) async throws {
        try await client.delete("integrations/\(provider)")
    }


    // MARK: - WhatsApp

    func getWhatsAppStatus() async throws -> WhatsAppStatusResponse {
        try await client.get("whatsapp/status")
    }

    func linkWhatsApp(phone: String) async throws {
        let _: EmptyResponse = try await client.post("whatsapp/link", body: WhatsAppLinkRequest(phone: phone))
    }

    func verifyWhatsApp(code: String) async throws -> WhatsAppVerifyResponse {
        try await client.post("whatsapp/verify", body: WhatsAppVerifyRequest(code: code))
    }

    func unlinkWhatsApp() async throws {
        let _: EmptyResponse = try await client.post("whatsapp/unlink", body: EmptyBody())
    }

    func syncPushPreferences(_ prefs: PushPreferencesRequest) async throws {
        let _: EmptyResponse = try await client.post("push/preferences", body: prefs)
    }

    // MARK: - Account Deletion (LGPD / App Store §5.1.1(v))

    func deleteUserData() async throws -> DeleteUserDataResponse {
        try await client.request(
            "DELETE",
            path: "user/delete-data",
            body: DeleteUserDataRequest(confirmation: "DELETE")
        )
    }
}

// MARK: - Request Types

struct OnboardingPostRequest: Encodable {
    let moment: String
    let studyGoal: String
    var year: Int?
    var selectedSubjects: [String]?
    var subjectDifficulties: [String: String]?
}

struct UniversityRequestBody: Encodable {
    let name: String
    let city: String
    let state: String
}

struct WhatsAppLinkRequest: Encodable {
    let phone: String
}

struct WhatsAppVerifyRequest: Encodable {
    let code: String
}

struct WhatsAppStatusResponse: Decodable {
    let phone: String?
    let verified: Bool
}

struct WhatsAppVerifyResponse: Decodable {
    let ok: Bool
    let verified: Bool
}

struct EmptyBody: Encodable {}

// MARK: - Account Deletion types

private struct DeleteUserDataRequest: Encodable {
    let confirmation: String
}

struct DeleteUserDataResponse: Decodable, Sendable {
    let success: Bool
    let message: String?
}
