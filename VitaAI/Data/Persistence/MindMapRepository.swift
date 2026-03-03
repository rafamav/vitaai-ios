import Foundation
import SwiftData

// MARK: - MindMapRepository
// CRUD operations for MindMapEntity via SwiftData ModelContext.
// All operations are synchronous (ModelContext is thread-safe when used on @MainActor).

@MainActor
final class MindMapRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Fetch

    func fetchAll() throws -> [MindMapEntity] {
        let descriptor = FetchDescriptor<MindMapEntity>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchById(_ id: String) throws -> MindMapEntity? {
        var descriptor = FetchDescriptor<MindMapEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // MARK: - Insert

    func insert(_ entity: MindMapEntity) throws {
        context.insert(entity)
        try context.save()
    }

    // MARK: - Update

    func update(
        id: String,
        title: String? = nil,
        nodesJson: String? = nil,
        coverColor: Int64? = nil
    ) throws {
        guard let entity = try fetchById(id) else {
            throw MindMapRepositoryError.notFound
        }

        if let title = title {
            entity.title = title
        }
        if let nodesJson = nodesJson {
            entity.nodesJson = nodesJson
        }
        if let coverColor = coverColor {
            entity.coverColor = coverColor
        }

        entity.updatedAt = Int64(Date().timeIntervalSince1970 * 1000)
        try context.save()
    }

    // MARK: - Delete

    func delete(id: String) throws {
        guard let entity = try fetchById(id) else {
            throw MindMapRepositoryError.notFound
        }
        context.delete(entity)
        try context.save()
    }
}

// MARK: - Errors

enum MindMapRepositoryError: LocalizedError {
    case notFound

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Mind map not found"
        }
    }
}
