import Foundation

// MARK: - Domain Types

struct TranscriptionFlashcard: Identifiable, Sendable {
    let id: String
    let front: String
    let back: String
}

/// A saved transcription entry returned by GET /api/study/transcrição
struct TranscricaoEntry: Identifiable {
    var id: String = UUID().uuidString
    var title: String = ""
    var duration: String?
    var detail: String?
    var date: String?
    var status: String? // "transcribed", "pending", "completed"
    var discipline: String?
    var fileName: String?
    var fileSize: Int?
    var createdAt: String?
    /// User-toggled favorite (via PATCH studio/sources/:id). Optional —
    /// backend pode não enviar em respostas legadas; client trata como false.
    var favorite: Bool?
    /// Custom user folder ID (studio_folders.id). Quando set, gravação
    /// aparece dentro daquela pasta no header chip.
    var folderId: String?

    var isTranscribed: Bool {
        let s = status?.lowercased() ?? ""
        return s == "transcribed" || s == "completed" || s == "ready"
    }

    /// Parse createdAt ISO string into Date for grouping
    var parsedDate: Date? {
        guard let str = createdAt ?? date else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: str) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: str)
    }

    /// Human-readable relative date
    var relativeDate: String {
        guard let d = parsedDate else { return date ?? "" }
        let cal = Calendar.current
        if cal.isDateInToday(d) {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            return "Hoje \(fmt.string(from: d))"
        }
        if cal.isDateInYesterday(d) { return "Ontem" }
        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM"
        return fmt.string(from: d)
    }

    /// File size formatted
    var formattedSize: String? {
        guard let s = fileSize, s > 0 else { return nil }
        if s < 1024 * 1024 {
            return "\(s / 1024) KB"
        }
        return String(format: "%.1f MB", Double(s) / 1_048_576.0)
    }
}

extension TranscricaoEntry: Decodable {
    // Use String-based keys to bypass convertFromSnakeCase interference
    private struct RawKey: CodingKey {
        var stringValue: String
        var intValue: Int?
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: RawKey.self)
        id = (try? c.decode(String.self, forKey: RawKey(stringValue: "id")!)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: RawKey(stringValue: "title")!)) ?? ""
        duration = try? c.decode(String.self, forKey: RawKey(stringValue: "duration")!)
        detail = try? c.decode(String.self, forKey: RawKey(stringValue: "detail")!)
        date = try? c.decode(String.self, forKey: RawKey(stringValue: "date")!)
        status = try? c.decode(String.self, forKey: RawKey(stringValue: "status")!)
        discipline = try? c.decode(String.self, forKey: RawKey(stringValue: "discipline")!)
        fileName = try? c.decode(String.self, forKey: RawKey(stringValue: "fileName")!)
        fileSize = try? c.decode(Int.self, forKey: RawKey(stringValue: "fileSize")!)
        createdAt = try? c.decode(String.self, forKey: RawKey(stringValue: "createdAt")!)
        favorite = try? c.decode(Bool.self, forKey: RawKey(stringValue: "favorite")!)
        folderId = try? c.decode(String.self, forKey: RawKey(stringValue: "folderId")!)

        // Debug: dump all keys in the JSON to find what's actually there
        let allKeys = c.allKeys.map { $0.stringValue }
        NSLog("[TranscricaoEntry] JSON keys: %@, status=%@, isTranscribed=%d", allKeys.joined(separator: ","), status ?? "NIL", isTranscribed ? 1 : 0)
    }
}

// MARK: - Studio Source Detail (GET /api/studio/sources/:id)

struct StudioSourceDetail: Decodable {
    let id: String
    let type: String
    let title: String
    let status: String
    let metadata: StudioSourceMetadata?
    let errorMessage: String?
    let createdAt: String
    let updatedAt: String
    let chunks: [StudioChunk]?
}

