import SwiftUI
import PDFKit
import PencilKit
import Vision
import OSLog

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

    // MARK: - UI state
    var showThumbnails: Bool = false
    var isAnnotating: Bool = false
    var isHighlightMode: Bool = false
    var isTextMode: Bool = false
    var isLassoMode: Bool = false

    // MARK: - Handwriting recognition state
    var recognizedText: String? = nil
    var isRecognizing: Bool = false
    var showRecognitionResult: Bool = false
    /// Set by Coordinator so the screen can pull the current page's drawing on demand.
    var currentDrawingProvider: (() -> PKDrawing?)? = nil

    // MARK: - Search state
    var isSearching: Bool = false
    var searchText: String = ""
    var searchResults: [PDFSelection] = []
    var currentSearchIndex: Int = 0

    private(set) var fileHash: String = ""

    // MARK: - Bookmarks
    var bookmarkedPages: Set<Int> = []

    var isCurrentPageBookmarked: Bool {
        bookmarkedPages.contains(currentPage)
    }

    func toggleBookmark() {
        toggleBookmark(forPage: currentPage)
    }

    /// Toggle bookmark for any page index (used by thumbnail sidebar context menu).
    func toggleBookmark(forPage index: Int) {
        if bookmarkedPages.contains(index) {
            bookmarkedPages.remove(index)
        } else {
            bookmarkedPages.insert(index)
        }
        saveBookmarks()
    }

    /// Rotate a specific page by +90 / -90 / 180 degrees. Changes persist in
    /// the in-memory PDFDocument; saveHighlights() writes them back to disk.
    func rotatePage(at index: Int, byDegrees delta: Int) {
        guard let document, let page = document.page(at: index) else { return }
        // PDFPage.rotation is normalized to 0/90/180/270
        let newRotation = ((page.rotation + delta) % 360 + 360) % 360
        page.rotation = newRotation
        isSaving = true
        saveHighlights()
    }

    func loadBookmarks() {
        let url = bookmarksFileURL()
        guard let data = try? Data(contentsOf: url),
              let pages = try? JSONDecoder().decode([Int].self, from: data) else { return }
        bookmarkedPages = Set(pages)
    }

    func saveBookmarks() {
        let url = bookmarksFileURL()
        let sorted = Array(bookmarkedPages).sorted()
        guard let data = try? JSONEncoder().encode(sorted) else { return }
        try? data.write(to: url)
    }

    private func bookmarksFileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pdf_annotations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(fileHash)_bookmarks.json")
    }

    // MARK: - Load

    private static let logger = Logger(subsystem: "com.bymav.vitaai", category: "pdf")

    func load(url: URL, tokenStore: TokenStore? = nil) async {
        fileName = url.deletingPathExtension().lastPathComponent
        fileHash = computeHash(url.absoluteString)

        let logger = Self.logger
        logger.notice("[PDF.load] url=\(url.absoluteString, privacy: .public) hasToken=\(tokenStore != nil)")
        SentryConfig.addBreadcrumb(
            message: "pdf load start",
            category: "pdf",
            data: ["url": url.absoluteString, "hasTokenStore": tokenStore != nil]
        )

        if let tokenStore, url.absoluteString.contains("/api/documents/") {
            do {
                let token = await tokenStore.token
                var request = URLRequest(url: url)
                if let token {
                    request.setValue(token, forHTTPHeaderField: "X-Extension-Token")
                }
                logger.notice("[PDF.load] fetching with auth, tokenPresent=\(token != nil)")
                let (data, response) = try await URLSession.shared.data(for: request)
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type") ?? "?"
                logger.notice("[PDF.load] response status=\(status) contentType=\(contentType, privacy: .public) bytes=\(data.count)")

                if status == 200 {
                    // Validate PDF signature — backend can return 200 with HTML login page.
                    let isPDF = data.count >= 4 && data[0] == 0x25 && data[1] == 0x50 && data[2] == 0x44 && data[3] == 0x46
                    if isPDF {
                        document = PDFDocument(data: data)
                    } else {
                        let preview = String(data: data.prefix(200), encoding: .utf8) ?? "<binary>"
                        logger.error("[PDF.load] 200 but not a PDF. preview=\(preview, privacy: .public)")
                        SentryConfig.capture(message: "PDF endpoint returned 200 with non-PDF body (first bytes=\(Array(data.prefix(4))))")
                    }
                } else {
                    let body = String(data: data.prefix(500), encoding: .utf8) ?? "<binary>"
                    logger.error("[PDF.load] non-200 status=\(status) body=\(body, privacy: .public)")
                    SentryConfig.capture(message: "PDF fetch failed status=\(status) url=\(url.absoluteString)")
                }
            } catch {
                logger.error("[PDF.load] URLSession threw: \(error.localizedDescription, privacy: .public)")
                SentryConfig.capture(error: error, context: ["url": url.absoluteString, "stage": "pdf-fetch"])
            }
        } else {
            logger.notice("[PDF.load] no-auth path (PDFDocument(url:)) — \(tokenStore == nil ? "tokenStore nil" : "url not /api/documents/", privacy: .public)")
            document = PDFDocument(url: url)
            if document == nil {
                SentryConfig.capture(message: "PDFDocument(url:) returned nil (no-auth path) url=\(url.absoluteString)")
            }
        }

        pageCount = document?.pageCount ?? 0
        logger.notice("[PDF.load] done. document=\(self.document != nil) pages=\(self.pageCount)")
        loadBookmarks()
        loadHighlights()
        isLoading = false
    }

    // MARK: - Annotation mode

    func toggleAnnotating() {
        isAnnotating.toggle()
        if isAnnotating {
            isHighlightMode = false
            isTextMode = false
        } else {
            isLassoMode = false
        }
    }

    func toggleLassoMode() {
        guard isAnnotating else { return }
        isLassoMode.toggle()
    }

    func toggleHighlightMode() {
        isHighlightMode.toggle()
        if isHighlightMode {
            isAnnotating = false
            isTextMode = false
        }
    }

    func toggleTextMode() {
        isTextMode.toggle()
        if isTextMode {
            isAnnotating = false
            isHighlightMode = false
        }
    }

    func toggleThumbnails() { showThumbnails.toggle() }

    // MARK: - Highlight persistence (full document write, keyed by hash)

    func highlightFileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pdf_annotations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(fileHash)_highlights.pdf")
    }

    func saveHighlights() {
        guard let document else { return }
        isSaving = true
        let url = highlightFileURL()
        document.write(to: url)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            self.isSaving = false
        }
    }

    func loadHighlights() {
        let url = highlightFileURL()
        guard FileManager.default.fileExists(atPath: url.path),
              let saved = PDFDocument(url: url),
              let current = document else { return }
        // Copy highlight annotations from saved doc into current doc
        for i in 0..<min(saved.pageCount, current.pageCount) {
            guard let savedPage = saved.page(at: i),
                  let currentPage = current.page(at: i) else { continue }
            for annotation in savedPage.annotations {
                guard annotation.type == "Highlight" else { continue }
                let copy = PDFAnnotation(bounds: annotation.bounds, forType: .highlight, withProperties: nil)
                copy.color = annotation.color
                currentPage.addAnnotation(copy)
            }
        }
    }

    // MARK: - Search

    func toggleSearch() {
        isSearching.toggle()
        if !isSearching { clearSearch() }
    }

    func clearSearch() {
        searchText = ""
        searchResults = []
        currentSearchIndex = 0
    }

    func performSearch(_ text: String, pdfView: PDFView?) {
        guard !text.isEmpty, let document else {
            searchResults = []
            currentSearchIndex = 0
            pdfView?.highlightedSelections = nil
            pdfView?.currentSelection = nil
            return
        }
        searchResults = document.findString(text, withOptions: [.caseInsensitive, .diacriticInsensitive])
        currentSearchIndex = 0
        highlightCurrentResult(in: pdfView)
    }

    func nextResult(pdfView: PDFView?) {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex + 1) % searchResults.count
        highlightCurrentResult(in: pdfView)
    }

    func previousResult(pdfView: PDFView?) {
        guard !searchResults.isEmpty else { return }
        currentSearchIndex = (currentSearchIndex - 1 + searchResults.count) % searchResults.count
        highlightCurrentResult(in: pdfView)
    }

    func highlightCurrentResult(in pdfView: PDFView?) {
        guard let pdfView else { return }
        pdfView.highlightedSelections = searchResults
        guard !searchResults.isEmpty else { return }
        let selection = searchResults[currentSearchIndex]
        pdfView.currentSelection = selection
        pdfView.go(to: selection)
        // Update current page indicator
        if let page = selection.pages.first, let doc = pdfView.document {
            let pageIndex = doc.index(for: page)
            currentPage = pageIndex
        }
    }

    func clearSearchHighlights(in pdfView: PDFView?) {
        pdfView?.highlightedSelections = nil
        pdfView?.currentSelection = nil
    }

    // MARK: - Annotation persistence (file-based, keyed by hash + page)

    func loadDrawing(pageIndex: Int) -> PKDrawing? {
        let url = annotationFileURL(page: pageIndex)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PKDrawing(data: data)
    }

    func saveDrawing(_ drawing: PKDrawing, pageIndex: Int) {
        isSaving = true
        let url = annotationFileURL(page: pageIndex)
        try? drawing.dataRepresentation().write(to: url)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            self.isSaving = false
        }
    }

    func saveAllAnnotations() {
        // Coordinator calls saveDrawing per page as they scroll off-screen.
        // Nothing extra needed here — file writes are synchronous in coordinator.
    }

    /// Apaga TODAS as anotações deste PDF (drawings + highlights + bookmarks)
    /// para o `fileHash` atual. Chamado pelo PdfSettingsSheet > Limpar
    /// anotações. Irreversível.
    func resetAllAnnotations() {
        let fm = FileManager.default
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pdf_annotations", isDirectory: true)
        guard let entries = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for url in entries where url.lastPathComponent.hasPrefix(fileHash) {
            try? fm.removeItem(at: url)
        }
        bookmarkedPages.removeAll()
        // Drop in-memory highlight annotations to mirror disk wipe.
        if let document {
            for i in 0..<document.pageCount {
                guard let page = document.page(at: i) else { continue }
                for annotation in page.annotations where annotation.type == "Highlight" {
                    page.removeAnnotation(annotation)
                }
            }
        }
    }

    // MARK: - Handwriting recognition

    func recognizeHandwriting(drawing: PKDrawing) async {
        guard !drawing.strokes.isEmpty else { return }
        isRecognizing = true

        let bounds = drawing.bounds
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(bounds)
            drawing.image(from: bounds, scale: 2.0).draw(in: bounds)
        }

        guard let cgImage = image.cgImage else {
            isRecognizing = false
            return
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["pt-BR", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try await Task.detached(priority: .userInitiated) {
                try handler.perform([request])
            }.value

            let observations = request.results ?? []
            let text = observations.compactMap { obs in
                obs.topCandidates(1).first?.string
            }.joined(separator: "\n")

            recognizedText = text.isEmpty ? nil : text
            showRecognitionResult = !text.isEmpty
        } catch {
            recognizedText = nil
        }

        isRecognizing = false
    }

    // MARK: - Private helpers

    func annotationFileURL(page: Int) -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("pdf_annotations", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(fileHash)_p\(page).pkdrawing")
    }

    private func computeHash(_ input: String) -> String {
        var hash: UInt64 = 5381
        for scalar in input.unicodeScalars {
            hash = (hash &<< 5) &+ hash &+ UInt64(scalar.value)
        }
        return String(hash, radix: 16)
    }
}
