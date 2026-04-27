import SwiftUI

// MARK: - Recording Detail Sheet

struct TranscricaoDetailSheet: View {
    let recording: TranscricaoEntry
    /// Called after a successful rename so the parent list can refresh without
    /// a full reload.
    var onRenamed: ((String) -> Void)? = nil
    /// Called after a successful delete so the parent list can drop the row.
    var onDeleted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container

    @State private var sourceDetail: StudioSourceDetail?
    @State private var outputs: [StudioOutput] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    @StateObject private var audioPlayer = TranscricaoAudioPlayer()
    @State private var allWords: [WhisperWord] = []
    @State private var allSegments: [WhisperSegment] = []
    @State private var professorSignals: [ProfessorSignals.Signal] = []
    @State private var hasAudioFile = false

    // Actions menu state.
    @State private var liveTitle: String
    @State private var showRenameDialog = false
    @State private var renameValue: String = ""
    @State private var showDeleteConfirm = false
    @State private var showShareSheet = false
    @State private var showMoveSheet = false
    @State private var actionBusy = false
    @State private var actionError: String?
    @State private var isFavorite: Bool = false
    @State private var currentDisciplineSlug: String? = nil
    @State private var currentFolderId: String? = nil

    init(recording: TranscricaoEntry,
         onRenamed: ((String) -> Void)? = nil,
         onDeleted: (() -> Void)? = nil) {
        self.recording = recording
        self.onRenamed = onRenamed
        self.onDeleted = onDeleted
        self._liveTitle = State(initialValue: recording.title)
    }

    private var displayStatus: RecordingStatus {
        if recording.hasFailed { return .failed }
        return recording.isTranscribed ? .transcribed : .pending
    }

    private var formattedDuration: String? {
        if let d = sourceDetail?.metadata?.durationSeconds, d > 0 {
            let mins = Int(d) / 60
            let secs = Int(d) % 60
            return String(format: "%d:%02d", mins, secs)
        }
        if let label = sourceDetail?.metadata?.durationLabel, !label.isEmpty { return label }
        if let d = recording.duration, !d.isEmpty { return d }
        return nil
    }

    private var fullTranscript: String {
        guard let chunks = sourceDetail?.chunks, !chunks.isEmpty else { return "" }
        let raw = chunks.sorted(by: { $0.chunkIndex < $1.chunkIndex })
            .map(\.content)
            .joined(separator: "\n\n")
        return Self.cleanWhisperHallucinations(raw)
    }

    /// Remove Whisper hallucination patterns: repeated phrases like
    /// "o tratador, o tratador, o tratador" or "o que é o que é o que é"
    private static func cleanWhisperHallucinations(_ text: String) -> String {
        var result = text

        // Pattern: any phrase of 2-8 words repeated 4+ times in a row (with optional comma/space between)
        // e.g. "o tratador, o tratador, o tratador, o tratador,"
        let patterns = [
            // "word word, word word, word word," repeated
            #"((?:\b\w+\b[\s,]*){1,8}?)\1{3,}"#,
            // Simpler: same 2-40 char substring repeated 4+ times
            #"(.{2,40}?)\1{3,}"#,
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1 [...] ")
            }
        }

        // Clean up multiple [...] in a row
        if let cleanupRegex = try? NSRegularExpression(pattern: #"\s*\[\.\.\.\]\s*(\[\.\.\.\]\s*)+"#) {
            let range = NSRange(result.startIndex..., in: result)
            result = cleanupRegex.stringByReplacingMatches(in: result, range: range, withTemplate: " [...] ")
        }

        // Clean up excessive whitespace
        if let wsRegex = try? NSRegularExpression(pattern: #"\n{3,}"#) {
            let range = NSRange(result.startIndex..., in: result)
            result = wsRegex.stringByReplacingMatches(in: result, range: range, withTemplate: "\n\n")
        }

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Enquanto o pipeline cloud tá em voo (status != "ready") o sheet faz
    /// polling a cada 2s pra re-carregar detail + outputs. Quando status vira
    /// "ready" (ou "failed") o loop encerra. User pode abrir o sheet enquanto
    /// a transcrição ainda tá rolando e vai ver as seções aparecendo uma a uma.
    @State private var isPollingForReady = false

    private var isReady: Bool {
        sourceDetail?.status == "ready"
    }

