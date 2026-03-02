import SwiftUI

// MARK: - VoiceModeScreen
// Full-screen voice mode UI — iOS equivalent of Android's VoiceModeScreen.kt.
// 4 states: IDLE, LISTENING, THINKING, SPEAKING.
// Pulsing avatar animation matches Android's VoiceAvatar composable (scale + glow ring).
// Design tokens: VitaColors.* and VitaTypography.* throughout — zero hardcoded colors.

struct VoiceModeScreen: View {
    @State var viewModel: VoiceModeViewModel
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            // MARK: Background — matches Android vertical gradient
            LinearGradient(
                colors: [
                    VitaColors.surface,
                    VitaColors.accent.opacity(0.06),
                    VitaColors.surface,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Top bar — close button
                HStack {
                    Spacer()
                    Button {
                        viewModel.dismiss()
                        onDismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(VitaColors.glassBg)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle().stroke(VitaColors.glassBorder, lineWidth: 1)
                                )
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(VitaColors.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, VitaTokens.Spacing.xl)
                .padding(.top, VitaTokens.Spacing.lg)

                Spacer()

                // MARK: Center — pulsing avatar + status text
                VStack(spacing: VitaTokens.Spacing._2xl) {
                    VoiceAvatarView(status: viewModel.status)

                    VStack(spacing: VitaTokens.Spacing.sm) {
                        Text(statusTitle(viewModel.status))
                            .font(VitaTypography.titleLarge)
                            .foregroundStyle(VitaColors.accent)
                            .animation(.easeInOut(duration: VitaTokens.Animation.durationNormal), value: viewModel.status)

                        Text(statusSubtitle(viewModel.status))
                            .font(VitaTypography.bodyMedium)
                            .foregroundStyle(VitaColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut(duration: VitaTokens.Animation.durationNormal), value: viewModel.status)
                    }
                }

                Spacer()

                // MARK: Transcript + response text area
                VoiceTranscriptArea(viewModel: viewModel)
                    .padding(.horizontal, VitaTokens.Spacing._3xl)
                    .padding(.bottom, VitaTokens.Spacing._2xl)

                // MARK: Permission denied fallback
                if viewModel.permissionStatus == .denied || viewModel.permissionStatus == .micDenied {
                    PermissionDeniedView()
                        .padding(.bottom, VitaTokens.Spacing.xl)
                } else {
                    // MARK: Mic toggle button — bottom center
                    MicButton(viewModel: viewModel)
                        .padding(.bottom, 56)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
        .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.isListening)
    }

    // MARK: - Status Strings (matches Android string values)

    private func statusTitle(_ status: VoiceModeStatus) -> String {
        switch status {
        case .idle:      return "Modo voz"
        case .listening: return "Ouvindo..."
        case .thinking:  return "Pensando..."
        case .speaking:  return "Respondendo..."
        }
    }

    private func statusSubtitle(_ status: VoiceModeStatus) -> String {
        switch status {
        case .idle:      return "Toque no microfone para comecar"
        case .listening: return "Pode falar"
        case .thinking:  return "Aguarde a resposta"
        case .speaking:  return "A Vita esta falando"
        }
    }
}

// MARK: - VoiceAvatarView
// Pulsing concentric rings + inner circle with "V" label.
// Mirrors Android's VoiceAvatar composable: outer glow + middle ring + inner circle.
// Using .id(status) to force view recreation when status changes — ensures
// animations always restart cleanly with correct parameters.

private struct VoiceAvatarView: View {
    let status: VoiceModeStatus

    var body: some View {
        VoiceAvatarAnimatedCore(status: status)
            // Force recreation of the animated sub-view when status changes.
            // This is the canonical SwiftUI way to restart infinite animations
            // with different parameters (avoids mid-animation state confusion).
            .id(status)
    }
}

private struct VoiceAvatarAnimatedCore: View {
    let status: VoiceModeStatus

    private var targetScale: CGFloat {
        switch status {
        case .listening: return 1.15
        case .speaking:  return 1.20
        default:         return 1.0
        }
    }

    private var pulseDuration: Double {
        switch status {
        case .listening: return 0.8
        case .speaking:  return 0.6
        default:         return 1.5
        }
    }

    private var targetGlowAlpha: Double {
        switch status {
        case .listening: return 0.45
        case .speaking:  return 0.50
        default:         return 0.20
        }
    }

    @State private var pulseScale: CGFloat = 1.0
    @State private var currentGlowAlpha: Double = 0.15

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(VitaColors.accent.opacity(currentGlowAlpha * 0.3))
                .frame(width: 160, height: 160)
                .scaleEffect(pulseScale)

            // Middle ring
            Circle()
                .fill(VitaColors.accent.opacity(currentGlowAlpha * 0.5))
                .frame(width: 128, height: 128)
                .scaleEffect(pulseScale * 0.95)

            // Inner circle — avatar face
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                VitaColors.accent.opacity(0.90),
                                VitaColors.accent.opacity(0.50),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 48
                        )
                    )
                    .frame(width: 96, height: 96)

