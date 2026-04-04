import SwiftUI

// MARK: - TranscricaoScreen
//
// Full-screen recording + transcription UI.
// Mirrors Android's single TranscricaoScreen.kt with phase-based rendering.
//
// Phases: idle → recording (live transcript) → uploading/transcribing/... → done (3-tab) / error
//
// iOS extras vs Android:
//   - Real-time live transcript panel while recording (SFSpeechRecognizer)
//   - Waveform pulsing rings (Siri-style) instead of simple scale animation
//   - VitaMarkdown for summary rendering

struct TranscricaoScreen: View {
    @Environment(\.appContainer) private var container
    let onBack: () -> Void

    @State private var viewModel: TranscricaoViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                TranscricaoContent(viewModel: vm, onBack: onBack)
            } else {
                ProgressView().tint(VitaColors.tealAccent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(VitaColors.surface.ignoresSafeArea())
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TranscricaoViewModel(client: container.transcricaoClient)
            }
        }
        .onDisappear {
            viewModel?.reset()
        }
    }
}

// MARK: - Content

@MainActor
private struct TranscricaoContent: View {
    @Bindable var viewModel: TranscricaoViewModel
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TranscricaoNavBar(
                onBack: onBack,
                backDisabled: viewModel.phase == .recording
            )
            Rectangle()
                .fill(VitaColors.surfaceBorder)
                .frame(height: 1)

            switch viewModel.phase {
            case .idle:
                IdlePhase { Task { await viewModel.startRecording() } }

            case .recording:
                RecordingPhase(
                    elapsedSeconds: viewModel.elapsedSeconds,
                    liveTranscript: viewModel.liveTranscript,
                    onStop: { viewModel.stopRecording() }
                )

            case .uploading, .transcribing, .summarizing, .generatingFlashcards:
                ProcessingPhase(
                    phase: viewModel.phase,
                    percent: viewModel.progressPercent,
                    stage: viewModel.progressStage
                )

            case .done:
                DonePhase(
                    transcript: viewModel.transcript,
                    summary: viewModel.summary,
                    flashcards: viewModel.flashcards,
                    onReset: { viewModel.reset() }
                )

            case .error:
                ErrorPhase(
                    message: viewModel.errorMessage ?? "Erro desconhecido",
                    onRetry: { viewModel.reset() }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VitaColors.surface.ignoresSafeArea())
    }
}

// MARK: - Nav Bar

private struct TranscricaoNavBar: View {
    let onBack: () -> Void
    let backDisabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(backDisabled ? VitaColors.textTertiary : VitaColors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(VitaColors.glassBg)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 1))
            }
            .disabled(backDisabled)
            .animation(.easeInOut(duration: 0.2), value: backDisabled)

            Text("Transcrever Aula")
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Idle Phase

private struct IdlePhase: View {
    let onStart: () -> Void
    @State private var glowPhase: Double = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Mic button with ambient glow — matches Android KastTeal 96dp style
            Button(action: onStart) {
                ZStack {
                    // Outer ambient glow
                    Circle()
                        .fill(VitaColors.tealAccent.opacity(0.08 + glowPhase * 0.04))
                        .frame(width: 140, height: 140)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: glowPhase)

                    // Mid ring
                    Circle()
                        .fill(VitaColors.tealAccent.opacity(0.12 + glowPhase * 0.04))
                        .frame(width: 115, height: 115)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.3), value: glowPhase)

                    // Main button
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [VitaColors.tealAccent, VitaColors.tealAccentDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 96, height: 96)
                        .shadow(color: VitaColors.tealAccent.opacity(0.45), radius: 24, x: 0, y: 8)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .onAppear { glowPhase = 1 }
            .sensoryFeedback(.impact(flexibility: .soft), trigger: false)

            VStack(spacing: 8) {
                Text("Toque para gravar sua aula")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)

                Text("Transcrição + resumo + flashcards automáticos")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }
}

// MARK: - Recording Phase

private struct RecordingPhase: View {
    let elapsedSeconds: Int
    let liveTranscript: String
    let onStop: () -> Void

    @State private var pulsePhase: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Stop button with pulsing rings — matches Android RecordingPhase
            ZStack {
                // Outermost ring
                Circle()
                    .stroke(VitaColors.dataRed.opacity(0.12), lineWidth: 1.5)
                    .frame(width: 150, height: 150)
                    .scaleEffect(1.0 + pulsePhase * 0.22)
                    .opacity(1.0 - pulsePhase * 0.4)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true).delay(0.3), value: pulsePhase)

                // Middle ring
                Circle()
                    .stroke(VitaColors.dataRed.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 125, height: 125)
                    .scaleEffect(1.0 + pulsePhase * 0.15)
                    .opacity(1.0 - pulsePhase * 0.3)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true).delay(0.15), value: pulsePhase)

                // Stop button
                Button(action: onStop) {
                    ZStack {
                        Circle()
                            .fill(VitaColors.dataRed.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Circle()
                            .fill(VitaColors.dataRed)
                            .frame(width: 80, height: 80)
                            .shadow(color: VitaColors.dataRed.opacity(0.4), radius: 14, x: 0, y: 5)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.stop, trigger: false)
            }
            .onAppear { pulsePhase = 1 }

            Spacer().frame(height: 24)

            // Timer — monospaced like Apple Voice Memos
            Text(formatElapsed(elapsedSeconds))
                .font(.system(size: 38, weight: .bold, design: .monospaced))
                .foregroundStyle(VitaColors.textPrimary)

            Spacer().frame(height: 8)

            Text("Gravando... toque para parar")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)

            Spacer().frame(height: 28)

            // Live transcript — real-time SFSpeechRecognizer output
            if !liveTranscript.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(VitaColors.dataRed)
                            .frame(width: 6, height: 6)
                        Text("Transcrição ao vivo")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.dataRed)
                    }

                    ScrollView(showsIndicators: false) {
                        Text(liveTranscript)
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                    .frame(maxHeight: 160)
                    .background(VitaColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 20)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(.easeOut(duration: 0.3), value: liveTranscript.isEmpty)
            }

            Spacer()
        }
    }
}

