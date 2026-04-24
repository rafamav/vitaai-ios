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
    /// ID da gravação que ACABOU de virar `ready` no pipeline cloud. Sinaliza
    /// pra UI abrir o sheet de detalhes automaticamente (pattern Otter: "sua
    /// gravação tá pronta"). View consome e reseta pra nil. Só dispara se
    /// user ainda está na tela (observer responde ou não).
    var justCompletedRecordingId: String? = nil
    /// Quando `true` (default): áudio sobe pro R2 + Whisper + LLM resumo/flashcards.
    /// Quando `false`: áudio fica só no device (Documents/audios/), user pode
    /// promover pra cloud depois via botão "Transcrever agora". Util pra rascunho
    /// rápido, conteúdo sensível ou gravação sem wifi.
    var transcribeWithAI: Bool = true
    /// Gravações salvas só no device (quando transcribeWithAI=false). Carregadas
    /// por `loadLocalRecordings()` e merged com `recordings` na UI.
    private(set) var localRecordings: [LocalRecording] = []
    /// User negou permissão do mic/speech — mostra banner sutil em vez de
    /// jogar a UI toda pra phase=.error (que antes fazia a tela virar um
    /// erro gigante toda vez que o user clicava "Não Permitir").
    var permissionBanner: String? = nil
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
    private var recordingStartDate = Date()
    /// Preferred live streaming client (WhisperLiveKit via WS). Ativado quando
    /// `AppConfig.whisperLiveWSURL` não tá vazio (DEBUG sempre, prod depende
    /// de ter proxy público autenticado). Quando nil, cai no
    /// SFSpeechRecognizer local (fallback).
    private var liveStreamClient: WhisperLiveClient?

    init(client: TranscricaoClient, api: VitaAPI? = nil, gamificationEvents: GamificationEventManager? = nil) {
        self.client = client
        self.api = api
        self.gamificationEvents = gamificationEvents
    }

    // MARK: - Public API

    /// Debounce timestamp — SwiftUI dispara `.task`/`.onAppear` múltiplas vezes
    /// em sheet dismiss, layout recalc, tab switch. Sem debounce, user via abrir
    /// tela disparava 6 requests iguais em sequência (incident 2026-04-23).
    private var lastLoadAt: Date = .distantPast

    /// Load saved recordings from the API. Debounced 2s; `force: true` pula
    /// o debounce (pull-to-refresh, callback pós-completion).
    func loadRecordings(force: Bool = false) async {
        // Local recordings first — disk access é sync e instantâneo, não faz
        // sentido esperar o network pra mostrar o que já existe no device.
        loadLocalRecordings()

        guard let api else { return }
        if !force && Date().timeIntervalSince(lastLoadAt) < 2 {
            NSLog("[TranscricaoVM] loadRecordings debounced (last=%.1fs)", Date().timeIntervalSince(lastLoadAt))
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
            // Não joga a UI pra .error — user pode só ter clicado "Não
            // Permitir" por acidente. Mostra um banner sutil no topo do
            // recorder com CTA "Abrir Ajustes" (Screen resolve o action).
            permissionBanner = "Ative microfone e reconhecimento de voz em Ajustes pra gravar."
            return
        }
        permissionBanner = nil

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

        // Gold standard (Otter/Airgram/Voice Memos): gravação termina →
        // card aparece na lista em <100ms. Pipeline cloud roda em background
        // silencioso. User NUNCA fica preso numa tela de "enviando áudio...".
        //
        // 1. Sempre salva local primeiro (checkpoint — se app crashar no meio
        //    do upload, o áudio não é perdido).
        // 2. phase → .done imediato.
        // 3. Se transcribeWithAI: Task background sobe pro R2 + Whisper + LLM,
        //    atualizando localRecordings[i].cloudStatus durante o caminho.
        //    Quando `ready`, a entry migra pra lista cloud e é removida local.
        let title = Self.defaultTitleForNow()
        let duration = Int(Date().timeIntervalSince(recordingStartDate))
        let localRec: LocalRecording
        do {
            localRec = try TranscricaoLocalStore.shared.save(
                tempURL: url,
                title: title,
                durationSeconds: duration,
                language: selectedLanguage,
                discipline: selectedDiscipline == "Auto-detectar" ? nil : selectedDiscipline
            )
        } catch {
            setError("Não foi possível salvar: \(error.localizedDescription)")
            return
        }

        // Captura o transcript AO VIVO antes de resetar — passa pro upload
        // background. Backend usa fast-path /ai/transcribe/from-live e pula
        // Whisper (economia 2-9s/áudio). Vazio = pipeline completo.
        let capturedLive = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)

        recordingURL = nil
        phase = .idle
        elapsedSeconds = 0
        liveTranscript = ""
        audioLevels = Array(repeating: 0, count: Self.waveformBarCount)
        loadLocalRecordings()

        if transcribeWithAI {
            VitaPostHogConfig.capture(event: "transcription_upload_started", properties: [
                "file_size_mb": Double(localRec.fileSize) / 1_048_576.0,
                "duration_seconds": duration,
                "background": true,
                "has_live_transcript": !capturedLive.isEmpty,
            ])
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.uploadLocalInBackground(id: localRec.id, liveTranscript: capturedLive)
            }
        } else {
            VitaPostHogConfig.capture(event: "transcription_saved_local", properties: [
                "duration_seconds": duration,
                "file_size_mb": Double(localRec.fileSize) / 1_048_576.0,
            ])
        }
    }

    /// Remove a recording from the local list (optimistic delete)
    func removeRecordingLocally(id: String) {
        recordings.removeAll { $0.id == id }
        localRecordings.removeAll { $0.id == id }
    }

    // MARK: - Local recordings (rascunhos + uploads em background)

    /// Recarrega a lista de gravações locais do disco. Marca como failed
    /// uploads em voo há mais de 5min (provavelmente zombies de sessões
    /// anteriores que crasharam no meio do pipeline).
    func loadLocalRecordings() {
        var list = TranscricaoLocalStore.shared.loadAll()
        let now = Date()
        for (i, rec) in list.enumerated() {
            let inFlight = rec.cloudStatus == "uploading"
                || rec.cloudStatus == "transcribing"
                || rec.cloudStatus == "summarizing"
                || rec.cloudStatus == "generating_flashcards"
            if inFlight && now.timeIntervalSince(rec.createdAt) > 300 {
                list[i].cloudStatus = "failed"
                try? TranscricaoLocalStore.shared.updateCloudStatus(id: rec.id, status: "failed")
            }
        }
        localRecordings = list
    }

    /// Promove uma gravação local pro pipeline cloud (user clicou "Transcrever
    /// agora" num rascunho puro). Roda em background, sem bloquear a UI.
    func promoteLocalToCloud(id: String) async {
        guard TranscricaoLocalStore.shared.fileURL(for: id) != nil else {
            setError("Arquivo local não encontrado.")
            return
        }
        await uploadLocalInBackground(id: id, liveTranscript: "")
    }

    /// Pipeline cloud silencioso — sobe áudio pro R2 + dispara Whisper + LLM
    /// atualizando `cloudStatus` no LocalStore durante o caminho. UI se
    /// atualiza porque `loadLocalRecordings()` é chamado a cada transição.
    ///
    /// Quando termina com `ready`: deleta entry local + refresh cloud list.
    /// Se falha: marca `cloudStatus="failed"` — user vê badge vermelho no card
    /// e pode tentar de novo pelo menu.
    func uploadLocalInBackground(id: String, liveTranscript: String = "") async {
        guard let fileURL = TranscricaoLocalStore.shared.fileURL(for: id) else {
            NSLog("[TranscricaoVM] uploadLocalInBackground: arquivo sumiu id=%@", id)
            return
        }
        try? TranscricaoLocalStore.shared.updateCloudStatus(id: id, status: "uploading")
        loadLocalRecordings()

        let uploadStart = Date()
        var finalStatus = "ready"
        var sourceIdSeen: String?
        do {
            for try await event in await client.uploadAndStream(
                fileURL: fileURL,
                language: localRecordings.first(where: { $0.id == id })?.language ?? selectedLanguage,
                discipline: localRecordings.first(where: { $0.id == id })?.discipline ?? selectedDiscipline,
                liveTranscript: liveTranscript,
                durationSeconds: localRecordings.first(where: { $0.id == id })?.durationSeconds ?? 0
            ) {
                switch event {
                case .progress(let stage, _):
                    let mapped = backgroundStatusFromStage(stage)
                    try? TranscricaoLocalStore.shared.updateCloudStatus(id: id, status: mapped)
                    loadLocalRecordings()
                case .uploadProgress(let pct):
                    try? TranscricaoLocalStore.shared.updateUploadProgress(id: id, pct: pct)
                    loadLocalRecordings()
                case .sourceCreated(let cloudId):
                    sourceIdSeen = cloudId
                    try? TranscricaoLocalStore.shared.updateCloudStatus(id: id, status: "uploading", sourceId: cloudId)
                    loadLocalRecordings()
                case .complete(let t, let s, let cards):
                    try? TranscricaoLocalStore.shared.updateCloudStatus(id: id, status: "ready", sourceId: sourceIdSeen)
                    VitaPostHogConfig.capture(event: "transcription_completed", properties: [
                        "word_count": t.split(separator: " ").count,
                        "flashcards_generated": cards.count,
                        "seconds_elapsed": Int(Date().timeIntervalSince(uploadStart)),
                        "background": true,
                    ])
                    _ = s
                case .error(let msg):
                    finalStatus = "failed"
                    try? TranscricaoLocalStore.shared.updateCloudStatus(id: id, status: "failed")
                    loadLocalRecordings()
                    VitaPostHogConfig.capture(event: "transcription_upload_failed", properties: [
                        "reason": msg,
                        "background": true,
                    ])
                }
            }
        } catch {
            finalStatus = "failed"
            try? TranscricaoLocalStore.shared.updateCloudStatus(id: id, status: "failed")
            loadLocalRecordings()
            VitaPostHogConfig.capture(event: "transcription_upload_failed", properties: [
                "reason": error.localizedDescription,
                "background": true,
            ])
        }

        if finalStatus == "ready" {
            // Cloud virou a fonte única — apaga a cópia local e refresh a lista
            // cloud pra mostrar a entry nova.
            let duration = localRecordings.first(where: { $0.id == id })?.durationSeconds ?? 0
            try? TranscricaoLocalStore.shared.delete(id: id)
            loadLocalRecordings()
            await loadRecordings(force: true)

            // Sinaliza pra UI abrir sheet de detalhes automaticamente
            // (pattern Otter/Airgram "sua gravação tá pronta"). Usa o sourceId
            // retornado pelo backend — é o mesmo ID do objeto TranscricaoEntry
            // que vai aparecer em `recordings` após o refresh acima.
            if let sourceId = sourceIdSeen {
                await MainActor.run { justCompletedRecordingId = sourceId }
            }

            // Gamification: study session log (mesmo que processUpload antigo fazia).
            let durationMinutes = duration / 60
            if let api, let gamificationEvents, durationMinutes > 0 {
                if let result = try? await api.logActivity(
                    action: "study_session_end",
                    metadata: ["durationMinutes": String(durationMinutes)]
                ) {
                    await gamificationEvents.handleActivityResponse(result, previousLevel: nil)
                }
            }
        }
    }

    private func backgroundStatusFromStage(_ stage: String) -> String {
        let lower = stage.lowercased()
        if lower.contains("transcri") { return "transcribing" }
        if lower.contains("resum") { return "summarizing" }
        if lower.contains("flash") { return "generating_flashcards" }
        return "uploading"
    }

    /// Apaga gravação local (m4a + index entry). Irreversível.
    func deleteLocalRecording(id: String) {
        do {
            try TranscricaoLocalStore.shared.delete(id: id)
            loadLocalRecordings()
        } catch {
            NSLog("[TranscricaoVM] deleteLocalRecording failed: %@", "\(error)")
        }
    }

    /// Renomeia gravação local.
    func renameLocalRecording(id: String, newTitle: String) {
        do {
            try TranscricaoLocalStore.shared.rename(id: id, to: newTitle)
            loadLocalRecordings()
        } catch {
            NSLog("[TranscricaoVM] renameLocalRecording failed: %@", "\(error)")
        }
    }

    /// "Gravação DD/MM HH:MM" — mesmo formato que o backend gera no deriveTitle.
    static func defaultTitleForNow() -> String {
        let now = Date()
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "pt_BR")
        fmt.dateFormat = "dd/MM HH:mm"
        return "Gravação \(fmt.string(from: now))"
    }

    func reset() {
        timerTask?.cancel()
        timerTask = nil
        endAudioCapture()
        if let url = recordingURL { try? FileManager.default.removeItem(at: url) }
        recordingURL = nil
        phase = .idle
        elapsedSeconds = 0
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

        // SFSpeechRecognizer for live partial transcript (fallback quando
        // WhisperLiveKit WS não está configurado; em DEBUG sempre conecta
        // no nosso whisper-live que usa large-v3-turbo, melhor qualidade).
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        recognitionRequest = request

        // WhisperLiveKit WS client — preferred path. Se AppConfig.whisperLiveWSURL
        // estiver vazio (prod sem proxy público hoje), o init retorna nil e a
        // gente cai só no SFSpeechRecognizer.
        let wsClient = WhisperLiveClient()
        if let wsClient {
            wsClient.onPartial = { [weak self] text in
                self?.liveTranscript = text
            }
            wsClient.onFinal = { [weak self] text in
                self?.liveTranscript = text
            }
            wsClient.onError = { msg in
                NSLog("[TranscricaoVM] whisper-live WS error: %@", msg)
            }
            wsClient.connect()
            liveStreamClient = wsClient
            NSLog("[TranscricaoVM] WhisperLiveKit WS conectado")
        } else {
            NSLog("[TranscricaoVM] WhisperLiveKit URL vazia — fallback SFSpeechRecognizer")
            liveStreamClient = nil
        }

        // Single tap: write samples to disk, feed speech recognizer, feed
        // whisper-live WS, and compute waveform power for the live bars.
        let clientRef = liveStreamClient
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [outputFile, request, weak self] buffer, _ in
            try? outputFile.write(from: buffer)
            request.append(buffer)
            let level = Self.averageLevel(buffer)
            Task { @MainActor [weak self] in
                self?.appendAudioLevel(level)
                clientRef?.sendAudio(buffer: buffer)
            }
        }

        try engine.start()
        audioEngine = engine

        // Recognition task — updates live transcript only (does NOT control recording stop)
        let authStatus = SFSpeechRecognizer.authorizationStatus()
        let authLabel: String
        switch authStatus {
        case .notDetermined: authLabel = "notDetermined"
        case .denied: authLabel = "denied"
        case .restricted: authLabel = "restricted"
        case .authorized: authLabel = "authorized"
        @unknown default: authLabel = "unknown"
        }
        NSLog("[TranscricaoVM] speech auth=%@ recognizer=%@ available=%@ onDeviceSupported=%@",
              authLabel,
              recognizer == nil ? "nil" : "ok",
              String(describing: recognizer?.isAvailable ?? false),
              String(describing: recognizer?.supportsOnDeviceRecognition ?? false))

        // NÃO força on-device: iOS Simulator tem bug conhecido onde o asset
        // Siri Understanding vem incompleto e kLSRErrorDomain=300 fecha o
        // recognizer silencioso. Deixa Apple escolher — device real usa
        // on-device automático, sim cai pro cloud (requer rede).
        request.requiresOnDeviceRecognition = false

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let error {
                NSLog("[TranscricaoVM] speech recognition error: %@", "\(error)")
                return
            }
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            Task { @MainActor [weak self] in
                self?.liveTranscript = text
            }
        }
        if recognitionTask == nil {
            NSLog("[TranscricaoVM] recognitionTask is nil — recognizer rejeitou silenciosamente")
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
        liveStreamClient?.close()
        liveStreamClient = nil
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


    private func setError(_ msg: String) {
        phase = .error
        errorMessage = msg
    }
}
