import SwiftUI

// MARK: - Recording Detail Sheet

struct TranscricaoDetailSheet: View {
    let recording: TranscricaoEntry
    @Environment(\.dismiss) private var dismiss

    @State private var isPlaying = false
    @State private var playProgress: Double = 0.0

    private var displayStatus: RecordingStatus {
        recording.isTranscribed ? .transcribed : .pending
    }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        ZStack {
                            Circle()
                                .fill(TealColors.accent.opacity(0.08))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(TealColors.accent.opacity(0.18), lineWidth: 1)
                                )
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(TealColors.accentLight.opacity(0.70))
                        }
                        .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Voltar")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(recording.title.isEmpty ? "Gravacao" : recording.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.90))
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            if let dur = recording.duration, !dur.isEmpty {
                                Text(dur)
                            }
                            if let date = recording.date, !date.isEmpty {
                                Text("\u{00B7}")
                                Text(date)
                            }
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.35))
                    }

                    Spacer()

                    TranscricaoStatusBadge(status: displayStatus)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(TealColors.accent.opacity(0.04))
                .overlay(alignment: .bottom) {
                    Rectangle().fill(TealColors.accent.opacity(0.10)).frame(height: 1)
                }

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Audio player bar
                        TranscricaoAudioPlayerBar(isPlaying: $isPlaying, progress: $playProgress)
                            .padding(.top, 4)

                        if recording.isTranscribed {
                            TranscricaoTranscribedContent(recording: recording)
                        } else {
                            TranscricaoPendingContent()
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Audio Player Bar

struct TranscricaoAudioPlayerBar: View {
    @Binding var isPlaying: Bool
    @Binding var progress: Double

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isPlaying.toggle() }
            } label: {
                ZStack {
                    Circle()
                        .fill(TealColors.accent.opacity(0.12))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle().stroke(TealColors.accent.opacity(0.20), lineWidth: 1)
                        )
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(TealColors.accentLight.opacity(0.90))
                        .offset(x: isPlaying ? 0 : 1)
                }
            }
            .buttonStyle(.plain)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 3)
                    Capsule()
                        .fill(TealColors.accent.opacity(0.50))
                        .frame(width: geo.size.width * progress, height: 3)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 20)

            Text("0:00")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.25))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TealColors.accent.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Pending Content (not yet transcribed)

struct TranscricaoPendingContent: View {
    @State private var isTranscribing = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Esta gravação ainda não foi transcrita")
                .font(.system(size: 13))
                .foregroundStyle(Color.white.opacity(0.50))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)

            if isTranscribing {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(TealColors.accentLight)
                        .scaleEffect(0.8)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Transcrevendo...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.90))
                        Text("~2 minutos")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.25))
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(TealColors.accent.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(TealColors.accent.opacity(0.10), lineWidth: 1)
                )
            } else {
                Button {
                    withAnimation { isTranscribing = true }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Transcrever agora")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(TealColors.accentLight.opacity(0.90))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(TealColors.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(TealColors.accent.opacity(0.24), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Text("A transcrição gera automaticamente resumo, flashcards e questões.")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.28))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

// MARK: - Transcribed Content

struct TranscricaoTranscribedContent: View {
    let recording: TranscricaoEntry
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Transcrição")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                        .tracking(0.5)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = recording.title
                        withAnimation(.easeInOut(duration: 0.2)) { copied = true }
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            withAnimation { copied = false }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11))
                            Text(copied ? "Copiado" : "Copiar")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(copied ? TealColors.badgeGreen : TealColors.accentLight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((copied ? TealColors.badgeGreen : TealColors.accent).opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Text("Toque em Transcrever para ver o texto completo.")
                    .font(.system(size: 12))
                    .lineSpacing(4)
                    .foregroundStyle(Color.white.opacity(0.65))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TealColors.accent.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TealColors.accent.opacity(0.10), lineWidth: 1)
                    )
            }

            TranscricaoActionsMenu()
        }
    }
}

// MARK: - Actions Menu

struct TranscricaoActionsMenu: View {
    private struct ActionDef: Identifiable {
        let id: String
        let icon: String
        let name: String
        let desc: String
    }

    private let actions: [ActionDef] = [
        ActionDef(id: "resumo", icon: "doc.text", name: "Gerar resumo", desc: "Resumo estruturado da aula"),
        ActionDef(id: "flashcards", icon: "rectangle.stack", name: "Gerar flashcards", desc: "Cards de memorizacao automaticos"),
        ActionDef(id: "questões", icon: "questionmark.circle", name: "Gerar questões", desc: "Questões de prova baseadas na aula"),
        ActionDef(id: "conceitos", icon: "key", name: "Extrair conceitos-chave", desc: "Termos e definicoes importantes"),
        ActionDef(id: "mindmap", icon: "point.3.connected.trianglepath.dotted", name: "Mindmap", desc: "Mapa mental visual do conteúdo"),
    ]

