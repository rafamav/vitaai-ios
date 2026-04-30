import SwiftUI
import PDFKit
import PencilKit
import Combine

// MARK: - PdfViewerScreen

/// Full-screen PDF viewer using native PDFView + PDFPageOverlayViewProvider + PKToolPicker.
/// Works like GoodNotes: continuous scroll, pinch zoom, Apple Pencil + finger ink per page.
struct PdfViewerScreen: View {
    let url: URL
    var initialTitle: String? = nil
    let onBack: () -> Void

    @Environment(\.appContainer) private var container
    @State private var viewModel = PdfViewerViewModel()
    @State private var workspace = PdfWorkspaceState()
    @State private var lastLoadedURL: URL? = nil
    @State private var isLoadingTab: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var exportedURL: URL? = nil
    @State private var searchDebounceTask: Task<Void, Never>? = nil
    @State private var recognitionCopied: Bool = false
    @State private var isFullscreen: Bool = false
    @State private var showPerguntaVita: Bool = false
    @State private var perguntaVitaImageData: Data? = nil
    @State private var showFilePicker: Bool = false
    // Scan mode (Pergunte ao Vita)
    @State private var isScanMode: Bool = false
    @State private var scanSelection: CGRect? = nil   // in pdfViewContainer coords
    @State private var pdfViewContainerFrame: CGRect = .zero
    // VisionKit document scanner (camera → PDF pages)
    @State private var showDocumentScanner: Bool = false
    // ZONE-A — Pen styles + eraser/pointer + undo/redo
    @State private var isEraserMode: Bool = false
    @State private var isPointerMode: Bool = false
    @State private var canUndo: Bool = false
    @State private var canRedo: Bool = false
    @State private var showPenStyles: Bool = false
    @State private var showHighlightColor: Bool = false
    // ZONE-B — Header sheets (bookmarks list, outline, settings)
    @State private var showBookmarksSheet: Bool = false
    @State private var showOutlineSheet: Bool = false
    @State private var showSettingsSheet: Bool = false
    // ZONE-C — Study Mode (masks pra estudar)
    @State private var isMaskingMode: Bool = false
    @State private var isStudyMode: Bool = false
    @State private var studyMaskPrompt: StudyMaskPrompt? = nil
    @State private var showStudyStatsSheet: Bool = false
    @State private var attemptFlash: AttemptFlash? = nil
    /// Painel flutuante inline "Estudo Ativo" (Rafael 2026-04-28 redesign).
    /// Toggle controlado pelo ícone do olho na toolbar. Quando ON, aparece
    /// card glass dentro do PDF com 2 ações (Criar máscaras / Revisar).
    @State private var showStudyActivePanel: Bool = false
    // Mode banner — ephemeral hint (3s fade) when entering a mode.
    // "Sair" only dismisses the banner — to exit the mode, user taps the icon again.
    @State private var isModeBannerVisible: Bool = false
    @State private var bannerHideTask: Task<Void, Never>? = nil
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    OrbMascot(palette: .vita, state: .thinking, size: 120)
                    Text("Abrindo documento")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textSecondary)
                }
            } else if let document = viewModel.document, viewModel.pageCount > 0 {
                mainContent(document: document)
            } else {
                errorView
            }

            // Scan overlay — on top of PDF, below the mascot.
            if isScanMode {
                PdfScanOverlay(
                    selection: $scanSelection,
                    onConfirm: {
                        performScan(rectInOverlay: scanSelection)
                    },
                    onFullPage: {
                        performScan(rectInOverlay: nil)
                    },
                    onCancel: {
                        exitScanMode()
                    }
                )
                .frame(width: pdfViewContainerFrame.width, height: pdfViewContainerFrame.height)
                .position(x: pdfViewContainerFrame.midX, y: pdfViewContainerFrame.midY)
                .transition(.opacity)
            }

            // Attempt flash overlay (verde acertei / vermelho errou) — bounce 600ms
            if let flash = attemptFlash {
                Image(systemName: flash.correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 96, weight: .bold))
                    .foregroundStyle(flash.correct ? Color.green : Color.red)
                    .shadow(color: (flash.correct ? Color.green : Color.red).opacity(0.7), radius: 24)
                    .scaleEffect(flash.scale)
                    .opacity(flash.opacity)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            // Active-mode banner — ephemeral hint (3s fade) when entering a mode.
            // "Sair" só dismissa o banner; sair do modo é re-tap no ícone do modo
            // (Rafael 2026-04-28). Banner reaparece toda vez que o modo é
            // re-ligado ou trocado por outro.
            if let banner = activeModeBanner, isModeBannerVisible {
                VStack {
                    activeModeBannerView(banner)
                        .padding(.top, 110)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }

            // Audio sync overlay — pílula flutuante no bottom mostrando estado
            // de gravação/playback. Visível durante .recording sempre, e quando
            // .loaded/.playing/.paused se isOverlayVisible == true.
            if viewModel.audioRecorder.isOverlayVisible
                || viewModel.audioRecorder.state == .recording {
                VStack {
                    Spacer()
                    PdfAudioPlaybackOverlay(
                        recorder: viewModel.audioRecorder,
                        onStartRecording: { toggleAudioRecording() },
                        onStopRecording: { toggleAudioRecording() },
                        onClose: { viewModel.audioRecorder.closeOverlay() }
                    )
                    .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Floating Study Mode indicator — fica no canto direito quando Study
            // ON. Tap abre stats sheet. Substitui o long-press escondido do ícone
            // da toolbar (Rafael 2026-04-28: "long-press não dá pra tirar da bunda").
            if isStudyMode {
                VStack {
                    HStack {
                        Spacer()
                        studyModeFloatingIndicator
                            .padding(.top, 130)
                            .padding(.trailing, 16)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .allowsHitTesting(true)
            }

            // Painel flutuante "Estudo Ativo" — Rafael 2026-04-28 redesign.
            // Card glass inline DENTRO do PDF (canto inferior direito) com
            // 2 ações (Criar máscaras / Revisar). Substitui o Menu nativo
            // SwiftUI antigo que sobrepunha o próprio botão.
            if showStudyActivePanel {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        studyActivePanel
                            .padding(.trailing, 16)
                            .padding(.bottom, 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.scale(scale: 0.85, anchor: .topTrailing).combined(with: .opacity))
                .allowsHitTesting(true)
            }

        }
        .task {
            // Multi-doc workspace: open the URL passed by the router as a tab.
            // If user already had other tabs from a previous session, they remain.
            // Mutating activeId here triggers .onChange below — single load path.
            workspace.open(url: url, title: initialTitle)
            // Wire study mode tap callback — Coordinator chama quando user toca mask
            viewModel.onStudyMaskTap = { prompt in
                studyMaskPrompt = prompt
            }
            // Wire HW->text substituição (Goodnotes 6 Live Text Conversion).
            // ViewModel.replaceCurrentDrawingWithFreeText invoca isso pra zerar o
            // PKCanvasView ativo da página visível depois de criar a PDFAnnotation.
            viewModel.onClearActiveCanvas = {
                currentCanvas()?.drawing = PKDrawing()
            }
        }
        .onChange(of: workspace.activeId, initial: true) { _, _ in
            Task {
                await loadActiveTab()
                ScreenLoadContext.finish(for: "PdfViewer")
                VitaPostHogConfig.capture(event: "pdf_opened", properties: [
                    "page_count": viewModel.pageCount,
                    "loaded": viewModel.document != nil,
                    "tab_count": workspace.openDocs.count,
                ])
            }
        }
        .onChange(of: activeModeBanner?.id) { oldId, newId in
            // Distingue 3 transições:
            //   nil → id      (ligou modo)         → mostra banner com fade-in
            //   idA → idB     (trocou de modo)     → re-mostra banner (novo conteúdo)
            //   id → nil      (desligou modo)      → cancela timer, esconde DIRETO sem reanimar
            // Bug pré-fix: o else esconde sem distinguir, mas como showModeBanner
            // tinha rodado antes com 3s timer ainda pendente, ao desligar o
            // banner reaparecia momentaneamente porque o `withAnimation` antigo
            // ainda estava em flight. Agora ao desligar matamos o task e baixamos
            // o flag sem nova animação — a view some no mesmo frame que
            // activeModeBanner vira nil.
            if newId != nil {
                if oldId != newId {
                    showModeBanner()
                }
            } else {
                bannerHideTask?.cancel()
                bannerHideTask = nil
                isModeBannerVisible = false
            }
        }
        // Goodnotes-style: + tab abre picker dos PDFs do user (Vita library),
        // não Files iOS. PdfUserDocumentsPicker já tem fallback "Importar Files"
        // dentro pra casos edge.
        // vita-modals-ignore: PdfUserDocumentsPicker tem NavigationStack próprio (necessário pra .searchable + toolbar com botão Files) — VitaSheet causaria header duplicado e quebra search nativo
        .sheet(isPresented: $showFilePicker) {
            PdfUserDocumentsPicker(
                onSelect: { pickedURL, title in
                    workspace.open(url: pickedURL, title: title)
                    showFilePicker = false
                },
                onCancel: { showFilePicker = false }
            )
        }
        // VisionKit Document Scanner — camera → PDF pages, anexa no fim do doc.
        // vita-modals-ignore: VNDocumentCameraViewController é viewController nativo Apple — VitaSheet quebraria a captura de câmera (precisa de fullScreenCover puro)
        .fullScreenCover(isPresented: $showDocumentScanner) {
            PdfDocumentScanner(
                onScan: { images in
                    showDocumentScanner = false
                    guard !images.isEmpty else { return }
                    viewModel.appendScannedPages(images)
                    VitaPostHogConfig.capture(event: "pdf_scan_pages_added", properties: [
                        "count": images.count,
                        "total_pages": viewModel.pageCount,
                    ])
                },
                onCancel: { showDocumentScanner = false }
            )
            .ignoresSafeArea()
        }
        .trackScreen("PdfViewer")
        .onDisappear { viewModel.saveAllAnnotations() }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard)
        // PDF é experiência imersiva — esconde TopBar + Breadcrumb + TabBar
        // assim que abre (não só em fullscreen). Botão back fica no header
        // interno (ícone casa). Status bar e safe-area só somem em fullscreen real.
        .statusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        .ignoresSafeArea(isFullscreen ? .all : [])
        .preference(key: ImmersivePreferenceKey.self, value: true)
        // vita-modals-ignore: ShareSheet (UIActivityViewController) é UIKit wrapper, não SwiftUI content — VitaSheet quebra a apresentação nativa do share dialog
        .sheet(isPresented: $showExportSheet) {
            if let exportedURL {
                ShareSheet(items: [exportedURL])
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $viewModel.showRecognitionResult) {
            VitaSheet(title: "Texto reconhecido", detents: [.medium, .large]) {
                recognitionResultSheet
            }
        }
        // vita-modals-ignore: PdfBookmarksListSheet já usa VitaSheet internamente — wrapper duplo causaria header duplicado
        .sheet(isPresented: $showBookmarksSheet) {
            if let document = viewModel.document {
                PdfBookmarksListSheet(
                    document: document,
                    bookmarkedPages: viewModel.bookmarkedPages,
                    onJumpToPage: { idx in
                        viewModel.currentPage = idx
                        showBookmarksSheet = false
                    },
                    onRemoveBookmark: { idx in
                        viewModel.toggleBookmark(forPage: idx)
                    }
                )
            }
        }
        // vita-modals-ignore: PdfOutlineSheet já usa VitaSheet internamente — wrapper duplo causaria header duplicado
        .sheet(isPresented: $showOutlineSheet) {
            if let document = viewModel.document {
                PdfOutlineSheet(
                    document: document,
                    onJumpToPage: { idx in
                        viewModel.currentPage = idx
                        showOutlineSheet = false
                    }
                )
            }
        }
        // vita-modals-ignore: PdfSettingsSheet já usa VitaSheet internamente — wrapper duplo causaria header duplicado
        .sheet(isPresented: $showSettingsSheet) {
            PdfSettingsSheet(
                onResetAnnotations: {
                    viewModel.resetAllAnnotations()
                    showSettingsSheet = false
                }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: .pdfSettingsChanged)) { note in
            applyPdfSettingsLive(note: note)
        }
        // Pen styles + highlight color popovers — abertos via long-press na toolbar.
        // vita-modals-ignore: VitaGlassCard custom inside, presentationDetent .height fixo — VitaSheet adiciona header/padding desnecessários pra picker compacto
        .sheet(isPresented: $showPenStyles) {
            PdfPenStylesPopover(onApply: { tool in applyInkingTool(tool) })
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        // vita-modals-ignore: ver acima — picker compacto custom
        .sheet(isPresented: $showHighlightColor) {
            PdfHighlightColorPopover(onApply: { color in applyHighlightColor(color) })
                .presentationDetents([.height(220)])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
        // Study Mode stats — long-press no botão Study Mode abre.
        // vita-modals-ignore: PdfStudyStatsSheet já usa VitaSheet internamente — wrapper duplo causaria header duplicado
        .sheet(isPresented: $showStudyStatsSheet) {
            if let document = viewModel.document {
                PdfStudyStatsSheet(
                    document: document,
                    fileHash: viewModel.fileHash,
                    onJumpToPage: { idx in
                        viewModel.currentPage = idx
                        showStudyStatsSheet = false
                    }
                )
            }
        }
        // Study Mode prompt — usuário tocou numa mask, pergunta acertei/errei.
        // vita-modals-ignore: VitaSheet importado mas conteúdo é decisão binária compacta — uso .sheet com .height(220) pra ficar discreto perto do tap point
        .sheet(item: $studyMaskPrompt) { prompt in
            StudyMaskPromptSheet(
                onCorrect: { recordStudyAttempt(prompt: prompt, correct: true) },
                onWrong: { recordStudyAttempt(prompt: prompt, correct: false) },
                onCancel: { studyMaskPrompt = nil }
            )
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        // Pergunte ao Vita chat opens as a sheet (not fullScreenCover) so the
        // PDF stays visible underneath — user can cross-reference while chatting.
        // vita-modals-ignore: VitaChatScreen é tela completa autocontida (próprio header, fundo, scroll) — VitaSheet duplicaria header e quebra layout interno do chat
        .sheet(isPresented: $showPerguntaVita) {
            VitaChatScreen(
                onClose: { showPerguntaVita = false },
                initialImageData: perguntaVitaImageData
            )
            .presentationDetents([.large, .medium])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(document: PDFDocument) -> some View {
        VStack(spacing: 0) {
            // Fullscreen real (Rafael 2026-04-25 v2): esconde TODA chrome do
            // PDF — toolbar + multi-doc tabs. Só fica o fullscreenExitPill
            // minimalista no canto top-leading pra sair. Tap no PDF mantém
            // gestos nativos (zoom/pan); pra reativar a chrome, sair fullscreen.
            if !isFullscreen {
            PdfToolbar(
                    fileName: viewModel.fileName,
                    currentPage: viewModel.currentPage + 1,
                    pageCount: viewModel.pageCount,
                    isSaving: viewModel.isSaving,
                    isAnnotating: viewModel.isAnnotating,
                    isHighlightMode: viewModel.isHighlightMode,
                    isTextMode: viewModel.isTextMode,
                    isSearching: viewModel.isSearching,
                    isBookmarked: viewModel.isCurrentPageBookmarked,
                    hasInkOnCurrentPage: viewModel.currentDrawingProvider?()?.strokes.isEmpty == false,
                    isRecognizing: viewModel.isRecognizing,
                    isLassoMode: viewModel.isLassoMode,
                    showThumbnailToggle: viewModel.pageCount > 1,
                    isEraserMode: isEraserMode,
                    isPointerMode: isPointerMode,
                    canUndo: canUndo,
                    canRedo: canRedo,
                    isMaskingMode: isMaskingMode,
                    isStudyMode: isStudyMode,
                    isStudyActiveMode: showStudyActivePanel,
                    onBack: {
                        viewModel.saveAllAnnotations()
                        onBack()
                    },
                    onToggleThumbnails: viewModel.toggleThumbnails,
                    onToggleAnnotating: viewModel.toggleAnnotating,
                    onToggleHighlight: viewModel.toggleHighlightMode,
                    onToggleText: viewModel.toggleTextMode,
                    onToggleLasso: viewModel.toggleLassoMode,
                    onToggleSearch: {
                        viewModel.toggleSearch()
                        if viewModel.isSearching {
                            isSearchFocused = true
                        }
                    },
                    onToggleBookmark: viewModel.toggleBookmark,
                    onToggleFullscreen: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isFullscreen.toggle()
                        }
                    },
                    onAskVita: {
                        let willEnable = !isScanMode
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isScanMode = willEnable
                            scanSelection = nil
                        }
                        VitaPostHogConfig.capture(event: "pergunte_ao_vita_tap", properties: ["enabled": willEnable])
                    },
                    onExport: {
                        Task { await exportPDF(document: document) }
                    },
                    onTranscribe: {
                        guard let drawing = viewModel.currentDrawingProvider?(),
                              !drawing.strokes.isEmpty else { return }
                        Task { await viewModel.recognizeHandwriting(drawing: drawing) }
                    },
                    onScanDocument: {
                        showDocumentScanner = true
                        VitaPostHogConfig.capture(event: "pdf_scan_document_tap")
                    },
                    onToggleEraser: {
                        isEraserMode.toggle()
                        if isEraserMode { isPointerMode = false }
                        applyToolMode()
                    },
                    onTogglePointer: {
                        isPointerMode.toggle()
                        if isPointerMode { isEraserMode = false }
                        applyToolMode()
                    },
                    onUndo: { performUndo() },
                    onRedo: { performRedo() },
                    onPenLongPress: { showPenStyles = true },
                    onHighlightLongPress: { showHighlightColor = true },
                    onShowBookmarksList: { showBookmarksSheet = true },
                    onShowOutline: { showOutlineSheet = true },
                    onShowSettings: { showSettingsSheet = true },
                    onToggleMasking: { toggleMaskingMode() },
                    onToggleStudyMode: { toggleStudyMode() },
                    onShowStudyStats: { showStudyStatsSheet = true },
                    onToggleStudyActive: {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                            showStudyActivePanel.toggle()
                        }
                        // Ao FECHAR o painel, sai dos sub-modos (limpa estado).
                        // Ao ABRIR, painel só mostra opções — sub-modos só ligam
                        // quando user clica em Criar máscaras ou Revisar.
                        if !showStudyActivePanel {
                            if isMaskingMode { toggleMaskingMode() }
                            if isStudyMode { toggleStudyMode() }
                        }
                        VitaPostHogConfig.capture(event: "pdf_study_active_toggle", properties: [
                            "open": showStudyActivePanel,
                        ])
                    },
                    isAudioRecording: viewModel.audioRecorder.state == .recording,
                    hasAudioRecorded: viewModel.audioRecorder.state == .loaded
                        || viewModel.audioRecorder.state == .playing
                        || viewModel.audioRecorder.state == .paused,
                    onToggleAudioRecording: { toggleAudioRecording() },
                    onTogglePlaybackOverlay: {
                        viewModel.audioRecorder.isOverlayVisible.toggle()
                    }
                )

                // Multi-doc tab bar (Goodnotes-style). Same fullscreen guard.
                PdfTabBar(
                    openDocs: workspace.openDocs,
                    activeId: workspace.activeId,
                    onSelect: { id in
                        viewModel.saveAllAnnotations()
                        workspace.setActive(id)
                    },
                    onClose: { id in
                        if id == workspace.activeId {
                            viewModel.saveAllAnnotations()
                        }
                        let stillOpen = workspace.close(id: id)
                        if !stillOpen {
                            // Last tab closed → exit the viewer
                            onBack()
                        }
                    },
                    onAdd: { showFilePicker = true },
                    onCloseOthers: { id in
                        viewModel.saveAllAnnotations()
                        workspace.closeOthers(keep: id)
                    },
                    onCloseAll: {
                        viewModel.saveAllAnnotations()
                        workspace.closeAll()
                        onBack()
                    }
                )
            }

            // Search bar slides in below top bar
            if viewModel.isSearching {
                PdfSearchBar(
                    searchText: $viewModel.searchText,
                    resultCount: viewModel.searchResults.count,
                    currentIndex: viewModel.searchResults.isEmpty ? 0 : viewModel.currentSearchIndex + 1,
                    isSearchFocused: $isSearchFocused,
                    onPrevious: {
                        if let pv = NativePdfView.pdfViewRef { viewModel.previousResult(pdfView: pv) }
                    },
                    onNext: {
                        if let pv = NativePdfView.pdfViewRef { viewModel.nextResult(pdfView: pv) }
                    },
                    onClose: {
                        viewModel.toggleSearch()
                        viewModel.clearSearchHighlights(in: NativePdfView.pdfViewRef)
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
                .onChange(of: viewModel.searchText) { _, newValue in
                    searchDebounceTask?.cancel()
                    searchDebounceTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        guard !Task.isCancelled else { return }
                        viewModel.performSearch(newValue, pdfView: NativePdfView.pdfViewRef)
                    }
                }
            }

            ZStack(alignment: .leading) {
                NativePdfView(viewModel: viewModel)
                    .allowsHitTesting(!isScanMode)   // disable pan/zoom during scan
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { pdfViewContainerFrame = geo.frame(in: .global) }
                                .onChange(of: geo.size) { _, _ in
                                    pdfViewContainerFrame = geo.frame(in: .global)
                                }
                        }
                    )

                PageThumbnailSidebar(
                    document: document,
                    pageCount: viewModel.pageCount,
                    currentPage: viewModel.currentPage,
                    isVisible: viewModel.showThumbnails,
                    bookmarkedPages: viewModel.bookmarkedPages,
                    onPageSelected: { page in
                        viewModel.currentPage = page
                    },
                    onToggleBookmarkFor: { index in
                        viewModel.toggleBookmark(forPage: index)
                    },
                    onRotatePage: { index, degrees in
                        viewModel.rotatePage(at: index, byDegrees: degrees)
                    },
                    onMovePage: { src, dst in
                        viewModel.movePage(from: src, to: dst)
                        VitaPostHogConfig.capture(event: "pdf_page_reordered", properties: [
                            "from": src,
                            "to": dst,
                        ])
                    },
                    onDeletePage: { index in
                        viewModel.deletePage(at: index)
                        VitaPostHogConfig.capture(event: "pdf_page_deleted", properties: [
                            "index": index,
                        ])
                    },
                    onDuplicatePage: { index in
                        viewModel.duplicatePage(at: index)
                        VitaPostHogConfig.capture(event: "pdf_page_duplicated", properties: [
                            "index": index,
                        ])
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSearching)
        .overlay(alignment: .topLeading) {
            if isFullscreen && !isScanMode {
                fullscreenExitPill
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Scan mode lifecycle

    private func exitScanMode() {
        withAnimation(.easeInOut(duration: 0.22)) {
            isScanMode = false
            scanSelection = nil
        }
    }

    /// Renders the selected region (or full current page if rectInOverlay is nil)
    /// as a JPEG and opens VitaChat with it attached.
    private func performScan(rectInOverlay: CGRect?) {
        guard let pdfView = NativePdfView.pdfViewRef,
              let page = pdfView.currentPage else {
            exitScanMode()
            return
        }

        // Decide the region in PAGE space to render.
        let pageBoxBounds = page.bounds(for: .mediaBox)
        let pageRectToRender: CGRect

        if let rect = rectInOverlay, rect.width > 0, rect.height > 0 {
            // Convert the overlay rect (screen / container coords) → PDFView local → page.
            // pdfViewContainerFrame is in .global, overlay rect was also captured
            // relative to the container (PdfScanOverlay lives in that frame).
            let topLeftInPDFView = CGPoint(x: rect.minX, y: rect.minY)
            let bottomRightInPDFView = CGPoint(x: rect.maxX, y: rect.maxY)

            let p1 = pdfView.convert(topLeftInPDFView, to: page)
            let p2 = pdfView.convert(bottomRightInPDFView, to: page)

            let minX = min(p1.x, p2.x)
            let maxX = max(p1.x, p2.x)
            let minY = min(p1.y, p2.y)
            let maxY = max(p1.y, p2.y)

            pageRectToRender = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                .intersection(pageBoxBounds)
        } else {
            pageRectToRender = pageBoxBounds
        }

        // Render the chosen page rect to a UIImage, scaled to max 1024pt on the
        // longest edge. Prevents OOM on very large pages.
        let longest = max(pageRectToRender.width, pageRectToRender.height)
        let scale = longest > 0 ? min(1024 / longest, 2.0) : 1.0
        let targetSize = CGSize(
            width: max(1, pageRectToRender.width * scale),
            height: max(1, pageRectToRender.height * scale)
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            let cg = ctx.cgContext
            // PDF page coordinates: origin bottom-left. UIImage: origin top-left.
            // Translate so the selected region starts at (0, 0) in render space.
            cg.translateBy(x: 0, y: targetSize.height)
            cg.scaleBy(x: scale, y: -scale)
            cg.translateBy(x: -pageRectToRender.minX, y: -pageRectToRender.minY)
            page.draw(with: .mediaBox, to: cg)
        }

        perguntaVitaImageData = image.jpegData(compressionQuality: 0.78)
        VitaPostHogConfig.capture(event: "pergunte_ao_vita_confirmed", properties: [
            "mode": rectInOverlay == nil ? "full_page" : "region",
            "bytes": perguntaVitaImageData?.count ?? 0,
            "page_index": viewModel.currentPage,
        ])
        exitScanMode()
        // Small delay lets the overlay animation finish before the chat presents.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            showPerguntaVita = true
        }
    }

    // Small floating pill shown in fullscreen mode — back + exit fullscreen + page counter.
    // Top-leading so it does not clash with the system clock/Dynamic Island on the right.
    private var fullscreenExitPill: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.saveAllAnnotations()
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
            }

            if viewModel.pageCount > 0 {
                Text("\(viewModel.currentPage + 1) / \(viewModel.pageCount)")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .monospacedDigit()
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isFullscreen = false
                }
            } label: {
                Image(systemName: "arrow.down.right.and.arrow.up.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitaColors.accent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VitaColors.surfaceCard.opacity(0.85))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(VitaColors.surfaceBorder.opacity(0.6), lineWidth: 0.5)
        )
        .padding(.top, 54)     // clear the status bar / notch area
        .padding(.leading, 12)
    }

    // MARK: - Live PDF settings application
    //
    // Recebe Notification.pdfSettingsChanged do PdfSettingsSheet e aplica
    // displayMode/two-page-spread/dark-mode no PDFView atual sem precisar
    // fechar/reabrir o documento. Brilho aplica via overlay já no body.

    private func applyPdfSettingsLive(note: Notification) {
        guard let info = note.userInfo,
              let pdfView = NativePdfView.pdfViewRef else { return }
        let pageByPage = info["pageByPage"] as? Bool ?? false
        let twoPageSpread = info["twoPageSpread"] as? Bool ?? false

        let newMode: PDFDisplayMode
        if twoPageSpread && UIDevice.current.userInterfaceIdiom == .pad {
            newMode = pageByPage ? .twoUp : .twoUpContinuous
        } else {
            newMode = pageByPage ? .singlePage : .singlePageContinuous
        }

        // Apple PDFKit bug (forum thread/81507): toggling displayMode entre
        // single↔two-up deixa PDFView 25% off-center + páginas em branco
        // intermitentes (tela preta entre slides em landscape). Workaround
        // canônico: nil→reassign do document força reset interno do
        // minScaleFactor / scaleFactorForSizeToFit. Preserva página atual.
        let currentPage = pdfView.currentPage
        pdfView.displayMode = newMode
        if let doc = pdfView.document {
            pdfView.document = nil
            pdfView.document = doc
            DispatchQueue.main.async {
                if let page = currentPage { pdfView.go(to: page) }
            }
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.fill.badge.ellipsis")
                .font(.system(size: 48))
                .foregroundStyle(VitaColors.textTertiary)
            Text("Não foi possível abrir o PDF")
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
            Button("Voltar", action: onBack)
                .foregroundStyle(VitaColors.accent)
        }
    }

    // MARK: - Recognition Result Sheet

    @ViewBuilder
    private var recognitionResultSheet: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Texto Reconhecido")
                    .font(VitaTypography.titleLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                Button {
                    viewModel.showRecognitionResult = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            Divider()
                .background(VitaColors.surfaceBorder)

            // Recognized text
            ScrollView {
                if let text = viewModel.recognizedText {
                    Text(text)
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .textSelection(.enabled)
                } else {
                    Text("Nenhum texto reconhecido.")
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textSecondary)
                        .padding(16)
                }
            }
            .frame(maxHeight: .infinity)

            Divider()
                .background(VitaColors.surfaceBorder)

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    if let text = viewModel.recognizedText {
                        UIPasteboard.general.string = text
                        withAnimation { recognitionCopied = true }
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(1.5))
                            withAnimation { recognitionCopied = false }
                        }
                    }
                } label: {
                    Label(
                        recognitionCopied ? "Copiado!" : "Copiar",
                        systemImage: recognitionCopied ? "checkmark" : "doc.on.doc"
                    )
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(recognitionCopied ? VitaColors.dataGreen : VitaColors.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(VitaColors.surfaceCard)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(recognitionCopied ? VitaColors.dataGreen : VitaColors.accentSubtle, lineWidth: 1)
                    )
                }

                Button {
                    guard let text = viewModel.recognizedText,
                          let pdfView = NativePdfView.pdfViewRef,
                          let page = pdfView.currentPage else { return }
                    let pagePoint = CGPoint(x: page.bounds(for: .mediaBox).midX,
                                           y: page.bounds(for: .mediaBox).midY)
                    let lineCount = max(1, text.components(separatedBy: "\n").count)
                    let height = max(40, CGFloat(lineCount) * 18 + 16)
                    let width: CGFloat = min(300, page.bounds(for: .mediaBox).width * 0.8)
                    let bounds = CGRect(
                        x: pagePoint.x - width / 2,
                        y: pagePoint.y - height / 2,
                        width: width,
                        height: height
                    )
                    let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
                    annotation.font = UIFont.systemFont(ofSize: 16, weight: .regular)
                    annotation.fontColor = UIColor.label
                    annotation.color = .clear
                    let nb = PDFBorder()
                    nb.lineWidth = 0
                    annotation.border = nb
                    annotation.isReadOnly = false
                    annotation.contents = text
                    page.addAnnotation(annotation)
                    viewModel.saveHighlights()
                    viewModel.showRecognitionResult = false
                } label: {
                    Label("Inserir como nota", systemImage: "note.text.badge.plus")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(VitaColors.surfaceCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(VitaColors.accentSubtle, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Botão primário: substituir o desenho original por texto digitado
            // (Goodnotes 6 "Live Text Conversion" — apaga PKDrawing + cria
            // PDFAnnotation .freeText no MESMO bbox).
            Button {
                viewModel.replaceCurrentDrawingWithFreeText()
                VitaPostHogConfig.capture(event: "pdf_handwriting_replaced_with_text")
            } label: {
                Label("Substituir desenho por texto", systemImage: "text.cursor")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(VitaColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(viewModel.lastRecognizedBounds == nil)
            .opacity(viewModel.lastRecognizedBounds == nil ? 0.5 : 1)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(VitaColors.surfaceCard)
    }

    // MARK: - Audio sync (Notability-style)
    //
    // Tap no mic da toolbar → toggle gravação. Se .idle/.loaded → começa.
    // Se .recording → para. Quando termina, .loaded permite playback via
    // botão waveform (que abre o overlay do player flutuante).

    private func toggleAudioRecording() {
        switch viewModel.audioRecorder.state {
        case .idle, .loaded, .paused:
            Task { await viewModel.audioRecorder.startRecording() }
            VitaPostHogConfig.capture(event: "pdf_audio_record_start")
        case .recording:
            viewModel.audioRecorder.stopRecording()
            VitaPostHogConfig.capture(event: "pdf_audio_record_stop", properties: [
                "duration_s": Int(viewModel.audioRecorder.totalDuration),
                "events": viewModel.audioRecorder.timeline.events.count,
            ])
        case .playing:
            viewModel.audioRecorder.pausePlayback()
        }
    }

    // MARK: - Study Mode (masking pen)

    private func toggleMaskingMode() {
        isMaskingMode.toggle()
        viewModel.isMaskingMode = isMaskingMode
        // Mutual exclusion com outros modos: turn off draw/highlight/text/lasso
        if isMaskingMode {
            viewModel.isAnnotating = false
            viewModel.isHighlightMode = false
            viewModel.isTextMode = false
            viewModel.isLassoMode = false
            isEraserMode = false
            isPointerMode = false
        }
        // Hint is now provided by activeModeBanner (permanent while mode is on).
    }

    private func toggleStudyMode() {
        isStudyMode.toggle()
        viewModel.isStudyMode = isStudyMode
        // Sair de masking ao entrar em study (são modos diferentes)
        if isStudyMode {
            if isMaskingMode { toggleMaskingMode() }
        }
        applyStudyModeVisibility()
        VitaPostHogConfig.capture(event: "pdf_study_mode_toggle", properties: [
            "active": isStudyMode,
            "page_index": viewModel.currentPage,
        ])
    }

    /// Itera todas as masks do documento e ajusta alpha:
    /// - Study ON: alpha 1 (cobre conteúdo, prontas pro tap-to-reveal)
    /// - Study OFF: alpha 0.2 (user vê onde estão pra ajustar/apagar)
    private func applyStudyModeVisibility() {
        guard let document = viewModel.document else { return }
        for i in 0..<document.pageCount {
            guard let page = document.page(at: i) else { continue }
            for ann in page.annotations where PdfMaskAnnotation.isMask(ann) {
                PdfMaskAnnotation.setVisible(ann, fullyOpaque: isStudyMode, on: page)
            }
        }
    }

    /// Chamado pelo Coordinator quando user toca numa mask em Study Mode.
    private func presentStudyPrompt(maskId: String, pageIndex: Int, bounds: CGRect, annotation: PDFAnnotation, page: PDFPage) {
        studyMaskPrompt = StudyMaskPrompt(
            maskId: maskId,
            pageIndex: pageIndex,
            bounds: bounds,
            annotation: annotation,
            page: page
        )
    }

    /// Registra resultado no UserDefaults (fonte primária local) e no backend
    /// fire-and-forget (cross-device tracking via /api/pdf/masks/attempt).
    private func recordStudyAttempt(prompt: StudyMaskPrompt, correct: Bool) {
        let key = "pdf.mask.attempts.\(viewModel.fileHash)"
        var entries = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        entries.append([
            "maskId": prompt.maskId,
            "correct": correct,
            "attemptedAt": ISO8601DateFormatter().string(from: Date()),
        ])
        UserDefaults.standard.set(entries, forKey: key)
        VitaPostHogConfig.capture(event: "pdf_mask_attempt", properties: [
            "correct": correct,
            "page_index": prompt.pageIndex,
        ])
        // Backend tracking — fire-and-forget. Falha = silent (UserDefaults é SOT).
        let docId = viewModel.fileHash
        Task.detached(priority: .background) {
            _ = try? await container.api.recordMaskAttempt(
                documentId: docId,
                maskId: prompt.maskId,
                pageIndex: prompt.pageIndex,
                bbox: prompt.bounds,
                correct: correct
            )
        }
        // Esconde a mask revelada pra mostrar conteúdo embaixo.
        PdfMaskAnnotation.hide(prompt.annotation, on: prompt.page)
        viewModel.saveHighlights()
        studyMaskPrompt = nil
        // Flash bounce 600ms (verde acertei / vermelho errou)
        UIImpactFeedbackGenerator(style: correct ? .light : .medium).impactOccurred()
        attemptFlash = AttemptFlash(correct: correct, scale: 0.5, opacity: 0)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
            attemptFlash?.scale = 1.0
            attemptFlash?.opacity = 1.0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.easeOut(duration: 0.25)) {
                attemptFlash?.opacity = 0
                attemptFlash?.scale = 1.2
            }
            try? await Task.sleep(for: .milliseconds(280))
            attemptFlash = nil
        }
    }

    // MARK: - Active mode banner (UX clarity per Rafael 2026-04-28)
    //
    // Permanent banner at the top while any tool mode is on. Shows what the
    // mode does + "Sair" button. Replaces the old 2.5s ephemeral hint that
    // only existed for masking. User has to ALWAYS know which mode they're in.

    private struct ModeHint {
        let id: String
        let icon: String
        let title: String
        let subtitle: String
    }

    /// Derives the current mode hint from viewModel state. Priority order matches
    /// the tap-handler in Coordinator.handleTap (most-specific mode wins).
    /// Banner é puramente informativo — fechar não desliga o modo.
    private var activeModeBanner: ModeHint? {
        if viewModel.isStudyMode {
            return ModeHint(
                id: "study",
                icon: "eye.fill",
                title: "Study Mode",
                subtitle: "Toque numa área coberta pra revelar e marcar acertou/errou."
            )
        }
        if viewModel.isMaskingMode {
            return ModeHint(
                id: "mask",
                icon: "rectangle.fill.on.rectangle.fill",
                title: "Marcador opaco",
                subtitle: "Arraste pra cobrir áreas. Toque numa máscara pra apagar."
            )
        }
        if viewModel.isTextMode {
            return ModeHint(
                id: "text",
                icon: "character.textbox",
                title: "Caixa de texto",
                subtitle: "Toque onde quer escrever. Toque num texto existente pra editar."
            )
        }
        if viewModel.isLassoMode {
            return ModeHint(
                id: "lasso",
                icon: "lasso",
                title: "Selecionar traços",
                subtitle: "Circule traços pra mover, copiar ou apagar em grupo."
            )
        }
        if viewModel.isHighlightMode {
            return ModeHint(
                id: "highlight",
                icon: "highlighter",
                title: "Marca-texto",
                subtitle: "Arraste sobre o texto pra destacar. Toque num destaque pra remover."
            )
        }
        if viewModel.isAnnotating {
            return ModeHint(
                id: "draw",
                icon: "scribble.variable",
                title: "Modo Desenho",
                subtitle: "Escreva ou desenhe com Apple Pencil ou dedo. Use a barra do PencilKit pra trocar ferramenta."
            )
        }
        return nil
    }

    /// Mostra o banner por 3s e agenda fade-out automático.
    /// "Sair" no banner chama `dismissModeBanner()` (cancela o timer).
    private func showModeBanner() {
        bannerHideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.22)) {
            isModeBannerVisible = true
        }
        bannerHideTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(3000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                isModeBannerVisible = false
            }
        }
    }

    private func dismissModeBanner() {
        bannerHideTask?.cancel()
        withAnimation(.easeInOut(duration: 0.22)) {
            isModeBannerVisible = false
        }
    }

    /// Painel flutuante "Estudo Ativo" — abre quando user clica no olho da toolbar.
    /// Card glass com 2 ações: Criar máscaras (ativa isMaskingMode) e Revisar
    /// (ativa isStudyMode). Cada ação é toggle — re-clicar desliga aquele sub-modo.
    /// Pequeno header explica o que é a feature em 1 linha.
    @ViewBuilder
    private var studyActivePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitaColors.accent)
                Text("Estudo Ativo")
                    .font(VitaTypography.labelMedium.weight(.semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 4)

            Text("Cobre conteúdo pra testar memória depois.")
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.bottom, 12)

            Divider()
                .background(VitaColors.glassBorder.opacity(0.4))

            // Ação 1 — Criar máscaras
            Button {
                toggleMaskingMode()
                VitaPostHogConfig.capture(event: "pdf_study_active_panel_tap", properties: [
                    "action": "mask",
                    "active": isMaskingMode,
                ])
            } label: {
                studyActionRow(
                    icon: isMaskingMode ? "checkmark.rectangle.fill" : "rectangle.fill.on.rectangle.fill",
                    title: isMaskingMode ? "Parar de criar máscaras" : "Criar máscaras",
                    subtitle: "Arraste no PDF pra cobrir áreas",
                    active: isMaskingMode
                )
            }
            .buttonStyle(.plain)

            Divider()
                .background(VitaColors.glassBorder.opacity(0.3))
                .padding(.leading, 44)

            // Ação 2 — Revisar
            Button {
                toggleStudyMode()
                VitaPostHogConfig.capture(event: "pdf_study_active_panel_tap", properties: [
                    "action": "review",
                    "active": isStudyMode,
                ])
            } label: {
                studyActionRow(
                    icon: isStudyMode ? "eye.slash.fill" : "eye.fill",
                    title: isStudyMode ? "Sair do modo Revisar" : "Revisar",
                    subtitle: "Toque numa máscara pra revelar",
                    active: isStudyMode
                )
            }
            .buttonStyle(.plain)
        }
        .frame(width: 280)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                RoundedRectangle(cornerRadius: 16)
                    .fill(VitaColors.surfaceCard.opacity(0.4))
                // Inner top highlight — vibe iOS 26 liquid glass
                LinearGradient(
                    colors: [Color.white.opacity(0.08), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .frame(height: 16)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(VitaColors.accent.opacity(0.45), lineWidth: 0.8)
        )
        .shadow(color: VitaColors.accent.opacity(0.3), radius: 18, y: 6)
        .shadow(color: .black.opacity(0.4), radius: 16, y: 8)
    }

    @ViewBuilder
    private func studyActionRow(icon: String, title: String, subtitle: String, active: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(active ? VitaColors.accent : VitaColors.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(active ? VitaColors.accent.opacity(0.20) : Color.clear)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(active ? VitaColors.accent : VitaColors.textPrimary)
                Text(subtitle)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }
            Spacer(minLength: 0)
            if active {
                Circle()
                    .fill(VitaColors.accent)
                    .frame(width: 6, height: 6)
                    .shadow(color: VitaColors.accent, radius: 4)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    /// Floating chip mostrado no canto direito enquanto Study Mode está ON.
    /// Tap → abre `PdfStudyStatsSheet` (substitui long-press oculto). Mostra
    /// glow pulsante pra sinalizar "modo de estudo ativo".
    private var studyModeFloatingIndicator: some View {
        Button {
            showStudyStatsSheet = true
            VitaPostHogConfig.capture(event: "pdf_study_stats_tap_indicator")
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "eye.fill")
                    .font(.system(size: 13, weight: .bold))
                Text("Study")
                    .font(VitaTypography.labelSmall.weight(.semibold))
            }
            .foregroundStyle(VitaColors.accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(VitaColors.surfaceCard.opacity(0.92))
            )
            .overlay(
                Capsule()
                    .stroke(VitaColors.accent.opacity(0.7), lineWidth: 1.0)
            )
            .shadow(color: VitaColors.accent.opacity(0.5), radius: 12, y: 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Estatísticas do Study Mode")
        .transition(.move(edge: .trailing).combined(with: .opacity))
    }

    @ViewBuilder
    private func activeModeBannerView(_ hint: ModeHint) -> some View {
        HStack(spacing: 10) {
            Image(systemName: hint.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VitaColors.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(hint.title)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                Text(hint.subtitle)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Button(action: dismissModeBanner) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .stroke(VitaColors.surfaceBorder.opacity(0.5), lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fechar dica")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 460)
        .background(VitaColors.surfaceCard.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VitaColors.accent.opacity(0.4), lineWidth: 0.6)
        )
        .shadow(color: .black.opacity(0.3), radius: 10, y: 3)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Multi-doc workspace

    /// Loads the workspace's active tab into the viewModel. Called on initial
    /// .task and on every workspace.activeId change. Saves annotations of the
    /// previous tab before swapping (caller is responsible for that).
    @MainActor
    private func loadActiveTab() async {
        guard let active = workspace.activeDoc else { return }
        // Skip if we already have this URL loaded
        if lastLoadedURL == active.url, viewModel.document != nil { return }
        // Serialize concurrent calls — onChange + .task can race on first mount
        if isLoadingTab { return }
        isLoadingTab = true
        defer { isLoadingTab = false }

        lastLoadedURL = active.url
        viewModel.fileName = active.title
        await viewModel.load(url: active.url, tokenStore: container.tokenStore)
        // load() overwrites fileName from response headers — restore the
        // human-friendly tab title.
        viewModel.fileName = active.title
    }

    // MARK: - Export

    private func exportPDF(document: PDFDocument) async {
        guard let url = try? await PdfExporter.export(
            document: document,
            pageCount: viewModel.pageCount,
            getDrawing: { viewModel.loadDrawing(pageIndex: $0) }
        ) else { return }
        self.exportedURL = url
        showExportSheet = true
    }

    // MARK: - Tool helpers (eraser/pointer/undo/redo)

    /// Reaches the current page's PKCanvasView via the shared pdfViewRef.
    /// Returns nil if no PDF is open or no page is current yet.
    private func currentCanvas() -> PKCanvasView? {
        guard let pdfView = NativePdfView.pdfViewRef,
              let page = pdfView.currentPage else { return nil }
        // Walk overlay subviews — PKCanvasView is the page overlay we install.
        for sub in pdfView.subviews.flatMap({ $0.subviews }) where sub is PKCanvasView {
            // Best-effort: page-bounded canvas with annotations enabled
            return sub as? PKCanvasView
        }
        _ = page
        return nil
    }

    /// Applies tool selection to the current canvas based on isEraserMode/isPointerMode.
    private func applyToolMode() {
        guard let canvas = currentCanvas() else { return }
        if isEraserMode {
            canvas.tool = PKEraserTool(.bitmap)
        } else if isPointerMode {
            // Pointer = no drawing input, allow finger to interact (e.g. tap to deselect).
            canvas.tool = PKInkingTool(.pen, color: .clear, width: 0.1)
            canvas.isUserInteractionEnabled = false
        } else {
            canvas.isUserInteractionEnabled = viewModel.isAnnotating
        }
        refreshUndoState()
    }

    private func performUndo() {
        currentCanvas()?.undoManager?.undo()
        refreshUndoState()
    }

    private func performRedo() {
        currentCanvas()?.undoManager?.redo()
        refreshUndoState()
    }

    private func refreshUndoState() {
        let mgr = currentCanvas()?.undoManager
        canUndo = mgr?.canUndo ?? false
        canRedo = mgr?.canRedo ?? false
    }

    /// Applies a freshly built PKInkingTool to the active canvas (called by popover).
    /// Persistence is handled by @AppStorage inside PdfPenStylesPopover.
    private func applyInkingTool(_ tool: PKInkingTool) {
        // Auto-activate annotation mode if not yet on, so the user sees the result.
        if !viewModel.isAnnotating {
            viewModel.isAnnotating = true
            isEraserMode = false
            isPointerMode = false
        }
        currentCanvas()?.tool = tool
    }

    /// Persists highlight color choice. Coordinator reads `pdf.highlight.colorHex`
    /// from UserDefaults the next time it applies a highlight.
    private func applyHighlightColor(_ color: UIColor) {
        // Auto-activate highlight mode for immediate feedback.
        if !viewModel.isHighlightMode {
            viewModel.toggleHighlightMode()
        }
    }
}

// MARK: - NativePdfView (UIViewRepresentable)

private struct NativePdfView: UIViewRepresentable {
    @Bindable var viewModel: PdfViewerViewModel

    /// Weak reference so search bar callbacks can reach the PDFView.
    nonisolated(unsafe) static weak var pdfViewRef: PDFView?

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.autoScales = true
        pdfView.usePageViewController(false)
        // Apple gold standard pra PDFKit + PencilKit overlay drawing (WWDC22
        // Session 10089 + Forum thread 716766): isInMarkupMode = true muda a
        // hit-testing priority pro PKCanvasView overlay receber os touches em
        // vez de PDFView interpretar como scroll. Sem isso, dedo/caneta
        // toca, mostra modo, mas NADA é desenhado.
        // ATENÇÃO: este flag é DINAMICAMENTE alternado em updateUIView baseado
        // em viewModel.isAnnotating. Quando o usuário NÃO está desenhando
        // (modos texto, highlight, mask, study), o flag precisa ficar FALSE
        // pra que UITapGestureRecognizer (handleTap) receba os touches.
        // Caso contrário, todos os tap-handlers são bloqueados pelo PKCanvas.
        pdfView.isInMarkupMode = false
        pdfView.backgroundColor = UIColor(VitaColors.surface)
        pdfView.pageOverlayViewProvider = context.coordinator
        pdfView.delegate = context.coordinator
        context.coordinator.pdfView = pdfView
        NativePdfView.pdfViewRef = pdfView

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )

        // Tap gesture to remove existing highlight annotations
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        tapGesture.delegate = context.coordinator
        pdfView.addGestureRecognizer(tapGesture)

        // Pan gesture for masking pen — drag pra criar retângulo opaco.
        // Só atua quando viewModel.isMaskingMode == true (checked dentro do handler).
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleMaskingPan(_:))
        )
        panGesture.delegate = context.coordinator
        panGesture.maximumNumberOfTouches = 1
        pdfView.addGestureRecognizer(panGesture)

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Document REFERENCE changed (initial load / file swap)
        let referenceChanged = pdfView.document !== viewModel.document
        // Document MUTATED in place (scanner appended pages, page deleted, reordered).
        // Apple PDFKit needs explicit nil→doc reassign to refresh layout — same-ref
        // assignment is a no-op (developer.apple.com/forums/thread/84737).
        let revisionChanged = context.coordinator.lastDocumentRevision != viewModel.documentRevision

        if referenceChanged {
            pdfView.document = viewModel.document
        } else if revisionChanged {
            // Snapshot zoom ANTES do reassign — sem isso o PDFView reseta pra
            // fit-page no next layout pass (sintoma "zoom out gigante várias
            // páginas visíveis" pós-scanner, Rafael 2026-04-28 build 140).
            let savedScale = pdfView.scaleFactor
            let preserveScale = viewModel.preserveScaleOnNextRevision
            let targetPageIndex = viewModel.currentPage
            let doc = viewModel.document
            pdfView.document = nil
            pdfView.document = doc
            // Restaura zoom + jump pra página escaneada na próxima runloop tick
            // (PDFKit aplica auto-fit dentro do layoutSubviews, então precisamos
            // setar DEPOIS dele rodar).
            if preserveScale, let doc, let target = doc.page(at: targetPageIndex) {
                DispatchQueue.main.async {
                    let dest = PDFDestination(page: target, at: CGPoint(x: 0, y: target.bounds(for: .mediaBox).height))
                    pdfView.go(to: dest)
                    // Restore zoom — clamp dentro de min/max do PDFView pra evitar
                    // edge cases quando scaleFactorForSizeToFit mudou.
                    let clamped = max(pdfView.minScaleFactor, min(pdfView.maxScaleFactor, savedScale))
                    pdfView.scaleFactor = clamped
                }
                viewModel.preserveScaleOnNextRevision = false
            }
        }
        context.coordinator.lastDocumentRevision = viewModel.documentRevision

        // CRITICAL: isInMarkupMode controls PKCanvasView hit-testing priority
        // (WWDC22 Session 10089). When true, PKCanvasView captures ALL touches
        // → handleTap never fires → text mode, highlight tap-to-remove, mask
        // tap, study-mode prompts ALL break. Only enable when actively drawing.
        pdfView.isInMarkupMode = viewModel.isAnnotating

        // Scroll to page when thumbnail sidebar taps OR scanner appended pages
        context.coordinator.scrollToPage(viewModel.currentPage, in: pdfView)
        // Toggle annotation mode on all visible canvases
        context.coordinator.applyAnnotationMode(viewModel.isAnnotating)
        // Sync highlight mode into coordinator + reapply drag interactions pra
        // que o pan custom capture drag livre (Goodnotes-style highlight).
        let highlightChanged = context.coordinator.isHighlightMode != viewModel.isHighlightMode
        context.coordinator.isHighlightMode = viewModel.isHighlightMode
        if highlightChanged {
            context.coordinator.applyDragModeInteractions()
        }
        // Sync text mode into coordinator
        context.coordinator.isTextMode = viewModel.isTextMode
        // Sync lasso mode — apply PKLassoTool or restore ink tool
        context.coordinator.applyLassoMode(viewModel.isLassoMode)
        // Sync masking mode — disables PDF scroll while drag-creating masks
        context.coordinator.applyMaskingMode(viewModel.isMaskingMode)
        // Sync study mode flag (tap-to-reveal behavior)
        context.coordinator.isStudyMode = viewModel.isStudyMode
    }

    static func dismantleUIView(_ pdfView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
        NativePdfView.pdfViewRef = nil
        coordinator.highlightDebounceTask?.cancel()
    }
}

// MARK: - Coordinator

private final class Coordinator: NSObject, PDFPageOverlayViewProvider, PDFViewDelegate, PKCanvasViewDelegate, PKToolPickerObserver, UIGestureRecognizerDelegate {
    let viewModel: PdfViewerViewModel
    weak var pdfView: PDFView?

    /// Tracks canvas per page so we can save/restore drawings and toggle tool picker.
    var pageToCanvas: [PDFPage: PKCanvasView] = [:]
    let toolPicker = PKToolPicker()

    /// Mirror of viewModel.isHighlightMode, updated from updateUIView
    var isHighlightMode: Bool = false

    /// Last documentRevision applied to the PDFView. Apple PDFKit does NOT
    /// auto-refresh after PDFDocument mutations (insert/delete/move) — same-ref
    /// reassign is a no-op. We force a nil→doc reassign whenever this counter
    /// drifts from viewModel.documentRevision.
    /// Bug confirmed: developer.apple.com/forums/thread/84737
    var lastDocumentRevision: Int = 0

    /// Mirror of viewModel.isTextMode, updated from updateUIView.
    /// Exiting text mode clears any active freeText selection (Goodnotes pattern).
    var isTextMode: Bool = false {
        didSet {
            if !isTextMode && oldValue {
                clearSelection()
            }
        }
    }

    /// Mirror of viewModel.isLassoMode, updated from updateUIView
    var isLassoMode: Bool = false

    /// Debounce task to avoid double-firing on selection change
    var highlightDebounceTask: Task<Void, Never>?

    /// Currently selected freeText annotation overlay — Goodnotes-style drag/resize.
    /// Only one selection at a time. nil = no selection.
    var selectedFreeTextOverlay: PdfFreeTextSelectionOverlay?

    private var lastScrolledPage: Int = -1

    /// Baseline de strokes por canvas — snapshot tirado ANTES do user começar a
    /// escrever (no canvasViewDrawingDidChange quando count crescia de 0->1).
    /// Usado pelo auto-convert pra calcular o delta (strokes novos da sessão atual).
    /// Key: ObjectIdentifier(canvasView). Value: strokes pré-existentes.
    private var canvasBaselines: [ObjectIdentifier: [PKStroke]] = [:]

    /// Debounce de auto-convert por canvas. Cancelado a cada novo stroke,
    /// dispara após pause de 1.2s.
    private var autoConvertTasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    init(viewModel: PdfViewerViewModel) {
        self.viewModel = viewModel
        super.init()
        // Provide a closure so the screen/VM can pull the current page's drawing on demand.
        viewModel.currentDrawingProvider = { [weak self] in
            guard let self,
                  let pdfView = self.pdfView,
                  let page = pdfView.currentPage,
                  let canvas = self.pageToCanvas[page] else { return nil }
            return canvas.drawing
        }
        // Observe tool picker changes to auto-deactivate lasso when user switches tool
        toolPicker.addObserver(self)
    }

    // MARK: PDFPageOverlayViewProvider

    func pdfView(_ view: PDFView, overlayViewFor page: PDFPage) -> UIView? {
        let canvas = PKCanvasView(frame: .zero)
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = self
        canvas.isUserInteractionEnabled = viewModel.isAnnotating
        // Critical: PKCanvasView needs an initial tool, otherwise the first touch
        // produces nothing visible (was bug "selecionei modo desenhar mas não escreve").
        // Sync to whatever the tool picker currently has selected; default is a 2pt
        // black ink pen which works for finger and Apple Pencil.
        canvas.tool = toolPicker.selectedTool
        pageToCanvas[page] = canvas

        // Apple Pencil hover preview (Pencil 2 em iPad Pro M2+ e Pencil Pro).
        // UIHoverGestureRecognizer expõe zOffset/azimuthAngle a partir de iOS 16.1.
        // Em hardware sem hover (iPad Air, Pencil 1, Pencil USB-C), o callback
        // simplesmente não dispara — degrada gracefully sem `if available` extra.
        attachPencilHoverPreview(to: canvas)

        // Load saved drawing from disk
        if let pageIndex = view.document?.index(for: page),
           let drawing = viewModel.loadDrawing(pageIndex: pageIndex) {
            canvas.drawing = drawing
        }

        if viewModel.isAnnotating {
            canvas.becomeFirstResponder()
            toolPicker.setVisible(true, forFirstResponder: canvas)
            toolPicker.addObserver(canvas)
        }

        return canvas
    }

    func pdfView(_ view: PDFView, willEndDisplayingOverlayView overlayView: UIView, for page: PDFPage) {
        guard let canvas = overlayView as? PKCanvasView,
              let pageIndex = view.document?.index(for: page) else { return }
        // Save drawing before page scrolls off screen
        viewModel.saveDrawing(canvas.drawing, pageIndex: pageIndex)
        toolPicker.removeObserver(canvas)
        pageToCanvas.removeValue(forKey: page)
        // Clean up auto-convert state for this canvas.
        let key = ObjectIdentifier(canvas)
        autoConvertTasks[key]?.cancel()
        autoConvertTasks.removeValue(forKey: key)
        canvasBaselines.removeValue(forKey: key)
    }

    // MARK: PKCanvasViewDelegate

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        // Autosave is handled on willEndDisplaying; mark saving indicator only
        viewModel.isSaving = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            self?.viewModel.isSaving = false
        }

        // Captura baseline na transição "canvas vazio/sem sessão" → "primeiro stroke
        // da sessão atual". Auto-convert (se ON) usa esse baseline pra calcular delta.
        let key = ObjectIdentifier(canvasView)
        if canvasBaselines[key] == nil {
            // Strokes pré-existentes ANTES do primeiro stroke desta sessão.
            // canvas.drawing.strokes já contém o stroke novo, então pegamos
            // todos exceto o último.
            let strokes = canvasView.drawing.strokes
            if strokes.count >= 1 {
                canvasBaselines[key] = Array(strokes.dropLast())
            } else {
                canvasBaselines[key] = []
            }
        }
    }

    /// Trigger de duas features quando o usuário pausa de escrever:
    ///   1. **Auto-convert handwriting → texto** (scribble) — debounce 1.2s,
    ///      controlado por `pdf.handwriting.autoConvert` (default OFF).
    ///   2. **Shape snap** (Goodnotes 6 / Notability pattern) — instant,
    ///      controlado por `pdf.shapeSnap.enabled` (default OFF).
    ///
    /// **Histórico shape-snap:**
    ///   - 2026-04-26 commit f1e0f92: implementação inicial.
    ///   - 2026-04-26 commit 29e9ead: DESLIGADO porque algoritmo convertia
    ///     letras manuscritas em shapes vazios.
    ///   - 2026-04-28: REATIVADO com guards conservadores e setting toggle.
    ///
    /// **Por que não usar API Apple:** PencilKit não expõe shape recognition
    /// pública pra third-party (só Notes/Markup têm). Implementamos custom
    /// com guards anti-letra robustos.
    ///
    /// **Confidence gate (shape-snap):** só aplica se `confidence >= 0.85`.
    func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
        // 1. Auto-convert handwriting → texto (scribble feature, debounce 1.2s).
        let autoOn = UserDefaults.standard.bool(forKey: "pdf.handwriting.autoConvert")
        if autoOn, viewModel.isAnnotating, !viewModel.isHighlightMode {
            let key = ObjectIdentifier(canvasView)
            autoConvertTasks[key]?.cancel()
            autoConvertTasks[key] = Task { @MainActor [weak self, weak canvasView] in
                try? await Task.sleep(for: .milliseconds(1200))
                guard !Task.isCancelled,
                      let self,
                      let canvasView,
                      let pdfView = self.pdfView else { return }
                // Página atual deste canvas (procura no map).
                guard let pdfPage = self.pageToCanvas.first(where: { $0.value === canvasView })?.key,
                      let pageIndex = pdfView.document?.index(for: pdfPage) else { return }

                await self.runAutoConvert(canvas: canvasView, pageIndex: pageIndex)
            }
        }

        // 2. Shape snap (linha/círculo).
        let snapEnabled = UserDefaults.standard.object(forKey: "pdf.shapeSnap.enabled") as? Bool ?? true  // default ON since 2026-04-30
