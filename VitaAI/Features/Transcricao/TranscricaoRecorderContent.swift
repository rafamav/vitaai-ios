import SwiftUI

// MARK: - Recorder Area (timer + waveform + discipline/language pickers + record button)

struct TranscricaoRecorderArea: View {
    let elapsedSeconds: Int
    let isRecording: Bool
    let isPaused: Bool
    let audioLevels: [Float]
    @Binding var selectedDiscipline: String
    @Binding var selectedLanguage: String
    @Binding var transcribeWithAI: Bool
    let disciplines: [String]
    let onToggle: () -> Void
    let onPauseResume: () -> Void
    let onDiscard: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showDiscardConfirm = false

    private var recorderButtonWidth: CGFloat {
        horizontalSizeClass == .regular ? 200 : 155
    }

    private var isActive: Bool { isRecording || isPaused }

    var body: some View {
        VStack(spacing: 12) {
            // Timer gigante no topo, centralizado.
            Text(formatTranscricaoElapsed(elapsedSeconds))
                .font(.system(size: 54, weight: .bold, design: .default))
                .tracking(-2)
                .monospacedDigit()
                .foregroundStyle(
                    isRecording
                        ? VitaColors.accentLight.opacity(0.95)
                        : Color.white.opacity(0.22)
                )
                .shadow(color: isRecording ? VitaColors.accent.opacity(0.4) : .clear, radius: 32)

            // Status label secundário — só aparece enquanto gravando/pausado
            // (quando .idle o "Toque para gravar" do orb já cobre o estado).
            if isActive {
                Text(statusLabel)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.70))
                    .transition(.opacity)
            }

            // Orb/mascote CENTRAL como botão principal. Label "Toque para
            // gravar / parar" mais forte abaixo, sem duplicar o statusLabel.
            Button(action: onToggle) {
                VStack(spacing: 10) {
                    VitaTypingMascot(isRecording: isActive, size: recorderButtonWidth)

                    Text(mascotLabel)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(
                            isActive
                                ? VitaColors.accentLight.opacity(0.85)
                                : Color.white.opacity(0.55)
                        )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isActive ? "Parar gravação" : "Iniciar gravação")

            // Waveform ao vivo — só aparece quando gravando.
            if isRecording || isPaused {
                LiveWaveformBars(levels: audioLevels, isActive: isRecording)
                    .frame(height: 36)
                    .transition(.opacity)
            }

            // Descartar + Pause/Resume + Stop enquanto gravando/pausado.
            // Padrão gold Otter/Voice Memos: trash icon separado pra abortar
            // sem salvar, stop principal pra finalizar, pause secundário.
            if isActive {
                HStack(spacing: 8) {
                    // Descartar — trash vermelho sutil, confirmation dialog.
                    Button {
                        showDiscardConfirm = true
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.40, blue: 0.40).opacity(0.90))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color(red: 1.0, green: 0.40, blue: 0.40).opacity(0.12))
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 1.0, green: 0.40, blue: 0.40).opacity(0.32), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Descartar gravação")

                    TranscricaoPauseResumeButton(isPaused: isPaused, onTap: onPauseResume)

