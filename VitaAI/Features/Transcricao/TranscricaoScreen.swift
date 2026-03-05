import SwiftUI
import UIKit

// MARK: - TranscricaoScreen

struct TranscricaoScreen: View {
    let onBack: () -> Void

    @Environment(\.appContainer) private var container
    @State private var viewModel: TranscricaoViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                TranscricaoContent(viewModel: vm, onBack: onBack)
            } else {
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    ProgressView().tint(VitaColors.accent)
                }
            }
        }
        .task {
            if viewModel == nil {
                let vm = TranscricaoViewModel(tokenStore: container.tokenStore)
                viewModel = vm
                await vm.checkAndRequestMicPermission()
            }
        }
    }
}

// MARK: - TranscricaoContent

private struct TranscricaoContent: View {
    @Bindable var viewModel: TranscricaoViewModel
    let onBack: () -> Void

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                TranscricaoHeader(onBack: onBack)

                // Phase-driven content
                Group {
                    switch viewModel.phase {
                    case .idle:
                        TranscricaoIdleView(viewModel: viewModel)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))

                    case .recording:
                        TranscricaoRecordingView(viewModel: viewModel)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))

                    case .uploading, .transcribing, .summarizing, .generatingFlashcards:
                        TranscricaoProcessingView(viewModel: viewModel)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))

                    case .done:
                        TranscricaoDoneView(viewModel: viewModel)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))

                    case .error(let message):
                        TranscricaoErrorView(message: message, onRetry: viewModel.reset)
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.phase)
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Header

private struct TranscricaoHeader: View {
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(VitaColors.glassBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text("Transcrição de Áudio")
                    .font(VitaTypography.titleLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                Text("Grave ou importe e obtenha transcrição + resumo + flashcards")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

// MARK: - Idle Phase

private struct TranscricaoIdleView: View {
    let viewModel: TranscricaoViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero record button
            VStack(spacing: 24) {
                // Mic button
                Button {
                    viewModel.startRecording()
                } label: {
                    ZStack {
                        // Outer ambient ring
                        Circle()
                            .fill(VitaColors.accent.opacity(0.08))
                            .frame(width: 130, height: 130)

                        // Mid ring
                        Circle()
                            .fill(VitaColors.accent.opacity(0.14))
                            .frame(width: 108, height: 108)

                        // Core
                        Circle()
                            .fill(VitaColors.accent)
                            .frame(width: 88, height: 88)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(VitaColors.black)
                    }
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .medium), trigger: viewModel.phase == .recording)
                .disabled(!viewModel.micPermissionGranted)
                .opacity(viewModel.micPermissionGranted ? 1 : 0.4)

                VStack(spacing: 6) {
                    Text(viewModel.micPermissionGranted ? "Toque para gravar" : "Permissao de microfone necessaria")
                        .font(VitaTypography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Transcrição + resumo + flashcards gerados automaticamente")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Mic permission hint
            if !viewModel.micPermissionGranted {
                VitaGlassCard {
                    HStack(spacing: 10) {
                        Image(systemName: "mic.slash")
                            .font(.system(size: 16))
                            .foregroundStyle(VitaColors.dataAmber)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Acesso ao microfone necessario")
                                .font(VitaTypography.labelMedium)
                                .foregroundStyle(VitaColors.textPrimary)
                            Text("Vá em Ajustes > VitaAI > Microfone para ativar")
                                .font(VitaTypography.bodySmall)
                                .foregroundStyle(VitaColors.textSecondary)
                        }

                        Spacer()

                        Button("Ajustes") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.accent)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            } else {
                // How it works chips
                HStack(spacing: 8) {
                    ForEach(["Gravar", "Transcrever", "Resumir", "Flashcards"], id: \.self) { step in
                        Text(step)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(VitaColors.glassBg)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(VitaColors.glassBorder, lineWidth: 1))
                    }
                }
                .padding(.bottom, 32)
            }
        }
    }
}

// MARK: - Recording Phase

private struct TranscricaoRecordingView: View {
    let viewModel: TranscricaoViewModel

    @State private var pulseScale: CGFloat = 1.0
    @State private var wavePhase: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Animated waveform bars
                WaveformBarsView(amplitude: viewModel.micAmplitude)
                    .frame(height: 60)
                    .padding(.horizontal, 48)

                // Pulsing stop button
                ZStack {
                    // Pulse rings
                    Circle()
                        .fill(VitaColors.dataRed.opacity(0.08))
                        .frame(width: 130, height: 130)
                        .scaleEffect(pulseScale)

                    Circle()
                        .fill(VitaColors.dataRed.opacity(0.12))
                        .frame(width: 108, height: 108)

                    // Stop button core
                    Button {
                        viewModel.stopRecording()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(VitaColors.dataRed)
                                .frame(width: 88, height: 88)

                            RoundedRectangle(cornerRadius: 6)
                                .fill(VitaColors.white)
                                .frame(width: 30, height: 30)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                        pulseScale = 1.18
                    }
                }

                // Elapsed time + label
                VStack(spacing: 6) {
                    Text(formatElapsed(viewModel.elapsedSeconds))
                        .font(.system(size: 36, weight: .bold, design: .monospaced))
                        .foregroundStyle(VitaColors.textPrimary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(VitaColors.dataRed)
                            .frame(width: 8, height: 8)
                        Text("Gravando... toque para parar")
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                }
            }

            Spacer()
        }
    }
}

