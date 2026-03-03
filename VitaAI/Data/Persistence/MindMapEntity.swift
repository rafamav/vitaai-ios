import Foundation
import SwiftData

// MARK: - MindMapEntity
// SwiftData persistent entity for mind maps.
// nodesJson stores serialized MindMapData (matches Android approach).

@Model
final class MindMapEntity {
    @Attribute(.unique) var id: String
    var title: String
    var nodesJson: String          // JSON serialized MindMapData
    var courseId: String?
    var courseName: String?
    var coverColor: Int64          // ARGB packed (signed Int64 for SwiftData)
    var createdAt: Int64           // milliseconds since epoch
    var updatedAt: Int64           // milliseconds since epoch

    init(
        id: String,
        title: String,
        nodesJson: String,
        courseId: String? = nil,
        courseName: String? = nil,
        coverColor: Int64,
        createdAt: Int64,
        updatedAt: Int64
    ) {
        self.id = id
        self.title = title
        self.nodesJson = nodesJson
        self.courseId = courseId
        self.courseName = courseName
        self.coverColor = coverColor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
