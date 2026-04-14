import Foundation
import Combine
import AVFoundation

// MARK: - CloudCarController
//
// Singleton orchestrator that wires the audio engine to the WebSocket client.
// Both the CarPlay scene and the in-app Terminal screen observe this object,
// so a single connection state is shared across the two surfaces.
//
// Why a singleton: CarPlay scene lifecycle is independent of the SwiftUI app
// lifecycle. The CPTemplateApplicationSceneDelegate gets called as soon as the
// car connects, even if the app's UI scene is suspended. A shared instance
// keeps the WebSocket alive across that boundary.

@MainActor
final class CloudCarController: ObservableObject {

    static let shared = CloudCarController()

    // MARK: - Published state

    enum LinkState: Equatable {
        case offline
        case connecting
        case online
        case reconnecting(attempt: Int)
        case error(String)

        var label: String {
            switch self {
            case .offline:                 return "Desconectado"
            case .connecting:              return "Conectando..."
            case .online:                  return "Conectado"
            case .reconnecting(let n):     return "Reconectando (\(n))"
            case .error(let msg):          return "Erro: \(msg)"
            }
        }
    }

    enum ListeningState: String {
        case idle
        case listening
        case thinking
        case speaking
    }

    struct Turn: Identifiable, Equatable {
        let id = UUID()
        let role: Role
        let text: String
        let timestamp: Date

        enum Role: String { case user, agent, system }
    }

    @Published private(set) var linkState: LinkState = .offline
    @Published private(set) var listening: ListeningState = .idle
    @Published private(set) var transcript: [Turn] = []
    @Published private(set) var partialTranscript: String = ""

    // MARK: - Internals

    private let audio: CloudCarAudioEngine
    private let client: CloudCarAgentClient
    private var stateObserverTask: Task<Void, Never>?
    private var inboundObserverTask: Task<Void, Never>?

    private init() {
        self.audio = CloudCarAudioEngine()
        // Reuse the app's keychain-backed token store so the CloudCar gateway
        // can fall back to the better-auth session cookie when no dedicated
        // bearer token is configured.
        self.client = CloudCarAgentClient(tokenStore: TokenStore())

        self.audio.onChunk = { [weak self] data in
            // onChunk fires from the AVAudioEngine thread; hop to the actor
            // for thread-safe send.
            Task { [weak self] in
                guard let self else { return }
                try? await self.client.send(.audioChunk(data))
            }
        }
    }

    // MARK: - Lifecycle

    func start() {
        observeState()
        observeInbound()
        if CloudCarConfig.autoConnect {
            Task { await client.connect() }
        }
    }

    func stop() {
        stopListening()
        Task { await client.disconnect() }
        stateObserverTask?.cancel()
        inboundObserverTask?.cancel()
        audio.deactivateSession()
    }

    func connect() {
        Task { await client.connect() }
    }

    func disconnect() {
        stopListening()
        Task { await client.disconnect() }
    }

    // MARK: - Voice turn

    /// Begin streaming microphone audio to the gateway. Idempotent.
    func startListening() {
        guard listening != .listening else { return }
        do {
            try audio.startCapture()
            listening = .listening
            logSystem("Microfone aberto")
        } catch {
            logSystem("Falha ao abrir microfone: \(error.localizedDescription)")
            listening = .idle
        }
    }

    /// Close the mic and tell the gateway the utterance is finished. The
    /// gateway should respond with transcript + response events.
    func stopListening() {
        guard listening == .listening else { return }
        audio.stopCapture()
        listening = .thinking
        Task {
            try? await self.client.send(.audioEnd)
        }
    }

    /// Push-to-talk toggle convenience for steering-wheel button binding.
    func togglePushToTalk() {
        switch listening {
        case .listening: stopListening()
        case .idle, .thinking, .speaking: startListening()
        }
    }

    /// Send a typed command directly (in-app debug path, also useful from
    /// CarPlay if Siri Intents fill in the text for us).
    func sendCommand(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        appendTurn(.user, text: trimmed)
        Task { try? await self.client.send(.command(trimmed)) }
    }

    /// Cut off the agent mid-response — useful when the driver wants to
    /// re-prompt without waiting for the current utterance to finish.
    func interrupt() {
        audio.stopSpeaking()
        audio.stopPlayback()
        listening = .idle
        Task { try? await self.client.send(.interrupt) }
    }

    // MARK: - Observers

    private func observeState() {
        stateObserverTask?.cancel()
        stateObserverTask = Task { [weak self] in
            guard let self else { return }
            for await state in await self.client.stateUpdates() {
                await MainActor.run { self.applyClientState(state) }
            }
        }
    }

    private func observeInbound() {
        inboundObserverTask?.cancel()
        inboundObserverTask = Task { [weak self] in
            guard let self else { return }
            for await event in await self.client.events() {
                await MainActor.run { self.handleInbound(event) }
            }
        }
    }

    private func applyClientState(_ state: CloudCarAgentClient.State) {
        switch state {
        case .disconnected:                    linkState = .offline
        case .connecting:                      linkState = .connecting
        case .connected:                       linkState = .online
        case .reconnecting(let attempt):       linkState = .reconnecting(attempt: attempt)
        case .failed(let msg):                 linkState = .error(msg)
        }
    }

    private func handleInbound(_ event: CloudCarInbound) {
        switch event {
        case .transcript(let text, let isFinal):
            if isFinal {
                partialTranscript = ""
                appendTurn(.user, text: text)
            } else {
                partialTranscript = text
            }

        case .response(let text):
            appendTurn(.agent, text: text)
            if CloudCarConfig.preferLocalTTS {
                listening = .speaking
                audio.speak(text)
            }

        case .audio(let pcm):
            listening = .speaking
            try? audio.playPCM(pcm)

        case .status(let state):
            switch state {
            case "thinking": listening = .thinking
            case "speaking": listening = .speaking
            case "idle":     listening = .idle
            default: break
            }

        case .error(let message):
            logSystem(message)

        case .unknown(let raw):
            #if DEBUG
            logSystem("Evento desconhecido: \(raw)")
            #else
            _ = raw
            #endif
        }
    }

    // MARK: - Transcript helpers

    private func appendTurn(_ role: Turn.Role, text: String) {
        let turn = Turn(role: role, text: text, timestamp: Date())
        transcript.append(turn)
        // Cap at 200 turns to avoid unbounded growth in long sessions.
        if transcript.count > 200 {
            transcript.removeFirst(transcript.count - 200)
        }
    }

    private func logSystem(_ text: String) {
        appendTurn(.system, text: text)
        NSLog("[CloudCar] %@", text)
    }

    func clearTranscript() {
        transcript.removeAll()
        partialTranscript = ""
    }
}