struct StudioSourceMetadata: Decodable {
    let durationSeconds: Double?
    let durationLabel: String?
    let fileName: String?
    let fileSize: Int?
    let whisperModel: String?
    let segments: [WhisperSegment]?
    let audioFileId: String?
    let audioR2Key: String?
    /// Short-lived presigned R2 GET URL for the audio file. Backend attaches
    /// it on GET /api/studio/sources/:id so AVPlayer can stream directly.
    let audioUrl: String?
    /// User-set discipline (portal) via PATCH.
    let disciplineSlug: String?
    /// User-set custom folder (studio_folders) via PATCH.
    let folderId: String?
    /// User-toggled favorite flag via PATCH.
    let favorite: Bool?

    enum CodingKeys: String, CodingKey {
        case duration, durationSeconds, fileName, fileSize, whisperModel, segments, audioFileId, audioR2Key, audioUrl, disciplineSlug, folderId, favorite
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        fileName = try c.decodeIfPresent(String.self, forKey: .fileName)
        fileSize = try c.decodeIfPresent(Int.self, forKey: .fileSize)
        whisperModel = try c.decodeIfPresent(String.self, forKey: .whisperModel)
        segments = try c.decodeIfPresent([WhisperSegment].self, forKey: .segments)
        audioFileId = try c.decodeIfPresent(String.self, forKey: .audioFileId)
        audioR2Key = try c.decodeIfPresent(String.self, forKey: .audioR2Key)
        audioUrl = try c.decodeIfPresent(String.self, forKey: .audioUrl)
        disciplineSlug = try c.decodeIfPresent(String.self, forKey: .disciplineSlug)
        folderId = try c.decodeIfPresent(String.self, forKey: .folderId)
        favorite = try c.decodeIfPresent(Bool.self, forKey: .favorite)

        // `duration` is the legacy key and may be Double (seconds) or String
        // ("~60min"). The new backend also writes `durationSeconds` directly —
        // we prefer that when present.
        let rawDurationSeconds = try? c.decodeIfPresent(Double.self, forKey: .durationSeconds)
        let rawDurationAsDouble = try? c.decodeIfPresent(Double.self, forKey: .duration)
        let rawDurationAsString = try? c.decodeIfPresent(String.self, forKey: .duration)
        if let d = rawDurationSeconds.flatMap({ $0 }) {
            durationSeconds = d
            durationLabel = nil
        } else if let d = rawDurationAsDouble.flatMap({ $0 }) {
            durationSeconds = d
            durationLabel = nil
        } else if let s = rawDurationAsString.flatMap({ $0 }) {
            durationSeconds = nil
            durationLabel = s
        } else {
            durationSeconds = nil
            durationLabel = nil
        }
    }
}

struct WhisperSegment: Decodable {
    let start: Double
    let end: Double
    let text: String
    let words: [WhisperWord]?
}

struct WhisperWord: Decodable, Identifiable {
    var id: String { "\(start)-\(word)" }
    let word: String
    let start: Double
    let end: Double
}

struct StudioChunk: Decodable, Identifiable {
    var id: Int { chunkIndex }
    let chunkIndex: Int
    let content: String
}

// MARK: - Studio Output (GET /api/studio/outputs?sourceId=X)

struct StudioOutputsResponse: Decodable {
    let outputs: [StudioOutput]
}

struct StudioOutput: Decodable, Identifiable {
    let id: String
    let outputType: String // "summary", "flashcards", "questions", "concepts", "mindmap"
    let title: String
    let sourceId: String?
    let createdAt: String?
    let status: String
    let content: StudioOutputContent?

