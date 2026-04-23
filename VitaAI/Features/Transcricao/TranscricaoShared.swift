import SwiftUI

// MARK: - Transcrição Colors (remapped to gold palette, unified with VitaColors)

enum TealColors {
    static let accent       = VitaColors.accent
    static let accentLight  = VitaColors.accentLight
    static let accentBright = VitaColors.accentHover

    static let cardBg = LinearGradient(
        colors: [
            Color(red: 12/255, green: 9/255, blue: 7/255, opacity: 0.94),
            Color(red: 14/255, green: 11/255, blue: 8/255, opacity: 0.90)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let screenBg = Color.clear

    static let badgeGreen     = VitaColors.dataGreen
    static let badgePending   = VitaColors.accentHover
    static let badgeRecording = VitaColors.dataRed
}

// MARK: - Teal Background

struct TealBackground: View {
    var body: some View {
        Color.clear.ignoresSafeArea()
    }
}

// MARK: - Recording Status Enum (for display)

enum RecordingStatus {
    case transcribed
    case pending
    case recording
}

// MARK: - Status Badge

struct TranscricaoStatusBadge: View {
    let status: RecordingStatus

    var body: some View {
        Text(label.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    private var label: String {
        switch status {
        case .transcribed: return "Transcrito"
        case .pending:     return "Não transcrito"
        case .recording:   return "Gravando"
        }
    }

    private var foregroundColor: Color {
        switch status {
        case .transcribed: return TealColors.badgeGreen.opacity(0.80)
        case .pending:     return TealColors.badgePending.opacity(0.80)
        case .recording:   return TealColors.badgeRecording.opacity(0.85)
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .transcribed: return TealColors.badgeGreen.opacity(0.10)
        case .pending:     return TealColors.badgePending.opacity(0.10)
        case .recording:   return TealColors.badgeRecording.opacity(0.10)
        }
    }

    private var borderColor: Color {
        switch status {
        case .transcribed: return TealColors.badgeGreen.opacity(0.14)
        case .pending:     return TealColors.badgePending.opacity(0.14)
        case .recording:   return TealColors.badgeRecording.opacity(0.20)
        }
    }
}

// MARK: - Mode Toggle

struct TranscricaoModeToggle: View {
    @Binding var selected: TranscricaoRecordingMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TranscricaoRecordingMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selected = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(
                            selected == mode
                                ? TealColors.accentBright.opacity(0.90)
                                : Color.white.opacity(0.30)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            selected == mode
                                ? RoundedRectangle(cornerRadius: 8)
                                    .fill(TealColors.accent.opacity(0.12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(TealColors.accent.opacity(0.20), lineWidth: 1)
                                    )
                                : nil
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(TealColors.accent.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Recording Mode (shared enum)

enum TranscricaoRecordingMode: String, CaseIterable {
    case offline = "Offline"
    case live = "Ao Vivo"
}

// MARK: - Processing Toast (inline card, not full-screen)

struct TranscricaoProcessingToast: View {
    let phase: TranscricaoViewModel.Phase
    /// Total seconds since the user hit "Stop recording". Used to show a real
    /// elapsed counter instead of the old "~2 minutos" lie.
    let elapsedSeconds: Int
    /// Free-form stage label coming from the backend SSE progress frame.
    /// We no longer show a fake percentage — the underlying pipeline runs
    /// sub-second for short clips and "5%" sitting still for minutes was
    /// pure theater.
    let stage: String

    private var label: String {
        switch phase {
        case .uploading:            return "Enviando áudio…"
        case .transcribing:         return "Transcrevendo…"
        case .summarizing:          return "Gerando resumo…"
        case .generatingFlashcards: return "Criando flashcards…"
        default:                    return stage.isEmpty ? "Processando…" : stage
        }
    }

    private var elapsedLabel: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    /// Four-step status bar — shows where we actually are without lying
    /// about percentages.
    private var stepIndex: Int {
        switch phase {
        case .uploading:            return 0
        case .transcribing:         return 1
        case .summarizing:          return 2
        case .generatingFlashcards: return 3
        case .done:                 return 4
        default:                    return 0
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(TealColors.accentLight)
                .scaleEffect(0.85)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.90))

                HStack(spacing: 8) {
                    Text(elapsedLabel)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(TealColors.accentLight.opacity(0.70))
                    // Segment bar: 4 slots, each lights up as the pipeline
                    // advances. Beats a fake percent — user sees a real
                    // transition and never sits at a fixed number.
                    HStack(spacing: 3) {
                        ForEach(0..<4, id: \.self) { i in
                            Capsule()
                                .fill(i < stepIndex ? TealColors.accent : Color.white.opacity(0.08))
                                .frame(width: 14, height: 3)
                                .animation(.easeInOut(duration: 0.25), value: stepIndex)
                        }
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(TealColors.accent.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(TealColors.accent.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: TealColors.accent.opacity(0.08), radius: 12, y: 4)
    }
}

// MARK: - Error Phase

struct TranscricaoErrorPhase: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(TealColors.badgeRecording.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.microphone.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(TealColors.badgeRecording.opacity(0.8))
            }

            Text("Algo deu errado")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.90))

            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(TealColors.badgeRecording.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Tentar novamente")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [TealColors.accent.opacity(0.85), TealColors.accent.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: TealColors.accent.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

// MARK: - Helper

func formatTranscricaoElapsed(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%02d:%02d", m, s)
}
