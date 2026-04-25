import Foundation

/// Single-connection SSE multiplexer pra GET /api/stream — etapa 4 do gold-standard
/// 2026 (ver shell.md secao 3.1 — REALTIME SYNC).
///
/// Mantem 1 conexao SSE persistente enquanto app foreground. Recebe frames
/// `id: <n>\ndata: <json>\n\n`, parseia, e despacha pro handler injetado
/// (em geral AppDataManager.applyEvent). Persiste ultimo id em UserDefaults
/// pra resume via Last-Event-ID na reconexao.
///
/// Backoff: 1s, 2s, 4s, 8s, 16s, 30s (cap). Reset apos primeiro frame
/// recebido com sucesso.
///
/// Vida util:
///   - VitaAIApp scenePhase=.active -> stream.connect()
///   - VitaAIApp scenePhase=.background -> stream.disconnect()
///
/// Auth: usa MESMO TokenStore que HTTPClient — header X-Extension-Token.
/// Backend resolve authId -> user_profiles.id pra LISTEN canal correto.
@MainActor
final class RealtimeStream {
    /// Frame parseado pronto pra aplicar no store.
    struct Event {
        let id: String
        let domain: String
        let op: String        // "upsert" | "delete" | "invalidate"
        let recordId: String?
        let payload: [String: Any]?
    }

    // MARK: - Public API

    typealias Handler = @MainActor (Event) -> Void

    var onEvent: Handler?

    private(set) var isConnected: Bool = false

    // MARK: - Private

    private let baseURL: URL
    private let tokenStore: TokenStore
    private let session: URLSession
    private var task: Task<Void, Never>?

    private static let lastEventIdKey = "vita.realtime.lastEventId"
    private var lastEventId: String? {
        get { UserDefaults.standard.string(forKey: Self.lastEventIdKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.lastEventIdKey) }
    }

    init(baseURL: URL, tokenStore: TokenStore) {
        self.baseURL = baseURL
        self.tokenStore = tokenStore

        let config = URLSessionConfiguration.default
        // SSE precisa NAO timeoutar — desativa timeoutInterval. Heartbeat
        // do server (`:hb` cada 25s) mantem TCP vivo.
        config.timeoutIntervalForRequest = 0
        config.timeoutIntervalForResource = 0
        config.waitsForConnectivity = true
        self.session = URLSession(configuration: config)
    }

    /// Idempotent. Se ja conectado/conectando, no-op.
    func connect() {
        guard task == nil else { return }
        task = Task { [weak self] in
            await self?.runWithBackoff()
        }
    }

    /// Cancela a Task; reconectar = chamar connect() de novo.
    func disconnect() {
        task?.cancel()
        task = nil
        isConnected = false
    }

    // MARK: - Run loop

    private func runWithBackoff() async {
        var attempt = 0
        while !Task.isCancelled {
            do {
                try await runOnce()
                // runOnce retornou sem erro (server fechou cleanly) → reset backoff
                attempt = 0
            } catch is CancellationError {
                return
            } catch {
                NSLog("[RealtimeStream] error: %@", "\(error)")
            }

            // Backoff: 1s, 2s, 4s, 8s, 16s, 30s
            let backoff = min(pow(2.0, Double(attempt)), 30.0)
            attempt += 1
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
        }
    }

    private func runOnce() async throws {
        let url = baseURL.appendingPathComponent("/api/stream")
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        req.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        if let token = await tokenStore.token {
            req.setValue(token, forHTTPHeaderField: "X-Extension-Token")
        }
        if let lastId = lastEventId {
            req.setValue(lastId, forHTTPHeaderField: "Last-Event-ID")
        }

        let (bytes, response) = try await session.bytes(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            NSLog("[RealtimeStream] non-2xx: %d", code)
            throw URLError(.badServerResponse)
        }

        isConnected = true
        NSLog("[RealtimeStream] connected (resume=%@)", lastEventId ?? "none")

        var pendingId: String?
        var pendingData: String?

        for try await line in bytes.lines {
            try Task.checkCancellation()

            // Ignore heartbeat comments (start with ':')
            if line.hasPrefix(":") {
                continue
            }
            // Empty line = end of frame -> dispatch
            if line.isEmpty {
                if let data = pendingData {
                    await dispatch(id: pendingId, data: data)
                }
                pendingId = nil
                pendingData = nil
                continue
            }
            if line.hasPrefix("id:") {
                pendingId = trimField(line, prefix: "id:")
            } else if line.hasPrefix("data:") {
                pendingData = trimField(line, prefix: "data:")
            }
            // Other SSE fields (event:, retry:) ignored — backend doesn't use
        }

        isConnected = false
        NSLog("[RealtimeStream] stream ended cleanly")
    }

    private func trimField(_ line: String, prefix: String) -> String {
        String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
    }

    private func dispatch(id: String?, data: String) async {
        guard
            let raw = data.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: raw) as? [String: Any],
            let domain = json["domain"] as? String,
            let op = json["op"] as? String
        else {
            NSLog("[RealtimeStream] failed to parse frame: %@", String(data.prefix(200)))
            return
        }

        let recordId = json["recordId"] as? String
        let payload = json["payload"] as? [String: Any]

        let evId = id ?? "?"
        let event = Event(id: evId, domain: domain, op: op, recordId: recordId, payload: payload)

        // Persist lastEventId BEFORE handler runs — se handler crashar, na
        // proxima reconexao pulamos esse evento (idempotencia eh
        // responsabilidade do handler, nao da persistencia).
        if let id = id { lastEventId = id }

        onEvent?(event)
    }
}
