import SwiftUI
import PDFKit
import PencilKit

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
        if bookmarkedPages.contains(currentPage) {
            bookmarkedPages.remove(currentPage)
        } else {
            bookmarkedPages.insert(currentPage)
        }
        saveBookmarks()
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

    func load(url: URL, tokenStore: TokenStore? = nil) async {
        fileName = url.deletingPathExtension().lastPathComponent
        fileHash = computeHash(url.absoluteString)

        if let tokenStore, url.absoluteString.contains("/api/documents/") {
            do {
                let token = await tokenStore.token
                var request = URLRequest(url: url)
                if let token {
                    request.setValue(token, forHTTPHeaderField: "X-Extension-Token")
                }
                let (data, response) = try await URLSession.shared.data(for: request)
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 {
                    document = PDFDocument(data: data)
                }
            } catch {
                print("[PdfViewer] Auth fetch failed: \(error.localizedDescription)")
            }
        } else {
            document = PDFDocument(url: url)
        }

        pageCount = document?.pageCount ?? 0
        loadBookmarks()
        isLoading = false
    }

    // MARK: - Annotation mode

    func toggleAnnotating() { isAnnotating.toggle() }
    func toggleThumbnails() { showThumbnails.toggle() }

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
