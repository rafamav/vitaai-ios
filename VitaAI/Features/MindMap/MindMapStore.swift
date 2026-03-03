import Foundation
import SwiftUI

// MARK: - MindMapStore
// Shared state for MindMap List and Editor.
// @Observable for SwiftUI automatic updates.
// @MainActor since SwiftData ModelContext requires main thread.

@Observable
@MainActor
final class MindMapStore {
    private let repository: MindMapRepository
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private(set) var mindMaps: [MindMap] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?

    init(repository: MindMapRepository) {
        self.repository = repository
    }

    // MARK: - Load All Mind Maps

    func loadMindMaps() async {
        isLoading = true
        error = nil

        do {
            let entities = try repository.fetchAll()
            mindMaps = entities.compactMap { entity in
                guard let data = entity.nodesJson.data(using: .utf8),
                      let decoded = try? decoder.decode(MindMapData.self, from: data) else {
                    return nil
                }

                return MindMap(
                    id: entity.id,
                    title: entity.title,
                    nodes: decoded.nodes,
                    courseId: entity.courseId,
                    courseName: entity.courseName,
                    coverColor: UInt64(bitPattern: entity.coverColor),
                    createdAt: Date(timeIntervalSince1970: Double(entity.createdAt) / 1000),
                    updatedAt: Date(timeIntervalSince1970: Double(entity.updatedAt) / 1000)
                )
            }
        } catch {
            self.error = "Failed to load mind maps: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Load Nodes for Editor

    func loadNodes(id: String) async -> (title: String, nodes: [MindMapNode])? {
        do {
            guard let entity = try repository.fetchById(id) else {
                return nil
            }

            guard let data = entity.nodesJson.data(using: .utf8),
                  let decoded = try? decoder.decode(MindMapData.self, from: data) else {
                return nil
            }

            return (title: entity.title, nodes: decoded.nodes)
        } catch {
            self.error = "Failed to load nodes: \(error.localizedDescription)"
            return nil
        }
    }

    // MARK: - Save Mind Map

    func saveMindMap(id: String, title: String, nodes: [MindMapNode]) async {
        do {
            let mindMapData = MindMapData(nodes: nodes)
            let jsonData = try encoder.encode(mindMapData)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                self.error = "Failed to encode nodes to JSON"
                return
            }

            let existingEntity = try repository.fetchById(id)

            if existingEntity != nil {
                // Update existing
                let coverColor = nodes.first?.color ?? mindMapNodeColors[0]
                try repository.update(
                    id: id,
                    title: title,
                    nodesJson: jsonString,
                    coverColor: Int64(bitPattern: coverColor)
                )
            } else {
                // Create new
                let now = Int64(Date().timeIntervalSince1970 * 1000)
                let coverColor = nodes.first?.color ?? mindMapNodeColors[0]
                let entity = MindMapEntity(
                    id: id,
                    title: title,
                    nodesJson: jsonString,
                    coverColor: Int64(bitPattern: coverColor),
                    createdAt: now,
                    updatedAt: now
                )
                try repository.insert(entity)
            }

            // Reload list
            await loadMindMaps()
        } catch {
            self.error = "Failed to save mind map: \(error.localizedDescription)"
        }
    }

    // MARK: - Delete Mind Map

    func deleteMindMap(id: String) async {
        do {
            try repository.delete(id: id)
            await loadMindMaps()
        } catch {
            self.error = "Failed to delete mind map: \(error.localizedDescription)"
        }
    }

    // MARK: - Clear Error

    func clearError() {
        error = nil
    }
}
