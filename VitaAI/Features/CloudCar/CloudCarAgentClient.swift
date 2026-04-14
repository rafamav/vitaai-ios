import Foundation

// MARK: - Wire Protocol
//
// Bidirectional JSON envelopes over a single WebSocket. Audio chunks are
// base64-encoded inside JSON to keep one channel for everything (text +
// binary) and avoid framing ambiguity on the gateway side.
//
//   client → server:
//     { "type": "audio_chunk", "data": "<base64 PCM16>" }
//     { "type": "audio_end" }
//     { "type": "command", "text": "<utterance>" }
//     { "type": "interrupt" }
//
//   server → client:
//     { "type": "transcript", "text": "<asr partial or final>", "final": true }
//     { "type": "response",   "text": "<assistant message>" }
//     { "type": "audio",      "data": "<base64 PCM16>" }
//     { "type": "status",     "state": "thinking" | "speaking" | "idle" }
//     { "type": "error",      "message": "<human readable>" }

enum CloudCarOutbound: Encodable {
    case audioChunk(Data)
    case audioEnd
    case command(String)
    case interrupt

    private enum CodingKeys: String, CodingKey {
        case type, data, text
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .audioChunk(let bytes):
            try c.encode("audio_chunk", forKey: .type)
            try c.encode(bytes.base64EncodedString(), forKey: .data)
        case .audioEnd:
            try c.encode("audio_end", forKey: .type)
        case .command(let text):
            try c.encode("command", forKey: .type)
            try c.encode(text, forKey: .text)
        case .interrupt:
            try c.encode("interrupt", forKey: .type)
        }
    }
}

enum CloudCarInbound: Sendable {
    case transcript(text: String, isFinal: Bool)
    case response(text: String)
    case audio(Data)
    case status(String)
    case error(String)
    case unknown(String)

    static func parse(_ json: [String: Any]) -> CloudCarInbound {
        let type = (json["type"] as? String) ?? ""
        switch type {
        case "transcript":
            let text = json["text"] as? String ?? ""
            let isFinal = json["final"] as? Bool ?? false
            return .transcript(text: text, isFinal: isFinal)
        case "response":
            return .response(text: json["text"] as? String ?? "")
        case "audio":
            let b64 = json["data"] as? String ?? ""
            return .audio(Data(base64Encoded: b64) ?? Data())
        case "status":
            return .status(json["state"] as? String ?? "")
        case "error":
            return .error(json["message"] as? String ?? "Unknown error")
        default:
            return .unknown(type)
        }
    }
}

// MARK: - CloudCarAgentClient
//
// Actor wrapping URLSessionWebSocketTask with reconnect + ping. The public
// surface is intentionally tiny: connect, send envelope, async stream of
// inbound events. Reconnect is handled internally and surfaced via the
// .status events so the controller (and CarPlay UI) can react.

