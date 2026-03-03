import AVFoundation
import Speech
import SwiftUI

// MARK: - VitaVoiceInput
//
// Native voice input button using SFSpeechRecognizer (Speech framework).
// States: idle → recording (pulsing red mic) → transcribing (spinner) → done
// Waveform animation: concentric pulsing circles during recording (Siri-style).
//
// Android reference: VitaVoiceInput.kt (VoiceInputButton + PulsingRing).
// iOS extends with Siri-style waveform and SFSpeechRecognizer integration.

// MARK: - State

enum VoiceInputState: Equatable {
    case idle
    case requestingPermission
    case recording
    case transcribing
    case done(text: String)
    case error(message: String)
}

// MARK: - VitaVoiceInput (Full Component)

/// Full-featured voice input button with animated waveform.
/// Embeds SFSpeechRecognizer and AVAudioEngine internally.
@MainActor
struct VitaVoiceInput: View {
    /// Called with the final transcribed text when recognition finishes.
    let onTranscript: (String) -> Void
    /// Optional: called on permission denial.
    var onPermissionDenied: (() -> Void)? = nil

    @State private var machine = VoiceInputMachine()

    var body: some View {
        Button {
            Task { await machine.toggle(onTranscript: onTranscript, onPermissionDenied: onPermissionDenied) }
        } label: {
            ZStack {
                // Waveform rings (only when recording)
                if machine.state == .recording {
                    WaveformRings()
                }

                // Button background
                Circle()
                    .fill(buttonBackground)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle()
                            .stroke(buttonBorder, lineWidth: 1)
                    )

                // Icon / spinner
                buttonContent
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)                  // 44pt touch target
        .accessibilityLabel(accessibilityLabel)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: machine.state == .recording)
    }

    // MARK: Appearance helpers

    private var isActive: Bool {
        machine.state == .recording || machine.state == .transcribing
    }

    private var buttonBackground: Color {
        switch machine.state {
        case .recording:    return VitaColors.dataRed.opacity(0.15)
        case .transcribing: return VitaColors.accent.opacity(0.1)
        default:            return VitaColors.glassBg
        }
    }

    private var buttonBorder: Color {
        switch machine.state {
        case .recording:    return VitaColors.dataRed.opacity(0.4)
        case .transcribing: return VitaColors.accent.opacity(0.3)
        default:            return VitaColors.glassBorder
        }
    }

    @ViewBuilder
    private var buttonContent: some View {
        switch machine.state {
        case .transcribing:
            ProgressView()
                .tint(VitaColors.accent)
                .scaleEffect(0.75)

        case .recording:
            Image(systemName: "stop.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VitaColors.dataRed)

        default:
            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(VitaColors.textSecondary)
        }
    }

    private var accessibilityLabel: String {
        switch machine.state {
        case .recording:    return "Parar gravação"
        case .transcribing: return "Transcrevendo..."
        default:            return "Falar"
        }
    }
}

// MARK: - Waveform Rings (Siri-style)

/// Three concentric pulsing circles that animate when recording.
private struct WaveformRings: View {
    @State private var phase: Double = 0

    private let rings: [(delay: Double, maxScale: CGFloat, opacity: Double)] = [
        (0.0, 1.6, 0.35),
        (0.2, 1.9, 0.20),
        (0.4, 2.2, 0.10),
    ]

    var body: some View {
        ForEach(Array(rings.enumerated()), id: \.offset) { index, ring in
            Circle()
                .stroke(VitaColors.dataRed, lineWidth: 1.5)
                .frame(width: 40, height: 40)
                .scaleEffect(ringScale(index: index))
                .opacity(ringOpacity(index: index))
                .animation(
                    .easeInOut(duration: 0.8)
                        .repeatForever(autoreverses: true)
                        .delay(ring.delay),
                    value: phase
                )
        }
        .onAppear { phase = 1 }
    }

    private func ringScale(index: Int) -> CGFloat {
        let target = rings[index].maxScale
        return phase > 0 ? target : 1.0
    }

    private func ringOpacity(index: Int) -> Double {
        let target = rings[index].opacity
        return phase > 0 ? target : 0
    }
}

// MARK: - VoiceInputMachine

