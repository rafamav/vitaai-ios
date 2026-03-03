import Foundation
import SwiftUI

// MARK: - MindMapEditorViewModel
// Editor state management for MindMap canvas.
// Handles nodes CRUD, selection, canvas transform (pan/zoom).

@Observable
@MainActor
final class MindMapEditorViewModel {

    // MARK: State
    var mindMapId: String
    var title: String = ""
    var nodes: [MindMapNode] = []
    var selectedNodeId: String?
    var isLoading: Bool = false

    // Canvas transform
    var scale: Float = 1.0
    var offsetX: Float = 0
    var offsetY: Float = 0

    // Dialogs
    var showEditTextDialog: Bool = false
    var showColorPickerDialog: Bool = false
    var editingText: String = ""

    // MARK: Dependencies
    private let store: MindMapStore

    // Auto-save debounce
    private var autoSaveTask: Task<Void, Never>?

    // MARK: Init
    init(mindMapId: String, store: MindMapStore) {
        self.mindMapId = mindMapId
        self.store = store
    }

    // MARK: - Lifecycle

    func onAppear() async {
        isLoading = true
        if let loaded = await store.loadNodes(id: mindMapId) {
            title = loaded.title
            nodes = loaded.nodes
        }
        isLoading = false
    }

    func onDisappear() async {
        // Final save on exit
        await save()
        autoSaveTask?.cancel()
    }

    // MARK: - Save

    func save() async {
        await store.saveMindMap(id: mindMapId, title: title, nodes: nodes)
    }

    func scheduleSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(for: .seconds(2))
            await save()
        }
    }

    // MARK: - Selection

    func selectNode(id: String?) {
        selectedNodeId = id
    }

    func deselectAll() {
        selectedNodeId = nil
    }

    // MARK: - Node CRUD

    func addNode() {
        guard let parentId = selectedNodeId,
              let parent = nodes.first(where: { $0.id == parentId }) else {
            return
        }

        let newNode = MindMapNode(
            id: UUID().uuidString,
            text: "Novo tópico",
            x: parent.x + 200,
            y: parent.y + 100,
            parentId: parentId,
            color: parent.color
        )
        nodes.append(newNode)
        selectedNodeId = newNode.id
        scheduleSave()
    }

    func deleteSelectedNode() {
        guard let nodeId = selectedNodeId else { return }

        // Recursively collect node + all descendants
        var toDelete: Set<String> = [nodeId]
        var queue = [nodeId]

        while !queue.isEmpty {
            let current = queue.removeFirst()
            let children = nodes.filter { $0.parentId == current }
            for child in children {
                toDelete.insert(child.id)
                queue.append(child.id)
            }
        }

        nodes.removeAll { toDelete.contains($0.id) }
        selectedNodeId = nil
        scheduleSave()
    }

    func moveNode(id: String, x: Float, y: Float) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[index].x = x
        nodes[index].y = y
        scheduleSave()
    }

    // MARK: - Edit Text Dialog

    func showEditText() {
        guard let nodeId = selectedNodeId,
              let node = nodes.first(where: { $0.id == nodeId }) else {
            return
        }
        editingText = node.text
        showEditTextDialog = true
    }

    func saveEditedText() {
        guard let nodeId = selectedNodeId,
              let index = nodes.firstIndex(where: { $0.id == nodeId }) else {
            return
        }
        nodes[index].text = editingText
        showEditTextDialog = false
        scheduleSave()
    }

    func cancelEditText() {
        showEditTextDialog = false
        editingText = ""
    }

    // MARK: - Color Picker Dialog

    func showColorPicker() {
        showColorPickerDialog = true
    }

    func selectColor(_ color: UInt64) {
        guard let nodeId = selectedNodeId,
              let index = nodes.firstIndex(where: { $0.id == nodeId }) else {
            return
        }
        nodes[index].color = color
        showColorPickerDialog = false
        scheduleSave()
    }

    func cancelColorPicker() {
        showColorPickerDialog = false
    }

    // MARK: - Canvas Transform

    func updateTransform(scale: Float, offsetX: Float, offsetY: Float) {
        self.scale = scale
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}
