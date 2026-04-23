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
    /// Real wall-clock counter that starts when the user hits "Stop
    /// recording". Replaces the old hardcoded "~2 minutos" label on the
    /// processing toast — no more lying about ETAs we can't predict.
    private(set) var processingSeconds: Int = 0
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
    /// Ticks `processingSeconds` while the upload/transcribe/persist
    /// pipeline is running. Cancelled on `.done` / `.error` / `reset()`.
    private var processingTimerTask: Task<Void, Never>?
    /// Polls GET /studio/sources/:id once we have the sourceId. The SSE
    /// stream from /api/ai/transcribe sometimes gets buffered or the
    /// server closes without URLSession.AsyncBytes emitting EOF — when
    /// that happens the UI would freeze forever. This poll independently
    /// observes the DB row and transitions us to `.done` as soon as the
    /// server marks it `ready`.
    private var pollingTask: Task<Void, Never>?
    /// Watchdog — after N seconds with no visible progress we give up on
    /// the live stream, flip the UI to `.done` (assuming server finished
    /// server-side) and refresh the list. 60s is well past whisper+LLM
    /// wall clock for a normal lecture clip; if it's still running the
    /// user can still check in "Transcrições".
    private var watchdogTask: Task<Void, Never>?

    init(client: TranscricaoClient, api: VitaAPI? = nil, gamificationEvents: GamificationEventManager? = nil) {
        self.client = client
        self.api = api
        self.gamificationEvents = gamificationEvents
    }

    // MARK: - Public API

    /// Timestamp of last successful load — used to debounce repeated calls.
    /// SwiftUI may fire `.task` / `.onAppear` multiple times on sheet dismiss,
    /// layout changes, or tab switches; this keeps us from re-fetching the
    /// same list 6× in a row (incident 2026-04-23 — Rafael viu "30s pra
    /// carregar 18 gravações" porque iOS disparava 6 requests em sequência).
    private var lastLoadAt: Date = .distantPast

    /// Load saved recordings from the API. Debounced — skips if called
    /// again within 2s. Pull-to-refresh / post-completion passam `force: true`.
    func loadRecordings(force: Bool = false) async {
        guard let api else { return }
        if !force && Date().timeIntervalSince(lastLoadAt) < 2 {
            NSLog("[TranscricaoVM] loadRecordings debounced (last=%.1fs ago)", Date().timeIntervalSince(lastLoadAt))
            return
        }
        recordingsLoading = true
        do {
            recordings = try await api.getTranscricoes()
            lastLoadAt = Date()
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
        progressStage = ""
        processingSeconds = 0
        startProcessingTimer()
        startProcessingWatchdog()
        uploadTask = Task { [weak self] in
            await self?.processUpload(fileURL: url)
        }
    }

    /// 1-Hz counter that drives the "Enviando áudio — 0:07" label on the
    /// processing toast. Started when upload begins, cancelled on done /
    /// error / reset. Real seconds — no prediction.
    private func startProcessingTimer() {
        processingTimerTask?.cancel()
        processingTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                await MainActor.run { self?.processingSeconds += 1 }
            }
        }
    }

    private func stopProcessingTimer() {
        processingTimerTask?.cancel()
        processingTimerTask = nil
    }

    /// If 60 seconds pass without a terminal SSE event, assume the server
    /// finished server-side (our backend is resilient to client disconnects)
    /// and pop the UI out of the processing state. One last loadRecordings
    /// guarantees the new row shows up under "Transcrições de hoje".
    private func startProcessingWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled, let self else { return }
            if self.phase == .uploading || self.phase == .transcribing
                || self.phase == .summarizing || self.phase == .generatingFlashcards {
                NSLog("[TranscricaoVM] watchdog fired — forcing done + refresh")
                self.uploadTask?.cancel()
                self.pollingTask?.cancel()
                self.phase = .done
                self.stopProcessingTimer()
                await self.loadRecordings(force: true)
            }
        }
    }

    /// Independent of the SSE stream, polls the DB row every 2s once we
    /// know its id. If the server marks it ready before (or after) SSE
    /// completes we pick that up and transition here. This is what stops
    /// "transcrevendo forever" dead.
    private func startPolling(sourceId: String) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let api = await self?.api else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { break }
                if let detail = try? await api.getStudioSourceDetail(id: sourceId),
                   detail.status == "ready" {
                    await MainActor.run {
                        guard let self else { return }
                        if self.phase != .done {
                            NSLog("[TranscricaoVM] polling saw status=ready — transitioning to done")
                            self.phase = .done
                            self.transcript = detail.chunks?
                                .sorted(by: { $0.chunkIndex < $1.chunkIndex })
                                .map(\.content)
                                .joined(separator: "\n\n") ?? self.transcript
                            self.stopProcessingTimer()
                            self.watchdogTask?.cancel()
                            Task { await self.loadRecordings(force: true) }
                        }
                    }
                    return
                }
            }
        }
    }

    /// Remove a recording from the local list (optimistic delete)
    func removeRecordingLocally(id: String) {
        recordings.removeAll { $0.id == id }
    }

    func reset() {
        timerTask?.cancel()
        uploadTask?.cancel()
        processingTimerTask?.cancel()
        pollingTask?.cancel()
        watchdogTask?.cancel()
        timerTask = nil
        uploadTask = nil
        processingTimerTask = nil
        pollingTask = nil
        watchdogTask = nil
        endAudioCapture()
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
        phase = .idle
        elapsedSeconds = 0
        processingSeconds = 0
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
                case .progress(let stage, _):
                    progressStage = stage
                    phase = phaseFromStage(stage)
                case .sourceCreated(let id):
                    // Start polling now — if the SSE stream stalls or the
                    // TCP pipe buffers, the poll still observes the DB
                    // going to status=ready and wakes the UI up.
                    startPolling(sourceId: id)
                case .complete(let t, let s, let cards):
                    transcript = t
                    summary = s
                    flashcards = cards
                    phase = .done
                    try? FileManager.default.removeItem(at: fileURL)
                    stopProcessingTimer()
                    pollingTask?.cancel()
                    watchdogTask?.cancel()
                    // Kick a list refresh so the new recording shows up under
                    // "Transcrições de hoje" without the user needing to
                    // navigate away and back. Runs concurrently with the
                    // gamification ping below. `force: true` bypassa debounce.
                    Task { await self.loadRecordings(force: true) }
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
                    // If the server reported an error AFTER whisper already
                    // persisted the transcript, the poll catches the ready
                    // row separately and flips us to `.done`. Don't mark
                    // error if polling already succeeded in parallel.
                    if phase != .done {
                        setError(msg)
                        stopProcessingTimer()
                    }
                    // Either way, refresh the list so the user sees whatever
                    // did land server-side. `force: true` bypassa debounce.
                    Task { await self.loadRecordings(force: true) }
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
