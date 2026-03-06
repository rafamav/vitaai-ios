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

    // MARK: - Canvas Data

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

    // MARK: - Flashcards

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
        try await client.get("ai/conversations")
    }

    func getConversationMessages(conversationId: String) async throws -> ConversationMessagesResponse {
        try await client.get("ai/conversations/\(conversationId)/messages")
    }

    func sendFeedback(messageId: String, feedback: Int) async throws {
        let _: EmptyResponse = try await client.post("ai/messages/\(messageId)/feedback", body: FeedbackRequest(feedback: feedback))
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

    func getWebalunoGrades() async throws -> WebalunoGradesResponse {
        try await client.get("webaluno/grades")
    }

    func getWebalunoSchedule() async throws -> WebalunoScheduleResponse {
        try await client.get("webaluno/schedule")
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

    func getPushPreferences() async throws -> PushPreferences {
        try await client.get("push/preferences")
    }

    func updatePushPreferences(_ prefs: PushPreferences) async throws {
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
        try await client.post("simulados/generate", body: body)
    }

    func answerSimuladoQuestion(attemptId: String, body: AnswerSimuladoRequest) async throws -> AnswerSimuladoResponse {
        try await client.post("simulados/\(attemptId)/answer", body: body)
    }

    func finishSimulado(attemptId: String, timeTakenMs: Int64) async throws -> FinishSimuladoResponse {
        struct FinishBody: Encodable { let timeTakenMs: Int64 }
        return try await client.post("simulados/\(attemptId)/finish", body: FinishBody(timeTakenMs: timeTakenMs))
    }

    func explainQuestion(attemptId: String, questionId: String) async throws -> ExplainResponse {
        struct ExplainBody: Encodable { let questionId: String }
        return try await client.post("simulados/\(attemptId)/explain", body: ExplainBody(questionId: questionId))
    }

    func deleteSimulado(attemptId: String) async throws {
        try await client.delete("simulados/\(attemptId)")
    }

    func archiveSimulado(attemptId: String) async throws {
        struct ArchiveBody: Encodable { let status: String }
        try await client.patch("simulados/\(attemptId)", body: ArchiveBody(status: "archived"))
    }

    func getSimuladoDiagnostics(subject: String = "all", period: String = "30d") async throws -> SimuladoDiagnosticsResponse {
        try await client.get("simulados/diagnostics", queryItems: [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "period", value: period),
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
}
