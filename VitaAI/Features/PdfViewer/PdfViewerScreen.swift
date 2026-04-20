import SwiftUI
import PDFKit
import PencilKit
import Combine

// MARK: - PdfViewerScreen

/// Full-screen PDF viewer using native PDFView + PDFPageOverlayViewProvider + PKToolPicker.
/// Works like GoodNotes: continuous scroll, pinch zoom, Apple Pencil + finger ink per page.
struct PdfViewerScreen: View {
    let url: URL
    let onBack: () -> Void

    @Environment(\.appContainer) private var container
    @State private var viewModel = PdfViewerViewModel()
    @State private var showExportSheet: Bool = false
    @State private var exportedURL: URL? = nil
    @State private var searchDebounceTask: Task<Void, Never>? = nil
    @State private var recognitionCopied: Bool = false
    @State private var isFullscreen: Bool = false
    @State private var showPerguntaVita: Bool = false
    @State private var perguntaVitaImageData: Data? = nil
    // Scan mode (Pergunte ao Vita)
    @State private var isScanMode: Bool = false
    @State private var scanSelection: CGRect? = nil   // in pdfViewContainer coords
    @State private var pdfViewContainerFrame: CGRect = .zero
    @AppStorage("pdf_show_mascot") private var showMascot: Bool = true
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView()
                    .tint(VitaColors.accent)
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
                    }
                )
                .transition(.opacity)
            }
        }
        .task { await viewModel.load(url: url, tokenStore: container.tokenStore) }
        .onDisappear { viewModel.saveAllAnnotations() }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard)
        // Fullscreen: hide status bar + home indicator. Propagate immersive state
        // to AppRouter via preference so it hides TopBar + TabBar + breadcrumb.
        .statusBarHidden(isFullscreen)
        .persistentSystemOverlays(isFullscreen ? .hidden : .automatic)
        .ignoresSafeArea(isFullscreen ? .all : [])
        .preference(key: ImmersivePreferenceKey.self, value: isFullscreen)
        .sheet(isPresented: $showExportSheet) {
            if let exportedURL {
                ShareSheet(items: [exportedURL])
                    .presentationDetents([.medium, .large])
            }
        }
        .sheet(isPresented: $viewModel.showRecognitionResult) {
            recognitionResultSheet
        }
        // Pergunte ao Vita chat opens as a sheet (not fullScreenCover) so the
        // PDF stays visible underneath — user can cross-reference while chatting.
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
            if !isFullscreen {
                PdfTopBar(
                    fileName: viewModel.fileName,
                    currentPage: viewModel.currentPage + 1,
                    pageCount: viewModel.pageCount,
                    isSaving: viewModel.isSaving,
                    isAnnotating: viewModel.isAnnotating,
                    isHighlightMode: viewModel.isHighlightMode,
                    isTextMode: viewModel.isTextMode,
                    isSearching: viewModel.isSearching,
                    isBookmarked: viewModel.isCurrentPageBookmarked,
                    showThumbnailToggle: viewModel.pageCount > 1,
                    hasInkOnCurrentPage: viewModel.currentDrawingProvider?()?.strokes.isEmpty == false,
                    isRecognizing: viewModel.isRecognizing,
                    isLassoMode: viewModel.isLassoMode,
                    isFullscreen: isFullscreen,
                    showMascot: showMascot,
                    onBack: {
                        viewModel.saveAllAnnotations()
                        onBack()
                    },
                    onToggleThumbnails: viewModel.toggleThumbnails,
                    onToggleAnnotating: viewModel.toggleAnnotating,
                    onToggleHighlight: viewModel.toggleHighlightMode,
                    onToggleText: viewModel.toggleTextMode,
                    onToggleSearch: {
                        viewModel.toggleSearch()
                        if viewModel.isSearching {
                            isSearchFocused = true
                        }
                    },
                    onToggleBookmark: viewModel.toggleBookmark,
                    onToggleLasso: viewModel.toggleLassoMode,
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
                    }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
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
                    annotation.font = UIFont.systemFont(ofSize: 13)
                    annotation.fontColor = UIColor.white
                    annotation.color = UIColor(white: 0.1, alpha: 0.85)
                    annotation.border = PDFBorder()
                    annotation.border?.lineWidth = 0.5
                    annotation.border?.style = .solid
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
        .presentationDetents([.medium, .large])
        .presentationBackground(.ultraThinMaterial)
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

    /// Mirror of viewModel.isTextMode, updated from updateUIView
    var isTextMode: Bool = false

    /// Mirror of viewModel.isLassoMode, updated from updateUIView
    var isLassoMode: Bool = false

    /// Debounce task to avoid double-firing on selection change
    var highlightDebounceTask: Task<Void, Never>?

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
        pageToCanvas[page] = canvas

        // Load saved drawing from disk
        if let pageIndex = view.document?.index(for: page),
           let drawing = viewModel.loadDrawing(pageIndex: pageIndex) {
            canvas.drawing = drawing
        }

        if viewModel.isAnnotating {
            toolPicker.setVisible(true, forFirstResponder: canvas)
            toolPicker.addObserver(canvas)
            canvas.becomeFirstResponder()
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
        let highlightColor = UIColor(red: 1.0, green: 0.78, blue: 0.47, alpha: 0.35)
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
            // Check if tapping an existing freeText annotation — show delete option
            for annotation in page.annotations {
                guard annotation.type == "FreeText" else { continue }
                if annotation.bounds.contains(pagePoint) {
                    showDeleteMenu(for: annotation, on: page, at: point, in: pdfView)
                    return
                }
            }
            // No existing annotation tapped — place a new text box
            placeTextAnnotation(at: pagePoint, on: page)
            return
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
        let width: CGFloat = 200
        let height: CGFloat = 40
        let bounds = CGRect(
            x: pagePoint.x - width / 2,
            y: pagePoint.y - height / 2,
            width: width,
            height: height
        )
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.font = UIFont.systemFont(ofSize: 13)
        annotation.fontColor = UIColor.white
        annotation.color = UIColor(white: 0.1, alpha: 0.85)
        annotation.border = PDFBorder()
        annotation.border?.lineWidth = 0.5
        annotation.border?.style = .solid
        annotation.color = UIColor(white: 0.1, alpha: 0.85)
        annotation.isReadOnly = false
        annotation.contents = ""
        page.addAnnotation(annotation)
        viewModel.saveHighlights()
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
        for (_, canvas) in pageToCanvas {
            canvas.isUserInteractionEnabled = annotating
            if annotating {
                toolPicker.setVisible(true, forFirstResponder: canvas)
                toolPicker.addObserver(canvas)
                canvas.becomeFirstResponder()
            } else {
                toolPicker.setVisible(false, forFirstResponder: canvas)
                canvas.resignFirstResponder()
                toolPicker.removeObserver(canvas)
            }
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
}

// MARK: - Top Bar

private struct PdfTopBar: View {
    let fileName: String
    let currentPage: Int
    let pageCount: Int
    let isSaving: Bool
    let isAnnotating: Bool
    let isHighlightMode: Bool
    let isTextMode: Bool
    let isSearching: Bool
    let isBookmarked: Bool
    let showThumbnailToggle: Bool
    let hasInkOnCurrentPage: Bool
    let isRecognizing: Bool
    let isLassoMode: Bool
    let isFullscreen: Bool
    let showMascot: Bool
    let onBack: () -> Void
    let onToggleThumbnails: () -> Void
    let onToggleAnnotating: () -> Void
    let onToggleHighlight: () -> Void
    let onToggleText: () -> Void
    let onToggleSearch: () -> Void
    let onToggleBookmark: () -> Void
    let onToggleLasso: () -> Void
    let onToggleFullscreen: () -> Void
    let onToggleMascot: () -> Void
    let onExport: () -> Void
    let onTranscribe: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 40, height: 40)
            }

            Text(fileName)
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isSaving {
                Text("Salvando…")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }

            if pageCount > 0 {
                Text("\(currentPage) / \(pageCount)")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                    .monospacedDigit()
            }

            // Search toggle
            Button(action: onToggleSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundStyle(isSearching ? VitaColors.accent : VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }

            // Pencil toggle — shows/hides PKToolPicker
            Button(action: onToggleAnnotating) {
                Image(systemName: isAnnotating ? "pencil.circle.fill" : "pencil.circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isAnnotating ? VitaColors.accent : VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }

            // Transcribe ink button — only when annotating and there's ink
            if isAnnotating {
                Button(action: onTranscribe) {
                    Group {
                        if isRecognizing {
                            ProgressView()
                                .tint(VitaColors.accent)
                                .scaleEffect(0.75)
                        } else {
                            Image(systemName: "text.viewfinder")
                                .font(.system(size: 18))
                                .foregroundStyle(hasInkOnCurrentPage ? VitaColors.accent : VitaColors.textTertiary)
                        }
                    }
                    .frame(width: 36, height: 36)
                }
                .disabled(!hasInkOnCurrentPage || isRecognizing)
            }

            // Lasso select — only when annotating
            if isAnnotating {
                Button(action: onToggleLasso) {
                    Image(systemName: "lasso")
                        .font(.system(size: 18))
                        .foregroundStyle(isLassoMode ? VitaColors.accentHover : VitaColors.textSecondary)
                        .frame(width: 36, height: 36)
                }
            }

            // Highlight toggle
            Button(action: onToggleHighlight) {
                Image(systemName: "highlighter")
                    .font(.system(size: 18))
                    .foregroundStyle(isHighlightMode ? VitaColors.accent : VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }

            // Text box toggle
            Button(action: onToggleText) {
                Image(systemName: "character.textbox")
                    .font(.system(size: 18))
                    .foregroundStyle(isTextMode ? VitaColors.accent : VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }

            // Bookmark toggle
            Button(action: onToggleBookmark) {
                Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16))
                    .foregroundStyle(isBookmarked ? VitaColors.accentHover : VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }

            if showThumbnailToggle {
                Button(action: onToggleThumbnails) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 16))
                        .foregroundStyle(VitaColors.textSecondary)
                        .frame(width: 36, height: 36)
                }
            }

            // Pergunte ao Vita mascot toggle — for users who don't want the FAB.
            Button(action: onToggleMascot) {
                Image(systemName: showMascot ? "questionmark.bubble.fill" : "questionmark.bubble")
                    .font(.system(size: 15))
                    .foregroundStyle(showMascot ? VitaColors.accent : VitaColors.textTertiary)
                    .frame(width: 36, height: 36)
            }

            // Fullscreen toggle — hides top bar so PDF fits the narrow iPhone portrait view.
            Button(action: onToggleFullscreen) {
                Image(systemName: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }

            Button(action: onExport) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(VitaColors.surfaceCard)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(VitaColors.surfaceBorder),
            alignment: .bottom
        )
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