                Text("V")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(VitaColors.black)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: pulseDuration).repeatForever(autoreverses: true)
            ) {
                pulseScale = targetScale
                currentGlowAlpha = targetGlowAlpha
            }
        }
    }
}

// MARK: - MicButton
// Large circular mic button with pulsing outer ring when listening.
// Matches Android's mic toggle + PulsingVoiceRing composable.

private struct MicButton: View {
    let viewModel: VoiceModeViewModel

    private var isListening: Bool { viewModel.isListening }
    private var isSpeaking: Bool { viewModel.status == .speaking }

    var body: some View {
        ZStack {
            // Pulsing outer ring — visible when listening (mirrors Android PulsingVoiceRing)
            if isListening {
                PulsingRingView()
            }

            // Main button
            Button {
                if isSpeaking {
                    viewModel.interruptSpeaking()
                } else {
                    viewModel.toggleListening()
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isListening ? VitaColors.accent : VitaColors.accent.opacity(0.15))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .stroke(
                                    isListening ? Color.clear : VitaColors.accent.opacity(0.30),
                                    lineWidth: 1.5
                                )
                        )

                    Image(systemName: micIcon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(isListening ? VitaColors.black : VitaColors.accent)
                }
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: VitaTokens.Animation.durationFast), value: isListening)
        }
    }

    private var micIcon: String {
        if isSpeaking { return "speaker.wave.2.fill" }
        return isListening ? "stop.fill" : "mic.fill"
    }
}

// MARK: - PulsingRingView
// Outer ring that pulses outward while listening.
// Mirrors Android's PulsingVoiceRing composable (scale 1→1.5, alpha 0.4→0.05, 700ms).

private struct PulsingRingView: View {
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.4

    var body: some View {
        Circle()
            .fill(VitaColors.accent.opacity(opacity))
            .frame(width: 88, height: 88)
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
                ) {
                    scale = 1.5
                    opacity = 0.05
                }
            }
    }
}

// MARK: - VoiceTranscriptArea
// Shows live partial transcription and the AI response.

private struct VoiceTranscriptArea: View {
    let viewModel: VoiceModeViewModel

    var body: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            // Transcript (what the user said)
            if !viewModel.transcriptText.isEmpty {
                HStack {
                    Spacer()
                    Text(viewModel.transcriptText)
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(VitaColors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(VitaColors.accent.opacity(0.20), lineWidth: 1)
                        )
                }
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }

            // AI response
            if !viewModel.responseText.isEmpty {
                HStack {
                    Text(viewModel.responseText)
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(VitaColors.glassBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(VitaColors.glassBorder, lineWidth: 1)
                        )
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.dataRed)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: VitaTokens.Animation.durationNormal), value: viewModel.transcriptText)
        .animation(.easeInOut(duration: VitaTokens.Animation.durationNormal), value: viewModel.responseText)
        .animation(.easeInOut(duration: VitaTokens.Animation.durationFast), value: viewModel.errorMessage)
    }
}

// MARK: - PermissionDeniedView

private struct PermissionDeniedView: View {
    var body: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 32))
                .foregroundStyle(VitaColors.textTertiary)

            Text("Permissao necessaria")
                .font(VitaTypography.titleSmall)
                .foregroundStyle(VitaColors.textPrimary)

            Text("Acesse Ajustes > VitaAI e ative o Microfone e Reconhecimento de Fala.")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Abrir Ajustes") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(VitaTypography.labelMedium)
            .foregroundStyle(VitaColors.accent)
            .padding(.top, VitaTokens.Spacing.xs)
        }
        .padding(.horizontal, VitaTokens.Spacing._3xl)
    }
}