    var body: some View {
        VitaSheet {
            VStack(spacing: 0) {
                // Header
                headerView

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Audio player bar — only show when audio file exists
                        if hasAudioFile {
                            TranscricaoLivePlayerBar(player: audioPlayer)
                                .padding(.top, 4)
                        }

                        if isLoading && sourceDetail == nil {
                            loadingView
                        } else if let error = errorMessage, sourceDetail == nil {
                            errorView(error)
                        } else {
                            // Progressive content — mostra o que tem, placeholder
                            // pro resto. Polling vai preenchendo.
                            progressiveContent
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
        }
        .task {
            await loadData()
            await pollUntilReady()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                ZStack {
                    Circle()
                        .fill(VitaColors.accent.opacity(0.08))
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(VitaColors.accent.opacity(0.18), lineWidth: 1))
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.70))
                }
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(liveTitle.isEmpty ? "Gravação" : liveTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(1)

                HStack(spacing: 4) {
                    if let dur = formattedDuration {
                        Text(dur)
                    }
                    if let date = recording.relativeDate as String?, !date.isEmpty {
                        Text("\u{00B7}")
                        Text(date)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.35))
            }

            Spacer()
            TranscricaoStatusBadge(status: displayStatus)

            actionsMenu
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(VitaColors.accent.opacity(0.04))
        .overlay(alignment: .bottom) {
            Rectangle().fill(VitaColors.accent.opacity(0.10)).frame(height: 1)
        }
    }

    // MARK: - Actions menu

