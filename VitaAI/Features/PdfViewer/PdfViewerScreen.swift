import SwiftUI
import PDFKit

// MARK: - PdfViewerScreen

/// Full-screen PDF viewer with GoodNotes-level annotation support.
/// Uses PDFKit page rendering + SwiftUI Canvas overlays for ink, shapes, and text.
struct PdfViewerScreen: View {
    let url: URL
    let onBack: () -> Void

    @State private var viewModel = PdfViewerViewModel()
    @State private var selectedPage: Int = 0
    @State private var showExportSheet: Bool = false
    @State private var exportedURL: URL? = nil

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
        .task { await viewModel.load(url: url) }
        .onDisappear { viewModel.forceSave() }
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
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Top bar
                PdfTopBar(
                    fileName: viewModel.fileName,
                    currentPage: viewModel.currentPage + 1,
                    pageCount: viewModel.pageCount,
                    isSaving: viewModel.isSaving,
                    showThumbnailToggle: viewModel.pageCount > 1,
                    onBack: {
                        viewModel.forceSave()
                        onBack()
                    },
                    onToggleThumbnails: viewModel.toggleThumbnails,
                    onExport: {
                        Task { await exportPDF(document: document) }
                    }
                )

                // Main pager
                ZStack(alignment: .leading) {
                    TabView(selection: $selectedPage) {
                        ForEach(0..<viewModel.pageCount, id: \.self) { pageIndex in
                            PdfPageView(
                                document: document,
                                pageIndex: pageIndex,
                                viewModel: viewModel,
                                isCurrentPage: pageIndex == viewModel.currentPage
                            )
                            .tag(pageIndex)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: selectedPage) { newPage in
                        viewModel.setCurrentPage(newPage)
                    }

                    // Thumbnail sidebar (slides in from left)
                    PageThumbnailSidebar(
                        document: document,
                        pageCount: viewModel.pageCount,
                        currentPage: viewModel.currentPage,
                        isVisible: viewModel.showThumbnails,
                        onPageSelected: { page in
                            selectedPage = page
                        }
                    )
                }
            }

            // Floating annotation toolbar
            AnnotationToolbar(
                isDrawMode: viewModel.isDrawMode,
                selectedTool: viewModel.selectedTool,
                selectedColor: viewModel.selectedColor,
                strokeWidth: viewModel.strokeWidth,
                canUndo: viewModel.canUndo,
                canRedo: viewModel.canRedo,
                onToggleDrawMode: viewModel.toggleDrawMode,
                onSelectTool: viewModel.selectTool,
                onSelectColor: viewModel.setColor,
                onStrokeWidthChange: viewModel.setStrokeWidth,
                onUndo: viewModel.undo,
                onRedo: viewModel.redo,
                onShapeMode: viewModel.selectTool
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
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

    // MARK: - Export

    private func exportPDF(document: PDFDocument) async {
        guard let exportedURL = try? await PdfExporter.export(
            document: document,
            pageCount: viewModel.pageCount,
            getStrokes: viewModel.strokes,
            getErasers: viewModel.erasers,
            getShapes: viewModel.shapes,
            getTexts: viewModel.texts
        ) else { return }
        self.exportedURL = exportedURL
        showExportSheet = true
    }
}

// MARK: - PDF Page View

private struct PdfPageView: View {
    let document: PDFDocument
    let pageIndex: Int
    @Bindable var viewModel: PdfViewerViewModel
    let isCurrentPage: Bool

    @State private var pageImage: UIImage? = nil
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    private var strokes: [InkStroke] {
        isCurrentPage ? viewModel.currentStrokes : viewModel.strokes(for: pageIndex)
    }
    private var eraserPaths: [EraserPath] {
        isCurrentPage ? viewModel.currentEraserPaths : viewModel.erasers(for: pageIndex)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let img = pageImage {
                    // Zoomable/pannable image when not drawing
                    ZStack {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(scale)
                            .offset(offset)
                            .gesture(viewModel.isDrawMode ? nil : magnifyAndPanGesture)

                        // Ink canvas overlay
                        InkCanvasView(
                            finishedStrokes: strokes,
                            eraserPaths: eraserPaths,
                            isDrawMode: viewModel.isDrawMode && isCurrentPage,
                            selectedTool: viewModel.selectedTool,
                            selectedColor: viewModel.selectedColor,
                            strokeWidth: viewModel.strokeWidth,
                            onStrokeFinished: { viewModel.addStrokes([$0]) },
                            onEraserPath: { viewModel.addEraserPath($0) }
                        )

                        // Shape overlay
                        ShapeOverlay(
                            shapes: isCurrentPage ? viewModel.shapeAnnotations : viewModel.shapes(for: pageIndex),
                            selectedTool: viewModel.selectedTool,
                            selectedColor: viewModel.selectedColor,
                            strokeWidth: viewModel.strokeWidth,
                            isActive: viewModel.isDrawMode && isCurrentPage && viewModel.selectedTool.isShapeTool,
                            onAddShape: { viewModel.addShapeAnnotation($0) }
                        )

                        // Text annotation overlay
                        TextAnnotationOverlay(
                            annotations: isCurrentPage ? viewModel.textAnnotations : viewModel.texts(for: pageIndex),
                            selectedColor: viewModel.selectedColor,
                            isActive: viewModel.isDrawMode && isCurrentPage && viewModel.selectedTool == .text,
                            onAddText: { viewModel.addTextAnnotation($0) },
                            onUpdateText: { viewModel.updateTextAnnotation($0) },
                            onRemoveText: { viewModel.removeTextAnnotation(id: $0) }
                        )
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                } else {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .task(id: pageIndex) {
            guard pageImage == nil else { return }
            pageImage = await renderPage()
        }
        .onChange(of: viewModel.isDrawMode) { drawing in
            if drawing { scale = 1; offset = .zero }
        }
    }

    // MARK: - Page Rendering

    private func renderPage() async -> UIImage? {
        await Task.detached(priority: .userInitiated) {
            guard let page = document.page(at: pageIndex) else { return nil }
            let targetWidth: CGFloat = UIScreen.main.bounds.width * UIScreen.main.scale
            let pageRect = page.bounds(for: .cropBox)
            let scl = targetWidth / pageRect.width
            let renderSize = CGSize(width: targetWidth, height: pageRect.height * scl)

            let renderer = UIGraphicsImageRenderer(size: renderSize)
            return renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(CGRect(origin: .zero, size: renderSize))
                ctx.cgContext.scaleBy(x: scl, y: scl)
                page.draw(with: .cropBox, to: ctx.cgContext)
            }
        }.value
    }

    // MARK: - Zoom/Pan Gesture

    private var magnifyAndPanGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = max(1, min(5, value))
                }
                .onEnded { value in
                    scale = max(1, min(5, value))
                    if scale == 1 { withAnimation(.spring) { offset = .zero } }
                },
            DragGesture()
                .onChanged { value in
                    guard scale > 1 else { return }
                    offset = value.translation
                }
                .onEnded { value in
                    guard scale > 1 else {
                        withAnimation(.spring) { offset = .zero }
                        return
                    }
                    offset = value.translation
                }
        )
    }
}

// MARK: - Top Bar

private struct PdfTopBar: View {
    let fileName: String
    let currentPage: Int
    let pageCount: Int
    let isSaving: Bool
    let showThumbnailToggle: Bool
    let onBack: () -> Void
    let onToggleThumbnails: () -> Void
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

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
