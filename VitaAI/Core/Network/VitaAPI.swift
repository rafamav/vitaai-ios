import Foundation

actor VitaAPI {
    private let client: HTTPClient

    init(client: HTTPClient) {
        self.client = client
    }

    // MARK: - Canvas Connection

    func getCanvasStatus() async throws -> CanvasStatusResponse {
        try await client.get("canvas/status")
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

    // MARK: - Portal Sync (universal — Vita crawl)

    /// Start Vita crawl: send cookies from WebView login, server-side Vita extracts everything
    func startVitaCrawl(cookies: String, instanceUrl: String) async throws -> VitaCrawlResponse {
        try await client.post("portal/vita-crawl", body: VitaCrawlRequest(cookies: cookies, instanceUrl: instanceUrl))
    }

    // MARK: - Canvas Data

    func getSyncProgress(syncId: String) async throws -> SyncProgressResponse {
        try await client.get("portal/sync-progress", queryItems: [.init(name: "syncId", value: syncId)])
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

    // MARK: - Profile

    func getProfile() async throws -> ProfileResponse {
        try await client.get("profile")
    }

    // MARK: - Universities (source of truth: database, 351 entries)

    func getUniversities(query: String? = nil) async throws -> UniversitiesResponse {
        var items: [URLQueryItem] = [.init(name: "limit", value: "500")]
        if let query, !query.isEmpty { items.append(.init(name: "q", value: query)) }
        return try await client.get("universities", queryItems: items)
    }

    // MARK: - Notifications

    func getNotifications() async throws -> NotificationsResponse {
        try await client.get("mockup/notifications")
    }

    // MARK: - Dashboard (unified endpoint — same as web)

    func getDashboard() async throws -> DashboardResponse {
        try await client.get("dashboard")
    }

    // MARK: - Server-Driven UI (SDUI)

    func getScreen(screenId: String) async throws -> ScreenResponse {
        try await client.get("screen/\(screenId)")
    }

    // MARK: - Progress

    func getProgress() async throws -> ProgressResponse {
        try await client.get("progress")
    }

    // MARK: - Exams

    func getExams(upcoming: Bool = false) async throws -> ExamsResponse {
        var items: [URLQueryItem] = []
        if upcoming { items.append(.init(name: "upcoming", value: "true")) }
        return try await client.get("exams", queryItems: items.isEmpty ? nil : items)
    }

    // MARK: - Study Events

    func getStudyEvents(from: String? = nil, to: String? = nil) async throws -> StudyEventsResponse {
        var items: [URLQueryItem] = []
        if let from { items.append(.init(name: "from", value: from)) }
        if let to { items.append(.init(name: "to", value: to)) }
        return try await client.get("study/events", queryItems: items.isEmpty ? nil : items)
    }

    // MARK: - Flashcards (mockup unified endpoint)

    func getMockupFlashcards(dueOnly: Bool = false) async throws -> [FlashcardDeckEntry] {
        var items: [URLQueryItem] = []
        if dueOnly { items.append(.init(name: "due", value: "true")) }
        return try await client.get("mockup/flashcards", queryItems: items.isEmpty ? nil : items)
    }

    func getMockupFlashcardsRecommended() async throws -> [FlashcardRecommended] {
        try await client.get("mockup/flashcards/recommended")
    }

    func generateFlashcards(discipline: String, count: Int = 30) async throws -> [FlashcardDeckEntry] {
        struct Body: Encodable { let discipline: String; let count: Int }
        let body = Body(discipline: discipline, count: count)
        if let decks: [FlashcardDeckEntry] = try? await client.post("mockup/flashcards/generate", body: body) {
            return decks
        }
        return try await client.post("study/flashcards/generate", body: body)
    }

    func generateFlashcardsAutoSeed() async throws -> [FlashcardDeckEntry] {
        struct Body: Encodable { let autoSeed: Bool }
        let body = Body(autoSeed: true)
        if let decks: [FlashcardDeckEntry] = try? await client.post("mockup/flashcards/generate", body: body) {
            return decks
        }
        return try await client.post("study/flashcards/generate", body: body)
    }

    // MARK: - Flashcards (legacy)

    func getFlashcardDecks(subjectId: String? = nil, dueOnly: Bool = false) async throws -> [FlashcardDeckEntry] {
        var items: [URLQueryItem] = []
        if let subjectId { items.append(.init(name: "subjectId", value: subjectId)) }
        if dueOnly { items.append(.init(name: "due", value: "true")) }
        return try await client.get("study/flashcards", queryItems: items.isEmpty ? nil : items)
    }

    func getFlashcardStats() async throws -> FlashcardStatsResponse {
        try await client.get("study/flashcards/stats")
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

    // MARK: - AI Conversations

    func getConversations() async throws -> [ConversationEntry] {
        try await client.get("ai/coach/conversations")
    }

    func getConversationMessages(conversationId: String) async throws -> ConversationMessagesResponse {
        try await client.get("ai/coach/conversations/\(conversationId)")
    }

    func sendFeedback(messageId: String, feedback: Int) async throws {
        let _: EmptyResponse = try await client.post("ai/coach/messages/\(messageId)/feedback", body: FeedbackRequest(feedback: feedback))
    }

    // MARK: - File Download

    /// Downloads raw bytes for a Canvas file. Used by EstudosViewModel to open PDFs in-app.
    func downloadFileData(fileId: String) async throws -> Data {
        try await client.downloadRaw("canvas/files/\(fileId)/download")
    }

    // MARK: - WebAluno

    func getWebalunoStatus() async throws -> WebalunoStatusResponse {
        try await client.get("webaluno/status")
    }

    func connectWebaluno(cpf: String, password: String, instanceUrl: String = "https://ac3949.mannesoftprime.com.br") async throws -> WebalunoConnectResponse {
        try await client.post("webaluno/connect", body: WebalunoConnectRequest(cpf: cpf, password: password, instanceUrl: instanceUrl))
    }

    func connectWebalunoWithSession(sessionCookie: String, instanceUrl: String = "https://ac3949.mannesoftprime.com.br") async throws -> WebalunoConnectResponse {
        try await client.post("webaluno/connect", body: WebalunoConnectRequest(sessionCookie: sessionCookie, instanceUrl: instanceUrl))
    }

    func syncWebaluno() async throws -> WebalunoSyncResponse {
        try await client.post("webaluno/sync")
    }

    func disconnectWebaluno() async throws {
        try await client.delete("webaluno/connect")
    }

    func getWebalunoGrades() async throws -> WebalunoGradesResponse {
        try await client.get("webaluno/grades")
    }

    func getWebalunoSchedule() async throws -> WebalunoScheduleResponse {
        try await client.get("webaluno/schedule")
    }

    // MARK: - Google Calendar

    func getGoogleCalendarStatus() async throws -> GoogleCalendarStatusResponse {
        try await client.get("google/calendar/status")
    }

    func syncGoogleCalendar() async throws -> GoogleCalendarSyncResponse {
        try await client.post("google/calendar/sync")
    }

    func disconnectGoogleCalendar() async throws {
        try await client.delete("google/calendar/connect")
    }

    // MARK: - Google Drive

    func getGoogleDriveStatus() async throws -> GoogleDriveStatusResponse {
        try await client.get("google/drive/status")
    }

    func syncGoogleDrive() async throws -> GoogleDriveSyncResponse {
        try await client.post("google/drive/sync")
    }

    func disconnectGoogleDrive() async throws {
        try await client.delete("google/drive/connect")
    }

    // MARK: - Transcricao (recordings list)

    func getTranscricoes() async throws -> [TranscricaoEntry] {
        try await client.get("study/transcricao")
    }

    // MARK: - OSCE

    func startOsceCase(specialty: String) async throws -> OsceStartResponse {
        try await client.post("ai/osce", body: OsceStartRequest(specialty: specialty))
    }

    // MARK: - Push Notifications

    func registerPushToken(token: String) async throws {
        let _: EmptyResponse = try await client.post("push/register", body: PushTokenRequest(token: token, platform: "ios"))
    }

    func unregisterPushToken(token: String) async throws {
        try await client.delete("push/unregister")
    }

    func syncPushPreferences(_ prefs: PushPreferencesRequest) async throws {
        let _: EmptyResponse = try await client.post("push/preferences", body: prefs)
    }

    // MARK: - Billing
    // Mirrors Android: MedCoachApi.getBillingStatus / getCheckoutUrl
    // Endpoints: GET billing/status, POST billing/checkout

    func getBillingStatus() async throws -> BillingStatus {
        try await client.get("billing/status")
    }

    func getCheckoutUrl(plan: String = "pro") async throws -> CheckoutResponse {
        try await client.post("billing/checkout", body: CheckoutRequest(plan: plan))
    }

    // MARK: - Simulado

    func listSimulados() async throws -> SimuladoListResponse {
        try await client.get("simulados")
    }

    func generateSimulado(_ body: GenerateSimuladoRequest) async throws -> GenerateSimuladoResponse {
        if let response: GenerateSimuladoResponse = try? await client.post("mockup/simulados/generate", body: body) {
            return response
        }
        return try await client.post("simulados/generate", body: body)
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

    /// Fetch questions list (page=1, limit=1) to get total available count for current filters.
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

    // MARK: - App Config (remote gamification config — single source of truth)

    func fetchAppConfig() async throws -> AppConfigResponse {
        try await client.get("config/app")
    }

    // MARK: - Activity / Gamification

    func logActivity(action: String, metadata: [String: String]? = nil) async throws -> LogActivityResponse {
        try await client.post("activity", body: LogActivityRequest(action: action, metadata: metadata))
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

    func getLeaderboard(period: String = "weekly", limit: Int = 20) async throws -> [LeaderboardEntry] {
        try await client.get("activity/leaderboard", queryItems: [
            URLQueryItem(name: "period", value: period),
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    /// Verify an Apple App Store transaction server-side after StoreKit 2 purchase.
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

    // MARK: - Crowd (Provas)
    // Mirrors Android: MedCoachApi crowd endpoints

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

    /// Uploads exam images as multipart/form-data.
    /// images: array of (Data, filename, mimeType) tuples.
    func uploadExamImages(_ images: [(Data, String, String)]) async throws -> CrowdUploadResponse {
        try await client.uploadMultipart("crowd/upload", images: images)
    }

    // MARK: - Study Plan (Planner — BYM-1152)

    func getStudyPlan() async throws -> StudyPlanResponse {
        try await client.get("estudos/plan")
    }

    // MARK: - Notes Cloud Sync
    // Endpoints: GET/POST/PATCH/DELETE /api/notes

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

    // MARK: - MindMap Cloud Sync
    // Endpoint: GET /api/study/mindmaps (read-only — server generates mindmaps via Studio)

    func getMindMaps(limit: Int = 50) async throws -> [RemoteMindMap] {
        try await client.get("study/mindmaps", queryItems: [
            URLQueryItem(name: "limit", value: String(limit)),
        ])
    }

    // MARK: - Onboarding

    func postOnboarding(_ body: OnboardingPostRequest) async throws {
        let _: EmptyResponse = try await client.post("onboarding", body: body)
    }

    func requestUniversity(name: String, city: String, state: String) async throws {
        let body = UniversityRequestBody(name: name, city: city, state: state)
        let _: EmptyResponse = try await client.post("universities/request", body: body)
    }
}

// MARK: - Onboarding Request

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

// UniversitiesResponse defined in OnboardingData.swift
