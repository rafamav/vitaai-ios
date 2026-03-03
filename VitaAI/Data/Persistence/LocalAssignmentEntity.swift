import Foundation
import SwiftData

// MARK: - LocalAssignmentEntity (SwiftData)
// Mirrors com.bymav.medcoach.data.local.entity.LocalAssignmentEntity (Android Room).
// Table: local_assignments — persists locally-authored assignment drafts.

@Model
final class LocalAssignmentEntity {
    @Attribute(.unique) var id: String
    var title: String
    var content: String
    var templateType: String   // "blank" | "essay" | "report" | "research" | "presentation"
    var status: String         // "draft" | "in_progress"
    var wordCount: Int
    var createdAt: Int64       // millis since epoch
    var updatedAt: Int64

    init(
        id: String,
        title: String,
        content: String,
        templateType: String,
        status: String,
        wordCount: Int,
        createdAt: Int64,
        updatedAt: Int64
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.templateType = templateType
        self.status = status
        self.wordCount = wordCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
