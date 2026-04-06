import Foundation

actor VitaAPI {
    private let client: HTTPClient

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

    func getNotifications() async throws -> NotificationsResponse {
        try await client.get("notifications")
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

    func getFlashcardDecks(subjectId: String? = nil, dueOnly: Bool = false) async throws -> [FlashcardDeckEntry] {
        var items: [URLQueryItem] = []
        if let subjectId { items.append(.init(name: "subjectId", value: subjectId)) }
        if dueOnly { items.append(.init(name: "due", value: "true")) }
        return try await client.get("study/flashcards", queryItems: items.isEmpty ? nil : items)
    }

    func getFlashcardStats() async throws -> FlashcardStatsResponse {
        try await client.get("study/flashcards/stats")
    }

    func generateFlashcards(discipline: String, count: Int = 30) async throws -> [FlashcardDeckEntry] {
        struct Body: Encodable { let discipline: String; let count: Int }
        return try await client.post("study/flashcards/generate", body: Body(discipline: discipline, count: count))
    }

    func generateFlashcardsAutoSeed() async throws -> [FlashcardDeckEntry] {
        struct Body: Encodable { let autoSeed: Bool }
        return try await client.post("study/flashcards/generate", body: Body(autoSeed: true))
    }

    func reviewFlashcard(cardId: String, rating: Int, responseTimeMs: Int64) async throws {
        let _: EmptyResponse = try await client.post(
            "study/flashcards/\(cardId)/review",
            body: FlashcardReviewRequest(rating: rating, responseTimeMs: responseTimeMs)
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

    func sendFeedback(messageId: String, feedback: Int) async throws {
        let _: EmptyResponse = try await client.post("ai/coach/messages/\(messageId)/feedback", body: FeedbackRequest(feedback: feedback))
    }

    // MARK: - OSCE

    func startOsceCase(specialty: String) async throws -> OsceStartResponse {
        try await client.post("ai/osce", body: OsceStartRequest(specialty: specialty))
    }

    // MARK: - Transcricao

    func getTranscricoes() async throws -> [TranscricaoEntry] {
        try await client.get("study/transcricao")
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

    func getQBankProgress() async throws -> QBankProgressResponse {
        try await client.get("qbank/progress")
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
        if !institutionIds.isEmpty {
            items.append(URLQueryItem(name: "institutionIds", value: institutionIds.map(String.init).joined(separator: ",")))
        }
        if !years.isEmpty {
            items.append(URLQueryItem(name: "years", value: years.map(String.init).joined(separator: ",")))
        }
        if !difficulties.isEmpty {
            items.append(URLQueryItem(name: "difficulties", value: difficulties.joined(separator: ",")))
        }
        if !topicIds.isEmpty {
            items.append(URLQueryItem(name: "topicIds", value: topicIds.map(String.init).joined(separator: ",")))
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

    func getWebalunoStatus() async throws -> WebalunoStatusResponse {
        try await client.get("portal/status")
    }

    func disconnectWebaluno() async throws {
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

    // ┌──────────────────────────────────────────────────────────────────┐
    // │  NO BACKEND YET — endpoints below have NO route.ts on server   │
    // │  Features calling these get 404 → catch → empty/error state    │
    // │  DO NOT add new functions here. Build the backend route first.  │
    // └──────────────────────────────────────────────────────────────────┘

    // MARK: - Canvas (NO BACKEND: canvas/courses, canvas/files, canvas/assignments, canvas/connect, canvas/sync)

    func getCanvasStatus() async throws -> CanvasStatusResponse {
        try await client.get("portal/status")
    }

    func connectCanvas(accessToken: String, instanceUrl: String = "https://ulbra.instructure.com") async throws -> CanvasConnectResponse {
        try await client.post("canvas/connect", body: CanvasConnectRequest(accessToken: accessToken, instanceUrl: instanceUrl))
    }

    func syncCanvas() async throws -> CanvasSyncResponse {
        try await client.post("canvas/sync")
    }

    func disconnectCanvas() async throws {
        try await client.delete("canvas/connect")
    }

    func getCourses() async throws -> CoursesResponse {
        try await client.get("canvas/courses")
    }

    func getFiles(courseId: String? = nil) async throws -> FilesResponse {
        var items: [URLQueryItem] = []
        if let courseId { items.append(.init(name: "courseId", value: courseId)) }
        return try await client.get("canvas/files", queryItems: items.isEmpty ? nil : items)
    }

    func getAssignments(courseId: String? = nil) async throws -> AssignmentsResponse {
        var items: [URLQueryItem] = []
        if let courseId { items.append(.init(name: "courseId", value: courseId)) }
        return try await client.get("canvas/assignments", queryItems: items.isEmpty ? nil : items)
    }

    func downloadFileData(fileId: String) async throws -> Data {
        try await client.downloadRaw("canvas/files/\(fileId)/download")
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

    // MARK: - WebAluno data (NO BACKEND: webaluno/connect, webaluno/sync, webaluno/grades, webaluno/schedule)

    func connectWebaluno(cpf: String, password: String, instanceUrl: String = "https://ac3949.mannesoftprime.com.br") async throws -> WebalunoConnectResponse {
        try await client.post("webaluno/connect", body: WebalunoConnectRequest(cpf: cpf, password: password, instanceUrl: instanceUrl))
    }

    func connectWebalunoWithSession(sessionCookie: String, instanceUrl: String = "https://ac3949.mannesoftprime.com.br") async throws -> WebalunoConnectResponse {
        try await client.post("webaluno/connect", body: WebalunoConnectRequest(sessionCookie: sessionCookie, instanceUrl: instanceUrl))
    }

    func syncWebaluno() async throws -> WebalunoSyncResponse {
        try await client.post("webaluno/sync")
    }

    func getWebalunoGrades() async throws -> WebalunoGradesResponse {
        try await client.get("webaluno/grades")
    }

    func getWebalunoSchedule() async throws -> WebalunoScheduleResponse {
        try await client.get("webaluno/schedule")
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

    func getStudyEvents(from: String? = nil, to: String? = nil) async throws -> StudyEventsResponse {
        var items: [URLQueryItem] = []
        if let from { items.append(.init(name: "from", value: from)) }
        if let to { items.append(.init(name: "to", value: to)) }
        return try await client.get("study/events", queryItems: items.isEmpty ? nil : items)
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

    func syncPushPreferences(_ prefs: PushPreferencesRequest) async throws {
        let _: EmptyResponse = try await client.post("push/preferences", body: prefs)
    }
}

// MARK: - Request Types

struct OnboardingPostRequest: Encodable {
    let moment: String
    var year: Int?
    var selectedSubjects: [String]?
    var subjectDifficulties: [String: String]?
}

struct UniversityRequestBody: Encodable {
    let name: String
    let city: String
    let state: String
}
