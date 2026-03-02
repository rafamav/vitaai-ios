import Foundation

// MARK: - VoiceModeStatus
// Mirrors Android's VoiceModeStatus enum in VitaChatViewModel.kt

enum VoiceModeStatus: Hashable {
    case idle
    case listening
    case thinking
    case speaking
}

// MARK: - VoiceModeViewModel
// Orchestrates voice mode: STT → API → TTS → loop.
// Integrates with existing ChatViewModel's stream API via VitaChatClient.
// Pattern: @Observable, @MainActor, async/await throughout.

@MainActor
@Observable
final class VoiceModeViewModel {

    // MARK: - State

    private(set) var status: VoiceModeStatus = .idle
    private(set) var transcriptText: String = ""
    private(set) var responseText: String = ""
    private(set) var errorMessage: String? = nil

    var isListening: Bool { speechManager.isListening }
    var permissionStatus: SpeechPermissionStatus { speechManager.permissionStatus }

    // MARK: - Dependencies

    let speechManager: SpeechRecognitionManager
    let ttsManager: TextToSpeechManager
    private let chatClient: VitaChatClient

    // MARK: - Private

    private var streamingConversationId: String?
    private var isSpeakingObservationTask: Task<Void, Never>?
    private var transcriptionObservationTask: Task<Void, Never>?
    private var isActive: Bool = false

    // MARK: - Init

    init(chatClient: VitaChatClient) {
        self.chatClient = chatClient
        self.speechManager = SpeechRecognitionManager()
        self.ttsManager = TextToSpeechManager()
    }

    // MARK: - Lifecycle

    func onAppear() async {
        speechManager.checkCurrentPermissions()

        if speechManager.permissionStatus == .notDetermined {
            await speechManager.requestPermissions()
        }

        if speechManager.permissionStatus == .authorized {
            enterListening()
        }
    }

    func onDisappear() {
        isActive = false
        isSpeakingObservationTask?.cancel()
        transcriptionObservationTask?.cancel()
        speechManager.stopListening()
        ttsManager.stop()
        status = .idle
    }

    // MARK: - Voice Mode Entry Points

    /// Begin listening — called automatically on appear and after TTS finishes.
    func enterListening() {
        guard speechManager.permissionStatus == .authorized,
              speechManager.isAvailable else { return }

        isActive = true
        status = .listening
        transcriptText = ""
        responseText = ""
        errorMessage = nil

        speechManager.startListening()
        observeTranscription()
    }

    /// Toggle mic on/off (tap on mic button).
    func toggleListening() {
        if speechManager.isListening {
            // User stopped speaking — send what we have
            speechManager.stopListening()
            let text = speechManager.transcribedText.isEmpty
                ? speechManager.partialText
                : speechManager.transcribedText
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Task { @MainActor in await self.sendToAPI(text: text) }
            } else {
                status = .idle
            }
        } else {
            enterListening()
        }
    }

    /// Dismiss voice mode from the close button.
    func dismiss() {
        onDisappear()
    }

    // MARK: - Transcription Observation
    // We poll speechManager.transcribedText via withObservationTracking.
    // When a final transcription arrives, auto-send to API.

    private func observeTranscription() {
        transcriptionObservationTask?.cancel()
        transcriptionObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            // Poll every 100ms for transcribed text changes
            var lastSeen = ""
            while !Task.isCancelled && self.isActive {
                let current = self.speechManager.transcribedText
                if current != lastSeen && !current.isEmpty {
                    lastSeen = current
                    self.transcriptText = current
                    // Final transcription received — send to API
                    await self.sendToAPI(text: current)
                    break
                }

                // Also surface partial text
                let partial = self.speechManager.partialText
                if !partial.isEmpty {
                    self.transcriptText = partial
                }

                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    // MARK: - API

    private func sendToAPI(text: String) async {
        guard isActive, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        speechManager.stopListening()
        transcriptionObservationTask?.cancel()

        status = .thinking
        transcriptText = text
        responseText = ""

        var fullResponse = ""

        do {
            for try await event in await chatClient.streamChat(
                message: text,
                conversationId: streamingConversationId,
                voiceMode: true
            ) {
                guard isActive else { break }

                switch event {
                case .textDelta(let chunk):
                    fullResponse += chunk
                    responseText = fullResponse

                case .messageStop(let convId):
                    if let convId {
                        streamingConversationId = convId
                    }

                case .error(let msg):
                    errorMessage = msg
                    status = .idle
                    return
                }
            }
        } catch {
            errorMessage = "Nao foi possivel conectar. Verifique sua conexao."
            status = .idle
            return
        }

        guard isActive else { return }

        // Speak the response
        if !fullResponse.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            status = .speaking
            ttsManager.speakChunked(fullResponse)
            observeTTSCompletion()
        } else {
            // Empty response — loop back to listening
            enterListening()
        }
    }

    // MARK: - TTS Completion

    private func observeTTSCompletion() {
        isSpeakingObservationTask?.cancel()
        isSpeakingObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            // Wait for TTS to start speaking before we begin polling for completion
            try? await Task.sleep(for: .milliseconds(300))

            // Poll until speaking stops
            while !Task.isCancelled && self.isActive {
                if !self.ttsManager.isSpeaking {
                    break
                }
                try? await Task.sleep(for: .milliseconds(150))
            }

            guard !Task.isCancelled && self.isActive else { return }

            // TTS finished — auto-loop back to listening (mirrors Android behavior)
            self.enterListening()
        }
    }

    // MARK: - Stop TTS (user taps mic while speaking)

    func interruptSpeaking() {
        ttsManager.stop()
        isSpeakingObservationTask?.cancel()
        enterListening()
    }
}
