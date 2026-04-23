import AVFoundation
import Foundation
import Speech
import SwiftUI

// MARK: - TranscricaoViewModel
//
// Manages the full recording → upload → transcription → done pipeline.
// Mirrors Android's TranscricaoViewModel state machine (Phase enum).
//
// iOS extras vs Android:
//   - SFSpeechRecognizer for live transcript display while recording
//   - AVAudioFile for direct-to-disk m4a capture alongside recognition

@MainActor
@Observable
final class TranscricaoViewModel {

    // MARK: - Phase (mirrors Android Phase enum)

    enum Phase: Equatable {
        case idle
        case recording
        case paused
        case uploading
        case transcribing
        case summarizing
        case generatingFlashcards
        case done
        case error
    }

    /// Number of bars in the live waveform. Kept as a small power-of-2 so the
    /// tap buffer can cheaply push into it without allocations.
    static let waveformBarCount = 24

    // MARK: - Exposed State

    private(set) var phase: Phase = .idle
    private(set) var elapsedSeconds: Int = 0
    private(set) var progressPercent: Int = 0
    private(set) var progressStage: String = ""
    /// Live waveform levels (0.0…1.0), length = `waveformBarCount`.
    /// Oldest sample is at index 0, newest at the end. Updated from the audio
    /// tap while recording.
    private(set) var audioLevels: [Float] = Array(repeating: 0, count: waveformBarCount)
    /// User-selected language code for Whisper (defaults to pt-BR audio input).
    var selectedLanguage: String = "pt"
    /// User-selected discipline for the recording. "Auto-detectar" means the
    /// server will classify from context (future Fase 2) — today it's just
    /// stored as metadata and used by the filter picker.
    var selectedDiscipline: String = "Auto-detectar"
    /// Real-time SFSpeechRecognizer partial transcript shown during recording.
    private(set) var liveTranscript: String = ""
    private(set) var transcript: String = ""
    private(set) var summary: String = ""
    private(set) var flashcards: [TranscriptionFlashcard] = []
    private(set) var errorMessage: String?
    /// Saved recordings loaded from API
    private(set) var recordings: [TranscricaoEntry] = []
    private(set) var recordingsLoading: Bool = false

    // MARK: - Private

    private let client: TranscricaoClient
    private var api: VitaAPI?
    private var gamificationEvents: GamificationEventManager?
    private var audioEngine: AVAudioEngine?
    private var activeOutputFile: AVAudioFile?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    private var recordingURL: URL?
    private var timerTask: Task<Void, Never>?
    private var uploadTask: Task<Void, Never>?
    private var recordingStartDate = Date()

    init(client: TranscricaoClient, api: VitaAPI? = nil, gamificationEvents: GamificationEventManager? = nil) {
        self.client = client
        self.api = api
        self.gamificationEvents = gamificationEvents
    }

    // MARK: - Public API

    /// Load saved recordings from the API
    func loadRecordings() async {
        guard let api else { return }
        recordingsLoading = true
        do {
            recordings = try await api.getTranscricoes()
            for r in recordings {
                NSLog("[TranscricaoVM] Recording: id=%@ title=%@ status=%@ isTranscribed=%d", r.id, r.title, r.status ?? "nil", r.isTranscribed ? 1 : 0)
            }
        } catch {
            NSLog("[TranscricaoVM] FAILED to load recordings: %@", "\(error)")
            // Non-fatal — just show empty list
        }
        recordingsLoading = false
    }