actor CloudCarAgentClient {

    enum State: Sendable, Equatable {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case failed(String)
    }

    // Dependencies
    private let tokenStore: TokenStore
    private let session: URLSession

    // State
    private var task: URLSessionWebSocketTask?
    private var state: State = .disconnected
    private var stateContinuations: [UUID: AsyncStream<State>.Continuation] = [:]
    private var inboundContinuation: AsyncStream<CloudCarInbound>.Continuation?
    private var inboundStream: AsyncStream<CloudCarInbound>?
    private var pingTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var reconnectAttempt = 0
    private var explicitlyDisconnected = false

    init(tokenStore: TokenStore, session: URLSession? = nil) {
        self.tokenStore = tokenStore
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.timeoutIntervalForResource = 0 // long-lived
            config.waitsForConnectivity = true
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Public API

    func currentState() -> State { state }

    /// Hot AsyncStream of inbound events. Survives reconnects — same stream
    /// continues to deliver events from each new socket.
    func events() -> AsyncStream<CloudCarInbound> {
        if let stream = inboundStream { return stream }
        let stream = AsyncStream<CloudCarInbound> { continuation in
            self.inboundContinuation = continuation
        }
        self.inboundStream = stream
        return stream
    }

    func stateUpdates() -> AsyncStream<State> {
        AsyncStream<State> { continuation in
            let id = UUID()
            self.stateContinuations[id] = continuation
            continuation.yield(self.state)
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeStateContinuation(id) }
            }
        }
    }

    private func removeStateContinuation(_ id: UUID) {
        stateContinuations.removeValue(forKey: id)
    }

    func connect() async {
        explicitlyDisconnected = false
        guard state != .connecting, state != .connected else { return }
        await openSocket()
    }

    func disconnect() {
        explicitlyDisconnected = true
        reconnectTask?.cancel(); reconnectTask = nil
        pingTask?.cancel(); pingTask = nil
        receiveTask?.cancel(); receiveTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        update(.disconnected)
    }

    func send(_ envelope: CloudCarOutbound) async throws {
        guard let task else { throw URLError(.notConnectedToInternet) }
        let data = try JSONEncoder().encode(envelope)
        guard let str = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        try await task.send(.string(str))
    }

    // MARK: - Socket Lifecycle

    private func openSocket() async {
        update(.connecting)

        guard let url = URL(string: CloudCarConfig.gatewayURL) else {
            update(.failed("Invalid gateway URL: \(CloudCarConfig.gatewayURL)"))
            scheduleReconnect()
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        if let token = CloudCarConfig.authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else if let session = await tokenStore.token {
            request.setValue("\(AppConfig.sessionCookieName)=\(session)", forHTTPHeaderField: "Cookie")
        }
        request.setValue(AppConfig.appName, forHTTPHeaderField: "User-Agent")
        request.setValue("cloudcar-ios/1", forHTTPHeaderField: "X-Client")

        let task = session.webSocketTask(with: request)
        self.task = task
        task.resume()

        // Optimistically mark connected. URLSession only surfaces failure via
        // the first send/receive, so we'll downgrade on error in receiveLoop.
        update(.connected)
        reconnectAttempt = 0

        startReceiveLoop()
        startPing()
    }

    private func startReceiveLoop() {
        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            guard let self else { return }
            await self.receiveLoop()
        }
    }

    private func receiveLoop() async {
        guard let task = self.task else { return }
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                handle(message: message)
            } catch {
                if Task.isCancelled { return }
                inboundContinuation?.yield(.error("Socket error: \(error.localizedDescription)"))
                await handleSocketFailure()
                return
            }
        }
    }

    private func handle(message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let raw):
            guard let data = raw.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                inboundContinuation?.yield(.unknown(raw))
                return
            }
            inboundContinuation?.yield(CloudCarInbound.parse(json))
        case .data(let data):
            // Treat raw binary as PCM audio for backward compatibility with
            // gateways that don't wrap audio in JSON.
            inboundContinuation?.yield(.audio(data))
        @unknown default:
            break
        }
    }

    private func startPing() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(CloudCarConfig.pingInterval * 1_000_000_000))
                if Task.isCancelled { return }
                await self.sendPing()
            }
        }
    }

    private func sendPing() async {
        guard let task else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            task.sendPing { _ in cont.resume() }
        }
    }

    private func handleSocketFailure() async {
        pingTask?.cancel(); pingTask = nil
        task?.cancel(with: .abnormalClosure, reason: nil)
        task = nil
        if explicitlyDisconnected { update(.disconnected); return }
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        reconnectAttempt += 1
        let attempt = reconnectAttempt
        let delay = min(
            CloudCarConfig.initialReconnectDelay * pow(2.0, Double(attempt - 1)),
            CloudCarConfig.maxReconnectDelay
        )
        update(.reconnecting(attempt: attempt))
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            if Task.isCancelled { return }
            await self?.openSocket()
        }
    }

    private func update(_ newState: State) {
        state = newState
        for cont in stateContinuations.values { cont.yield(newState) }
    }
}