    private enum CodingKeys: String, CodingKey {
        case id, outputType, type, title, sourceId, createdAt, status, content
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        // GET returns "outputType", POST generate returns "type"
        outputType = (try? c.decode(String.self, forKey: .outputType))
            ?? (try? c.decode(String.self, forKey: .type))
            ?? "unknown"
        sourceId = try? c.decode(String.self, forKey: .sourceId)
        createdAt = try? c.decode(String.self, forKey: .createdAt)
        status = (try? c.decode(String.self, forKey: .status)) ?? "ready"
        content = try? c.decode(StudioOutputContent.self, forKey: .content)
        // Title: top-level or from content.title
        title = (try? c.decode(String.self, forKey: .title))
            ?? content?.title
            ?? outputType
    }
}

struct StudioOutputContent: Decodable {
    let title: String?
    let markdown: String?
    let flashcards: [StudioFlashcard]?
    let questions: [StudioQuestion]?
}

struct StudioFlashcard: Decodable, Identifiable {
    var id: String { front }
    let front: String
    let back: String
}

struct StudioQuestion: Decodable, Identifiable {
    var id: String { question }
    let question: String
    let answer: String?
}

enum TranscricaoSSEEvent: Sendable {
    case progress(stage: String, percent: Int)
    /// Upload bytes pro R2 avançando — `pct` 0-100. Emitido antes de
    /// `sourceCreated`. UI mostra "Enviando 45%" no card local.
    case uploadProgress(pct: Int)
    /// Emitted as soon as the server seeds / finds the `studio_sources` row
    /// for this recording. The ViewModel uses this id to start a parallel
    /// poll against GET /api/studio/sources/:id so if the SSE stream stalls
    /// we still observe the real persisted state.
    case sourceCreated(id: String)
    case complete(transcript: String, summary: String, flashcards: [TranscriptionFlashcard])
    case error(message: String)
}

// MARK: - TranscricaoClient
//
// Actor-based SSE client for audio upload + streaming transcription pipeline.
// Mirrors Android's TranscricaoSseClient pattern: multipart/form-data POST -> SSE response.
//
// Endpoint: POST /ai/transcribe
// Events:  { type: "progress", stage, percent }
//          { type: "complete", transcript, summary, flashcards }
//          { type: "error", message }