                    Button(action: onToggle) {
                        HStack(spacing: 6) {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("Parar")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(VitaColors.accentHover.opacity(0.90))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [VitaColors.accent.opacity(0.18), VitaColors.accent.opacity(0.10)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(VitaColors.accent.opacity(0.30), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .confirmationDialog(
                    "Descartar gravação?",
                    isPresented: $showDiscardConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Descartar", role: .destructive) { onDiscard() }
                    Button("Continuar gravando", role: .cancel) {}
                } message: {
                    Text("O áudio será deletado. Não dá pra desfazer.")
                }
            }

            // 3 chips compactos lado a lado (Rafael 2026-04-24): Disciplina /
            // Idioma / Modo. Auto-sized, centralizados, não competem com o orb.
            HStack(spacing: 8) {
                    TranscricaoDisciplinePicker(
                        selected: $selectedDiscipline,
                        disciplines: disciplines,
                        disabled: isRecording
                    )
                    TranscricaoLanguagePicker(
                        selected: $selectedLanguage,
                        disabled: isRecording
                    )
                    Menu {
                        Button {
                            if !isRecording { transcribeWithAI = true }
                        } label: {
                            if transcribeWithAI {
                                Label("VITACloud", systemImage: "checkmark")
                            } else {
                                Label("VITACloud", systemImage: "cloud.fill")
                            }
                        }
                        Button {
                            if !isRecording { transcribeWithAI = false }
                        } label: {
                            if !transcribeWithAI {
                                Label("Só no dispositivo", systemImage: "checkmark")
                            } else {
                                Label("Só no dispositivo", systemImage: "iphone")
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: transcribeWithAI ? "cloud.fill" : "iphone")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(VitaColors.accent)
                            Text(transcribeWithAI ? "Cloud" : "Local")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.80))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.30))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.03))
                                .overlay(Capsule().stroke(VitaColors.accent.opacity(0.18), lineWidth: 0.5))
                        )
                        .contentShape(Capsule())
                    }
                    .disabled(isRecording)
                    .opacity(isRecording ? 0.5 : 1)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    private var statusLabel: String {
        if isPaused { return "Pausado" }
        if isRecording { return "Gravando…" }
        return "Pronto para gravar"
    }

    private var mascotLabel: String {
        if isPaused { return "Toque para parar" }
        if isRecording { return "Toque para parar" }
        return "Toque para gravar"
    }
}

// MARK: - Live Waveform Bars
//
// Reads the ViewModel's audioLevels (length = TranscricaoViewModel.waveformBarCount)
// and renders real-time bars. When idle/paused, bars drop to a subtle baseline.

struct LiveWaveformBars: View {
    let levels: [Float]
    let isActive: Bool

    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 34

    var body: some View {
        HStack(spacing: 1.5) {
            ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                let h: CGFloat = isActive
                    ? max(minHeight, minHeight + CGFloat(level) * (maxHeight - minHeight))
                    : minHeight + 2
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        isActive
                            ? LinearGradient(
                                colors: [VitaColors.accent.opacity(0.55), VitaColors.accentLight.opacity(0.90)],
                                startPoint: .bottom, endPoint: .top
                              )
                            : LinearGradient(
                                colors: [VitaColors.accent.opacity(0.10)],
                                startPoint: .bottom, endPoint: .top
                              )
                    )
                    .frame(width: 2.5, height: h)
                    .animation(.easeOut(duration: 0.12), value: h)
            }
        }
    }
}

// MARK: - (legacy discipline chips — kept for recordings list filter, renamed)

private struct LegacyChips: View {
    let disciplines: [String]
    @Binding var selected: String
    let disabled: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(disciplines, id: \.self) { disc in
                    let isSelected = selected == disc
                    Button {
                        if !disabled {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selected = disc
                            }
                        }
                    } label: {
                        Text(disc)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(
                                isSelected
                                    ? VitaColors.accentHover.opacity(0.90)
                                    : VitaColors.textWarm.opacity(0.35)
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(
                                        isSelected
                                            ? VitaColors.accent.opacity(0.10)
                                            : Color.white.opacity(0.04)
                                    )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        isSelected
                                            ? VitaColors.accent.opacity(0.30)
                                            : VitaColors.accent.opacity(0.06),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .opacity(disabled ? 0.5 : 1.0)
                }
            }
        }
    }
}

// MARK: - Live Transcript Box

struct TranscricaoLiveTranscriptBox: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ZStack {
                    Circle().fill(VitaColors.accent.opacity(0.20)).frame(width: 10, height: 10)
                    Circle().fill(VitaColors.accent).frame(width: 6, height: 6)
                        .opacity(0.85)
                }
                Text("AO VIVO")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(VitaColors.accentLight)
                Spacer()
            }

            ScrollView(showsIndicators: false) {
                if text.isEmpty {
                    Text("Ouvindo… fale algo.")
                        .font(.system(size: 12, weight: .medium))
                        .italic()
                        .foregroundStyle(Color.white.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(text)
                        .font(.system(size: 13))
                        .lineSpacing(4)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxHeight: 120)
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 12).fill(VitaColors.accent.opacity(0.06))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.accent.opacity(0.22), lineWidth: 0.5)
        )
    }
}

