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
        Text(label)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
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
    let percent: Int
    let stage: String

    private var label: String {
        switch phase {
        case .uploading:            return "Enviando áudio..."
        case .transcribing:         return "Transcrevendo..."
        case .summarizing:          return "Gerando resumo..."
        case .generatingFlashcards: return "Criando flashcards..."
        default:                    return stage.isEmpty ? "Processando..." : stage
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(TealColors.accentLight)
                .scaleEffect(0.85)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.90))

                HStack(spacing: 6) {
                    if percent > 0 {
                        Text("\(percent)%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(TealColors.accentLight.opacity(0.80))
                    }
                    Text("~2 minutos")
                        .font(.system(size: 10))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.25))
                }
            }

            Spacer()

            // Mini progress bar
            if percent > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 3)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [TealColors.accent, TealColors.accentLight],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * CGFloat(percent) / 100.0, height: 3)
                            .animation(.easeOut(duration: 0.5), value: percent)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(width: 60, height: 16)
            }
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