// MARK: - Waveform Bars

private struct WaveformBarsView: View {
    let amplitude: Float

    private let barCount = 28

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    let phase = Double(i) * 0.4
                    let wave = sin(t * 5.0 + phase) * 0.5 + 0.5
                    let baseHeight: Double = 8
                    let maxExtra: Double = 44
                    let height = baseHeight + maxExtra * wave * Double(amplitude)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [VitaColors.accent, VitaColors.accentDark],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 3, height: max(baseHeight, height))
                        .animation(.linear(duration: 0.05), value: amplitude)
                }
            }
        }
    }
}

// MARK: - Processing Phase

private struct TranscricaoProcessingView: View {
    let viewModel: TranscricaoViewModel

    @State private var rotation: Double = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Rotating accent ring
                ZStack {
                    Circle()
                        .stroke(VitaColors.accent.opacity(0.12), lineWidth: 4)
                        .frame(width: 88, height: 88)

                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(
                            AngularGradient(
                                colors: [VitaColors.accent, VitaColors.accent.opacity(0.1)],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 88, height: 88)
                        .rotationEffect(.degrees(rotation))
                        .onAppear {
                            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                                rotation = 360
                            }
                        }

                    Image(systemName: phaseIcon)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(VitaColors.accent)
                }

                VStack(spacing: 12) {
                    Text(viewModel.phase.processingLabel)
                        .font(VitaTypography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.phase.processingLabel)

                    if viewModel.progressPercent > 0 {
                        VStack(spacing: 6) {
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(VitaColors.accent.opacity(0.12))
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [VitaColors.accent, VitaColors.accentLight],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * CGFloat(viewModel.progressPercent) / 100, height: 6)
                                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.progressPercent)
                                }
                            }
                            .frame(height: 6)
                            .padding(.horizontal, 48)

                            Text("\(viewModel.progressPercent)%")
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textTertiary)
                                .monospacedDigit()
                        }
                    }

                    // Stage pills
                    HStack(spacing: 8) {
                        StagePill(label: "Upload", isDone: isDoneStage(.uploading), isActive: isActiveStage(.uploading))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(VitaColors.textTertiary)
                        StagePill(label: "Transcrição", isDone: isDoneStage(.transcribing), isActive: isActiveStage(.transcribing))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(VitaColors.textTertiary)
                        StagePill(label: "Resumo", isDone: isDoneStage(.summarizing), isActive: isActiveStage(.summarizing))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8))
                            .foregroundStyle(VitaColors.textTertiary)
                        StagePill(label: "Cards", isDone: isDoneStage(.generatingFlashcards), isActive: isActiveStage(.generatingFlashcards))
                    }
                }
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var phaseIcon: String {
        switch viewModel.phase {
        case .uploading:            return "arrow.up.circle"
        case .transcribing:         return "text.bubble"
        case .summarizing:          return "doc.text.magnifyingglass"
        case .generatingFlashcards: return "rectangle.stack"
        default:                    return "gearshape.2"
        }
    }

    private func isActiveStage(_ target: TranscricaoPhase) -> Bool {
        viewModel.phase == target
    }

    private func isDoneStage(_ target: TranscricaoPhase) -> Bool {
        let order: [TranscricaoPhase] = [.uploading, .transcribing, .summarizing, .generatingFlashcards]
        guard let current = order.firstIndex(of: viewModel.phase),
              let targetIdx = order.firstIndex(of: target) else { return false }
        return current > targetIdx
    }
}