    private var actionsMenu: some View {
        Menu {
            Button {
                Task { await toggleFavorite() }
            } label: {
                Label(
                    isFavorite ? "Remover dos favoritos" : "Favoritar",
                    systemImage: isFavorite ? "star.slash" : "star"
                )
            }
            Button {
                showMoveSheet = true
            } label: {
                Label("Mover pra disciplina…", systemImage: "folder")
            }
            Button {
                renameValue = liveTitle
                showRenameDialog = true
            } label: {
                Label("Renomear", systemImage: "pencil")
            }
            Divider()
            Button {
                UIPasteboard.general.string = fullTranscript
            } label: {
                Label("Copiar transcrição", systemImage: "doc.on.doc")
            }
            .disabled(fullTranscript.isEmpty)
            Button {
                showShareSheet = true
            } label: {
                Label("Compartilhar", systemImage: "square.and.arrow.up")
            }
            .disabled(fullTranscript.isEmpty)
            Button {
                exportAsTextFile()
            } label: {
                Label("Exportar como TXT", systemImage: "doc.badge.arrow.up")
            }
            .disabled(fullTranscript.isEmpty)
            Divider()
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Excluir", systemImage: "trash")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(VitaColors.accent.opacity(0.08))
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(VitaColors.accent.opacity(0.18), lineWidth: 1))
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.70))
            }
            .frame(minWidth: 44, minHeight: 44)
        }
        .disabled(actionBusy)
        // vita-modals-ignore: TextField inline no .alert — VitaAlert não suporta input de texto
        .alert("Renomear gravação", isPresented: $showRenameDialog) {
            TextField("Título", text: $renameValue)
            Button("Cancelar", role: .cancel) { }
            Button("Salvar") { Task { await performRename() } }
                .disabled(renameValue.trimmingCharacters(in: .whitespaces).isEmpty)
        } message: {
            Text("Defina um nome mais fácil de encontrar depois.")
        }
        .vitaAlert(
            isPresented: $showDeleteConfirm,
            // quality-gate-ignore: demonstrativo PT-BR (this), não verbo
            title: "Excluir esta gravação?",
            message: "O áudio, a transcrição e os resumos gerados serão removidos. Não dá pra desfazer.",
            destructiveLabel: "Excluir",
            onConfirm: { Task { await performDelete() } }
        )
        .vitaBubble(isPresented: $showShareSheet, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Compartilhar")
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                TranscricaoShareSheet(items: shareItems)
            }
            .frame(width: 280)
        }
        .vitaBubble(isPresented: $showMoveSheet, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mover para")
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                TranscricaoMovePickerSheet(
                    currentSlug: currentDisciplineSlug,
                    currentFolderId: currentFolderId,
                    onPick: { folderId, slug in
                        showMoveSheet = false
                        Task { await moveToTarget(folderId: folderId, slug: slug) }
                    }
                )
                .frame(maxHeight: 320)
            }
            .frame(width: 300)
        }
        .overlay(alignment: .bottom) {
            if let err = actionError {
                Text(err)
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.dataRed.opacity(0.9))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
    }

    private var shareItems: [Any] {
        var items: [Any] = []
        let title = liveTitle.isEmpty ? "Gravação" : liveTitle
        let body = fullTranscript.isEmpty ? title : "\(title)\n\n\(fullTranscript)"
        items.append(body)
        return items
    }

    /// Exporta transcrição como arquivo .txt — abre UIActivityViewController
    /// com URL do arquivo. iOS oferece "Salvar em Arquivos", "Mail", AirDrop,
    /// "Importar pra Notes", etc. Padrão Apple Notes/Voice Memos export.
    private func exportAsTextFile() {
        guard !fullTranscript.isEmpty else { return }
        let title = liveTitle.isEmpty ? "Gravação" : liveTitle
        // Sanitiza nome de arquivo — remove chars proibidos no FAT/APFS.
        let safeName = title
            .components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|"))
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = (safeName.isEmpty ? "Transcricao" : safeName) + ".txt"

        // Cabeçalho com metadata pra ficar útil offline (Apple Files preview).
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "pt_BR")
        dateFmt.dateStyle = .long
        dateFmt.timeStyle = .short
        let header = """
        \(title)
        \(dateFmt.string(from: Date()))
        ─────────────────────────────────────

        """
        let content = header + fullTranscript

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            actionError = "Falha ao gerar arquivo"
            return
        }

        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func performRename() async {
        let newTitle = renameValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newTitle.isEmpty else { return }
        actionBusy = true
        actionError = nil
        do {
            try await container.api.renameStudioSource(id: recording.id, title: newTitle)
            liveTitle = newTitle
            onRenamed?(newTitle)
        } catch {
            actionError = "Falha ao renomear"
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run { actionError = nil }
            }
        }
        actionBusy = false
    }

    private func toggleFavorite() async {
        let newValue = !isFavorite
        actionBusy = true
        actionError = nil
        do {
            try await container.api.updateStudioSource(
                id: recording.id,
                favorite: newValue
            )
            isFavorite = newValue
        } catch {
            actionError = "Falha ao favoritar"
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run { actionError = nil }
            }
        }
        actionBusy = false
    }

    /// Aplica folderId OU disciplineSlug (ou nada = "Sem pasta"). Mutual
    /// exclusive — passar um zera o outro.
    private func moveToTarget(folderId: String?, slug: String?) async {
        actionBusy = true
        actionError = nil
        do {
            try await container.api.updateStudioSource(
                id: recording.id,
                disciplineSlug: slug,
                clearDiscipline: slug == nil,
                folderId: folderId,
                clearFolder: folderId == nil
            )
            currentDisciplineSlug = slug
            currentFolderId = folderId
        } catch {
            actionError = "Falha ao mover"
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run { actionError = nil }
            }
        }
        actionBusy = false
    }

    private func performDelete() async {
        actionBusy = true
        actionError = nil
        do {
            try await container.api.deleteStudioSource(id: recording.id)
            onDeleted?()
            dismiss()
        } catch {
            actionError = "Falha ao excluir"
            Task {
                try? await Task.sleep(for: .seconds(3))
                await MainActor.run { actionError = nil }
            }
        }
        actionBusy = false
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(VitaColors.accentLight)
            Text("Carregando transcrição...")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Error

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(VitaColors.dataRed.opacity(0.7))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.55))
                .multilineTextAlignment(.center)
            Button("Tentar novamente") { Task { await loadData() } }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VitaColors.accentLight)
        }
        .padding(.vertical, 20)
    }

    // MARK: - Progressive Content (polls until ready)

    /// Renderiza o que já tiver carregado — transcript se houver chunks,
    /// outputs (summary + flashcards) se já geraram. Seções em progresso
    /// mostram skeleton com label "Transcrevendo…" / "Gerando resumo…".
    @ViewBuilder
    private var progressiveContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Live status banner — só aparece enquanto não tá ready.
            if !isReady, let status = sourceDetail?.status {
                pipelineBanner(status: status)
            }

            // Professor signals (só quando transcript tá carregado)
            if !professorSignals.isEmpty {
                ProfessorSignalsSummary(signals: professorSignals)
            }

            // Transcript: mostra real se tem chunks, skeleton senão.
            if !fullTranscript.isEmpty {
                if !allWords.isEmpty {
                    TranscricaoKaraokeTranscriptSection(
                        words: allWords,
                        segments: allSegments,
                        signals: professorSignals,
                        player: audioPlayer
                    )
                } else {
                    TranscricaoRealTranscriptSection(
                        text: fullTranscript,
                        signals: professorSignals
                    )
                }
            } else if !isReady {
                sectionSkeleton(title: "TRANSCRIÇÃO", hint: "Transcrevendo áudio…")
            }

            // Outputs existentes (summary, flashcards).
            if !outputs.isEmpty {
                TranscricaoOutputsSection(outputs: outputs)
            } else if !isReady && !fullTranscript.isEmpty {
                // Transcript pronto mas LLM ainda roda — mostra skeleton do resumo.
                sectionSkeleton(title: "RESUMO", hint: "Gerando resumo…")
            }

            // Actions menu só quando ready (gerar mais outputs exige source pronto).
            if isReady {
                TranscricaoActionsMenu(
                    sourceId: recording.id,
                    existingOutputTypes: Set(outputs.map(\.outputType)),
                    onGenerated: { newOutput in
                        outputs.append(newOutput)
                    }
                )
            }
        }
    }

    private func pipelineBanner(status: String) -> some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(VitaColors.accentLight)
                .scaleEffect(0.8)
            Text(bannerLabel(for: status))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VitaColors.accentLight)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(VitaColors.accent.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(VitaColors.accent.opacity(0.30), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func bannerLabel(for status: String) -> String {
        switch status {
        case "processing": return "Transcrevendo e gerando resumo…"
        case "pending", "uploading": return "Enviando áudio…"
        case "failed": return "Falhou — tente de novo"
        default: return "Processando…"
        }
    }

    private func sectionSkeleton(title: String, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                .tracking(0.5)
            HStack(spacing: 10) {
                ProgressView()
                    .tint(VitaColors.accentLight)
                    .scaleEffect(0.75)
                Text(hint)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.45))
                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(0.03))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Transcribed Content (real data)

    private var transcribedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Professor signals summary
            if !professorSignals.isEmpty {
                ProfessorSignalsSummary(signals: professorSignals)
            }

            // Transcript section — karaoke mode if word timestamps available
            if !fullTranscript.isEmpty {
                if !allWords.isEmpty {
                    TranscricaoKaraokeTranscriptSection(
                        words: allWords,
                        segments: allSegments,
                        signals: professorSignals,
                        player: audioPlayer
                    )
                } else {
                    TranscricaoRealTranscriptSection(
                        text: fullTranscript,
                        signals: professorSignals
                    )
                }
            }

            // Existing outputs (summary, flashcards, etc)
            if !outputs.isEmpty {
                TranscricaoOutputsSection(outputs: outputs)
            }

            // Actions menu for generating more
            TranscricaoActionsMenu(
                sourceId: recording.id,
                existingOutputTypes: Set(outputs.map(\.outputType)),
                onGenerated: { newOutput in
                    outputs.append(newOutput)
                }
            )
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let detailTask = container.api.getStudioSourceDetail(id: recording.id)
            async let outputsTask = container.api.getStudioOutputs(sourceId: recording.id)
            let (detail, outputsResp) = try await (detailTask, outputsTask)
            sourceDetail = detail
            outputs = outputsResp.outputs

            // Sync favorite + folder/discipline state from metadata (PATCH updates).
            isFavorite = detail.metadata?.favorite ?? false
            currentDisciplineSlug = detail.metadata?.disciplineSlug
            currentFolderId = detail.metadata?.folderId

            // Extract all words from segments for karaoke
            if let segments = detail.metadata?.segments {
                allWords = segments.flatMap { $0.words ?? [] }
                allSegments = segments
            }

            // Detect professor signals in transcript
            let transcript = fullTranscript
            if !transcript.isEmpty {
                professorSignals = ProfessorSignals.detect(in: transcript)
            }

            // Prepare audio player if we have a file. Preferred path is the
            // presigned R2 URL the backend bakes into metadata — no extra
            // /files roundtrip needed.
            if detail.type == "audio" {
                if let audioUrl = detail.metadata?.audioUrl, !audioUrl.isEmpty {
                    hasAudioFile = true
                    audioPlayer.prepareFromUrl(audioUrl, words: allWords)
                } else if let audioFileId = detail.metadata?.audioFileId {
                    hasAudioFile = true
                    audioPlayer.prepareFromFileId(
                        fileId: audioFileId,
                        tokenStore: container.tokenStore,
                        words: allWords
                    )
                } else if let fileName = detail.metadata?.fileName {
                    hasAudioFile = true
                    audioPlayer.prepare(
                        fileName: fileName,
                        tokenStore: container.tokenStore,
                        words: allWords
                    )
                }
            }
        } catch {
            print("[TranscricaoDetail] loadData error: \(error)")
            errorMessage = "Erro ao carregar: \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Pole GET /studio/sources/:id até status=ready (ou failed / task cancelled).
    /// Enquanto a seção não estiver completa, cada tick re-chama loadData()
    /// pra preencher transcript/outputs progressivamente.
    private func pollUntilReady() async {
        guard !isPollingForReady else { return }
        isPollingForReady = true
        defer { isPollingForReady = false }

        // Se já veio ready na primeira carga, encerra.
        if sourceDetail?.status == "ready" || sourceDetail?.status == "failed" { return }

        // Polling com timeout de 180s (3x whisper+LLM) — se passou disso algo
        // tá muito errado no servidor, melhor abortar e mostrar botão retry.
        let deadline = Date().addingTimeInterval(180)
        while !Task.isCancelled, Date() < deadline {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { break }
            await loadData()
            if let status = sourceDetail?.status, status == "ready" || status == "failed" {
                break
            }
        }
    }
}