    func startRecording() async {
        guard await requestPermissions() else {
            phase = .error
            errorMessage = "Microfone ou reconhecimento de voz bloqueado. Ative em Ajustes > Privacidade."
            return
        }

        recordingStartDate = Date()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vita_audio_\(Int(Date().timeIntervalSince1970)).m4a")
        recordingURL = url
        liveTranscript = ""

        do {
            try beginAudioCapture(outputURL: url)
            phase = .recording
            elapsedSeconds = 0
            startTimer()
        } catch {
            phase = .error
            errorMessage = "Não foi possível iniciar a gravação: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        timerTask?.cancel()
        timerTask = nil
        endAudioCapture()

        guard let url = recordingURL else {
            setError("Arquivo de gravação não encontrado.")
            return
        }
        phase = .uploading
        progressPercent = 0
        progressStage = ""
        uploadTask = Task { [weak self] in
            await self?.processUpload(fileURL: url)
        }
    }

    /// Remove a recording from the local list (optimistic delete)
    func removeRecordingLocally(id: String) {
        recordings.removeAll { $0.id == id }
    }

    func reset() {
        timerTask?.cancel()
        uploadTask?.cancel()
        timerTask = nil
        uploadTask = nil
        endAudioCapture()
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
        phase = .idle
        elapsedSeconds = 0
        progressPercent = 0
        progressStage = ""
        liveTranscript = ""
        transcript = ""
        summary = ""
        flashcards = []
        errorMessage = nil
        audioLevels = Array(repeating: 0, count: Self.waveformBarCount)
    }

    /// Pause recording without finalizing the file. Removes the tap so no more
    /// samples flow in, pauses the timer, keeps the AVAudioFile + engine alive
    /// so resume continues into the same m4a.
    func pauseRecording() {
        guard phase == .recording else { return }
        audioEngine?.inputNode.removeTap(onBus: 0)
        timerTask?.cancel()
        timerTask = nil
        phase = .paused
    }

    /// Resume from `.paused`. Re-installs the tap on the same node so buffers
    /// flow back into the existing AVAudioFile and the SFSpeechRecognizer
    /// request (which was never cancelled).
    func resumeRecording() {
        guard phase == .paused,
              let engine = audioEngine,
              let outputFile = activeOutputFile,
              let request = recognitionRequest else { return }
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [outputFile, request, weak self] buffer, _ in
            try? outputFile.write(from: buffer)
            request.append(buffer)
            let level = Self.averageLevel(buffer)
            Task { @MainActor [weak self] in self?.appendAudioLevel(level) }
        }
        phase = .recording
        startTimer()
    }

    // MARK: - Waveform helpers

    /// Shift audio levels left by one and append the new sample to the end.
    /// Called on MainActor from the tap at whatever cadence iOS decides
    /// (~20–40 Hz with a 4096-frame buffer at 44.1 kHz). Cheap O(N) array op.
    private func appendAudioLevel(_ raw: Float) {
        // Soft-knee curve so quiet speech still shows visible bars and loud
        // peaks don't saturate into a flat line.
        let normalized = min(1, max(0, sqrtf(raw) * 2.4))
        if audioLevels.count == Self.waveformBarCount {
            audioLevels.removeFirst()
        }
        audioLevels.append(normalized)
    }

    /// Linear average of absolute sample values across the first channel.
    /// Fast, lock-free, no FFT. Called from the realtime audio thread.
    nonisolated private static func averageLevel(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<frames { sum += abs(channelData[i]) }
        return sum / Float(frames)
    }

    // MARK: - Permissions