guard snapEnabled else { return }
        guard let lastStroke = canvasView.drawing.strokes.last else { return }

        let (result, outcome) = PdfShapeSnap.detect(stroke: lastStroke)

        // Telemetria do outcome (mesmo quando rejeita — pra calibrar thresholds).
        let outcomeProps: [String: Any]
        switch outcome {
        case .appliedLine(let conf):
            outcomeProps = ["kind": "line", "confidence": Double(conf), "applied": false]
        case .appliedCircle(let conf):
            outcomeProps = ["kind": "circle", "confidence": Double(conf), "applied": false]
        case .appliedRectangle(let conf):
            outcomeProps = ["kind": "rectangle", "confidence": Double(conf), "applied": false]
        case .rejectedTooShort:
            outcomeProps = ["kind": "none", "reason": "tooShort", "applied": false]
        case .rejectedTooSmall:
            outcomeProps = ["kind": "none", "reason": "tooSmall", "applied": false]
        case .rejectedTooFewPoints:
            outcomeProps = ["kind": "none", "reason": "tooFewPoints", "applied": false]
        case .rejectedNoMatch:
            outcomeProps = ["kind": "none", "reason": "noMatch", "applied": false]
        case .triangleDetectedButNotApplied(let conf):
            outcomeProps = ["kind": "triangle", "reason": "no_replacement_geometry", "confidence": Double(conf), "applied": false]
        }

        // Confidence gate: só substitui se algoritmo está MUITO seguro.
        let minConfidence: CGFloat = 0.65
        let appliedKind: String?
        switch (result, outcome) {
        case (.line, .appliedLine(let conf)) where conf >= minConfidence:
            applySnapResult(result, lastStroke: lastStroke, canvasView: canvasView)
            appliedKind = "line"
        case (.circle, .appliedCircle(let conf)) where conf >= minConfidence:
            applySnapResult(result, lastStroke: lastStroke, canvasView: canvasView)
            appliedKind = "circle"
        case (.rectangle, .appliedRectangle(let conf)) where conf >= minConfidence:
            applySnapResult(result, lastStroke: lastStroke, canvasView: canvasView)
            appliedKind = "rectangle"
        default:
            appliedKind = nil
        }

        // Evento final reflete o que efetivamente aconteceu.
        var finalProps = outcomeProps
        finalProps["applied"] = appliedKind != nil
        if let appliedKind { finalProps["kind"] = appliedKind }
        VitaPostHogConfig.capture(event: "pdf_shape_snap_applied", properties: finalProps)
    }

    /// Roda o pipeline de auto-convert: pega delta vs baseline, recognize, replace.
    /// Após terminar (sucesso OU falha), reseta baseline pra próxima sessão.
    private func runAutoConvert(canvas: PKCanvasView, pageIndex: Int) async {
        let key = ObjectIdentifier(canvas)
        let priorStrokes = canvasBaselines[key] ?? []
        let allStrokes = canvas.drawing.strokes

        // Strokes novos = todos menos os do baseline (assumindo append-only durante sessão).
        // Se user usou borracha durante a sessão, allStrokes pode ser menor que priorStrokes
        // — nesse caso, abortar (não dá pra inferir intent).
        guard allStrokes.count > priorStrokes.count else {
            canvasBaselines[key] = allStrokes
            return
        }
        let newStrokes = Array(allStrokes.suffix(allStrokes.count - priorStrokes.count))

        let converted = await viewModel.autoConvertHandwriting(
            newStrokes: newStrokes,
            priorStrokes: priorStrokes,
            pageIndex: pageIndex,
            applyToCanvas: { newDrawing in
                canvas.drawing = newDrawing
            }
        )

        if converted {
            VitaPostHogConfig.capture(
                event: "pdf_handwriting_auto_converted",
                properties: [
                    "stroke_count": newStrokes.count,
                    "page_index": pageIndex,
                ]
            )
            // Após substituição, o canvas só tem priorStrokes — reset baseline pra esse novo estado.
            canvasBaselines[key] = priorStrokes
        } else {
            // Não converteu (rabisco / baixa confiança / texto curto). Mantém os strokes
            // e atualiza baseline pra refletir o estado atual — próxima sessão é o que
            // user escrever a partir de AGORA.
            canvasBaselines[key] = canvas.drawing.strokes
        }
    }

    /// Substitui o último stroke do canvas por uma versão geometricamente
    /// perfeita (linha ou círculo). Preserva ink do stroke original.
    private func applySnapResult(_ result: PdfShapeSnap.Result,
                                 lastStroke: PKStroke,
                                 canvasView: PKCanvasView) {
        guard let replacement = PdfShapeSnap.makeReplacementStroke(for: result, ink: lastStroke.ink) else {
            return
        }
        // Reconstrói o drawing trocando apenas o último stroke.
        var strokes = canvasView.drawing.strokes
        strokes.removeLast()
        strokes.append(replacement)
        canvasView.drawing = PKDrawing(strokes: strokes)
    }

    // MARK: PDFViewDelegate — page change notification

    @objc func pageChanged(_ notification: Notification) {
        guard let pdfView = notification.object as? PDFView,
              let page = pdfView.currentPage,
              let doc = pdfView.document else { return }
        // Selection lives on a specific page — page change drops it (Goodnotes parity)
        clearSelection()
        let pageIndex = doc.index(for: page)
        if pageIndex != viewModel.currentPage {
            Task { @MainActor [weak self] in
                self?.viewModel.currentPage = pageIndex
            }
        }
    }

    // MARK: PDFViewSelectionChanged — auto-apply highlight

    @objc func selectionChanged(_ notification: Notification) {
        guard isHighlightMode,
              let pdfView = notification.object as? PDFView,
              let selection = pdfView.currentSelection,
              !selection.pages.isEmpty else { return }

        highlightDebounceTask?.cancel()
        highlightDebounceTask = Task { @MainActor [weak self] in
            // Small delay so PDFView fully commits the selection before we grab it
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled, let self else { return }
            guard self.isHighlightMode,
                  let currentSel = pdfView.currentSelection,
                  !currentSel.pages.isEmpty else { return }
            self.applyHighlight(selection: currentSel, in: pdfView)
        }
    }

    private func applyHighlight(selection: PDFSelection, in pdfView: PDFView) {
        // Read user preference (set by PdfHighlightColorPopover); fall back to gold.
        let highlightColor = Self.userHighlightColor()
        for page in selection.pages {
            let bounds = selection.bounds(for: page)
            guard bounds != .zero else { continue }
            let annotation = PDFAnnotation(bounds: bounds, forType: .highlight, withProperties: nil)
            annotation.color = highlightColor
            page.addAnnotation(annotation)
        }
        // Clear selection after applying
        pdfView.clearSelection()
        // Persist highlights
        viewModel.saveHighlights()
    }

    // MARK: Tap to remove highlight / place text box

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let pdfView = gesture.view as? PDFView else { return }
        let point = gesture.location(in: pdfView)
        guard let page = pdfView.page(for: point, nearest: false) else { return }
        let pagePoint = pdfView.convert(point, to: page)

        // Mask tap handling
        // - Study Mode ON: dispara prompt acertei/errei (revela conteúdo)
        // - Masking Mode ON sem Study: action sheet "Apagar"
        if isStudyMode {
            for annotation in page.annotations where PdfMaskAnnotation.isMask(annotation) {
                if annotation.bounds.contains(pagePoint) {
                    let pageIndex = pdfView.document?.index(for: page) ?? 0
                    let id = PdfMaskAnnotation.id(for: annotation, pageIndex: pageIndex)
                    let prompt = StudyMaskPrompt(
                        maskId: id,
                        pageIndex: pageIndex,
                        bounds: annotation.bounds,
                        annotation: annotation,
                        page: page
                    )
                    Task { @MainActor [weak self] in
                        self?.viewModel.onStudyMaskTap?(prompt)
                    }
                    return
                }
            }
            // Em Study Mode, se tap não bateu em mask, não faz nada (não cria highlight/text)
            return
        }

        if isMaskingMode {
            for annotation in page.annotations where PdfMaskAnnotation.isMask(annotation) {
                if annotation.bounds.contains(pagePoint) {
                    showMaskActionMenu(for: annotation, on: page, at: point, in: pdfView)
                    return
                }
            }
        }

        if isTextMode {
            // Check if tapping an existing freeText annotation — activate selection
            for annotation in page.annotations {
                guard annotation.type == "FreeText" else { continue }
                if annotation.bounds.contains(pagePoint) {
                    activateSelection(for: annotation, on: page, in: pdfView)
                    return
                }
            }
            // Tap fora de qualquer freeText:
            //   - se há overlay ativo → deselect (Goodnotes pattern)
            //   - se não há → cria nova annotation no ponto
            if selectedFreeTextOverlay != nil {
                clearSelection()
            } else {
                placeTextAnnotation(at: pagePoint, on: page)
            }
            return
        }

        // Fora de modo texto: tap em qualquer lugar deseleciona
        if selectedFreeTextOverlay != nil {
            clearSelection()
        }

        if isHighlightMode {
            // Find highlight annotation at tap point
            for annotation in page.annotations {
                guard annotation.type == "Highlight" else { continue }
                if annotation.bounds.contains(pagePoint) {
                    page.removeAnnotation(annotation)
                    viewModel.saveHighlights()
                    return
                }
            }
        }
    }

    private func placeTextAnnotation(at pagePoint: CGPoint, on page: PDFPage) {
        // Gold standard: floating UITextView IN-PLACE no PDF.
        // Pattern Apple Notes / Goodnotes — usuário vê EXATAMENTE onde tá
        // digitando, cursor + teclado naquele ponto.
        //
        // Steps:
        //   1. Convert page coord → view coord (PDFKit faz)
        //   2. Insert InlineTextEditor (UIView wrapper com UITextView) na posição
        //   3. textView.becomeFirstResponder → teclado abre
        //   4. textViewDidChange → auto-resize
        //   5. textViewDidEndEditing OU "Done" tap → salva como PDFAnnotation
        //      freeText na pagePoint, remove o UITextView
        guard let pdfView = self.pdfView else { return }

        // Convert pagePoint (PDF coord, origin bottom-left) to pdfView coord
        // (UIKit, origin top-left).
        let viewPoint = pdfView.convert(pagePoint, from: page)

        let editor = InlineTextEditor(frame: CGRect(
            x: viewPoint.x - 8,    // small left offset so cursor sits at tap point
            y: viewPoint.y - 18,   // raise so baseline is at tap point
            width: 240,
            height: 36
        ))
        editor.onCommit = { [weak self] text in
            guard let self else { return }
            editor.removeFromSuperview()
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            // Goodnotes pattern: texto puro no PDF — fundo transparente default,
            // sem moldura. Usuário pode ativar fundo opaco depois via toolbar
            // contextual (Fase 3). Cor do texto preta pra legibilidade em PDF
            // branco — paleta editável no color picker.
            let font = UIFont.systemFont(ofSize: 16, weight: .regular)
            let textSize = (trimmed as NSString).boundingRect(
                with: CGSize(width: 280, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            ).size
            let pad: CGFloat = 4
            let width = ceil(textSize.width) + pad * 2
            let height = max(24, ceil(textSize.height) + pad * 2)
            let bounds = CGRect(
                x: pagePoint.x,
                y: pagePoint.y - height,
                width: width,
                height: height
            )

            let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
            annotation.font = font
            annotation.fontColor = UIColor.label
            annotation.color = .clear
            let border = PDFBorder()
            border.lineWidth = 0
            annotation.border = border
            annotation.isReadOnly = false
            annotation.contents = trimmed
            page.addAnnotation(annotation)
            self.viewModel.saveHighlights()
        }
        editor.onCancel = {
            editor.removeFromSuperview()
        }
        pdfView.addSubview(editor)
        // Garante que nenhum PKCanvasView visível esteja como firstResponder —
        // se estiver, o teclado não sobe pro UITextView novo (Apple bug clássico
        // quando duas views competem por firstResponder no mesmo run loop).
        for (_, canvas) in pageToCanvas {
            if canvas.isFirstResponder { canvas.resignFirstResponder() }
        }
        // Async permite a view entrar na hierarchy antes de pedir teclado.
        // Sem isso, becomeFirstResponder() retorna false silenciosamente — o
        // editor existe mas o teclado não sobe (sintoma do build 140).
        DispatchQueue.main.async {
            editor.beginEditing()
        }
    }

    // MARK: Selection / drag / resize / edit-mode-reentry (Goodnotes parity)

    /// Activates the selection overlay for an existing freeText annotation.
    /// Replaces previous selection if any. Subsequent taps outside deselect;
    /// double-tap inside re-enters edit mode pre-loaded with current contents.
    func activateSelection(for annotation: PDFAnnotation, on page: PDFPage, in pdfView: PDFView) {
        clearSelection()
        let overlay = PdfFreeTextSelectionOverlay(annotation: annotation, page: page, pdfView: pdfView)
        overlay.onChange = { [weak self] in
            self?.viewModel.saveHighlights()
        }
        overlay.onEditRequest = { [weak self, weak annotation, weak page] in
            guard let self, let annotation, let page else { return }
            self.reEditAnnotation(annotation, on: page)
        }
        overlay.onDelete = { [weak self, weak annotation, weak page] in
            guard let self, let annotation, let page else { return }
            page.removeAnnotation(annotation)
            self.viewModel.saveHighlights()
            self.clearSelection()
        }
        pdfView.addSubview(overlay)
        selectedFreeTextOverlay = overlay
    }

    func clearSelection() {
        selectedFreeTextOverlay?.removeFromSuperview()
        selectedFreeTextOverlay = nil
    }

    /// Re-enter edit mode on an already-placed annotation. Drops a fresh
    /// InlineTextEditor pre-loaded with current contents at the annotation
    /// view-coords; on commit, updates contents + bounds and re-renders.
    private func reEditAnnotation(_ annotation: PDFAnnotation, on page: PDFPage) {
        guard let pdfView = self.pdfView else { return }
        clearSelection()
        let viewRect = pdfView.convert(annotation.bounds, from: page)
        let editor = InlineTextEditor(frame: viewRect)
        editor.preload(text: annotation.contents ?? "")
        editor.onCommit = { [weak self, weak annotation, weak page] text in
            editor.removeFromSuperview()
            guard let self, let annotation, let page else { return }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                page.removeAnnotation(annotation)
                self.viewModel.saveHighlights()
                return
            }
            // Mutate contents then force redraw via remove/add cycle (PDFKit limitation)
            annotation.contents = trimmed
            page.removeAnnotation(annotation)
            page.addAnnotation(annotation)
            self.viewModel.saveHighlights()
            // Reactivate selection so user can drag again immediately
            self.activateSelection(for: annotation, on: page, in: pdfView)
        }
        editor.onCancel = {
            editor.removeFromSuperview()
        }
        pdfView.addSubview(editor)
        // Mesmo fix do placeTextAnnotation — resigna canvas + async pra teclado.
        for (_, canvas) in pageToCanvas {
            if canvas.isFirstResponder { canvas.resignFirstResponder() }
        }
        DispatchQueue.main.async {
            editor.beginEditing()
        }
    }

    /// Action sheet para mask em modo Marcador (não-Study): apagar.
    /// Em Study Mode é tratado separadamente (commit 3 — popup acertei/errei).
    private func showMaskActionMenu(for annotation: PDFAnnotation, on page: PDFPage, at viewPoint: CGPoint, in pdfView: PDFView) {
        guard let hostVC = pdfView.findViewController() else { return }
        let alert = UIAlertController(title: "Marcação opaca", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Apagar", style: .destructive) { [weak self] _ in
            page.removeAnnotation(annotation)
            self?.viewModel.saveHighlights()
        })
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = pdfView
            popover.sourceRect = CGRect(origin: viewPoint, size: .zero)
        }
        hostVC.present(alert, animated: true)
    }

    private func showDeleteMenu(for annotation: PDFAnnotation, on page: PDFPage, at viewPoint: CGPoint, in pdfView: PDFView) {
        guard let hostVC = pdfView.findViewController() else { return }
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Excluir caixa de texto", style: .destructive) { [weak self] _ in
            page.removeAnnotation(annotation)
            self?.viewModel.saveHighlights()
        })
        alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = pdfView
            popover.sourceRect = CGRect(origin: viewPoint, size: .zero)
        }
        hostVC.present(alert, animated: true)
    }

    // MARK: UIGestureRecognizerDelegate — allow simultaneous recognition with PDFView's own gestures

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool { true }

    // MARK: Helpers

    func scrollToPage(_ pageIndex: Int, in pdfView: PDFView) {
        guard lastScrolledPage != pageIndex,
              let doc = pdfView.document,
              let page = doc.page(at: pageIndex) else { return }
        // Only scroll if this was triggered externally (thumbnail tap)
        let currentIndex = pdfView.currentPage.flatMap { doc.index(for: $0) } ?? -1
        if currentIndex != pageIndex {
            lastScrolledPage = pageIndex
            pdfView.go(to: page)
        }
    }

    func applyAnnotationMode(_ annotating: Bool) {
        // Critical: when annotating, PDFView's internal UIScrollView
        // steals single-finger drags for scrolling BEFORE they reach the
        // overlay canvas. Disable the scroll view's pan/pinch while annotating
        // so the finger draws instead of scrolls. Two-finger scroll still works
        // via the PDFView's other gesture recognizers.
        if let pdfView = self.pdfView {
            for subview in pdfView.subviews {
                if let scrollView = subview as? UIScrollView {
                    scrollView.panGestureRecognizer.isEnabled = !annotating
                    scrollView.pinchGestureRecognizer?.isEnabled = !annotating
                }
            }
        }

        for (_, canvas) in pageToCanvas {
            canvas.isUserInteractionEnabled = annotating
            // Re-sync tool from picker on every mode entry — guarantees first touch
            // always has an active tool (was bug "modo ativo mas não escreve").
            canvas.tool = toolPicker.selectedTool
            if annotating {
                // becomeFirstResponder BEFORE setVisible so the tool picker
                // has a valid responder target when it renders.
                canvas.becomeFirstResponder()
                toolPicker.setVisible(true, forFirstResponder: canvas)
                toolPicker.addObserver(canvas)
            } else {
                toolPicker.setVisible(false, forFirstResponder: canvas)
                canvas.resignFirstResponder()
                toolPicker.removeObserver(canvas)
            }
        }
        // Force visible pages to redraw their overlays so the new interaction
        // state takes effect immediately (otherwise overlay can stay stale until
        // user scrolls the page).
        if let pdfView = self.pdfView {
            pdfView.setNeedsLayout()
            pdfView.layoutIfNeeded()
        }
    }

    func applyLassoMode(_ lasso: Bool) {
        guard isLassoMode != lasso else { return }
        isLassoMode = lasso
        for (_, canvas) in pageToCanvas {
            if lasso {
                canvas.tool = PKLassoTool()
            } else {
                // Restore the tool picker's currently selected tool
                canvas.tool = toolPicker.selectedTool
            }
        }
    }

    // MARK: Masking Mode (Study Mode F1)

    var isMaskingMode: Bool = false
    var isStudyMode: Bool = false
    private var maskDragLayer: CAShapeLayer?
    private var maskDragStartView: CGPoint?

    func applyMaskingMode(_ masking: Bool) {
        guard isMaskingMode != masking else { return }
        isMaskingMode = masking
        applyDragModeInteractions()
    }

    /// Aplica enable/disable de scroll + canvas pra que o pan custom capture
    /// drag em modo masking OU highlight. Chamado quando masking/highlight mudam.
    func applyDragModeInteractions() {
        // Drag livre (mask ou highlight) requer scroll pan desativado pra
        // single-finger drag virar shape, não scroll.
        let highlight = viewModel.isHighlightMode
        let masking = isMaskingMode
        if let pdfView = self.pdfView {
            for subview in pdfView.subviews {
                if let scrollView = subview as? UIScrollView {
                    scrollView.panGestureRecognizer.isEnabled = !masking && !highlight && !viewModel.isAnnotating
                }
            }
        }
        // Disable canvas interaction so drag goes to our pan recognizer, not PencilKit.
        for (_, canvas) in pageToCanvas {
            canvas.isUserInteractionEnabled = !masking && !highlight && viewModel.isAnnotating
        }
    }

    /// Modos do pan gesture que partilha o mesmo recognizer (mask + highlight livre).
    enum PdfPanDragMode {
        case mask
        case highlight
    }

    @objc func handleMaskingPan(_ gesture: UIPanGestureRecognizer) {
        // Decide modo: masking (preto) OU highlight livre (amarelo Goodnotes-style).
        // Highlight livre: arrasta em qualquer área da página, NÃO requer texto seletível.
        // **Sempre exige isAnnotating=false** — guarda contra interceptar drag em
        // modo desenho (bug 2026-04-26: drawing era apagado se highlight ativou
        // antes e estado ficou desincronizado).
        if viewModel.isAnnotating { return }
        let activeMode: PdfPanDragMode
        if isMaskingMode, !isStudyMode { activeMode = .mask }
        else if isHighlightMode { activeMode = .highlight }
        else { return }

        guard let pdfView = gesture.view as? PDFView else { return }
        let viewPoint = gesture.location(in: pdfView)

        switch gesture.state {
        case .began:
            maskDragStartView = viewPoint
            let layer = CAShapeLayer()
            switch activeMode {
            case .mask:
                layer.strokeColor = UIColor.systemYellow.withAlphaComponent(0.8).cgColor
                layer.fillColor = UIColor.black.withAlphaComponent(0.4).cgColor
                layer.lineWidth = 1.0
                layer.lineDashPattern = [4, 3]
            case .highlight:
                let hex = Self.userHighlightColor()
                layer.strokeColor = hex.withAlphaComponent(0.8).cgColor
                layer.fillColor = hex.withAlphaComponent(0.35).cgColor
                layer.lineWidth = 0
            }
            pdfView.layer.addSublayer(layer)
            maskDragLayer = layer

        case .changed:
            guard let start = maskDragStartView, let layer = maskDragLayer else { return }
            let rect = CGRect(
                x: min(start.x, viewPoint.x),
                y: min(start.y, viewPoint.y),
                width: abs(viewPoint.x - start.x),
                height: abs(viewPoint.y - start.y)
            )
            layer.path = UIBezierPath(rect: rect).cgPath

        case .ended:
            defer {
                maskDragLayer?.removeFromSuperlayer()
                maskDragLayer = nil
                maskDragStartView = nil
            }
            guard let start = maskDragStartView else { return }
            let dragRect = CGRect(
                x: min(start.x, viewPoint.x),
                y: min(start.y, viewPoint.y),
                width: abs(viewPoint.x - start.x),
                height: abs(viewPoint.y - start.y)
            )
            // Reject taps disguised as drags
            guard dragRect.width > 12, dragRect.height > 12 else { return }
            // Convert view rect to page rect via two corners
            guard let page = pdfView.page(for: CGPoint(x: dragRect.midX, y: dragRect.midY), nearest: true) else { return }
            let p1 = pdfView.convert(CGPoint(x: dragRect.minX, y: dragRect.minY), to: page)
            let p2 = pdfView.convert(CGPoint(x: dragRect.maxX, y: dragRect.maxY), to: page)
            let pageRect = CGRect(
                x: min(p1.x, p2.x),
                y: min(p1.y, p2.y),
                width: abs(p2.x - p1.x),
                height: abs(p2.y - p1.y)
            )
            switch activeMode {
            case .mask:
                let mask = PdfMaskAnnotation.makeAnnotation(bounds: pageRect)
                page.addAnnotation(mask)
                VitaPostHogConfig.capture(event: "pdf_mask_created", properties: [
                    "page_index": viewModel.currentPage,
                    "width": Int(pageRect.width),
                    "height": Int(pageRect.height),
                ])
            case .highlight:
                let highlightColor = Self.userHighlightColor()
                let annotation = PDFAnnotation(bounds: pageRect, forType: .highlight, withProperties: nil)
                annotation.color = highlightColor
                page.addAnnotation(annotation)
                VitaPostHogConfig.capture(event: "pdf_highlight_free_drag", properties: [
                    "page_index": viewModel.currentPage,
                    "width": Int(pageRect.width),
                    "height": Int(pageRect.height),
                ])
            }
            viewModel.saveHighlights()

        case .cancelled, .failed:
            maskDragLayer?.removeFromSuperlayer()
            maskDragLayer = nil
            maskDragStartView = nil
        default:
            break
        }
    }

    // MARK: PKToolPickerObserver — deactivate lasso when user picks a different tool

    func toolPickerSelectedToolItemDidChange(_ toolPicker: PKToolPicker) {
        guard isLassoMode else { return }
        // User switched tool via the picker — deactivate lasso mode
        Task { @MainActor [weak self] in
            self?.viewModel.isLassoMode = false
        }
    }

    /// Reads `pdf.highlight.colorHex` from UserDefaults (set by PdfHighlightColorPopover)
    /// and returns the highlight UIColor with fixed 40% opacity. Falls back to gold default.
    static func userHighlightColor() -> UIColor {
        let hex = UserDefaults.standard.string(forKey: "pdf.highlight.colorHex") ?? "#FFD84D"
        let trimmed = hex.replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6, let v = UInt32(trimmed, radix: 16) else {
            return UIColor(red: 1.0, green: 0.78, blue: 0.47, alpha: 0.35)
        }
        let r = CGFloat((v >> 16) & 0xFF) / 255.0
        let g = CGFloat((v >> 8) & 0xFF) / 255.0
        let b = CGFloat(v & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: 0.4)
    }

    // MARK: Apple Pencil hover preview
    //
    // Goodnotes/Notability/Apple Notes mostram um "ghost" do tip da Pencil antes
    // do toque encostar na tela. UIHoverGestureRecognizer (iOS 13+) ganhou as
    // properties zOffset/azimuthAngle/altitudeAngle em iOS 16.1 (WWDC 22 +
    // iPadOS 16.1 release). Funciona automaticamente com Apple Pencil 2 em
    // iPad Pro M2/M4 e Apple Pencil Pro. Em hardware sem hover (Pencil 1,
    // Pencil USB-C, iPad Air não-M2), o callback simplesmente nunca dispara —
    // ou dispara com zOffset=0, que filtramos abaixo.
    //
    // Sources:
    //   developer.apple.com/documentation/UIKit/adopting-hover-support-for-apple-pencil
    //   developer.apple.com/documentation/uikit/uihovergesturerecognizer/zoffset
    //   developer.apple.com/news/?id=23ksaoks (Spotlight on: Apple Pencil hover)

    /// Tag aplicada à subview de preview pra encontrá-la depois sem property novo
    /// no Coordinator (evitamos guardar map per-canvas que vazaria com a página).
    private static let hoverPreviewTag: Int = 7331

    private func attachPencilHoverPreview(to canvas: PKCanvasView) {
        // Preview view: subview do próprio canvas, em coordenadas do canvas.
        // Já entra escondida — só aparece quando hover de Pencil dispara.
        let preview = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 12))
        preview.tag = Coordinator.hoverPreviewTag
        preview.isHidden = true
        preview.isUserInteractionEnabled = false
        preview.backgroundColor = .clear
        preview.layer.allowsEdgeAntialiasing = true
        canvas.addSubview(preview)

        let hover = UIHoverGestureRecognizer(target: self,
                                             action: #selector(handlePencilHover(_:)))
        // Reconhecer mesmo se PKCanvasView tiver outros gestures ativos.
        hover.delegate = self
        canvas.addGestureRecognizer(hover)
    }

    @objc private func handlePencilHover(_ gr: UIHoverGestureRecognizer) {
        guard let canvas = gr.view as? PKCanvasView,
              let preview = canvas.viewWithTag(Coordinator.hoverPreviewTag) else { return }

        // Gate: só mostra hover preview em modo de desenho real.
        // Pointer-mode (cor .clear) não desenha, então não faz sentido preview.
        guard viewModel.isAnnotating else {
            preview.isHidden = true
            return
        }

        switch gr.state {
        case .began, .changed:
            // zOffset == 0 quando a fonte não é Apple Pencil capable de hover
            // (mouse, finger, Pencil 1). Filtra silenciosamente.
            let zOffset: CGFloat
            if #available(iOS 16.1, *) {
                zOffset = gr.zOffset
            } else {
                zOffset = 0
            }
            guard zOffset > 0 else {
                preview.isHidden = true
                return
            }

            let location = gr.location(in: canvas)
            updateHoverPreview(preview, at: location, zOffset: zOffset, on: canvas)

        case .ended, .cancelled, .failed:
            preview.isHidden = true

        default:
            break
        }
    }

    /// Repinta + reposiciona o ghost baseado no tool ativo. Sem animação no
    /// .changed pra manter 60fps; ajusta center via transform-equivalent direto.
    private func updateHoverPreview(_ preview: UIView,
                                    at location: CGPoint,
                                    zOffset: CGFloat,
                                    on canvas: PKCanvasView) {
        // Opacidade cresce conforme tip se aproxima da tela (1mm-12mm range).
        // zOffset é normalizado [0, 1] — quanto menor, mais perto.
        let proximityAlpha = max(0.35, 1.0 - zOffset)

        let tool = canvas.tool

        // Limpa shape anterior (recriamos a cada frame — barato pra primitivas
        // simples, evita guardar estado e fica visualmente correto se o user
        // trocar de tool no PKToolPicker enquanto pairava com a Pencil).
        preview.layer.sublayers?.removeAll()
        preview.backgroundColor = .clear
        preview.layer.cornerRadius = 0
        preview.layer.borderWidth = 0
        preview.transform = .identity

        if let eraser = tool as? PKEraserTool {
            // Borracha: círculo cinza translúcido. Bitmap eraser usa raio
            // ~22pt; vector eraser segue a width do tool. Damos fallback 22.
            let radius: CGFloat
            switch eraser.eraserType {
            case .bitmap: radius = 22
            case .vector: radius = 18
            @unknown default: radius = 20
            }
            let size = CGSize(width: radius * 2, height: radius * 2)
            preview.bounds = CGRect(origin: .zero, size: size)
            preview.center = location
            preview.layer.cornerRadius = radius
            preview.backgroundColor = UIColor.systemGray.withAlphaComponent(0.18 * proximityAlpha)
            preview.layer.borderWidth = 1
            preview.layer.borderColor = UIColor.systemGray.withAlphaComponent(0.45 * proximityAlpha).cgColor

        } else if let ink = tool as? PKInkingTool {
            let color = ink.color
            // Heurística marca-texto: marker tool OU cor com alpha < 1 (highlight).
            let isHighlighter: Bool = {
                if ink.inkType == .marker { return true }
                var alpha: CGFloat = 1
                color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
                return alpha < 0.95
            }()

            // Pointer-mode usa cor totalmente transparente — não desenha nada
            // visível. Pra esse caso, esconde preview (não há "tip" real).
            var alpha: CGFloat = 1
            color.getRed(nil, green: nil, blue: nil, alpha: &alpha)
            if alpha < 0.05 {
                preview.isHidden = true
                return
            }

            if isHighlighter {
                // Barra horizontal proporcional à largura do marker.
                let barHeight = max(6, ink.width * 0.9)
                let barWidth: CGFloat = 28
                preview.bounds = CGRect(x: 0, y: 0, width: barWidth, height: barHeight)
                preview.center = location
                preview.backgroundColor = color.withAlphaComponent(min(0.65, alpha) * proximityAlpha)
                preview.layer.cornerRadius = barHeight / 2
            } else {
                // Pen/pencil/fountain: dot pequeno na cor do tool, raio
                // proporcional à width (clamp 3...8 pra não virar bolha).
                let dotRadius = max(3, min(8, ink.width / 2 + 1))
                let size = CGSize(width: dotRadius * 2, height: dotRadius * 2)
                preview.bounds = CGRect(origin: .zero, size: size)
                preview.center = location
                preview.backgroundColor = color.withAlphaComponent(0.85 * proximityAlpha)
                preview.layer.cornerRadius = dotRadius
                preview.layer.borderWidth = 0.5
                preview.layer.borderColor = UIColor.white.withAlphaComponent(0.7 * proximityAlpha).cgColor
            }

        } else {
            // Lasso, ou tool desconhecido: dot neutro discreto.
            let size = CGSize(width: 8, height: 8)
            preview.bounds = CGRect(origin: .zero, size: size)
            preview.center = location
            preview.backgroundColor = UIColor.label.withAlphaComponent(0.4 * proximityAlpha)
            preview.layer.cornerRadius = 4
        }

        preview.isHidden = false
    }
}


