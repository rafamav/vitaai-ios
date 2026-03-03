import Foundation
import Speech
import AVFoundation

// MARK: - SpeechPermissionStatus

enum SpeechPermissionStatus {
    case notDetermined
    case denied
    case authorized
    case micDenied
}

// MARK: - SpeechRecognitionManager
// iOS equivalent of Android's SpeechRecognitionHelper.
// Uses Apple Speech framework with SFSpeechRecognizer for on-device recognition.
// Supports pt-BR locale primarily, falls back to device locale.

@MainActor
@Observable
final class SpeechRecognitionManager {

    // MARK: - Published State

    private(set) var isListening: Bool = false
    private(set) var partialText: String = ""
    private(set) var transcribedText: String = ""
    private(set) var errorMessage: String? = nil
    private(set) var permissionStatus: SpeechPermissionStatus = .notDetermined

    // MARK: - Private

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    var isAvailable: Bool {
        recognizer?.isAvailable == true
    }

    // MARK: - Init

    init() {
        // Prefer pt-BR; fall back gracefully
        self.recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
            ?? SFSpeechRecognizer()
    }

    // MARK: - Permissions

    func requestPermissions() async {
        // Mic
        let micStatus = await AVAudioApplication.requestRecordPermission()
        guard micStatus else {
            permissionStatus = .micDenied
            return
        }

        // Speech
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        switch speechStatus {
        case .authorized:
            permissionStatus = .authorized
        case .denied, .restricted:
            permissionStatus = .denied
        case .notDetermined:
            permissionStatus = .notDetermined
        @unknown default:
            permissionStatus = .denied
        }
    }

    func checkCurrentPermissions() {
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let speechStatus = SFSpeechRecognizer.authorizationStatus()

        if micStatus == .denied || micStatus == .restricted {
            permissionStatus = .micDenied
            return
        }
        switch speechStatus {
        case .authorized:
            permissionStatus = micStatus == .authorized ? .authorized : .notDetermined
        case .denied, .restricted:
            permissionStatus = .denied
        case .notDetermined:
            permissionStatus = .notDetermined
        @unknown default:
            permissionStatus = .denied
        }
    }

    // MARK: - Start Listening

    func startListening() {
        guard permissionStatus == .authorized else {
            errorMessage = "Permissao de microfone necessaria"
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Reconhecimento de voz nao disponivel neste dispositivo"
            return
        }

        // Reset state
        stopListening()
        errorMessage = nil
        transcribedText = ""
        partialText = ""

        do {
            try configureAudioSession()
            try startRecognitionTask(with: recognizer)
        } catch {
            isListening = false
            errorMessage = "Erro ao iniciar reconhecimento: \(error.localizedDescription)"
        }
    }

    // MARK: - Stop Listening

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false

        // Deactivate audio session so TTS can resume
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Clear Error

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private Helpers

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startRecognitionTask(with recognizer: SFSpeechRecognizer) throws {
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Prefer on-device recognition when available (iOS 17+)
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.recognitionRequest = request

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            Task { @MainActor in
                if let result {
                    let text = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.transcribedText = text
                        self.partialText = ""
                        self.isListening = false
                        self.stopListening()
                    } else {
                        self.partialText = text
                    }
                }

                if let error = error as NSError? {
                    // Code 1 = recognition cancelled (normal on stopListening())
                    // Code 203 = no speech detected — treat as soft error
                    if error.domain == "kAFAssistantErrorDomain" && (error.code == 1 || error.code == 209) {
                        // Cancelled — not an error
                    } else if error.code == 203 {
                        self.errorMessage = "Nenhuma fala detectada"
                        self.isListening = false
                        self.stopListening()
                    } else {
                        self.errorMessage = self.mapError(error)
                        self.isListening = false
                        self.stopListening()
                    }
                }
            }
        }

        // Tap audio engine input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
    }

    private func mapError(_ error: NSError) -> String {
        switch error.code {
        case 1:  return "Reconhecimento cancelado"
        case 203: return "Nenhuma fala detectada"
        case 209: return "Timeout — nenhuma fala detectada"
        case 301: return "Erro de rede"
        default:  return "Erro de reconhecimento (\(error.code))"
        }
    }
}