// MARK: - Recordings List Section (data from API)

struct TranscricaoRecordingsListSection: View {
    let recordings: [TranscricaoEntry]
    let isLoading: Bool
    @Binding var selectedFilter: String?
    let filterChips: [String]
    let onTap: (TranscricaoEntry) -> Void
    let onDelete: (TranscricaoEntry) -> Void
    /// Context menu action: dispara geração direto (summary, flashcards, questions,
    /// concepts, mindmap). Sem precisar abrir sheet + tab de ações.
    var onGenerate: ((TranscricaoEntry, String) -> Void)? = nil
    /// Swipe right quick-action: favorita gravação.
    var onFavorite: ((TranscricaoEntry) -> Void)? = nil
    /// Long press → renomear. Abre alert inline sem precisar entrar no detail.
    var onRename: ((TranscricaoEntry, String) -> Void)? = nil

    @State private var renamingRec: TranscricaoEntry? = nil
    @State private var renameValue: String = ""

    private var filteredRecordings: [TranscricaoEntry] {
        guard let filter = selectedFilter else { return recordings }
        return recordings.filter { $0.discipline?.uppercased() == filter.uppercased() }
    }

    // Group recordings by date bucket
    private var groupedRecordings: [(key: String, recordings: [TranscricaoEntry])] {
        let items = filteredRecordings
        let cal = Calendar.current
        let now = Date()

        var today: [TranscricaoEntry] = []
        var thisWeek: [TranscricaoEntry] = []
        var older: [TranscricaoEntry] = []

        for rec in items {
            let date = rec.parsedDate ?? .distantPast
            if cal.isDateInToday(date) {
                today.append(rec)
            } else if let weekAgo = cal.date(byAdding: .day, value: -7, to: now), date >= weekAgo {
                thisWeek.append(rec)
            } else {
                older.append(rec)
            }
        }

        var result: [(key: String, recordings: [TranscricaoEntry])] = []
        if !today.isEmpty { result.append(("Hoje", today)) }
        if !thisWeek.isEmpty { result.append(("Esta semana", thisWeek)) }
        if !older.isEmpty { result.append(("Anteriores", older)) }
        return result
    }

