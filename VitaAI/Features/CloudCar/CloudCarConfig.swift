import Foundation

// MARK: - CloudCar Configuration
//
// CloudCar is a CarPlay-first voice terminal that streams microphone audio
// over WebSocket to a remote agent gateway (CloudCode running on the user's
// PC or in the cloud). The phone app is a pure I/O bridge: capture audio,
// transmit, receive text/audio, play back. The "brain" lives on the gateway.
//
// This config object centralises gateway URL, auth token, and audio format
// parameters. Defaults are dev-friendly (loopback) and can be overridden at
// runtime via UserDefaults from the in-app settings screen.

enum CloudCarConfig {

    // MARK: - Storage Keys

    private enum Keys {
        static let gatewayURL = "cloudcar_gateway_url"
        static let authToken = "cloudcar_auth_token"
        static let autoConnect = "cloudcar_auto_connect"
        static let preferLocalTTS = "cloudcar_prefer_local_tts"
    }

    // MARK: - Defaults

    /// Default WebSocket URL for the agent gateway. Dev points at the local
    /// monstro tunnel; prod points at the public CloudCar gateway. Either can
    /// be overridden from the in-app settings screen.
    #if DEBUG
    static let defaultGatewayURL = "ws://monstro.tail7e98e6.ts.net:3120/agent"
    #else
    static let defaultGatewayURL = "wss://cloudcar.vita-ai.cloud/agent"
    #endif

    // MARK: - Audio Format
    //
    // PCM 16-bit signed little-endian, 16 kHz mono. This is the lowest common
    // denominator for STT engines (Whisper, Deepgram, etc.) and keeps the
    // wire format trivial — no Opus encoder dependency in V1.

    static let sampleRate: Double = 16_000
    static let channelCount: UInt32 = 1
    static let bitsPerSample: UInt32 = 16

    /// Chunk size for streaming. ~100ms of audio at 16kHz mono 16-bit
    /// = 16000 * 0.1 * 2 = 3200 bytes. Small enough for low latency,
    /// large enough to avoid WebSocket frame overhead.
    static let chunkBytes = 3_200

    // MARK: - Connection

    /// Initial reconnect delay in seconds. Doubles up to maxReconnectDelay.
    static let initialReconnectDelay: TimeInterval = 1
    static let maxReconnectDelay: TimeInterval = 30

    /// Idle ping interval to keep WebSocket alive through carrier NATs.
    static let pingInterval: TimeInterval = 20

    // MARK: - Runtime Overrides

    static var gatewayURL: String {
        get {
            let stored = UserDefaults.standard.string(forKey: Keys.gatewayURL)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let stored, !stored.isEmpty { return stored }
            return defaultGatewayURL
        }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                UserDefaults.standard.removeObject(forKey: Keys.gatewayURL)
            } else {
                UserDefaults.standard.set(trimmed, forKey: Keys.gatewayURL)
            }
        }
    }

    /// Optional bearer token for the agent gateway. When present, the client
    /// sends `Authorization: Bearer <token>` on the WebSocket upgrade request.
    /// Falls back to the VitaAI session cookie if not set, allowing reuse of
    /// the existing better-auth session.
    static var authToken: String? {
        get {
            let stored = UserDefaults.standard.string(forKey: Keys.authToken)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return (stored?.isEmpty == false) ? stored : nil
        }
        set {
            if let value = newValue?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                UserDefaults.standard.set(value, forKey: Keys.authToken)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.authToken)
            }
        }
    }

    /// Auto-connect on CarPlay scene attach. Defaults to true so the driver
    /// never has to fish for the phone — connection comes up with the car.
    static var autoConnect: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.autoConnect) == nil { return true }
            return UserDefaults.standard.bool(forKey: Keys.autoConnect)
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.autoConnect) }
    }

    /// When true, synthesise responses on-device with AVSpeechSynthesizer.
    /// When false, the client expects audio chunks back from the server.
    static var preferLocalTTS: Bool {
        get {
            if UserDefaults.standard.object(forKey: Keys.preferLocalTTS) == nil { return true }
            return UserDefaults.standard.bool(forKey: Keys.preferLocalTTS)
        }
        set { UserDefaults.standard.set(newValue, forKey: Keys.preferLocalTTS) }
    }
}
