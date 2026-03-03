import Foundation
import SwiftUI

// MARK: - MindMapListViewModel
// Mirrors MindMapListViewModel.kt (Android).
// @Observable replaces Kotlin StateFlow + MutableStateFlow.

@Observable
@MainActor
final class MindMapListViewModel {

    // MARK: State
    var mindMaps: [MindMap] = []
    var isLoading: Bool = false
    var showCreateDialog: Bool = false

    // MARK: Dependencies
    private let store: MindMapStore

    // MARK: Init
    init(store: MindMapStore) {
        self.store = store
    }

    // MARK: - Lifecycle

    func onAppear() async {
        isLoading = true
        await store.loadMindMaps()
        mindMaps = store.mindMaps
        isLoading = false
    }

    func refresh() async {
        isLoading = true
        await store.loadMindMaps()
        mindMaps = store.mindMaps
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

    func createMindMap(title: String) async -> String? {
        let newId = UUID().uuidString
        let centerNode = MindMapNode(
            id: UUID().uuidString,
            text: "Tema Central",
            x: 0,
            y: 0,
            parentId: nil,
            color: mindMapNodeColors[0]
        )
        await store.saveMindMap(id: newId, title: title, nodes: [centerNode])
        mindMaps = store.mindMaps
        showCreateDialog = false
        return newId
    }

    func deleteMindMap(id: String) async {
        await store.deleteMindMap(id: id)
        mindMaps = store.mindMaps
    }
}