// MARK: - Search Bar

private struct PdfSearchBar: View {
    @Binding var searchText: String
    let resultCount: Int
    let currentIndex: Int
    @FocusState.Binding var isSearchFocused: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15))
                .foregroundStyle(VitaColors.textTertiary)

            TextField("Buscar no PDF…", text: $searchText)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textPrimary)
                .tint(VitaColors.accent)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .frame(maxWidth: .infinity)

            if resultCount > 0 {
                Text("\(currentIndex)/\(resultCount)")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .monospacedDigit()
                    .fixedSize()
            } else if !searchText.isEmpty {
                Text("Sem resultados")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }

            if resultCount > 0 {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VitaColors.textSecondary)
                        .frame(width: 30, height: 30)
                }

                Button(action: onNext) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VitaColors.textSecondary)
                        .frame(width: 30, height: 30)
                }
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(VitaColors.textTertiary)
                    .frame(width: 30, height: 30)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(VitaColors.surfaceCard)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(VitaColors.surfaceBorder),
            alignment: .bottom
        )
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - UIView helper

private extension UIView {
    func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}


// MARK: - InlineTextEditor — floating UITextView for in-place PDF text annotation

/// Floating glass text editor that appears at the tap location on the PDF.
/// Apple Notes / Goodnotes pattern: user sees exactly where they're typing,
/// cursor + keyboard appear at the touched point.
///
/// On commit (Done button or resign focus): calls `onCommit(text)`.
/// On cancel (Esc-equivalent / scroll dismiss): calls `onCancel()`.
private final class InlineTextEditor: UIView, UITextViewDelegate {
    var onCommit: ((String) -> Void)?
    var onCancel: (() -> Void)?

