import Foundation
import AVFoundation

// MARK: - CloudCarAudioEngine
//
// Captures microphone audio as PCM 16-bit @ 16 kHz mono and emits chunks
// suitable for direct base64 transmission. Also plays back PCM audio chunks
// received from the gateway, and exposes a TTS path via AVSpeechSynthesizer
// for gateways that return text-only responses.
//
// The class is @MainActor because AVAudioSession + AVAudioEngine touch UIKit
// state on activation; chunks are dispatched off-main via the onChunk
// callback so the WebSocket actor can drain them without blocking UI.

@MainActor
final class CloudCarAudioEngine: NSObject {

    // MARK: - Public surface

    typealias ChunkHandler = @Sendable (Data) -> Void

    private(set) var isCapturing = false
    private(set) var isSpeaking = false

    var onChunk: ChunkHandler?

    // MARK: - Internals

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let speechSynth = AVSpeechSynthesizer()

    /// Target capture format. Hardware input rarely comes back at 16 kHz, so
    /// we install a converter from the input node's native format to this.
    private lazy var captureFormat: AVAudioFormat = {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: CloudCarConfig.sampleRate,
            channels: CloudCarConfig.channelCount,
            interleaved: true
        )!
    }()

    /// AVAudioPlayerNode requires a non-interleaved float format on its
    /// output connection, so playback runs in Float32 even though the wire
    /// format is PCM16. We convert PCM16 → Float32 inside `playPCM`.
    private lazy var playbackFormat: AVAudioFormat = {
        AVAudioFormat(
            standardFormatWithSampleRate: CloudCarConfig.sampleRate,
            channels: CloudCarConfig.channelCount
        )!
    }()

    private var converter: AVAudioConverter?
    private var pendingChunk = Data()

    override init() {
        super.init()
        speechSynth.delegate = self
    }

    // MARK: - Session

    /// Configure the shared AVAudioSession for full-duplex voice over CarPlay.
    /// `.playAndRecord` with `.voiceChat` mode + `.allowBluetoothA2DP` routes
    /// audio through the car's speakers and microphone when CarPlay is active.
    func activateSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP, .duckOthers]
        )
        try session.setActive(true, options: [.notifyOthersOnDeactivation])
    }

    func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    // MARK: - Capture

    func startCapture() throws {
        guard !isCapturing else { return }
        try activateSession()

        // Make sure the player node is attached so the engine graph is
        // valid even before the first playback chunk arrives.
        if playerNode.engine == nil {
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: playbackFormat)
        }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        converter = AVAudioConverter(from: inputFormat, to: captureFormat)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
        isCapturing = true
    }

    func stopCapture() {
        guard isCapturing else { return }
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        isCapturing = false
        flushPending()
    }

    private func process(buffer: AVAudioPCMBuffer) {
        guard let converter else { return }

        let outFrameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * captureFormat.sampleRate / buffer.format.sampleRate
        ) + 1024
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: captureFormat, frameCapacity: outFrameCapacity) else {
            return
        }

        var error: NSError?
        var didProvide = false
        let status = converter.convert(to: outBuffer, error: &error) { _, inputStatus in
            if didProvide {
                inputStatus.pointee = .endOfStream
                return nil
            }
            didProvide = true
            inputStatus.pointee = .haveData
            return buffer
        }

        if status == .error || error != nil { return }
        guard let channelData = outBuffer.int16ChannelData?[0] else { return }
        let byteCount = Int(outBuffer.frameLength) * Int(captureFormat.streamDescription.pointee.mBytesPerFrame)
        let chunk = Data(bytes: channelData, count: byteCount)
        pendingChunk.append(chunk)
        drainPending()
    }

    private func drainPending() {
        let target = CloudCarConfig.chunkBytes
        while pendingChunk.count >= target {
            let slice = pendingChunk.prefix(target)
            pendingChunk.removeFirst(target)
            onChunk?(Data(slice))
        }
    }

    private func flushPending() {
        if !pendingChunk.isEmpty {
            onChunk?(pendingChunk)
            pendingChunk.removeAll(keepingCapacity: false)
        }
    }

    // MARK: - Playback (raw PCM from server)

    /// Append a PCM16 mono @ 16 kHz chunk to the playback queue. Starts the
    /// engine + player node lazily on first chunk. Converts to Float32 on
    /// the way in because AVAudioPlayerNode connects via a float format.
    func playPCM(_ data: Data) throws {
        if engine.attachedNodes.contains(playerNode) == false {
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: playbackFormat)
        }
        if !engine.isRunning {
            try activateSession()
            engine.prepare()
            try engine.start()
        }

        let int16FrameCount = data.count / MemoryLayout<Int16>.size
        guard int16FrameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: playbackFormat,
                                            frameCapacity: AVAudioFrameCount(int16FrameCount)) else { return }
        buffer.frameLength = AVAudioFrameCount(int16FrameCount)
        guard let dst = buffer.floatChannelData?[0] else { return }

        data.withUnsafeBytes { rawBuffer in
            guard let src = rawBuffer.bindMemory(to: Int16.self).baseAddress else { return }
            // Int16 [-32768, 32767] → Float32 [-1.0, 1.0]
            for i in 0..<int16FrameCount {
                dst[i] = Float(src[i]) / 32768.0
            }
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
        if !playerNode.isPlaying { playerNode.play() }
        isSpeaking = true
    }

    func stopPlayback() {
        if playerNode.isPlaying { playerNode.stop() }
        isSpeaking = false
    }

    // MARK: - TTS (local fallback)

    /// Speak a text response using the on-device synthesiser. Used when the
    /// gateway returns text-only or when CloudCarConfig.preferLocalTTS is on.
    func speak(_ text: String, language: String = "pt-BR") {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
            ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynth.speak(utterance)
        isSpeaking = true
    }

    func stopSpeaking() {
        if speechSynth.isSpeaking {
            speechSynth.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension CloudCarAudioEngine: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
