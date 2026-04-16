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
        }
        .task { await viewModel.load(url: url, tokenStore: container.tokenStore) }
        .onDisappear { viewModel.saveAllAnnotations() }
        .navigationBarHidden(true)
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showExportSheet) {
            if let exportedURL {
                ShareSheet(items: [exportedURL])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(document: PDFDocument) -> some View {
        VStack(spacing: 0) {
            PdfTopBar(
                fileName: viewModel.fileName,
                currentPage: viewModel.currentPage + 1,
                pageCount: viewModel.pageCount,
                isSaving: viewModel.isSaving,
                isAnnotating: viewModel.isAnnotating,
                isSearching: viewModel.isSearching,
                isBookmarked: viewModel.isCurrentPageBookmarked,
                showThumbnailToggle: viewModel.pageCount > 1,
                onBack: {
                    viewModel.saveAllAnnotations()
                    onBack()
                },
                onToggleThumbnails: viewModel.toggleThumbnails,
                onToggleAnnotating: viewModel.toggleAnnotating,
                onToggleSearch: {
                    viewModel.toggleSearch()
                    if viewModel.isSearching {
                        isSearchFocused = true
                    }
                },
                onToggleBookmark: viewModel.toggleBookmark,
                onExport: {
                    Task { await exportPDF(document: document) }
                }
            )

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
    }

    static func dismantleUIView(_ pdfView: PDFView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
        NativePdfView.pdfViewRef = nil
    }
}

// MARK: - Coordinator

private final class Coordinator: NSObject, PDFPageOverlayViewProvider, PDFViewDelegate, PKCanvasViewDelegate {
    let viewModel: PdfViewerViewModel
    weak var pdfView: PDFView?

    /// Tracks canvas per page so we can save/restore drawings and toggle tool picker.
    var pageToCanvas: [PDFPage: PKCanvasView] = [:]
    let toolPicker = PKToolPicker()

    private var lastScrolledPage: Int = -1

    init(viewModel: PdfViewerViewModel) {
        self.viewModel = viewModel
        super.init()
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
}

// MARK: - Top Bar

private struct PdfTopBar: View {
    let fileName: String
    let currentPage: Int
    let pageCount: Int
    let isSaving: Bool
    let isAnnotating: Bool
    let isSearching: Bool
    let isBookmarked: Bool
    let showThumbnailToggle: Bool
    let onBack: () -> Void
    let onToggleThumbnails: () -> Void
    let onToggleAnnotating: () -> Void
    let onToggleSearch: () -> Void
    let onToggleBookmark: () -> Void
    let onExport: () -> Void

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