actor TranscricaoClient {
    private let tokenStore: TokenStore
    private let session: URLSession
    private let tokenRefresher: TokenRefresher
    private var onUnauthorized: (@Sendable @MainActor () -> Void)?

    private static let maxRetries = 3

    init(tokenStore: TokenStore, tokenRefresher: TokenRefresher? = nil, session: URLSession? = nil) {
        self.tokenStore = tokenStore
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 300
            self.session = URLSession(configuration: config)
        }
        self.tokenRefresher = tokenRefresher ?? TokenRefresher(tokenStore: tokenStore)
    }

    func setOnUnauthorized(_ handler: @escaping @Sendable @MainActor () -> Void) {
        self.onUnauthorized = handler
    }

    // MARK: - Upload + Stream (R2 direct upload)

    /// Uploads audio via 3-step R2 flow + returns an SSE stream with progress
    /// and completion events.
    ///
    /// Flow (gold-standard, avoids buffering the file on the app server):
    ///   1. `POST /api/audio/upload-url` → `{r2Key, sourceId, presignedPutUrl}`
    ///   2. `PUT  <presignedPutUrl>` with the m4a body — goes direct to CF edge
    ///   3. `POST /api/ai/transcribe` with JSON `{r2Key, sourceId, language, discipline}`
    ///      returns SSE progress → transcript → summary → flashcards
    ///
    /// If step 1 or 2 fails, falls back to the legacy multipart POST so older
    /// backends (and non-R2 dev envs) keep working.
    func uploadAndStream(
        fileURL: URL,
        language: String = "pt",
        discipline: String? = nil,
        liveTranscript: String = "",
        durationSeconds: Int = 0
    ) -> AsyncThrowingStream<TranscricaoSSEEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let fileData = try? Data(contentsOf: fileURL) else {
                        continuation.finish(throwing: APIError.noData)
                        return
                    }
                    let fileName = fileURL.lastPathComponent

                    // Try R2 flow first
                    let t0 = Date()
                    if let uploadInfo = try? await self.requestUploadUrl(
                        fileName: fileName,
                        discipline: discipline,
                        language: language,
                        fileSize: fileData.count
                    ) {
                        let t1 = Date()
                        NSLog("[TranscricaoClient] TIMING presign_ms=%d size_kb=%d hasLive=%d",
                              Int(t1.timeIntervalSince(t0) * 1000),
                              fileData.count / 1024,
                              liveTranscript.isEmpty ? 0 : 1)
                        do {
                            try await self.putToR2(
                                presignedUrl: uploadInfo.presignedPutUrl,
                                data: fileData,
                                onProgress: { pct in
                                    continuation.yield(.uploadProgress(pct: pct))
                                }
                            )
                            let t2 = Date()
                            NSLog("[TranscricaoClient] TIMING r2_put_ms=%d",
                                  Int(t2.timeIntervalSince(t1) * 1000))
                            // Fast-path: live já transcreveu — skipa Whisper batch.
                            if !liveTranscript.isEmpty {
                                try await self.persistFromLive(
                                    sourceId: uploadInfo.sourceId,
                                    r2Key: uploadInfo.r2Key,
                                    transcript: liveTranscript,
                                    language: language,
                                    discipline: discipline,
                                    durationSeconds: durationSeconds,
                                    fileSize: fileData.count,
                                    continuation: continuation
                                )
                                let t3 = Date()
                                NSLog("[TranscricaoClient] TIMING fromlive_ms=%d total_ms=%d",
                                      Int(t3.timeIntervalSince(t2) * 1000),
                                      Int(t3.timeIntervalSince(t0) * 1000))
                                return
                            }
                            // Sem live: pipeline completo.
                            try await self.streamTranscribeJson(
                                r2Key: uploadInfo.r2Key,
                                sourceId: uploadInfo.sourceId,
                                language: language,
                                discipline: discipline,
                                continuation: continuation
                            )
                            return
                        } catch {
                            // R2 PUT or transcribe call failed — fall through to multipart fallback
                            NSLog("[TranscricaoClient] R2 flow failed, falling back to multipart: %@", "\(error)")
                        }
                    }

                    // Legacy multipart fallback (older backend, R2 not configured, etc.)
                    try await self.streamTranscribeMultipart(
                        fileData: fileData,
                        language: language,
                        discipline: discipline,
                        continuation: continuation
                    )
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - R2 flow helpers

    private struct AudioUploadInfo: Decodable {
        let sourceId: String
        let r2Key: String
        let presignedPutUrl: String
        let expiresAt: String
    }

    /// Step 1: ask the server for a pre-signed PUT URL.
    private func requestUploadUrl(
        fileName: String,
        discipline: String?,
        language: String,
        fileSize: Int
    ) async throws -> AudioUploadInfo {
        guard let url = URL(string: AppConfig.apiBaseURL + "/audio/upload-url") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await self.tokenStore.token {
            request.setValue("__Secure-better-auth.session_token=\(token)", forHTTPHeaderField: "Cookie")
        }
        var body: [String: Any] = [
            "fileName": fileName,
            "language": language,
            "contentType": "audio/m4a",
            "durationSeconds": 0,
        ]
        if let discipline = discipline, !discipline.isEmpty, discipline != "Auto-detectar" {
            body["discipline"] = discipline
        }
        body["fileSize"] = fileSize
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        let (data, response) = try await self.session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.serverError(code)
        }
        return try JSONDecoder().decode(AudioUploadInfo.self, from: data)
    }

    /// Step 2: PUT the m4a bytes straight to R2. Uses the plain URLSession
    /// (not the auth'd session) because the presigned URL carries the auth
    /// in its query string and CF would reject extra headers.
    private func putToR2(
        presignedUrl: String,
        data: Data,
        onProgress: (@Sendable (Int) -> Void)? = nil
    ) async throws {
        guard let url = URL(string: presignedUrl) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300
        let delegate = R2UploadProgressDelegate(onProgress: onProgress)
        let putSession = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { putSession.finishTasksAndInvalidate() }
        let (_, response) = try await putSession.upload(for: request, from: data)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.serverError(code)
        }
    }

    /// Fast-path: POST /api/ai/transcribe/from-live com transcript pronto.
    /// Emite sourceCreated + complete sintéticos.
    private func persistFromLive(
        sourceId: String,
        r2Key: String,
        transcript: String,
        language: String,
        discipline: String?,
        durationSeconds: Int,
        fileSize: Int,
        continuation: AsyncThrowingStream<TranscricaoSSEEvent, Error>.Continuation
    ) async throws {
        guard let url = URL(string: AppConfig.apiBaseURL + "/ai/transcribe/from-live") else {
            throw APIError.invalidURL
        }
        var body: [String: Any] = [
            "sourceId": sourceId,
            "r2Key": r2Key,
            "transcript": transcript,
            "language": language,
        ]
        if let discipline, !discipline.isEmpty, discipline != "Auto-detectar" {
            body["discipline"] = discipline
        }
        if durationSeconds > 0 { body["durationSeconds"] = durationSeconds }
        if fileSize > 0 { body["fileSize"] = fileSize }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await self.tokenStore.token {
            request.setValue("__Secure-better-auth.session_token=\(token)", forHTTPHeaderField: "Cookie")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 30

        continuation.yield(.sourceCreated(id: sourceId))
        let (_, response) = try await self.session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            continuation.yield(.error(message: "Falha ao salvar (\(code))"))
            continuation.finish()
            return
        }
        continuation.yield(.complete(transcript: transcript, summary: "", flashcards: []))
        continuation.finish()
    }

    /// Step 3: trigger the Whisper+LLM pipeline with the R2 key.
    private func streamTranscribeJson(
        r2Key: String,
        sourceId: String,
        language: String,
        discipline: String?,
        continuation: AsyncThrowingStream<TranscricaoSSEEvent, Error>.Continuation
    ) async throws {
        guard let url = URL(string: AppConfig.apiBaseURL + "/ai/transcribe") else {
            throw APIError.invalidURL
        }
        var body: [String: Any] = [
            "r2Key": r2Key,
            "sourceId": sourceId,
            "language": language,
        ]
        if let discipline = discipline, !discipline.isEmpty, discipline != "Auto-detectar" {
            body["discipline"] = discipline
        }
        let jsonBody = try JSONSerialization.data(withJSONObject: body)

        var didAttemptRefresh = false
        for attempt in 0..<Self.maxRetries {
            if attempt > 0 {
                let delay = UInt64(pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.httpBody = jsonBody
            request.timeoutInterval = 300
            if let token = await self.tokenStore.token {
                request.setValue("__Secure-better-auth.session_token=\(token)", forHTTPHeaderField: "Cookie")
            }

            let bytes: URLSession.AsyncBytes
            let response: URLResponse
            do {
                (bytes, response) = try await self.session.bytes(for: request)
            } catch {
                if attempt == Self.maxRetries - 1 { throw APIError.networkError(error) }
                continue
            }
            guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

            if http.statusCode == 401 {
                if !didAttemptRefresh {
                    didAttemptRefresh = true
                    if await self.tokenRefresher.refreshSession() { continue }
                }
                if let handler = self.onUnauthorized { await handler() }
                throw APIError.unauthorized
            }
            if !(200...299).contains(http.statusCode) {
                if (500...599).contains(http.statusCode) && attempt < Self.maxRetries - 1 { continue }
                throw APIError.serverError(http.statusCode)
            }

            try await self.consumeSSE(bytes: bytes, continuation: continuation)
            return
        }
        throw APIError.unknown
    }

    /// Legacy multipart path — kept for older backends and local dev without R2.
    private func streamTranscribeMultipart(
        fileData: Data,
        language: String,
        discipline: String?,
        continuation: AsyncThrowingStream<TranscricaoSSEEvent, Error>.Continuation
    ) async throws {
        let boundary = "VitaBoundary-\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        var body = Data()
        body.append(formPart(boundary: boundary, name: "audio", filename: "audio.m4a",
                             contentType: "audio/m4a", data: fileData))
        body.append(formTextPart(boundary: boundary, name: "language", value: language))
        if let discipline = discipline, !discipline.isEmpty, discipline != "Auto-detectar" {
            body.append(formTextPart(boundary: boundary, name: "discipline", value: discipline))
        }
        body.append("--\(boundary)--\r\n".utf8Data)

        guard let url = URL(string: AppConfig.apiBaseURL + "/ai/transcribe") else {
            throw APIError.invalidURL
        }
        var didAttemptRefresh = false
        for attempt in 0..<Self.maxRetries {
            if attempt > 0 {
                let delay = UInt64(pow(2.0, Double(attempt - 1)) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.httpBody = body
            request.timeoutInterval = 300
            if let token = await self.tokenStore.token {
                request.setValue("__Secure-better-auth.session_token=\(token)", forHTTPHeaderField: "Cookie")
            }

            let bytes: URLSession.AsyncBytes
            let response: URLResponse
            do {
                (bytes, response) = try await self.session.bytes(for: request)
            } catch {
                if attempt == Self.maxRetries - 1 { throw APIError.networkError(error) }
                continue
            }
            guard let http = response as? HTTPURLResponse else { throw APIError.unknown }

            if http.statusCode == 401 {
                if !didAttemptRefresh {
                    didAttemptRefresh = true
                    if await self.tokenRefresher.refreshSession() { continue }
                }
                if let handler = self.onUnauthorized { await handler() }
                throw APIError.unauthorized
            }
            if !(200...299).contains(http.statusCode) {
                if (500...599).contains(http.statusCode) && attempt < Self.maxRetries - 1 { continue }
                throw APIError.serverError(http.statusCode)
            }

            try await self.consumeSSE(bytes: bytes, continuation: continuation)
            return
        }
        throw APIError.unknown
    }

    /// Shared SSE consumer — reads `data:` frames. The backend emits
    /// `data: {"type":"...", ...}\n\n` without an `event:` prefix, so the
    /// discriminator lives inside the JSON payload.
    private func consumeSSE(
        bytes: URLSession.AsyncBytes,
        continuation: AsyncThrowingStream<TranscricaoSSEEvent, Error>.Continuation
    ) async throws {
        var dataLines: [String] = []
        var accumulatedTranscript = ""
        var accumulatedSummary = ""
        var accumulatedCards: [TranscriptionFlashcard] = []
        for try await line in bytes.lines {
            if line.hasPrefix("data:") {
                let content = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                dataLines.append(content)
            } else if line.isEmpty, !dataLines.isEmpty {
                let rawJSON = dataLines.joined(separator: "\n")
                dataLines = []
                NSLog("[TranscricaoSSE] frame: %@", String(rawJSON.prefix(200)))
                let parsed = Self.parseFrame(
                    rawJSON: rawJSON,
                    transcript: &accumulatedTranscript,
                    summary: &accumulatedSummary,
                    cards: &accumulatedCards
                )
                switch parsed {
                case .yield(let event):
                    NSLog("[TranscricaoSSE] yield: %@", "\(event)")
                    continuation.yield(event)
                case .finishOK:
                    NSLog("[TranscricaoSSE] finishOK transcript=%d chars", accumulatedTranscript.count)
                    continuation.yield(.complete(
                        transcript: accumulatedTranscript,
                        summary: accumulatedSummary,
                        flashcards: accumulatedCards
                    ))
                    continuation.finish()
                    return
                case .finishError(let msg):
                    NSLog("[TranscricaoSSE] finishError: %@", msg)
                    continuation.yield(.error(message: msg))
                    continuation.finish()
                    return
                case .ignore:
                    break
                }
            }
        }
        // Stream closed without message_stop → treat as best-effort complete.
        if !accumulatedTranscript.isEmpty {
            continuation.yield(.complete(
                transcript: accumulatedTranscript,
                summary: accumulatedSummary,
                flashcards: accumulatedCards
            ))
        }
        continuation.finish()
    }

    // MARK: - Multipart Builder

    private func formPart(boundary: String, name: String, filename: String,
                          contentType: String, data: Data) -> Data {
        var part = Data()
        part.append("--\(boundary)\r\n".utf8Data)
        part.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".utf8Data)
        part.append("Content-Type: \(contentType)\r\n\r\n".utf8Data)
        part.append(data)
        part.append("\r\n".utf8Data)
        return part
    }

    private func formTextPart(boundary: String, name: String, value: String) -> Data {
        var part = Data()
        part.append("--\(boundary)\r\n".utf8Data)
        part.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".utf8Data)
        part.append(value.utf8Data)
        part.append("\r\n".utf8Data)
        return part
    }

    // MARK: - SSE Parser

    /// Internal parse result. Backend streams individual frames
    /// (progress/transcript/summary/flashcards/source_created/message_stop/error)
    /// and finishes with `message_stop`; we accumulate partials here and emit
    /// `.complete` once we see `message_stop`.
    private enum ParsedFrame {
        case yield(TranscricaoSSEEvent)
        case finishOK
        case finishError(String)
        case ignore
    }

    private static func parseFrame(
        rawJSON: String,
        transcript: inout String,
        summary: inout String,
        cards: inout [TranscriptionFlashcard]
    ) -> ParsedFrame {
        guard let jsonData = rawJSON.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else { return .ignore }
        let type = (json["type"] as? String) ?? ""

        switch type {
        case "progress":
            return .yield(.progress(
                stage: json["stage"] as? String ?? "",
                percent: json["percent"] as? Int ?? 0
            ))
        case "transcript":
            transcript = (json["content"] as? String) ?? transcript
            return .ignore
        case "summary":
            summary = (json["content"] as? String) ?? summary
            return .ignore
        case "flashcards":
            let rawCards = json["flashcards"] as? [[String: String]] ?? []
            cards = rawCards.enumerated().map { idx, card in
                TranscriptionFlashcard(
                    id: card["id"] ?? "\(idx)",
                    front: card["front"] ?? "",
                    back: card["back"] ?? ""
                )
            }
            return .ignore
        case "source_created":
            if let id = json["sourceId"] as? String {
                return .yield(.sourceCreated(id: id))
            }
            return .ignore
        case "message_stop":
            return .finishOK
        case "error":
            let msg = (json["content"] as? String)
                ?? (json["message"] as? String)
                ?? "Erro desconhecido"
            return .finishError(msg)
        default:
            return .ignore
        }
    }
}

// MARK: - Helper

private extension String {
    var utf8Data: Data { data(using: .utf8) ?? Data() }
}

// MARK: - R2 Upload Progress Delegate

/// URLSessionTaskDelegate que intercepta `didSendBodyData` do PUT R2 e
/// traduz bytes enviados em % (0-100). Callback roda em background queue.
final class R2UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    let onProgress: (@Sendable (Int) -> Void)?
    private var lastPct: Int = -1

    init(onProgress: (@Sendable (Int) -> Void)?) {
        self.onProgress = onProgress
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64
    ) {
        guard totalBytesExpectedToSend > 0 else { return }
        let pct = Int(Double(totalBytesSent) / Double(totalBytesExpectedToSend) * 100.0)
        if pct != lastPct {
            lastPct = pct
            onProgress?(pct)
        }
    }
}

