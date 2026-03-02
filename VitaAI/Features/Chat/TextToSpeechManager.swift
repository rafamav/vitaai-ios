import Foundation
import AVFoundation

// MARK: - TextToSpeechManager
// iOS equivalent of Android's VitaTtsEngine.
// Uses AVSpeechSynthesizer with pt-BR voice.
// Interruptible — stops immediately when stop() is called (e.g. user taps mic).

@MainActor
@Observable
final class TextToSpeechManager: NSObject {

    // MARK: - State

    private(set) var isSpeaking: Bool = false

    // MARK: - Private

    private let synthesizer = AVSpeechSynthesizer()
    private var preferredVoice: AVSpeechSynthesisVoice?

    // MARK: - Init

    override init() {
        super.init()
        synthesizer.delegate = self
        preferredVoice = bestPtBRVoice()
    }

    // MARK: - Speak

    /// Speak a single utterance. Stops any current speech first.
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stop()
        activateAudioSession()

        let utterance = makeUtterance(trimmed)
        synthesizer.speak(utterance)
    }

    /// Splits text on sentence boundaries and speaks sequentially.
    /// Matches Android's speakChunked() behavior for long AI responses.
    func speakChunked(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        stop()
        activateAudioSession()

        let parts = splitIntoSentences(trimmed)
        for part in parts {
            let utterance = makeUtterance(part)
            synthesizer.speak(utterance)
        }
    }

    /// Stop current speech immediately.
    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
    }

    // MARK: - Private Helpers

    private func splitIntoSentences(_ text: String) -> [String] {
        // Split on sentence-ending punctuation followed by whitespace.
        // Mirrors Android's split regex: "(?<=[.?!\\n])\\s+"
        var sentences: [String] = []
        var current = ""

        for char in text {
            current.append(char)
            if (char == "." || char == "?" || char == "!" || char == "\n") {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    sentences.append(trimmed)
                }
                current = ""
            }
        }

        // Append any remaining text
        let remaining = current.trimmingCharacters(in: .whitespaces)
        if !remaining.isEmpty {
            sentences.append(remaining)
        }

        return sentences.isEmpty ? [text] : sentences
    }

    private func makeUtterance(_ text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = preferredVoice
        utterance.rate = 0.52           // Slightly above default 0.5 — matches Android's 1.1x rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        return utterance
    }

    private func bestPtBRVoice() -> AVSpeechSynthesisVoice? {
        let ptBRVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("pt-BR") }

        // Prefer enhanced quality voice
        if let enhanced = ptBRVoices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        // Any pt-BR voice
        if let any = ptBRVoices.first {
            return any
        }
        // System default pt-BR
        return AVSpeechSynthesisVoice(language: "pt-BR")
    }

    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? session.setActive(true)
    }
}

// MARK: - AVSpeechSynthesizerDelegate

extension TextToSpeechManager: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = true
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            // Only set isSpeaking = false when the entire queue is done
            if !synthesizer.isSpeaking {
                self.isSpeaking = false
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}
