import Foundation
import PencilKit
import SwiftUI
import Combine

// MARK: - EditorViewModel
// Mirrors EditorViewModel.kt (Android).
// Uses PencilKit PKDrawing for native Apple Pencil support instead of
// manual stroke serialisation. Undo/redo is delegated to PKCanvasView's
// UndoManager (UIKit), so EditorViewModel only tracks metadata state.

@Observable
@MainActor
final class EditorViewModel {

    // MARK: State — notebook metadata
    var notebookId: UUID?
    var notebookTitle: String = ""
    var pages: [NotebookPage] = []
    var currentPageIndex: Int = 0
    var isLoading: Bool = true

    // MARK: State — drawing tools
    var currentBrush: BrushType = .pen
    var currentColor: UInt64 = 0xFF1A1A2E   // near-black ink
    var currentSize: Float = 4.0
    var paperTemplate: PaperTemplate = .ruled

    // MARK: PKDrawing managed by DrawingCanvasView (PKCanvasView delegate)
    // canUndo / canRedo are updated by the UndoManager observation in DrawingCanvasView
    var canUndo: Bool = false
    var canRedo: Bool = false

    // Signal to PKCanvasView to trigger undo / redo
    var undoTrigger: Int = 0
    var redoTrigger: Int = 0

    // MARK: Auto-save debounce
    private var saveTask: Task<Void, Never>?

    // MARK: Dependencies
    private let store: NotebookStore

    // MARK: Init
    init(store: NotebookStore) {
        self.store = store
    }

    // MARK: - Load

    func loadNotebook(notebookId: UUID) async {
        self.notebookId = notebookId
        isLoading = true

        await store.loadNotebooks()
        if let nb = store.notebooks.first(where: { $0.id == notebookId }) {
            notebookTitle = nb.title
        }

        pages = await store.loadPages(for: notebookId)
        currentPageIndex = 0
        isLoading = false
    }

    // MARK: - Page navigation

    var currentPage: NotebookPage? {
        pages.indices.contains(currentPageIndex) ? pages[currentPageIndex] : nil
    }

    func goToPage(_ index: Int) {
        guard pages.indices.contains(index) else { return }
        currentPageIndex = index
    }

    func addPage() async {
        guard let nbId = notebookId else { return }
        let newPage = await store.addPage(to: nbId, template: paperTemplate)
        pages = await store.loadPages(for: nbId)
        if let idx = pages.firstIndex(where: { $0.id == newPage.id }) {
            currentPageIndex = idx
        }
    }

    // MARK: - Drawing tool controls

    func setBrush(_ brush: BrushType) {
        currentBrush = brush
    }

    func setColor(_ color: UInt64) {
        currentColor = color
    }

    func setSize(_ size: Float) {
        currentSize = size
    }

    func setPaperTemplate(_ template: PaperTemplate) {
        paperTemplate = template
    }

    // MARK: - Undo / Redo (signals to PKCanvasView's UndoManager)

    func undo() {
        undoTrigger += 1
    }

    func redo() {
        redoTrigger += 1
    }

    // MARK: - Save (debounced 2 seconds, mirrors scheduleSave in Android)

    func scheduleSave(drawing: PKDrawing) {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s debounce
            guard !Task.isCancelled else { return }
            await persist(drawing: drawing)
        }
    }

    func forceSave(drawing: PKDrawing) async {
        saveTask?.cancel()
        await persist(drawing: drawing)
    }

    // MARK: - Private

    private func persist(drawing: PKDrawing) async {
        guard let nbId = notebookId, let page = currentPage else { return }
        let data = drawing.dataRepresentation()
        await store.saveCanvasData(data, notebookId: nbId, pageId: page.id)
    }

    // MARK: - Load canvas data for current page

    func loadCanvasData() -> Data? {
        guard let nbId = notebookId, let page = currentPage else { return nil }
        return store.loadCanvasData(notebookId: nbId, pageId: page.id)
    }
}