// MARK: - Processing Phase

private struct ProcessingPhase: View {
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
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .progressViewStyle(.circular)
                .tint(VitaColors.tealAccent)
                .scaleEffect(1.5)

            Text(label)
                .font(VitaTypography.titleSmall)
                .fontWeight(.medium)
                .foregroundStyle(VitaColors.textPrimary)
                .multilineTextAlignment(.center)

            if percent > 0 {
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(VitaColors.surfaceElevated)
                                .frame(height: 6)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [VitaColors.tealAccent, VitaColors.tealAccentDark],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * CGFloat(percent) / 100.0, height: 6)
                                .animation(.easeOut(duration: 0.5), value: percent)
                        }
                    }
                    .frame(height: 6)
                    .padding(.horizontal, 48)

                    Text("\(percent)%")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Done Phase

private struct DonePhase: View {
    let transcript: String
    let summary: String
    let flashcards: [TranscriptionFlashcard]
    let onReset: () -> Void

    @State private var selectedTab = 0
    private let tabs = ["Transcrição", "Resumo", "Flashcards"]

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar — mirrors Android TabRow
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
                    } label: {
                        VStack(spacing: 6) {
                            Text(title)
                                .font(VitaTypography.labelMedium)
                                .fontWeight(selectedTab == index ? .semibold : .regular)
                                .foregroundStyle(
                                    selectedTab == index ? VitaColors.tealAccent : VitaColors.textSecondary
                                )
                            Rectangle()
                                .fill(selectedTab == index ? VitaColors.tealAccent : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(VitaColors.glassBorder).frame(height: 1)
            }

            switch selectedTab {
            case 0: TranscriptTab(text: transcript)
            case 1: SummaryTab(text: summary)
            case 2: FlashcardsTab(flashcards: flashcards, onReset: onReset)
            default: EmptyView()
            }
        }
    }
}

// MARK: - Transcript Tab

private struct TranscriptTab: View {
    let text: String
    @State private var copied = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Transcrição completa")
                        .font(VitaTypography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = text
                        withAnimation(.easeInOut(duration: 0.2)) { copied = true }
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { copied = false }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12))
                            Text(copied ? "Copiado" : "Copiar")
                                .font(VitaTypography.labelSmall)
                        }
                        .foregroundStyle(copied ? VitaColors.dataGreen : VitaColors.tealAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((copied ? VitaColors.dataGreen : VitaColors.tealAccent).opacity(0.1))
                        .clipShape(Capsule())
                        .animation(.easeInOut(duration: 0.2), value: copied)
                    }
                }

                Text(text.isEmpty ? "Nenhuma transcrição disponível." : text)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(VitaColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Summary Tab

private struct SummaryTab: View {
    let text: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Resumo da aula")
                    .font(VitaTypography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.textPrimary)

                if text.isEmpty {
                    Text("Resumo não disponível.")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                } else {
                    VitaMarkdown(content: text)
                        .padding(14)
                        .background(VitaColors.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(VitaColors.glassBorder, lineWidth: 1)
                        )
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Flashcards Tab

private struct FlashcardsTab: View {
    let flashcards: [TranscriptionFlashcard]
    let onReset: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                HStack {
                    Text("\(flashcards.count) flashcard\(flashcards.count == 1 ? "" : "s") gerado\(flashcards.count == 1 ? "" : "s")")
                        .font(VitaTypography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)
                    Spacer()
                    Button {
                        withAnimation { onReset() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Nova gravação")
                                .font(VitaTypography.labelSmall)
                        }
                        .foregroundStyle(VitaColors.tealAccent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VitaColors.tealAccent.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                if flashcards.isEmpty {
                    Text("Nenhum flashcard gerado.")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                        .padding(.top, 8)
                } else {
                    ForEach(flashcards) { card in
                        FlashcardItemView(card: card)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }
}

private struct FlashcardItemView: View {
    let card: TranscriptionFlashcard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(card.front)
                .font(VitaTypography.bodyMedium)
                .fontWeight(.medium)
                .foregroundStyle(VitaColors.textPrimary)
                .padding(14)

            Rectangle()
                .fill(VitaColors.glassBorder)
                .frame(height: 1)

            Text(card.back)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
                .padding(14)
        }
        .background(VitaColors.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Error Phase

private struct ErrorPhase: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(VitaColors.dataRed.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.microphone.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(VitaColors.dataRed.opacity(0.8))
            }

            Text("Algo deu errado")
                .font(VitaTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundStyle(VitaColors.textPrimary)

            Text(message)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.dataRed.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Tentar novamente")
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(VitaColors.tealAccent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: VitaColors.tealAccent.opacity(0.3), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

// MARK: - Helper

private func formatElapsed(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%02d:%02d", m, s)
}
