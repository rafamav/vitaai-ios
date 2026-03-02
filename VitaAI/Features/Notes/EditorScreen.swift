import SwiftUI
import PencilKit

// MARK: - EditorScreen
// Full-screen canvas editor with floating toolbar and top bar overlay.
// Mirrors EditorScreen.kt (Android).
// Uses PencilKit PKCanvasView for GoodNotes-level Apple Pencil experience.

struct EditorScreen: View {

    let notebookId: UUID
    let onBack: () -> Void

    @State private var viewModel: EditorViewModel
    @State private var currentDrawing: PKDrawing = PKDrawing()
    @State private var canvasKey: UUID = UUID()     // forces DrawingCanvasView re-init on page change
    @State private var showTemplateMenu: Bool = false

    // Notes editor top bar — dark surface, not from VitaColors
    private let topBarBg      = Color(red: 0.118, green: 0.118, blue: 0.180)  // 0xFF1E1E2E
    private let topBarText    = Color(red: 0.878, green: 0.878, blue: 0.910)  // 0xFFE0E0E8
    private let topBarSecondary = Color(red: 0.533, green: 0.533, blue: 0.627) // 0xFF888 8A0

    init(notebookId: UUID, store: NotebookStore, onBack: @escaping () -> Void) {
        self.notebookId = notebookId
        self.onBack = onBack
        _viewModel = State(initialValue: EditorViewModel(store: store))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Paper background
            PaperBackgroundView(template: viewModel.paperTemplate)
                .ignoresSafeArea()

            // 2. PencilKit canvas
            if !viewModel.isLoading {
                DrawingCanvasView(
                    currentBrush: viewModel.currentBrush,
                    currentColor: viewModel.currentColor,
                    currentSize: viewModel.currentSize,
                    paperTemplate: viewModel.paperTemplate,
                    undoTrigger: viewModel.undoTrigger,
                    redoTrigger: viewModel.redoTrigger,
                    onDrawingChanged: { drawing in
                        currentDrawing = drawing
                        viewModel.scheduleSave(drawing: drawing)
                    },
                    onUndoStateChanged: { canUndo, canRedo in
                        viewModel.canUndo = canUndo
                        viewModel.canRedo = canRedo
                    },
                    initialCanvasData: viewModel.loadCanvasData()
                )
                .id(canvasKey)   // re-create when page changes
                .ignoresSafeArea()
            }

            // 3. Top bar overlay (semi-transparent dark pill)
            VStack {
                topBar
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            // 4. Floating toolbar — bottom center
            EditorToolbar(
                currentBrush: viewModel.currentBrush,
                currentColor: viewModel.currentColor,
                currentSize: viewModel.currentSize,
                canUndo: viewModel.canUndo,
                canRedo: viewModel.canRedo,
                onBrushChange: viewModel.setBrush(_:),
                onColorChange: viewModel.setColor(_:),
                onSizeChange: viewModel.setSize(_:),
                onUndo: viewModel.undo,
                onRedo: viewModel.redo
            )
            .padding(.bottom, 32)
        }
        .navigationBarHidden(true)
        .statusBarHidden(false)
        .task {
            await viewModel.loadNotebook(notebookId: notebookId)
            // Load initial canvas data after pages are ready
            if let data = viewModel.loadCanvasData(),
               let drawing = try? PKDrawing(data: data) {
                currentDrawing = drawing
            }
        }
        .onChange(of: viewModel.currentPageIndex) { _, _ in
            // Force canvas re-init on page change so it loads correct PKDrawing
            canvasKey = UUID()
            if let data = viewModel.loadCanvasData(),
               let drawing = try? PKDrawing(data: data) {
                currentDrawing = drawing
            } else {
                currentDrawing = PKDrawing()
            }
        }
        .onDisappear {
            Task { await viewModel.forceSave(drawing: currentDrawing) }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 0) {
            // Back button
            Button {
                Task { await viewModel.forceSave(drawing: currentDrawing) }
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(topBarText)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Voltar")

            // Title + page indicator
            HStack(spacing: 6) {
                Text(viewModel.notebookTitle)
                    .font(VitaTypography.titleMedium)
                    .foregroundColor(topBarText)
                    .lineLimit(1)

                if !viewModel.pages.isEmpty {
                    Text("pg \(viewModel.currentPageIndex + 1)/\(viewModel.pages.count)")
                        .font(VitaTypography.labelSmall)
                        .foregroundColor(topBarSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)

            // Page navigation (prev / next / add)
            if viewModel.pages.count > 1 {
                HStack(spacing: 0) {
                    Button {
                        viewModel.goToPage(viewModel.currentPageIndex - 1)
                    } label: {
                        Image(systemName: "chevron.left.circle")
                            .font(.system(size: 18))
                            .foregroundColor(viewModel.currentPageIndex > 0 ? topBarText : topBarSecondary.opacity(0.3))
                    }
                    .frame(width: 36, height: 44)
                    .disabled(viewModel.currentPageIndex == 0)

                    Button {
                        viewModel.goToPage(viewModel.currentPageIndex + 1)
                    } label: {
                        Image(systemName: "chevron.right.circle")
                            .font(.system(size: 18))
                            .foregroundColor(viewModel.currentPageIndex < viewModel.pages.count - 1 ? topBarText : topBarSecondary.opacity(0.3))
                    }
                    .frame(width: 36, height: 44)
                    .disabled(viewModel.currentPageIndex >= viewModel.pages.count - 1)
                }
            }

            // Add page button
            Button {
                Task { await viewModel.addPage() }
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                    .foregroundColor(topBarSecondary)
                    .frame(width: 36, height: 44)
            }
            .accessibilityLabel("Adicionar página")

            // Template picker
            Menu {
                ForEach(PaperTemplate.allCases, id: \.self) { template in
                    Button {
                        viewModel.setPaperTemplate(template)
                        showTemplateMenu = false
                    } label: {
                        Label(
                            template.displayName,
                            systemImage: template.systemIcon
                        )
                        if template == viewModel.paperTemplate {
                            Text("(atual)")
                        }
                    }
                }
            } label: {
                Image(systemName: viewModel.paperTemplate.systemIcon)
                    .font(.system(size: 16))
                    .foregroundColor(topBarSecondary)
                    .frame(width: 36, height: 44)
            }
            .accessibilityLabel("Template de papel")
        }
        .padding(.horizontal, 8)
        .padding(.top, 0)
        .background(topBarBg.opacity(0.88))
    }
}