private struct StagePill: View {
    let label: String
    let isDone: Bool
    let isActive: Bool

    var body: some View {
        Text(label)
            .font(VitaTypography.labelSmall)
            .foregroundStyle(
                isDone ? VitaColors.dataGreen :
                isActive ? VitaColors.accent :
                VitaColors.textTertiary
            )
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        isDone ? VitaColors.dataGreen.opacity(0.12) :
                        isActive ? VitaColors.accent.opacity(0.12) :
                        VitaColors.glassBg
                    )
            )
    }
}

// MARK: - Done Phase

private struct TranscricaoDoneView: View {
    @Bindable var viewModel: TranscricaoViewModel

    @State private var selectedTab: Int = 0
    @State private var copiedToast: Bool = false

    private let tabs = ["Transcrição", "Resumo", "Flashcards"]

    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { idx, title in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = idx }
                    } label: {
                        VStack(spacing: 6) {
                            Text(title)
                                .font(VitaTypography.labelMedium)
                                .fontWeight(selectedTab == idx ? .semibold : .regular)
                                .foregroundStyle(
                                    selectedTab == idx ? VitaColors.accent : VitaColors.textSecondary
                                )
                            Rectangle()
                                .fill(selectedTab == idx ? VitaColors.accent : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .animation(.easeInOut(duration: 0.2), value: selectedTab)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(VitaColors.glassBorder)
                    .frame(height: 1)
            }

            // Tab content
            Group {
                switch selectedTab {
                case 0:
                    TranscriptTabView(
                        transcript: viewModel.result?.transcript ?? "",
                        onCopy: { copyToClipboard(viewModel.result?.transcript ?? "") },
                        onShare: { shareText(viewModel.result?.transcript ?? "") },
                        onReset: viewModel.reset
                    )
                case 1:
                    SummaryTabView(
                        summary: viewModel.result?.summary ?? "",
                        onCopy: { copyToClipboard(viewModel.result?.summary ?? "") },
                        onShare: { shareText(viewModel.result?.summary ?? "") },
                        onReset: viewModel.reset
                    )
                case 2:
                    FlashcardsTabView(
                        flashcards: viewModel.result?.flashcards ?? [],
                        onReset: viewModel.reset
                    )
                default:
                    EmptyView()
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
        }
        .overlay(alignment: .top) {
            if copiedToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(VitaColors.dataGreen)
                    Text("Copiado!")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        withAnimation(.spring(response: 0.3)) { copiedToast = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.3)) { copiedToast = false }
        }
    }

    private func shareText(_ text: String) {
        guard !text.isEmpty else { return }
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            var presented = rootVC
            while let next = presented.presentedViewController { presented = next }
            presented.present(activityVC, animated: true)
        }
    }
}

// MARK: - Transcript Tab