// MARK: - Share Sheet (UIActivityViewController bridge)

private struct TranscricaoShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Real Transcript Section

struct TranscricaoRealTranscriptSection: View {
    let text: String
    var signals: [ProfessorSignals.Signal] = []

    @State private var isExpanded = false
    @State private var copied = false
    @State private var searchQuery: String = ""
    @State private var showSearch: Bool = false

    private var displayText: String {
        // Quando user busca, expande automaticamente o transcript pra search
        // ter contexto completo. Padrão Apple Notes/Mail: search reveals.
        if !searchQuery.isEmpty || isExpanded { return text }
        let limit = 500
        if text.count <= limit { return text }
        return String(text.prefix(limit)) + "..."
    }

    /// Conta matches da query no texto (case-insensitive). Pra mostrar
    /// "3 resultados" no search bar.
    private var matchCount: Int {
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return 0 }
        return text.lowercased().components(separatedBy: q.lowercased()).count - 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TRANSCRIÇÃO")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    .tracking(0.5)
                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearch.toggle()
                        if !showSearch { searchQuery = "" }
                    }
                } label: {
                    Image(systemName: showSearch ? "magnifyingglass.circle.fill" : "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundStyle(showSearch ? VitaColors.accentLight : VitaColors.accent.opacity(0.70))
                        .frame(width: 28, height: 24)
                }
                .buttonStyle(.plain)

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
                            .font(.system(size: 11))
                        Text(copied ? "Copiado" : "Copiar")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(copied ? VitaColors.dataGreen : VitaColors.accentLight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((copied ? VitaColors.dataGreen : VitaColors.accent).opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Search bar inline — revelado pelo botão da lupa. Highlight via
            // ProfessorSignals reusado (mesma engine), tratando query como
            // signal artificial. Expande displayText quando há busca ativa.
            if showSearch {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.50))
                    TextField("Buscar na transcrição", text: $searchQuery)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !searchQuery.isEmpty {
                        Text("\(matchCount)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(matchCount > 0 ? VitaColors.accentLight : Color.white.opacity(0.30))
                            .monospacedDigit()
                        Button {
                            searchQuery = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.30))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(Color.white.opacity(0.04))
                        .overlay(Capsule().stroke(VitaColors.accent.opacity(0.18), lineWidth: 0.5))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Combina signals do professor com query do user (highlight unificado).
            let displaySignals = combinedSignals(text: displayText)
            if !displaySignals.isEmpty {
                TranscricaoHighlightedText(text: displayText, signals: displaySignals)
            } else {
                Text(displayText)
                    .font(.system(size: 12))
                    .lineSpacing(4)
                    .foregroundStyle(Color.white.opacity(0.65))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 12)
            }

            if text.count > 500 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
                } label: {
                    Text(isExpanded ? "Ver menos" : "Ver transcrição completa")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.80))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    /// Combina ProfessorSignals com matches da query do user. Reusa o mesmo
    /// rendering pipeline (TranscricaoHighlightedText) e Category novo
    /// `.searchMatch` introduzido em ProfessorSignals.
    private func combinedSignals(text searchedText: String) -> [ProfessorSignals.Signal] {
        var all = ProfessorSignals.detect(in: searchedText)
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return all }

        // Acha todas ocorrências case-insensitive da query no texto.
        let lowerText = searchedText.lowercased()
        let lowerQuery = q.lowercased()
        var searchStart = lowerText.startIndex
        while let range = lowerText.range(of: lowerQuery, range: searchStart..<lowerText.endIndex) {
            // Mapeia de volta pra range do texto original (mesmo offsets).
            all.append(ProfessorSignals.Signal(
                range: range,
                keyword: String(searchedText[range]),
                category: .searchMatch
            ))
            searchStart = range.upperBound
        }
        return all
    }
}

