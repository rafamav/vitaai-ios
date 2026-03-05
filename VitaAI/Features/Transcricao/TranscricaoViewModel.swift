import Foundation
import AVFoundation

// MARK: - TranscricaoPhase
// Mirrors Android TranscricaoViewModel.Phase

enum TranscricaoPhase: Equatable {
    case idle
    case recording
    case uploading
    case transcribing
    case summarizing
    case generatingFlashcards
    case done
    case error(String)
}

// MARK: - TranscriptionFlashcard

struct TranscriptionFlashcard: Identifiable {
    let id: UUID
    let front: String
    let back: String

    init(front: String, back: String) {
        self.id = UUID()
        self.front = front
        self.back = back
    }
}

// MARK: - TranscricaoResult

struct TranscricaoResult {
    let transcript: String
    let summary: String
    let flashcards: [TranscriptionFlashcard]
}

// MARK: - TranscricaoViewModel

@MainActor
@Observable
final class TranscricaoViewModel: NSObject {

    // MARK: - State

    private(set) var phase: TranscricaoPhase = .idle
    private(set) var elapsedSeconds: Int = 0
    private(set) var progressPercent: Int = 0
    private(set) var progressStage: String = ""
    private(set) var result: TranscricaoResult? = nil
    private(set) var micPermissionGranted: Bool = false

    // MARK: - Dependencies

    private let tokenStore: TokenStore

    // MARK: - Audio Recording

    private var audioRecorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var elapsedTimer: Task<Void, Never>?

    // MARK: - Init

    init(tokenStore: TokenStore) {
        self.tokenStore = tokenStore
    }

    // MARK: - Permission

    func checkAndRequestMicPermission() async {
        let current = AVCaptureDevice.authorizationStatus(for: .audio)
        if current == .authorized {
            micPermissionGranted = true
            return
        }
        let granted = await AVAudioApplication.requestRecordPermission()
        micPermissionGranted = granted
    }

    // MARK: - Record

    func startRecording() {
        guard micPermissionGranted else { return }

        // Temp file in app cache dir
        let fileName = "vita_transcricao_\(Int(Date().timeIntervalSince1970)).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.record()

            phase = .recording
            elapsedSeconds = 0
            startElapsedTimer()
        } catch {
            phase = .error("Falha ao iniciar gravação: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        elapsedTimer?.cancel()
        elapsedTimer = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Non-critical
        }

        guard let url = recordingURL else {
            phase = .error("Falha ao parar gravação")
            return
        }

        phase = .uploading
        progressPercent = 0
        progressStage = ""

        Task { @MainActor in
            await self.uploadAndStream(url: url)
        }
    }

    // MARK: - Upload + SSE Stream

