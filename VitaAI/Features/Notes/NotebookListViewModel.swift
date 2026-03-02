import Foundation
import SwiftUI

// MARK: - NotebookListViewModel
// Mirrors NotebookListViewModel.kt (Android).
// @Observable replaces Kotlin StateFlow + MutableStateFlow.

@Observable
@MainActor
final class NotebookListViewModel {

    // MARK: State
    var notebooks: [Notebook] = []
    var isLoading: Bool = false
    var showCreateDialog: Bool = false

    // MARK: Dependencies
    private let store: NotebookStore

    // MARK: Init
    init(store: NotebookStore) {
        self.store = store
    }

    // MARK: - Lifecycle

    func onAppear() async {
        isLoading = true
        await store.loadNotebooks()
        notebooks = store.notebooks
        isLoading = false
    }

    func refresh() async {
        isLoading = true
        await store.loadNotebooks()
        notebooks = store.notebooks
        isLoading = false
    }

    // MARK: - Dialog control

    func showCreate() {
        showCreateDialog = true
    }

    func hideCreate() {
        showCreateDialog = false
    }

    // MARK: - CRUD

    func createNotebook(title: String, coverColor: UInt64) async {
        await store.createNotebook(title: title, coverColor: coverColor)
        notebooks = store.notebooks
        showCreateDialog = false
    }

    func deleteNotebook(id: UUID) async {
        await store.deleteNotebook(id: id)
        notebooks = store.notebooks
    }
}