// MARK: - Outputs Section (existing generated content)

struct TranscricaoOutputsSection: View {
    let outputs: [StudioOutput]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CONTEÚDO GERADO")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                .tracking(0.5)

            ForEach(outputs) { output in
                TranscricaoOutputCard(output: output)
            }
        }
    }
}

struct TranscricaoOutputCard: View {
    let output: StudioOutput
    @State private var isExpanded = false

    private var icon: String {
        switch output.outputType {
        case "summary": return "doc.text"
        case "flashcards": return "rectangle.stack"
        case "questions": return "questionmark.circle"
        case "concepts": return "key"
        case "mindmap": return "point.3.connected.trianglepath.dotted"
        default: return "doc"
        }
    }

    private var label: String {
        switch output.outputType {
        case "summary": return "Resumo"
        case "flashcards": return "Flashcards"
        case "questions": return "Questões"
        case "concepts": return "Conceitos-chave"
        case "mindmap": return "Mindmap"
        default: return output.outputType.capitalized
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(VitaColors.accent.opacity(0.08))
                            .frame(width: 36, height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(VitaColors.accent.opacity(0.12), lineWidth: 1)
                            )
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.80))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(label)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.80))
                        if output.status == "ready" {
                            Text("Pronto")
                                .font(.system(size: 10))
                                .foregroundStyle(VitaColors.dataGreen.opacity(0.7))
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.30))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded, let content = output.content {
                Rectangle().fill(VitaColors.accent.opacity(0.10)).frame(height: 1)

                // Flashcards — render as flip-style cards
                if let flashcards = content.flashcards, !flashcards.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(flashcards) { card in
                            TranscricaoFlashcardMini(front: card.front, back: card.back)
                        }
                    }
                    .padding(14)
                }
                // Questions — render as Q&A pairs
                else if let questions = content.questions, !questions.isEmpty {
                    VStack(spacing: 10) {
                        ForEach(Array(questions.enumerated()), id: \.offset) { idx, q in
                            TranscricaoQuestionMini(index: idx + 1, question: q.question, answer: q.answer)
                        }
                    }
                    .padding(14)
                }
                // Markdown fallback
                else if let markdown = content.markdown, !markdown.isEmpty {
                    VitaMarkdown(content: markdown, fontSize: 12)
                        .padding(14)
                }
            }
        }
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Live Audio Player Bar (real AVPlayer)