    private func uploadAndStream(url: URL) async {
        guard let token = await tokenStore.token else {
            phase = .error("Sessao expirada. Faca login novamente.")
            return
        }

        guard let apiURL = URL(string: AppConfig.apiBaseURL + "/ai/transcribe") else {
            phase = .error("URL de API invalida.")
            return
        }

        // Build multipart form data
        let boundary = "VitaBoundary-\(UUID().uuidString)"
        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        // Generous timeouts for audio upload + transcription
        request.timeoutInterval = 300

        do {
            let audioData = try Data(contentsOf: url)
            let body = buildMultipartBody(audioData: audioData, fileName: url.lastPathComponent, boundary: boundary)
            request.httpBody = body
        } catch {
            phase = .error("Falha ao ler arquivo de audio: \(error.localizedDescription)")
            return
        }

        // Stream SSE response
        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300
            config.timeoutIntervalForResource = 600
            let session = URLSession(configuration: config)

            let (bytes, response) = try await session.bytes(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                phase = .error("Erro do servidor (\(code)). Tente novamente.")
                return
            }

            var dataBuffer = ""

            for try await line in bytes.lines {
                if line.hasPrefix("data:") {
                    dataBuffer += line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                } else if line.isEmpty && !dataBuffer.isEmpty {
                    let raw = dataBuffer
                    dataBuffer = ""
                    processSSEData(raw)
                }
            }

            // Ensure we are done if stream ends without explicit complete event
            if case .transcribing = phase {
                phase = .error("Conexao encerrada antes da conclusao. Tente novamente.")
            } else if case .uploading = phase {
                phase = .error("Conexao encerrada antes da conclusao. Tente novamente.")
            }

        } catch {
            phase = .error("Erro de conexao: \(error.localizedDescription)")
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: url)
        recordingURL = nil
    }

    private func processSSEData(_ raw: String) {
        guard let data = raw.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "progress":
            let stage = json["stage"] as? String ?? ""
            let percent = json["percent"] as? Int ?? 0
            progressPercent = percent
            progressStage = stage
            phase = stageToPhase(stage)

        case "complete":
            let transcript = json["transcript"] as? String ?? ""
            let summary = json["summary"] as? String ?? ""
            var flashcards: [TranscriptionFlashcard] = []
            if let cards = json["flashcards"] as? [[String: Any]] {
                flashcards = cards.compactMap { card in
                    guard let front = card["front"] as? String,
                          let back = card["back"] as? String else { return nil }
                    return TranscriptionFlashcard(front: front, back: back)
                }
            }
            result = TranscricaoResult(transcript: transcript, summary: summary, flashcards: flashcards)
            progressPercent = 100
            phase = .done

        case "error":
            let msg = json["content"] as? String ?? "Erro desconhecido"
            phase = .error(msg)

        default:
            break
        }
    }

    private func stageToPhase(_ stage: String) -> TranscricaoPhase {
        let lower = stage.lowercased()
        if lower.contains("transcri") { return .transcribing }
        if lower.contains("resum") { return .summarizing }
        if lower.contains("flash") { return .generatingFlashcards }
        return .uploading
    }

    // MARK: - Reset

    func reset() {
        audioRecorder?.stop()
        audioRecorder = nil
        elapsedTimer?.cancel()
        elapsedTimer = nil
        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }
        phase = .idle
        elapsedSeconds = 0
        progressPercent = 0
        progressStage = ""
        result = nil
    }

    // MARK: - Elapsed Timer

    private func startElapsedTimer() {
        elapsedTimer?.cancel()
        elapsedTimer = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { break }
                self.elapsedSeconds += 1
            }
        }
    }

    // MARK: - Helpers

    private func buildMultipartBody(audioData: Data, fileName: String, boundary: String) -> Data {
        var body = Data()
        let crlf = "\r\n"

        // Audio field
        body.append("--\(boundary)\(crlf)".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileName)\"\(crlf)".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\(crlf)\(crlf)".data(using: .utf8)!)
        body.append(audioData)
        body.append(crlf.data(using: .utf8)!)

        // Closing boundary
        body.append("--\(boundary)--\(crlf)".data(using: .utf8)!)

        return body
    }

    // MARK: - Waveform amplitude (for visualization)

    var micAmplitude: Float {
        audioRecorder?.updateMeters()
        let power = audioRecorder?.averagePower(forChannel: 0) ?? -60
        // Normalize from [-60, 0] dB to [0, 1]
        let normalized = (power + 60) / 60
        return max(0, min(1, normalized))
    }
}

// MARK: - AVAudioRecorderDelegate

extension TranscricaoViewModel: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                // Only surface error if we were still expecting to record
                if case .recording = self.phase {
                    self.phase = .error("Gravacao encerrada inesperadamente")
                }
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.phase = .error("Erro de codificacao: \(error?.localizedDescription ?? "desconhecido")")
        }
    }
}

// MARK: - Phase helpers

extension TranscricaoPhase {
    var processingLabel: String {
        switch self {
        case .uploading:            return "Enviando audio..."
        case .transcribing:         return "Transcrevendo audio..."
        case .summarizing:          return "Gerando resumo..."
        case .generatingFlashcards: return "Criando flashcards..."
        default:                    return "Processando..."
        }
    }

    var isProcessing: Bool {
        switch self {
        case .uploading, .transcribing, .summarizing, .generatingFlashcards:
            return true
        default:
            return false
        }
    }
}