private struct TranscriptTabView: View {
    let transcript: String
    let onCopy: () -> Void
    let onShare: () -> Void
    let onReset: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Action row
                HStack {
                    Text("Transcrição completa")
                        .font(VitaTypography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)

                    Spacer()

                    HStack(spacing: 8) {
                        ActionIconButton(systemImage: "doc.on.doc", tint: VitaColors.accent, action: onCopy)
                        ActionIconButton(systemImage: "square.and.arrow.up", tint: VitaColors.accent, action: onShare)
                    }
                }

                // Content card
                VitaGlassCard {
                    Text(transcript.isEmpty ? "Nenhuma transcrição disponível." : transcript)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(transcript.isEmpty ? VitaColors.textTertiary : VitaColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }

                // Nova transcrição
                VitaButton(
                    text: "Nova Transcrição",
                    action: onReset,
                    variant: .secondary,
                    size: .md,
                    leadingSystemImage: "arrow.counterclockwise"
                )
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Summary Tab

private struct SummaryTabView: View {
    let summary: String
    let onCopy: () -> Void
    let onShare: () -> Void
    let onReset: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Resumo da aula")
                        .font(VitaTypography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)

                    Spacer()

                    HStack(spacing: 8) {
                        ActionIconButton(systemImage: "doc.on.doc", tint: VitaColors.accent, action: onCopy)
                        ActionIconButton(systemImage: "square.and.arrow.up", tint: VitaColors.accent, action: onShare)
                    }
                }

                VitaGlassCard {
                    Text(summary.isEmpty ? "Nenhum resumo disponível." : summary)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(summary.isEmpty ? VitaColors.textTertiary : VitaColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }

                VitaButton(
                    text: "Nova Transcrição",
                    action: onReset,
                    variant: .secondary,
                    size: .md,
                    leadingSystemImage: "arrow.counterclockwise"
                )
                .frame(maxWidth: .infinity)
            }
            .padding(16)
            .padding(.bottom, 32)
        }
    }
}

// MARK: - Flashcards Tab

private struct FlashcardsTabView: View {
    let flashcards: [TranscriptionFlashcard]
    let onReset: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                HStack {
                    Text("\(flashcards.count) flashcard\(flashcards.count == 1 ? "" : "s") gerado\(flashcards.count == 1 ? "" : "s")")
                        .font(VitaTypography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)

                    Spacer()

                    ActionIconButton(
                        systemImage: "arrow.counterclockwise",
                        tint: VitaColors.accent,
                        action: onReset
                    )
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                if flashcards.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "rectangle.stack")
                            .font(.system(size: 32))
                            .foregroundStyle(VitaColors.textTertiary)
                        Text("Nenhum flashcard gerado")
                            .font(VitaTypography.bodyMedium)
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                } else {
                    ForEach(flashcards) { card in
                        FlashcardItemView(card: card)
                            .padding(.horizontal, 16)
                    }
                }

                VitaButton(
                    text: "Nova Transcrição",
                    action: onReset,
                    variant: .secondary,
                    size: .md,
                    leadingSystemImage: "arrow.counterclockwise"
                )
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
        }
    }
}

private struct FlashcardItemView: View {
    let card: TranscriptionFlashcard

    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                // Front
                Text(card.front)
                    .font(VitaTypography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Divider
                Rectangle()
                    .fill(VitaColors.glassBorder)
                    .frame(height: 1)

                // Back
                Text(card.back)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
    }
}

// MARK: - Error Phase

private struct TranscricaoErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(VitaColors.dataRed.opacity(0.12))
                        .frame(width: 80, height: 80)

                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(VitaColors.dataRed)
                }

                VStack(spacing: 8) {
                    Text("Algo deu errado")
                        .font(VitaTypography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)

                    Text(message)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.dataRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }

                VitaButton(
                    text: "Tentar novamente",
                    action: onRetry,
                    variant: .primary,
                    size: .lg,
                    leadingSystemImage: "arrow.counterclockwise"
                )
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }
}

// MARK: - Action Icon Button

private struct ActionIconButton: View {
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

private func formatElapsed(_ seconds: Int) -> String {
    let m = seconds / 60
    let s = seconds % 60
    return String(format: "%02d:%02d", m, s)
}