    private let textView = UITextView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Glass background with gold border — same vibe as VitaModals D4
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.layer.cornerRadius = 10
        blurView.layer.borderWidth = 1
        // Gold accentHover at 40% — same token as VitaColors.accentHover
        blurView.layer.borderColor = UIColor(red: 1.0, green: 0.784, blue: 0.471, alpha: 0.40).cgColor
        blurView.clipsToBounds = true
        addSubview(blurView)

        textView.frame = bounds.insetBy(dx: 8, dy: 4)
        textView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        textView.backgroundColor = .clear
        textView.isOpaque = false
        textView.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        textView.textColor = .white
        textView.tintColor = UIColor(red: 1.0, green: 0.784, blue: 0.471, alpha: 1.0) // gold cursor
        textView.delegate = self
        textView.returnKeyType = .done
        textView.autocapitalizationType = .sentences
        textView.textContainerInset = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        addSubview(textView)

        // Toolbar with Done button as keyboard accessory (visible UX safety net
        // in case user wants explicit confirm without losing focus to scroll).
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 40))
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped)),
        ]
        toolbar.sizeToFit()
        textView.inputAccessoryView = toolbar

        // Subtle drop shadow to lift off PDF surface
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    required init?(coder: NSCoder) { fatalError() }

    func beginEditing() {
        textView.becomeFirstResponder()
    }

    /// Pre-fill the editor with existing text (used on re-edit of placed annotation).
    func preload(text: String) {
        textView.text = text
        textViewDidChange(textView)
    }

    @objc private func doneTapped() {
        commit()
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    private func commit() {
        let text = textView.text ?? ""
        onCommit?(text)
    }

    // MARK: UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        // Auto-grow horizontally then vertically. Cap width at 280, then wrap.
        let maxWidth: CGFloat = 280
        let measured = textView.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        var newFrame = self.frame
        newFrame.size.width = min(maxWidth, max(120, measured.width + 24))
        newFrame.size.height = max(36, measured.height + 12)
        self.frame = newFrame
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        // Pressing Return commits (single-line annotation). Shift+Return would
        // require key modifier detection — keep simple for v1.
        if text == "\n" {
            commit()
            return false
        }
        return true
    }
}

// MARK: - AttemptFlash — overlay animado pós tap-to-reveal

struct AttemptFlash {
    let correct: Bool
    var scale: CGFloat
    var opacity: Double
}

// MARK: - StudyMaskPrompt — payload do tap em mask em Study Mode

struct StudyMaskPrompt: Identifiable {
    var id: String { maskId }
    let maskId: String
    let pageIndex: Int
    let bounds: CGRect
    let annotation: PDFAnnotation
    let page: PDFPage
}

// MARK: - StudyMaskPromptSheet — popup acertei/errei

struct StudyMaskPromptSheet: View {
    let onCorrect: () -> Void
    let onWrong: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("Como foi?")
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textPrimary)
                .padding(.top, 8)

            Text("Lembrou do conteúdo coberto?")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                Button(action: onWrong) {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                        Text("Errei")
                            .font(VitaTypography.labelMedium)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Button(action: onCorrect) {
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                        Text("Acertei")
                            .font(VitaTypography.labelMedium)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 16)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
    }
}
