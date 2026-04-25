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
    @AppStorage("pdf_show_mascot") private var showMascot: Bool = true
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

            // Vita mascot FAB — top-level overlay so it draws above everything,
            // including the (hidden-when-fullscreen) tab bar.
            // bottomInset reserves space for the app TabBar (~96pt) unless in fullscreen.
            if viewModel.document != nil && !isScanMode && showMascot {
                VitaFloatingMascot(
                    positionKey: "pdf_mascot_pos",
                    bottomInset: isFullscreen ? 16 : 96,
                    isActive: isScanMode,
                    onTap: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            isScanMode = true
                            scanSelection = nil
                        }
                        VitaPostHogConfig.capture(event: "pergunte_ao_vita_tap")
                    }
                )
                .transition(.opacity)
            }
        }
        .task {
            // Multi-doc workspace: open the URL passed by the router as a tab.
            // If user already had other tabs from a previous session, they remain.
            // Mutating activeId here triggers .onChange below — single load path.
            workspace.open(url: url, title: initialTitle)
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
        .trackScreen("PdfViewer")
        .onDisappear { viewModel.saveAllAnnotations() }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard)
        // Fullscreen: hide status bar + home indicator. Propagate immersive state
        // to AppRouter via preference so it hides TopBar + TabBar + breadcrumb.
        .statusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        .ignoresSafeArea(isFullscreen ? .all : [])
        .preference(key: ImmersivePreferenceKey.self, value: isFullscreen)
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
            // Toolbar visible always (Rafael 2026-04-25): in fullscreen the user
            // still needs highlight/text/draw/search/bookmark/transcribe access.
            // The fullscreenExitPill (top-leading floating) handles the
            // back+exit-fullscreen affordance in fullscreen mode.
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
                    showMascot: showMascot,
                    showThumbnailToggle: viewModel.pageCount > 1,
                    isEraserMode: isEraserMode,
                    isPointerMode: isPointerMode,
                    canUndo: canUndo,
                    canRedo: canRedo,
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
                    onToggleMascot: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            showMascot.toggle()
                        }
                    },
                    onExport: {
                        Task { await exportPDF(document: document) }
                    },
                    onTranscribe: {
                        guard let drawing = viewModel.currentDrawingProvider?(),
                              !drawing.strokes.isEmpty else { return }
                        Task { await viewModel.recognizeHandwriting(drawing: drawing) }
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
                    onShowSettings: { showSettingsSheet = true }
                )

            // Multi-doc tab bar (Goodnotes-style). Hidden in fullscreen so the
            // PDF gets the whole screen.
            if !isFullscreen {
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

        if twoPageSpread && UIDevice.current.userInterfaceIdiom == .pad {
            pdfView.displayMode = pageByPage ? .twoUp : .twoUpContinuous
        } else {
            pdfView.displayMode = pageByPage ? .singlePage : .singlePageContinuous
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
                        .background(VitaColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(VitaColors.surfaceCard)
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
        pdfView.isInMarkupMode = true
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

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== viewModel.document {
            pdfView.document = viewModel.document
        }
        // Scroll to page when thumbnail sidebar taps
        context.coordinator.scrollToPage(viewModel.currentPage, in: pdfView)
        // Toggle annotation mode on all visible canvases
        context.coordinator.applyAnnotationMode(viewModel.isAnnotating)
        // Sync highlight mode into coordinator
        context.coordinator.isHighlightMode = viewModel.isHighlightMode
        // Sync text mode into coordinator
        context.coordinator.isTextMode = viewModel.isTextMode
        // Sync lasso mode — apply PKLassoTool or restore ink tool
        context.coordinator.applyLassoMode(viewModel.isLassoMode)
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
    }

    // MARK: PKCanvasViewDelegate

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        // Autosave is handled on willEndDisplaying; mark saving indicator only
        viewModel.isSaving = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(800))
            self?.viewModel.isSaving = false
        }
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
        editor.beginEditing()
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
        editor.beginEditing()
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