/// State machine + SFSpeechRecognizer logic. @Observable for SwiftUI reactivity.
@Observable
@MainActor
final class VoiceInputMachine {
    private(set) var state: VoiceInputState = .idle

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))

    // MARK: Toggle

    func toggle(
        onTranscript: @escaping (String) -> Void,
        onPermissionDenied: (() -> Void)?
    ) async {
        switch state {
        case .recording:
            stopRecording()
        case .idle, .done, .error:
            await startIfPermitted(onTranscript: onTranscript, onPermissionDenied: onPermissionDenied)
        default:
            break
        }
    }

    // MARK: Permission + Start

    private func startIfPermitted(
        onTranscript: @escaping (String) -> Void,
        onPermissionDenied: (() -> Void)?
    ) async {
        state = .requestingPermission

        // Check microphone permission
        let micStatus = AVAudioApplication.shared.recordPermission
        if micStatus == .denied {
            state = .error(message: "Microfone bloqueado. Ative nas configurações.")
            onPermissionDenied?()
            return
        }
        if micStatus == .undetermined {
            let granted = await AVAudioApplication.requestRecordPermission()
            guard granted else {
                state = .idle
                onPermissionDenied?()
                return
            }
        }

        // Check speech recognition permission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        if speechStatus == .denied || speechStatus == .restricted {
            state = .error(message: "Reconhecimento de voz bloqueado.")
            onPermissionDenied?()
            return
        }
        if speechStatus == .notDetermined {
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
            guard granted else {
                state = .idle
                onPermissionDenied?()
                return
            }
        }

        startRecording(onTranscript: onTranscript)
    }

    // MARK: Recording

    private func startRecording(onTranscript: @escaping (String) -> Void) {
        guard let recognizer, recognizer.isAvailable else {
            state = .error(message: "Reconhecimento de voz indisponível.")
            return
        }

        let engine = AVAudioEngine()
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            try engine.start()
        } catch {
            state = .error(message: "Erro ao iniciar áudio: \(error.localizedDescription)")
            return
        }

        audioEngine = engine
        recognitionRequest = request

        var finalText = ""

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result {
                finalText = result.bestTranscription.formattedString

                // On iOS, isFinal triggers when silence is detected
                if result.isFinal {
                    self.finishRecording()
                    if !finalText.isEmpty {
                        onTranscript(finalText)
                        self.state = .done(text: finalText)
                        // Auto-reset to idle after 1.5s
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.5))
                            if case .done = self.state { self.state = .idle }
                        }
                    } else {
                        self.state = .idle
                    }
                }
            }

            if let error {
                let nsError = error as NSError
                // Code 1110 = "No speech detected" — not a real error
                if nsError.code != 1110 {
                    self.state = .error(message: error.localizedDescription)
                    self.finishRecording()
                }
            }
        }

        state = .recording
    }

    private func stopRecording() {
        state = .transcribing
        recognitionRequest?.endAudio()
        // Recognition task will call finalResult and update state
    }

    private func finishRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recognitionTask = nil
        recognitionRequest = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }
}

// MARK: - Convenience Button (compact for chat input)

/// Standalone mic button for embedding directly in input bars.
/// Lighter than VitaVoiceInput — no waveform overlay, smaller footprint.
struct VitaMicButton: View {
    @Binding var isListening: Bool
    let onTranscript: (String) -> Void
    var onPermissionDenied: (() -> Void)? = nil

    @State private var machine = VoiceInputMachine()
    @State private var pulsePhase: Double = 0

    var body: some View {
        Button {
            Task {
                await machine.toggle(onTranscript: { text in
                    onTranscript(text)
                    isListening = false
                }, onPermissionDenied: onPermissionDenied)
            }
        } label: {
            ZStack {
                // Pulsing ring (Android-equivalent: PulsingRing composable)
                if machine.state == .recording {
                    Circle()
                        .stroke(VitaColors.dataRed.opacity(0.3 * (1 - pulsePhase * 0.5)), lineWidth: 1)
                        .frame(width: 36, height: 36)
                        .scaleEffect(1.0 + pulsePhase * 0.4)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: pulsePhase
                        )
                }

                Image(systemName: machine.state == .recording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(machine.state == .recording ? VitaColors.dataRed : VitaColors.textSecondary)
                    .frame(width: 40, height: 40)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(machine.state == .recording ? "Parar gravação" : "Falar")
        .onChange(of: machine.state) { _, newState in
            isListening = newState == .recording
            if newState == .recording {
                withAnimation { pulsePhase = 1 }
            } else {
                withAnimation { pulsePhase = 0 }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Voice Input Button") {
    VStack(spacing: 32) {
        Text("Toque no microfone e fale")
            .font(VitaTypography.bodyMedium)
            .foregroundStyle(VitaColors.textSecondary)

        VitaVoiceInput { text in
            print("Transcribed: \(text)")
        }

        Text("Compact mic:")
            .foregroundStyle(VitaColors.textSecondary)

        HStack {
            TextField("Pergunte...", text: .constant(""))
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textPrimary)
            VitaMicButton(isListening: .constant(false)) { text in
                print(text)
            }
        }
        .padding(12)
        .background(VitaColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VitaColors.glassBorder))
        .padding(.horizontal, 20)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(VitaColors.surface)
    .preferredColorScheme(.dark)
}
#endif
