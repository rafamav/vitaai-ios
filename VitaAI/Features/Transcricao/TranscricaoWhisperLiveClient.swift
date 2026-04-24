import Foundation
import AVFoundation

/// WebSocket client que streamava PCM 16kHz 16bit mono pro backend
/// WhisperLiveKit rodando no monstro (porta 8791, path `/asr`).
///
/// Protocolo:
/// - iOS abre WebSocket.
/// - Envia áudio raw (PCM s16le) em chunks binários conforme chegam do
///   AudioEngine (downsampled pra 16kHz mono).
/// - Server retorna mensagens JSON:
///   `{"type": "transcription", "text": "...", "is_final": bool}`
///   `{"type": "error", "message": "..."}`
///
/// Uso:
/// ```swift
/// let client = WhisperLiveClient()
/// client.onPartial = { text in viewModel.liveTranscript = text }
/// try client.connect()
/// // enquanto grava:
/// client.sendAudio(buffer: pcmBuffer)
/// // stop:
/// client.close()
/// ```
@MainActor
final class WhisperLiveClient {
    enum State { case idle, connecting, connected, closing, closed, failed }

    private(set) var state: State = .idle
    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var task: URLSessionWebSocketTask?
    private let session: URLSession
    private let endpoint: URL
    /// Target sample rate do WhisperLiveKit (PCM 16bit mono 16kHz).
    private let targetSampleRate: Double = 16000
    private var converter: AVAudioConverter?
    private var converterSource: AVAudioFormat?

    init?(endpoint: URL? = nil) {
        let resolved: URL? = endpoint ?? {
            let s = AppConfig.whisperLiveWSURL
            return s.isEmpty ? nil : URL(string: s)
        }()
        guard let resolved else { return nil }
        self.endpoint = resolved
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: cfg)
    }

    func connect() {
        guard state == .idle || state == .closed || state == .failed else { return }
        state = .connecting
        var req = URLRequest(url: endpoint)
        req.setValue("audio/pcm", forHTTPHeaderField: "X-Audio-Format")
        task = session.webSocketTask(with: req)
        task?.resume()
        state = .connected
        listen()
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            Task { @MainActor in
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let s): self.handleMessage(s)
                    case .data(let d):
                        if let s = String(data: d, encoding: .utf8) {
                            self.handleMessage(s)
                        }
                    @unknown default: break
                    }
                    self.listen()
                case .failure(let err):
                    NSLog("[WhisperLive] WS receive failed: %@", "\(err)")
                    self.state = .failed
                    self.onError?(err.localizedDescription)
                }
            }
        }
    }

    private func handleMessage(_ json: String) {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Tipo "config" vem uma vez ao abrir — ignorar silenciosamente.
        // Tipo "ready_to_stop" quando server terminou de processar.
        if let type = obj["type"] as? String {
            if type == "config" || type == "ready_to_stop" { return }
            if type == "error" {
                onError?(obj["message"] as? String ?? "server error")
                return
            }
        }

        // Payload de transcrição real:
        //   { "status": "...",
        //     "lines": [{"speaker": 1, "text": "...", "start": "00:00:01"}, ...],
        //     "buffer_transcription": "partial here",
        //     ... }
        // Finais = concat dos lines[].text. Parcial = buffer_transcription.
        let lines = (obj["lines"] as? [[String: Any]]) ?? []
        let finalText = lines
            .compactMap { $0["text"] as? String }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let buffer = (obj["buffer_transcription"] as? String) ?? ""

        // Display: linhas finalizadas + buffer parcial em andamento.
        let combined = [finalText, buffer]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .joined(separator: " ")

        if !combined.isEmpty {
            // Só emite onFinal quando buffer some (fluxo terminou ou pausa longa).
            if buffer.isEmpty && !finalText.isEmpty {
                onFinal?(finalText)
            } else {
                onPartial?(combined)
            }
        }
    }

    /// Converte buffer do AVAudioEngine (qualquer SR, 1-2 canais, Float32) pra
    /// PCM 16bit mono 16kHz e envia pro WS.
    private var sendCount = 0
    func sendAudio(buffer: AVAudioPCMBuffer) {
        guard state == .connected else { return }
        guard let pcm16 = downsampleTo16kMono(buffer) else {
            NSLog("[WhisperLive] downsample returned nil (sr=%.0f ch=%d frames=%d)",
                  buffer.format.sampleRate, buffer.format.channelCount, buffer.frameLength)
            return
        }
        sendCount += 1
        // Log a cada ~20 chunks (~0.5s se 10Hz cadence): sample count + pico.
        if sendCount % 20 == 1 {
            var peak: Int16 = 0
            pcm16.withUnsafeBytes { raw in
                let ptr = raw.bindMemory(to: Int16.self)
                for v in ptr {
                    let m = v < 0 ? -v : v
                    if m > peak { peak = m }
                }
            }
            NSLog("[WhisperLive] sent chunk #%d bytes=%d peak_int16=%d (silence<200)",
                  sendCount, pcm16.count, peak)
        }
        task?.send(.data(pcm16)) { err in
            if let err { NSLog("[WhisperLive] WS send failed: %@", "\(err)") }
        }
    }

    private func downsampleTo16kMono(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let inFormat = buffer.format.sampleRate > 0 ? buffer.format : nil else { return nil }
        guard let outFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: true
        ) else { return nil }

        // Reuse converter se o source format não mudou.
        if converter == nil || converterSource != inFormat {
            converter = AVAudioConverter(from: inFormat, to: outFormat)
            converterSource = inFormat
        }
        guard let converter else { return nil }

        let ratio = outFormat.sampleRate / inFormat.sampleRate
        let outFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1
        guard let outBuffer = AVAudioPCMBuffer(
            pcmFormat: outFormat,
            frameCapacity: outFrameCapacity
        ) else { return nil }

        var fedInput = false
        var err: NSError?
        let status = converter.convert(to: outBuffer, error: &err) { _, outStatus in
            if fedInput {
                outStatus.pointee = .noDataNow
                return nil
            }
            fedInput = true
            outStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, err == nil else { return nil }

        let frames = Int(outBuffer.frameLength)
        guard let channelData = outBuffer.int16ChannelData?[0] else { return nil }
        return Data(bytes: channelData, count: frames * MemoryLayout<Int16>.size)
    }

    func close() {
        guard state == .connected || state == .connecting else { return }
        state = .closing
        task?.send(.string("{\"type\":\"close\"}")) { _ in }
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        state = .closed
    }
}
