import SwiftUI
import PDFKit
import Foundation

@MainActor
@Observable
final class PdfViewerViewModel {

    // MARK: - Document state
    var document: PDFDocument?
    var pageCount: Int = 0
    var currentPage: Int = 0
    var fileName: String = ""
    var isLoading: Bool = true
    var isSaving: Bool = false

    // MARK: - Annotation mode
    var isDrawMode: Bool = false
    var selectedTool: AnnotationTool = .pen
    var selectedColor: Color = VitaColors.accent
    var strokeWidth: CGFloat = 4

    // MARK: - Current page annotations (hot cache for UI)
    var currentStrokes: [InkStroke] = []
    var currentEraserPaths: [EraserPath] = []
    var textAnnotations: [TextAnnotation] = []
    var shapeAnnotations: [ShapeAnnotation] = []

    // MARK: - UI state
    var showThumbnails: Bool = false
    var canUndo: Bool = false
    var canRedo: Bool = false

    // MARK: - Per-page storage
    private var pageStrokes: [Int: [InkStroke]] = [:]
    private var pageEraserPaths: [Int: [EraserPath]] = [:]
    private var pageTextAnnotations: [Int: [TextAnnotation]] = [:]
    private var pageShapeAnnotations: [Int: [ShapeAnnotation]] = [:]
    private var undoStacks: [Int: [PageSnapshot]] = [:]
    private var redoStacks: [Int: [PageSnapshot]] = [:]

    private var fileHash: String = ""
    private var saveTask: Task<Void, Never>?

    // MARK: - Load

    func load(url: URL) async {
        fileName = url.deletingPathExtension().lastPathComponent
        fileHash = computeHash(url.absoluteString)
        document = PDFDocument(url: url)
        pageCount = document?.pageCount ?? 0
        isLoading = false
        await loadAnnotations(for: 0)
    }

    // MARK: - Page Navigation

    func setCurrentPage(_ page: Int) {
        guard page != currentPage else { return }
        scheduleSave(page: currentPage)
        currentPage = page
        Task { await loadAnnotations(for: page) }
    }

    // MARK: - Draw Mode

    func toggleDrawMode() { isDrawMode.toggle() }

    func selectTool(_ tool: AnnotationTool) {
        selectedTool = tool
        isDrawMode = true
    }

    func setColor(_ color: Color) { selectedColor = color }
    func setStrokeWidth(_ width: CGFloat) { strokeWidth = width }

    // MARK: - Ink Strokes

    func addStrokes(_ strokes: [InkStroke]) {
        let page = currentPage
        var list = pageStrokes[page, default: []]
        let eraserList = pageEraserPaths[page, default: []]
        pushUndoSnapshot(page: page, strokes: list, erasers: eraserList)
        list.append(contentsOf: strokes)
        pageStrokes[page] = list
        currentStrokes = list
        canUndo = true; canRedo = false
        scheduleSave(page: page)
    }

    func addEraserPath(_ path: EraserPath) {
        let page = currentPage
        let strokeList = pageStrokes[page, default: []]
        var eraserList = pageEraserPaths[page, default: []]
        pushUndoSnapshot(page: page, strokes: strokeList, erasers: eraserList)
        eraserList.append(path)
        pageEraserPaths[page] = eraserList
        currentEraserPaths = eraserList
        canUndo = true; canRedo = false
        scheduleSave(page: page)
    }

    // MARK: - Undo/Redo

    func undo() {
        let page = currentPage
        guard var stack = undoStacks[page], !stack.isEmpty else { return }
        let current = PageSnapshot(
            strokes: pageStrokes[page, default: []],
            eraserPaths: pageEraserPaths[page, default: []]
        )
        var redo = redoStacks[page, default: []]
        redo.append(current)
        redoStacks[page] = redo
        let prev = stack.removeLast()
        undoStacks[page] = stack
        pageStrokes[page] = prev.strokes
        pageEraserPaths[page] = prev.eraserPaths
        currentStrokes = prev.strokes
        currentEraserPaths = prev.eraserPaths
        canUndo = !stack.isEmpty; canRedo = true
        scheduleSave(page: page)
    }

    func redo() {
        let page = currentPage
        guard var stack = redoStacks[page], !stack.isEmpty else { return }
        let current = PageSnapshot(
            strokes: pageStrokes[page, default: []],
            eraserPaths: pageEraserPaths[page, default: []]
        )
        var undo = undoStacks[page, default: []]
        undo.append(current)
        undoStacks[page] = undo
        let next = stack.removeLast()
        redoStacks[page] = stack
        pageStrokes[page] = next.strokes
        pageEraserPaths[page] = next.eraserPaths
        currentStrokes = next.strokes
        currentEraserPaths = next.eraserPaths
        canUndo = true; canRedo = !stack.isEmpty
        scheduleSave(page: page)
    }