    @State private var showFilterSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: "GRAVAÇÕES · N" + botão filtro à direita (padrão Apple
            // Mail/Notes). Quando filtro ativo, mostra pill removível.
            HStack(spacing: 6) {
                Text("GRAVAÇÕES")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                    .tracking(0.5)

                if !recordings.isEmpty {
                    Text("· \(recordings.count)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        .tracking(0.5)
                }

                Spacer()

                // Pill removível mostrando filtro ativo.
                if let active = selectedFilter {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedFilter = nil
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 9, weight: .semibold))
                            Text(active)
                                .font(.system(size: 11, weight: .semibold))
                                .lineLimit(1)
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .opacity(0.6)
                        }
                        .foregroundStyle(VitaColors.accentLight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(VitaColors.accent.opacity(0.14)))
                        .overlay(Capsule().stroke(VitaColors.accent.opacity(0.30), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: selectedFilter == nil
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(
                            selectedFilter == nil
                                ? VitaColors.textWarm.opacity(0.45)
                                : VitaColors.accentLight
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .sheet(isPresented: $showFilterSheet) {
                TranscricaoFilterSheet(
                    disciplines: filterChips,
                    selected: $selectedFilter
                )
            }

            if isLoading {
                ProgressView()
                    .tint(TealColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else if recordings.isEmpty {
                // Empty state
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [VitaColors.accent.opacity(0.12), VitaColors.accent.opacity(0.03)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 40
                                )
                            )
                            .frame(width: 80, height: 80)
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 30, weight: .light))
                            .foregroundStyle(VitaColors.accent.opacity(0.55))
                    }

                    Text("Nenhuma gravação ainda")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.65))

                    Text("Grave sua aula e a IA transcreve, resume,\ne cria flashcards automaticamente.")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 32)
            } else {
                // Date-grouped recordings
                VStack(spacing: 4) {
                    ForEach(groupedRecordings, id: \.key) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(group.key.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                                .tracking(0.8)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            ForEach(group.recordings) { rec in
                                SwipeableCardRow(
                                    onSwipeLeft: { onDelete(rec) },
                                    onSwipeRight: { onFavorite?(rec) }
                                ) {
                                    TealGlassRecordingCard(recording: rec)
                                }
                                    .padding(.horizontal, 16)
                                    .contentShape(Rectangle())
                                    .onTapGesture { onTap(rec) }
                                    // Long press → context menu com todas ações quick-access.
                                    // Pattern Apple Mail/Photos: hold revela menu contextual
                                    // sem precisar abrir sheet inteiro.
                                    .contextMenu {
                                        // Ver detalhes (mesmo que tap)
                                        Button {
                                            onTap(rec)
                                        } label: {
                                            Label("Ver detalhes", systemImage: "doc.text.magnifyingglass")
                                        }

                                        // Renomear inline — sem precisar abrir sheet
                                        Button {
                                            renameValue = rec.title
                                            renamingRec = rec
                                        } label: {
                                            Label("Renomear", systemImage: "pencil")
                                        }

                                        Divider()

                                        // Gerar conteúdo — 5 ações direto, sem sheet
                                        if rec.isTranscribed, let onGenerate {
                                            Button {
                                                onGenerate(rec, "summary")
                                            } label: {
                                                Label("Gerar resumo", systemImage: "doc.text")
                                            }
                                            Button {
                                                onGenerate(rec, "flashcards")
                                            } label: {
                                                Label("Gerar flashcards", systemImage: "rectangle.stack")
                                            }
                                            Button {
                                                onGenerate(rec, "questions")
                                            } label: {
                                                Label("Gerar questões", systemImage: "questionmark.circle")
                                            }
                                            Button {
                                                onGenerate(rec, "concepts")
                                            } label: {
                                                Label("Extrair conceitos-chave", systemImage: "key")
                                            }
                                            Button {
                                                onGenerate(rec, "mindmap")
                                            } label: {
                                                Label("Gerar mindmap", systemImage: "point.3.connected.trianglepath.dotted")
                                            }

                                            Divider()
                                        }

                                        // Excluir (destructive, sempre disponível)
                                        Button(role: .destructive) {
                                            onDelete(rec)
                                        } label: {
                                            Label("Excluir", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
        }
        .alert(
            "Renomear gravação",
            isPresented: Binding(
                get: { renamingRec != nil },
                set: { if !$0 { renamingRec = nil } }
            )
        ) {
            TextField("Título", text: $renameValue)
            Button("Cancelar", role: .cancel) { renamingRec = nil }
            Button("Salvar") {
                let trimmed = renameValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if let rec = renamingRec, !trimmed.isEmpty {
                    onRename?(rec, trimmed)
                }
                renamingRec = nil
            }
            .disabled(renameValue.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}


// MARK: - Teal Glass Recording Card

struct TealGlassRecordingCard: View {
    let recording: TranscricaoEntry

    private var displayStatus: RecordingStatus {
        recording.isTranscribed ? .transcribed : .pending
    }

    /// Sempre retorna uma string — se LLM não classificou ou disciplina vazia,
    /// cai pra "OUTROS" (pasta default, pattern iOS Notes/Arquivos/Lembretes).
    /// Evita card "órfão" sem contexto visual.
    private var disciplineDisplay: String {
        let trimmed = (recording.discipline ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? "Outros" : trimmed).uppercased()
    }

    /// Sanitiza título: se backend gravou UUID como título (bug — algumas
    /// gravações subiam sem título e o backend caía no ID), substitui por
    /// "Gravação". Regex pega UUID v4 padrão.
    private var titleDisplay: String {
        let t = recording.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "Gravação" }
        // UUID v4: 8-4-4-4-12 hex chars
        if t.range(of: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#, options: .regularExpression) != nil {
            return "Gravação"
        }
        return t
    }

    var body: some View {
        HStack(spacing: 14) {
            // Mic icon in glass circle
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                VitaColors.accent.opacity(displayStatus == .pending ? 0.15 : 0.32),
                                VitaColors.accent.opacity(displayStatus == .pending ? 0.06 : 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.accent.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.40), radius: 6, y: 3)

                Image(systemName: "waveform")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.92))
            }
            .opacity(displayStatus == .pending ? 0.5 : 1.0)

            // Text block
            VStack(alignment: .leading, spacing: 3) {
                // Discipline header (sempre presente, fallback "Outros")
                // iOS pattern: Notes/Voice Memos mostram pasta/categoria antes do título
                Text(disciplineDisplay)
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.9)
                    .lineLimit(1)
                    .foregroundStyle(VitaColors.accent.opacity(0.85))

                Text(titleDisplay)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .lineLimit(1)

                // Metadata row: date · duration · size
                HStack(spacing: 5) {
                    let dateStr = recording.relativeDate
                    if !dateStr.isEmpty {
                        Label(dateStr, systemImage: "clock")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    }

                    if let duration = recording.duration, !duration.isEmpty {
                        if !dateStr.isEmpty {
                            Circle().fill(VitaColors.textWarm.opacity(0.20)).frame(width: 2.5, height: 2.5)
                        }
                        Text(duration)
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    }

                    if let size = recording.formattedSize {
                        Circle().fill(VitaColors.textWarm.opacity(0.20)).frame(width: 2.5, height: 2.5)
                        Text(size)
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    }
                }
                .labelStyle(.titleOnly)
            }

            Spacer()

            // Status badge only — chevron removed (data+duration já fica
            // abaixo do título, indicador visual de tappable é o próprio
            // glassCard com hover state).
            TranscricaoStatusBadge(status: displayStatus)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 16)
    }
}

// `abbreviateDiscipline` moved to TranscricaoControls.swift (shared with pickers).


// MARK: - Swipeable card row (Tinder-like horizontal gestures)

/// Wrapper que adiciona swipe-left (delete) e swipe-right (favorite)
/// ao card, revelando background colorido conforme arrasta.
/// Full-swipe (>40% da largura) executa ação imediatamente com haptic.
/// Partial-swipe volta pro lugar suavemente.
///
/// Pattern: iOS Mail, Gmail Android, Todoist.
struct SwipeableCardRow<Content: View>: View {
    let onSwipeLeft: () -> Void   // destructive (delete)
    let onSwipeRight: () -> Void  // positive (favorite)
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    @State private var isDragging = false
    private let actionThreshold: CGFloat = 100

    var body: some View {
        ZStack {
            // Background actions (revealed as card slides)
            HStack(spacing: 0) {
                // Right action (shown when swiping RIGHT: card moves right, leading edge revealed)
                if offset > 0 {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Favoritar")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 24)
                    .opacity(min(offset / actionThreshold, 1.0))
                }

                Spacer()

                // Left action (shown when swiping LEFT: card moves left, trailing edge revealed)
                if offset < 0 {
                    HStack {
                        Text("Excluir")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                        Image(systemName: "trash.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 24)
                    .opacity(min(abs(offset) / actionThreshold, 1.0))
                }
            }
            .background(
                // Cor muda conforme direção
                offset > 0
                ? Color.yellow.opacity(0.55 * min(offset / actionThreshold, 1.0))
                : Color.red.opacity(0.55 * min(abs(offset) / actionThreshold, 1.0))
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .animation(.easeOut(duration: 0.15), value: offset)

            // Card itself, offset by drag
            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            isDragging = true
                            // Resistência nas extremidades (rubber band)
                            let raw = value.translation.width
                            offset = raw.magnitude > 200 ? (raw > 0 ? 200 : -200) : raw
                        }
                        .onEnded { value in
                            isDragging = false
                            let dx = value.translation.width
                            if dx > actionThreshold {
                                // Swipe right → favoritar
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = 400  // sai da tela
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    onSwipeRight()
                                    offset = 0
                                }
                            } else if dx < -actionThreshold {
                                // Swipe left → delete
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    offset = -400
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    onSwipeLeft()
                                    offset = 0
                                }
                            } else {
                                // Volta pro lugar
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                    offset = 0
                                }
                            }
                        }
                )
        }
    }
}