struct TranscricaoLivePlayerBar: View {
    @ObservedObject var player: TranscricaoAudioPlayer
    @State private var isSeeking = false
    @State private var seekValue: Double = 0

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                // Play/Pause
                Button {
                    player.togglePlayPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(VitaColors.accent.opacity(0.12))
                            .frame(width: 40, height: 40)
                            .overlay(Circle().stroke(VitaColors.accent.opacity(0.20), lineWidth: 1))

                        if player.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(VitaColors.accentLight)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(VitaColors.accentLight.opacity(0.90))
                                .offset(x: player.isPlaying ? 0 : 1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(player.isLoading)

                // Scrubber
                VStack(spacing: 2) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06)).frame(height: 4)
                            Capsule().fill(
                                LinearGradient(
                                    colors: [VitaColors.accent.opacity(0.70), VitaColors.accentLight.opacity(0.50)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * (isSeeking ? seekValue : player.progress), height: 4)

                            // Thumb
                            Circle()
                                .fill(VitaColors.accentLight)
                                .frame(width: 10, height: 10)
                                .shadow(color: VitaColors.accent.opacity(0.3), radius: 3)
                                .offset(x: geo.size.width * (isSeeking ? seekValue : player.progress) - 5)
                                .opacity(player.duration > 0 ? 1 : 0)
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    isSeeking = true
                                    seekValue = max(0, min(1, value.location.x / geo.size.width))
                                }
                                .onEnded { _ in
                                    player.seek(to: seekValue)
                                    isSeeking = false
                                }
                        )
                    }
                    .frame(height: 20)

                    // Timestamps
                    HStack {
                        Text(player.currentTimeFormatted)
                        Spacer()
                        Text(player.durationFormatted)
                    }
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.30))
                }
            }

            // Speed picker + skip silence — só aparece quando duração>0 (áudio
            // carregado). Padrão Overcast/Pocket Casts: linha sub abaixo do
            // scrubber, controles compactos e gold-tinted.
            if player.duration > 0 {
                HStack(spacing: 8) {
                    Menu {
                        ForEach([0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { rate in
                            Button {
                                player.playbackRate = Float(rate)
                            } label: {
                                if abs(Double(player.playbackRate) - rate) < 0.01 {
                                    Label(String(format: "%.2f×", rate), systemImage: "checkmark")
                                } else {
                                    Text(String(format: "%.2f×", rate))
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gauge.with.needle")
                                .font(.system(size: 10, weight: .medium))
                            Text(String(format: "%.2g×", Double(player.playbackRate)))
                                .font(.system(size: 11, weight: .semibold))
                                .monospacedDigit()
                        }
                        .foregroundStyle(player.playbackRate == 1.0 ? Color.white.opacity(0.50) : VitaColors.accentLight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(player.playbackRate == 1.0 ? Color.white.opacity(0.04) : VitaColors.accent.opacity(0.10))
                                .overlay(Capsule().stroke(VitaColors.accent.opacity(0.18), lineWidth: 0.5))
                        )
                    }

                    Button {
                        player.skipSilenceEnabled.toggle()
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: player.skipSilenceEnabled ? "forward.end.alt.fill" : "forward.end.alt")
                                .font(.system(size: 10, weight: .medium))
                            Text("Pular silêncio")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(player.skipSilenceEnabled ? VitaColors.accentLight : Color.white.opacity(0.50))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(player.skipSilenceEnabled ? VitaColors.accent.opacity(0.10) : Color.white.opacity(0.04))
                                .overlay(Capsule().stroke(VitaColors.accent.opacity(0.18), lineWidth: 0.5))
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }

            if player.error != nil {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.slash")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.25))
                    Text("Áudio não disponível")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 12)
    }
}

// MARK: - Karaoke Transcript Section

struct TranscricaoKaraokeTranscriptSection: View {
    let words: [WhisperWord]
    let segments: [WhisperSegment]
    let signals: [ProfessorSignals.Signal]
    @ObservedObject var player: TranscricaoAudioPlayer
    @State private var copied = false

    private var fullText: String {
        words.map(\.word).joined(separator: " ")
    }

    /// Formato [mm:ss] tipo Otter/Plaud — clicável pra pular áudio.
    private static func formatTimestamp(_ seconds: Double) -> String {
        let total = max(0, Int(seconds))
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TRANSCRIÇÃO")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    .tracking(0.5)

                Image(systemName: "waveform")
                    .font(.system(size: 10))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.5))

                Spacer()

                Button {
                    UIPasteboard.general.string = fullText
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
                    .foregroundStyle(copied ? VitaColors.dataGreen : VitaColors.accentLight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((copied ? VitaColors.dataGreen : VitaColors.accent).opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Render segment-by-segment com timestamp clicável tipo Otter/Plaud.
            // Timestamp só aparece quando agrega valor: 2+ segments OU primeiro
            // segment começa depois do início (>1s). Gravação curta de 1 bloco
            // começando do 0 não precisa — só polui (Rafael 2026-04-27).
            let showTimestamps = segments.count > 1 || (segments.first?.start ?? 0) > 1.0
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(segments.enumerated()), id: \.offset) { idx, seg in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        // Timestamp clicável — Otter/Plaud pattern: tap pula áudio.
                        // Ícone ▶ deixa claro que é "play from", não relógio.
                        if showTimestamps {
                            Button {
                                player.seekToTime(seg.start)
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } label: {
                                HStack(spacing: 3) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 8, weight: .bold))
                                    Text(Self.formatTimestamp(seg.start))
                                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                }
                                .foregroundStyle(VitaColors.accentLight.opacity(0.85))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(VitaColors.accent.opacity(0.10))
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        // Words deste segment (subset do words flat global,
                        // pra activeWordIndex continuar batendo).
                        let segWords = seg.words ?? []
                        if !segWords.isEmpty {
                            // Indices globais das words deste segment.
                            let globalStartIdx = words.firstIndex(where: {
                                $0.start == segWords.first!.start && $0.word == segWords.first!.word
                            }) ?? 0

                            TranscricaoKaraokeText(
                                words: segWords,
                                signals: signals,
                                activeWordIndex: player.activeWordIndex.map { $0 - globalStartIdx },
                                isPlaying: player.isPlaying,
                                onTapWord: { localIdx in
                                    player.seekToWord(at: globalStartIdx + localIdx)
                                }
                            )
                        } else {
                            // Fallback: segment sem words por algum motivo
                            Text(seg.text)
                                .font(.system(size: 13))
                                .foregroundStyle(Color.white.opacity(0.55))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }

            Text("Toque na palavra ou no timestamp pra pular o áudio")
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.25))
                .frame(maxWidth: .infinity, alignment: .center)
        }
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
                        .tint(VitaColors.accentLight)
                        .scaleEffect(0.8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Transcrevendo...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.90))
                        Text("Feche e abra depois — avisamos quando estiver pronto.")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.25))
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .glassCard(cornerRadius: 12)
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
                    .foregroundStyle(VitaColors.accentLight.opacity(0.90))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(VitaColors.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(VitaColors.accent.opacity(0.24), lineWidth: 1)
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

// MARK: - Actions Menu

struct TranscricaoActionsMenu: View {
    let sourceId: String
    let existingOutputTypes: Set<String>
    let onGenerated: (StudioOutput) -> Void

    @Environment(\.appContainer) private var container

    private struct ActionDef: Identifiable {
        let id: String
        let icon: String
        let name: String
        let desc: String
    }

    private let actions: [ActionDef] = [
        ActionDef(id: "summary", icon: "doc.text", name: "Gerar resumo", desc: "Resumo estruturado da aula"),
        ActionDef(id: "flashcards", icon: "rectangle.stack", name: "Gerar flashcards", desc: "Cards de memorização automáticos"),
        ActionDef(id: "questions", icon: "questionmark.circle", name: "Gerar questões", desc: "Questões de prova baseadas na aula"),
        ActionDef(id: "concepts", icon: "key", name: "Extrair conceitos-chave", desc: "Termos e definições importantes"),
        ActionDef(id: "mindmap", icon: "point.3.connected.trianglepath.dotted", name: "Mindmap", desc: "Mapa mental visual do conteúdo"),
    ]

    @State private var selectedActions: Set<String> = []
    @State private var isGenerating = false
    @State private var generatingType: String?
    @State private var generateError: String?

    private var availableActions: [ActionDef] {
        actions.filter { !existingOutputTypes.contains($0.id) }
    }

    var body: some View {
        if !availableActions.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("O QUE FAZER COM ESTA AULA?")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    .tracking(0.5)

                ForEach(availableActions) { action in
                    TranscricaoActionItemRow(
                        icon: action.icon,
                        name: action.name,
                        desc: action.desc,
                        isSelected: selectedActions.contains(action.id),
                        isGenerating: generatingType == action.id,
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

                if let err = generateError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.dataRed.opacity(0.8))
                        Text(err)
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.dataRed.opacity(0.7))
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(VitaColors.dataRed.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if !selectedActions.isEmpty {
                    Button {
                        Task { await generateSelected() }
                    } label: {
                        HStack(spacing: 8) {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .scaleEffect(0.7)
                            }
                            Text(isGenerating ? "Gerando..." : "Gerar selecionados (\(selectedActions.count))")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [VitaColors.accent.opacity(0.85), VitaColors.accentLight.opacity(0.65)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: VitaColors.accent.opacity(0.25), radius: 10, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isGenerating)
                    .opacity(isGenerating ? 0.7 : 1)
                    .padding(.top, 4)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
    }

    private func generateSelected() async {
        isGenerating = true
        generateError = nil
        var failCount = 0
        let types = Array(selectedActions)
        for type in types {
            generatingType = type
            do {
                let output = try await container.api.generateStudioOutput(sourceId: sourceId, outputType: type)
                await MainActor.run {
                    onGenerated(output)
                    selectedActions.remove(type)
                }
            } catch {
                failCount += 1
                let label = actions.first { $0.id == type }?.name ?? type
                generateError = "Falha ao gerar \(label): \(error.localizedDescription)"
            }
        }
        generatingType = nil
        isGenerating = false
    }
}

// MARK: - Action Item Row

struct TranscricaoActionItemRow: View {
    let icon: String
    let name: String
    let desc: String
    let isSelected: Bool
    var isGenerating: Bool = false
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VitaColors.accent.opacity(0.08))
                        .frame(width: 36, height: 36)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(VitaColors.accent.opacity(0.12), lineWidth: 1)
                        )
                    if isGenerating {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(VitaColors.accentLight)
                            .scaleEffect(0.6)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 14))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.80))
                    }
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
                        .fill(isSelected ? VitaColors.accent.opacity(0.20) : Color.clear)
                        .frame(width: 20, height: 20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    isSelected ? VitaColors.accent.opacity(0.60) : Color.white.opacity(0.12),
                                    lineWidth: 1.5
                                )
                        )
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.90))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassCard(cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }
}

