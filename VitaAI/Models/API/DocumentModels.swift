import Foundation

// MARK: - VitaDocument
//
// Represents a document/PDF in the user's library. Source of truth: backend
// `documents` table (see /Users/mav/vitaai-web/src/db/schema.ts).
// Endpoint: GET /api/documents → returns array of these.
// Documents come from two sources:
//   - "canvas" / "mannesoft" — synced automatically from connected portal
//   - "upload" — manually uploaded by the user

struct VitaDocument: Codable, Identifiable {
    var id: String
    var userId: String
    var title: String
    var fileName: String
    var fileUrl: String
    var subjectId: String?
    var totalPages: Int = 0
    var currentPage: Int = 0
    var readProgress: Double = 0
    var isFavorite: Bool = false
    var source: String?           // 'upload' | 'canvas' | 'mannesoft'
    var canvasFileId: String?
    var studioSourceId: String?
    var createdAt: String?
    var updatedAt: String?
}