    // MARK: - Text Annotations

    func addTextAnnotation(_ ann: TextAnnotation) {
        let page = currentPage
        var list = pageTextAnnotations[page, default: []]
        list.append(ann)
        pageTextAnnotations[page] = list
        textAnnotations = list
        scheduleSave(page: page)
    }

    func updateTextAnnotation(_ ann: TextAnnotation) {
        let page = currentPage
        var list = pageTextAnnotations[page, default: []]
        if let idx = list.firstIndex(where: { $0.id == ann.id }) {
            list[idx] = ann
            pageTextAnnotations[page] = list
            textAnnotations = list
            scheduleSave(page: page)
        }
    }

    func removeTextAnnotation(id: UUID) {
        let page = currentPage
        var list = pageTextAnnotations[page, default: []]
        list.removeAll { $0.id == id }
        pageTextAnnotations[page] = list
        textAnnotations = list
        scheduleSave(page: page)
    }

    // MARK: - Shape Annotations

    func addShapeAnnotation(_ ann: ShapeAnnotation) {
        let page = currentPage
        var list = pageShapeAnnotations[page, default: []]
        list.append(ann)
        pageShapeAnnotations[page] = list
        shapeAnnotations = list
        scheduleSave(page: page)
    }

    func removeShapeAnnotation(id: UUID) {
        let page = currentPage
        var list = pageShapeAnnotations[page, default: []]
        list.removeAll { $0.id == id }
        pageShapeAnnotations[page] = list
        shapeAnnotations = list
        scheduleSave(page: page)
    }

    // MARK: - Thumbnails

    func toggleThumbnails() { showThumbnails.toggle() }

    // MARK: - Accessors for all pages (export)

    func strokes(for page: Int) -> [InkStroke]       { pageStrokes[page, default: []] }
    func erasers(for page: Int) -> [EraserPath]       { pageEraserPaths[page, default: []] }
    func texts(for page: Int) -> [TextAnnotation]     { pageTextAnnotations[page, default: []] }
    func shapes(for page: Int) -> [ShapeAnnotation]   { pageShapeAnnotations[page, default: []] }

    // MARK: - Force Save (on dismiss)

    func forceSave() {
        saveTask?.cancel()
        let page = currentPage
        Task { await performSave(page: page) }
    }

    // MARK: - Private Helpers

    private func pushUndoSnapshot(page: Int, strokes: [InkStroke], erasers: [EraserPath]) {
        var stack = undoStacks[page, default: []]
        stack.append(PageSnapshot(strokes: strokes, eraserPaths: erasers))
        undoStacks[page] = stack
        redoStacks[page] = []
    }

    private func scheduleSave(page: Int) {
        saveTask?.cancel()
        isSaving = true
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await performSave(page: page)
            isSaving = false
        }
    }

    private func loadAnnotations(for page: Int) async {
        guard !fileHash.isEmpty else { return }
        let key = annotationKey(page: page)
        guard let data = UserDefaults.standard.data(forKey: key),
              let ann = try? JSONDecoder().decode(PageAnnotations.self, from: data)
        else { return }

        pageStrokes[page] = ann.strokes
        pageEraserPaths[page] = ann.eraserPaths
        pageTextAnnotations[page] = ann.textAnnotations
        pageShapeAnnotations[page] = ann.shapeAnnotations

        if page == currentPage {
            currentStrokes = ann.strokes
            currentEraserPaths = ann.eraserPaths
            textAnnotations = ann.textAnnotations
            shapeAnnotations = ann.shapeAnnotations
            canUndo = false; canRedo = false
        }
    }

    private func performSave(page: Int) async {
        guard !fileHash.isEmpty else { return }
        let ann = PageAnnotations(
            strokes: pageStrokes[page, default: []],
            eraserPaths: pageEraserPaths[page, default: []],
            textAnnotations: pageTextAnnotations[page, default: []],
            shapeAnnotations: pageShapeAnnotations[page, default: []]
        )
        guard let data = try? JSONEncoder().encode(ann) else { return }
        UserDefaults.standard.set(data, forKey: annotationKey(page: page))
    }

    private func annotationKey(page: Int) -> String { "vita_pdf_ann_\(fileHash)_p\(page)" }

    private func computeHash(_ input: String) -> String {
        var hash: UInt64 = 5381
        for scalar in input.unicodeScalars {
            hash = (hash &<< 5) &+ hash &+ UInt64(scalar.value)
        }
        return String(hash, radix: 16)
    }
}