// MARK: - Flashcard Mini Card

struct TranscricaoFlashcardMini: View {
    let front: String
    let back: String
    @State private var showBack = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 9))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.5))
                Text("Flashcard")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.5))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showBack.toggle() }
                } label: {
                    Text(showBack ? "Esconder" : "Ver resposta")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            Text(front)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))

            if showBack {
                Rectangle()
                    .fill(VitaColors.accent.opacity(0.10))
                    .frame(height: 1)
                Text(back)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(VitaColors.accent.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(VitaColors.accent.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Question Mini Card

struct TranscricaoQuestionMini: View {
    let index: Int
    let question: String
    let answer: String?
    @State private var showAnswer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 6) {
                Text("\(index)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.6))
                    .frame(width: 18, height: 18)
                    .background(VitaColors.accent.opacity(0.10))
                    .clipShape(Circle())

                Text(question)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
            }

            if let answer, !answer.isEmpty {
                if showAnswer {
                    Rectangle()
                        .fill(VitaColors.accent.opacity(0.10))
                        .frame(height: 1)
                    Text(answer)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.60))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showAnswer = true }
                    } label: {
                        Text("Ver resposta")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.7))
                            .padding(.leading, 24)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(VitaColors.accent.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(VitaColors.accent.opacity(0.10), lineWidth: 1)
        )
    }
}