    private func requestPermissions() async -> Bool {
        // Microphone
        let micStatus = AVAudioSession.sharedInstance().recordPermission
        if micStatus == .denied { return false }
        if micStatus == .undetermined {
            let granted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in cont.resume(returning: granted) }
            }
            guard granted else { return false }
        }
        // Speech recognition
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .denied || speechStatus == .restricted { return false }
        if speechStatus == .notDetermined {
            let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
                SFSpeechRecognizer.requestAuthorization { status in
                    cont.resume(returning: status == .authorized)
                }
            }
            guard granted else { return false }
        }
        return true
    }

    // MARK: - Audio Capture

    private func beginAudioCapture(outputURL: URL) throws {
        // Activate audio session FIRST — inputNode.outputFormat returns 0 Hz otherwise,
        // which causes installTap to throw an uncatchable NSException and terminate the app.
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            try? session.setActive(false)
            throw NSError(domain: "Transcricao", code: -1, userInfo: [NSLocalizedDescriptionKey: "Microfone indisponível (formato inválido). Tente novamente."])
        }

        // Write to disk (AAC/m4a). Channel count MUST match the tap buffer
        // (inputFormat.channelCount) — if the file is 1ch but the buffer is
        // 2ch, every AVAudioFile.write(from:) returns error -50 and the file
        // is silently empty. Whisper handles stereo fine; downmix is not
        // worth the AVAudioConverter dance here.
        let fileSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: inputFormat.sampleRate,
            AVNumberOfChannelsKey: Int(inputFormat.channelCount),
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: fileSettings)
        activeOutputFile = outputFile

        // SFSpeechRecognizer for live partial transcript
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        // Single tap: write samples to disk, feed speech recognizer, AND
        // compute waveform power for the live bars. Pushing levels back via a
        // weak MainActor hop keeps the realtime audio thread lock-free.
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [outputFile, request, weak self] buffer, _ in
            try? outputFile.write(from: buffer)
            request.append(buffer)
            let level = Self.averageLevel(buffer)
            Task { @MainActor [weak self] in self?.appendAudioLevel(level) }
        }

        try engine.start()
        audioEngine = engine

        // Recognition task — updates live transcript only (does NOT control recording stop)
        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, _ in
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            Task { @MainActor [weak self] in
                self?.liveTranscript = text
            }
        }
    }

    private func endAudioCapture() {
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        activeOutputFile = nil
        recognitionRequest = nil
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.elapsedSeconds += 1 }
            }
        }
    }

    // MARK: - Upload

    private func processUpload(fileURL: URL) async {
        let uploadStart = Date()
        let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
        VitaPostHogConfig.capture(event: "transcription_upload_started", properties: [
            "file_size_mb": Double(sizeBytes) / 1_048_576.0,
            "duration_seconds": Int(Date().timeIntervalSince(recordingStartDate)),
        ])
        do {
            for try await event in await client.uploadAndStream(
                fileURL: fileURL,
                language: selectedLanguage,
                discipline: selectedDiscipline
            ) {
                switch event {
                case .progress(let stage, let percent):
                    progressPercent = percent
                    progressStage = stage
                    phase = phaseFromStage(stage)
                case .complete(let t, let s, let cards):
                    transcript = t
                    summary = s
                    flashcards = cards
                    progressPercent = 100
                    phase = .done
                    try? FileManager.default.removeItem(at: fileURL)
                    VitaPostHogConfig.capture(event: "transcription_completed", properties: [
                        "word_count": t.split(separator: " ").count,
                        "flashcards_generated": cards.count,
                        "seconds_elapsed": Int(Date().timeIntervalSince(uploadStart)),
                    ])

                    // Log study session for gamification
                    let durationMinutes = Int(Date().timeIntervalSince(recordingStartDate) / 60)
                    if let api, let gamificationEvents {
                        Task {
                            if let result = try? await api.logActivity(
                                action: "study_session_end",
                                metadata: ["durationMinutes": String(durationMinutes)]
                            ) {
                                await gamificationEvents.handleActivityResponse(result, previousLevel: nil)
                            }
                        }
                    }
                case .error(let msg):
                    setError(msg)
                    VitaPostHogConfig.capture(event: "transcription_upload_failed", properties: [
                        "reason": msg,
                    ])
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            setError("Erro no envio: \(error.localizedDescription)")
            VitaPostHogConfig.capture(event: "transcription_upload_failed", properties: [
                "reason": error.localizedDescription,
            ])
        }
    }

    private func phaseFromStage(_ stage: String) -> Phase {
        let lower = stage.lowercased()
        if lower.contains("transcri") { return .transcribing }
        if lower.contains("resum") { return .summarizing }
        if lower.contains("flash") { return .generatingFlashcards }
        return .uploading
    }

    private func setError(_ msg: String) {
        phase = .error
        errorMessage = msg
    }
}