    @State private var selectedActions: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("O QUE FAZER COM ESTA AULA?")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                .tracking(0.5)

            ForEach(actions) { action in
                TranscricaoActionItemRow(
                    icon: action.icon,
                    name: action.name,
                    desc: action.desc,
                    isSelected: selectedActions.contains(action.id),
                    onToggle: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if selectedActions.contains(action.id) {
                                selectedActions.remove(action.id)
                            } else {
                                selectedActions.insert(action.id)
                            }
                        }
                    }
                )
            }

            if !selectedActions.isEmpty {
                Button {
                    // TODO: trigger generation for selected actions
                } label: {
                    Text("Gerar selecionados (\(selectedActions.count))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [TealColors.accent.opacity(0.85), TealColors.accentLight.opacity(0.65)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: TealColors.accent.opacity(0.25), radius: 10, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }
}

// MARK: - Action Item Row

struct TranscricaoActionItemRow: View {
    let icon: String
    let name: String
    let desc: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(TealColors.accent.opacity(0.08))
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(TealColors.accent.opacity(0.12), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(TealColors.accentLight.opacity(0.80))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.80))
                    Text(desc)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.30))
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? TealColors.accent.opacity(0.20) : Color.clear)
                        .frame(width: 20, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    isSelected
                                        ? TealColors.accent.opacity(0.60)
                                        : Color.white.opacity(0.12),
                                    lineWidth: 1.5
                                )
                        )
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(TealColors.accentLight.opacity(0.90))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        isSelected
                            ? TealColors.accent.opacity(0.08)
                            : Color.white.opacity(0.06)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected
                            ? TealColors.accent.opacity(0.28)
                            : TealColors.accent.opacity(0.06),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Done Phase (after transcription completes)

struct TranscricaoDonePhase: View {
    let transcript: String
    let summary: String
    let flashcards: [TranscriptionFlashcard]
    let onReset: () -> Void

    @State private var selectedTab = 0
    private let tabs = ["Transcrição", "Resumo", "Flashcards"]

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
                    } label: {
                        VStack(spacing: 6) {
                            Text(title)
                                .font(.system(size: 12, weight: selectedTab == index ? .semibold : .regular))
                                .foregroundStyle(
                                    selectedTab == index
                                        ? TealColors.accentLight
                                        : Color.white.opacity(0.55)
                                )
                            Rectangle()
                                .fill(selectedTab == index ? TealColors.accent : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(TealColors.accent.opacity(0.10)).frame(height: 1)
            }

            switch selectedTab {
            case 0: TranscricaoTranscriptTab(text: transcript)
            case 1: TranscricaoSummaryTab(text: summary)
            case 2: TranscricaoFlashcardsTab(flashcards: flashcards, onReset: onReset)
            default: EmptyView()
            }
        }
    }
}

// MARK: - Transcript Tab

struct TranscricaoTranscriptTab: View {
    let text: String
    @State private var copied = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Transcrição completa")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.90))
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
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(copied ? TealColors.badgeGreen : TealColors.accentLight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((copied ? TealColors.badgeGreen : TealColors.accent).opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                Text(text.isEmpty ? "Nenhuma transcrição disponível." : text)
                    .font(.system(size: 12))
                    .lineSpacing(4)
                    .foregroundStyle(Color.white.opacity(0.70))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TealColors.accent.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(TealColors.accent.opacity(0.10), lineWidth: 1)
                    )
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Summary Tab

struct TranscricaoSummaryTab: View {
    let text: String

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Resumo da aula")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))

                if text.isEmpty {
                    Text("Resumo não disponível.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.55))
                } else {
                    VitaMarkdown(content: text)
                        .padding(14)
                        .background(TealColors.accent.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(TealColors.accent.opacity(0.10), lineWidth: 1)
                        )
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Flashcards Tab

struct TranscricaoFlashcardsTab: View {
    let flashcards: [TranscriptionFlashcard]
    let onReset: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                HStack {
                    Text("\(flashcards.count) flashcard\(flashcards.count == 1 ? "" : "s") gerado\(flashcards.count == 1 ? "" : "s")")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.90))
                    Spacer()
                    Button {
                        withAnimation { onReset() }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Nova gravação")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(TealColors.accentLight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(TealColors.accent.opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                if flashcards.isEmpty {
                    Text("Nenhum flashcard gerado.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .padding(.top, 8)
                } else {
                    ForEach(flashcards) { card in
                        TranscricaoFlashcardItemView(card: card)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 100)
        }
    }
}

struct TranscricaoFlashcardItemView: View {
    let card: TranscriptionFlashcard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(card.front)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.90))
                .padding(14)

            Rectangle()
                .fill(TealColors.accent.opacity(0.10))
                .frame(height: 1)

            Text(card.back)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(14)
        }
        .background(
            Color(red: 8/255, green: 12/255, blue: 11/255, opacity: 0.94)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TealColors.accent.opacity(0.10), lineWidth: 1)
        )
    }
}