// MARK: - Done Phase (after transcription completes via SSE)

struct TranscricaoDonePhase: View {
    let transcript: String
    let summary: String
    let flashcards: [TranscriptionFlashcard]
    let onReset: () -> Void

    @State private var selectedTab = 0
    private let tabs = ["Transcrição", "Resumo", "Flashcards"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, title in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = index }
                    } label: {
                        VStack(spacing: 6) {
                            Text(title)
                                .font(.system(size: 12, weight: selectedTab == index ? .semibold : .regular))
                                .foregroundStyle(
                                    selectedTab == index ? VitaColors.accentLight : Color.white.opacity(0.55)
                                )
                            Rectangle()
                                .fill(selectedTab == index ? VitaColors.accent : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(VitaColors.accent.opacity(0.10)).frame(height: 1)
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
                        .foregroundStyle(copied ? VitaColors.dataGreen : VitaColors.accentLight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background((copied ? VitaColors.dataGreen : VitaColors.accent).opacity(0.1))
                        .clipShape(Capsule())
                    }
                }

                Text(text.isEmpty ? "Nenhuma transcrição disponível." : text)
                    .font(.system(size: 12))
                    .lineSpacing(4)
                    .foregroundStyle(Color.white.opacity(0.70))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(cornerRadius: 12)
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
                        .glassCard(cornerRadius: 12)
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
                        .foregroundStyle(VitaColors.accentLight)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(VitaColors.accent.opacity(0.1))
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
            Rectangle().fill(VitaColors.accent.opacity(0.10)).frame(height: 1)
            Text(card.back)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.55))
                .padding(14)
        }
        .glassCard(cornerRadius: 12)
    }
}
