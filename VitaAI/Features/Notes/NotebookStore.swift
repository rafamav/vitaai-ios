import Foundation
import Combine

// MARK: - NotebookStore
// Local persistence using FileManager. Mirrors NotebookRepository on Android.
// Notebooks: Documents/notebooks/notebooks.json
// Pages:     Documents/notebooks/<notebookId>/pages.json
// Strokes:   Documents/notebooks/<notebookId>/<pageId>/strokes.json
// PKCanvas:  Documents/notebooks/<notebookId>/<pageId>/canvas.pkdata

@Observable
final class NotebookStore {

    // MARK: Published state
    private(set) var notebooks: [Notebook] = []
    private(set) var isLoading: Bool = false

    // MARK: Private
    private let rootURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    // MARK: Init
    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        rootURL = docs.appendingPathComponent("notebooks", isDirectory: true)
        try? FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    // MARK: - Notebook CRUD

    func loadNotebooks() async {
        isLoading = true
        let url = rootURL.appendingPathComponent("notebooks.json")
        guard
            let data = try? Data(contentsOf: url),
            let loaded = try? decoder.decode([Notebook].self, from: data)
        else {
            isLoading = false
            notebooks = []
            return
        }
        notebooks = loaded.sorted { $0.updatedAt > $1.updatedAt }
        isLoading = false
    }

    @discardableResult
    func createNotebook(title: String, coverColor: UInt64) async -> Notebook {
        var nb = Notebook(title: title, coverColor: coverColor)
        notebooks.insert(nb, at: 0)
        await persistNotebooks()

        // Create first page
        let firstPage = NotebookPage(notebookId: nb.id, pageIndex: 0)
        await savePages([firstPage], for: nb.id)

        // Update pageCount
        nb.pageCount = 1
        if let idx = notebooks.firstIndex(where: { $0.id == nb.id }) {
            notebooks[idx] = nb
        }
        await persistNotebooks()
        return nb
    }

    func deleteNotebook(id: UUID) async {
        notebooks.removeAll { $0.id == id }
        await persistNotebooks()
        // Remove all files for this notebook
        let dir = notebookDirectory(id)
        try? FileManager.default.removeItem(at: dir)
    }

    func touchNotebook(id: UUID) async {
        guard let idx = notebooks.firstIndex(where: { $0.id == id }) else { return }
        notebooks[idx].updatedAt = Date()
        await persistNotebooks()
    }

    // MARK: - Page operations

    func loadPages(for notebookId: UUID) async -> [NotebookPage] {
        let url = notebookDirectory(notebookId).appendingPathComponent("pages.json")
        guard
            let data = try? Data(contentsOf: url),
            let pages = try? decoder.decode([NotebookPage].self, from: data)
        else {
            // If no pages exist yet, create one
            let firstPage = NotebookPage(notebookId: notebookId, pageIndex: 0)
            await savePages([firstPage], for: notebookId)
            return [firstPage]
        }
        return pages.sorted { $0.pageIndex < $1.pageIndex }
    }

    func savePages(_ pages: [NotebookPage], for notebookId: UUID) async {
        let dir = notebookDirectory(notebookId)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("pages.json")
        guard let data = try? encoder.encode(pages) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func addPage(to notebookId: UUID, template: PaperTemplate = .ruled) async -> NotebookPage {
        var pages = await loadPages(for: notebookId)
        let newPage = NotebookPage(
            notebookId: notebookId,
            pageIndex: pages.count,
            template: template
        )
        pages.append(newPage)
        await savePages(pages, for: notebookId)

        // Update pageCount on notebook
        if let idx = notebooks.firstIndex(where: { $0.id == notebookId }) {
            notebooks[idx].pageCount = pages.count
            notebooks[idx].updatedAt = Date()
        }
        await persistNotebooks()
        return newPage
    }

    // MARK: - PencilKit canvas data (primary storage)

    func saveCanvasData(_ data: Data, notebookId: UUID, pageId: UUID) async {
        let dir = pageDirectory(notebookId: notebookId, pageId: pageId)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("canvas.pkdata")
        try? data.write(to: url, options: .atomic)
        await touchNotebook(id: notebookId)
    }

    func loadCanvasData(notebookId: UUID, pageId: UUID) -> Data? {
        let url = pageDirectory(notebookId: notebookId, pageId: pageId)
            .appendingPathComponent("canvas.pkdata")
        return try? Data(contentsOf: url)
    }

    // MARK: - Directory helpers

    private func notebookDirectory(_ notebookId: UUID) -> URL {
        rootURL.appendingPathComponent(notebookId.uuidString, isDirectory: true)
    }

    private func pageDirectory(notebookId: UUID, pageId: UUID) -> URL {
        notebookDirectory(notebookId)
            .appendingPathComponent(pageId.uuidString, isDirectory: true)
    }

    // MARK: - Persist notebooks list

    private func persistNotebooks() async {
        let url = rootURL.appendingPathComponent("notebooks.json")
        guard let data = try? encoder.encode(notebooks) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
