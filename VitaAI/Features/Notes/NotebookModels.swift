import Foundation
import SwiftUI

// MARK: - Paper Template

enum PaperTemplate: String, CaseIterable, Codable {
    case blank    = "blank"
    case ruled    = "ruled"
    case grid     = "grid"
    case dotted   = "dotted"
    case cornell  = "cornell"

    var displayName: String {
        switch self {
        case .blank:   return "Branco"
        case .ruled:   return "Pautado"
        case .grid:    return "Grid"
        case .dotted:  return "Pontilhado"
        case .cornell: return "Cornell"
        }
    }

    var systemIcon: String {
        switch self {
        case .blank:   return "doc"
        case .ruled:   return "lines.measurement.horizontal"
        case .grid:    return "grid"
        case .dotted:  return "circle.dotted"
        case .cornell: return "rectangle.split.2x1"
        }
    }
}

// MARK: - Brush Type

enum BrushType: String, Codable, CaseIterable {
    case pen      = "PEN"
    case marker   = "MARKER"
    case eraser   = "ERASER"
}

// MARK: - Stroke Point (Notes-specific, uses Float for compact serialization)

struct NoteStrokePoint: Codable {
    var x: Float
    var y: Float
}

// MARK: - DrawStroke (serializable)

struct DrawStroke: Codable, Identifiable {
    var id: UUID = UUID()
    var points: [NoteStrokePoint]
    var color: UInt64          // ARGB hex e.g. 0xFF1A1A2E
    var size: Float
    var brushType: BrushType

    // Convenience: CGColor from packed ARGB
    var uiColor: Color {
        Color(
            red:   Double((color >> 16) & 0xFF) / 255.0,
            green: Double((color >> 8) & 0xFF) / 255.0,
            blue:  Double(color & 0xFF) / 255.0,
            opacity: Double((color >> 24) & 0xFF) / 255.0
        )
    }

    enum CodingKeys: String, CodingKey {
        case id, points, color, size, brushType
    }

    init(id: UUID = UUID(), points: [NoteStrokePoint], color: UInt64, size: Float, brushType: BrushType) {
        self.id = id
        self.points = points
        self.color = color
        self.size = size
        self.brushType = brushType
    }
}

// MARK: - Page

struct NotebookPage: Codable, Identifiable {
    var id: UUID
    var notebookId: UUID
    var pageIndex: Int
    var template: PaperTemplate
    var pkCanvasData: Data?      // PencilKit PKDrawing serialised bytes

    init(id: UUID = UUID(), notebookId: UUID, pageIndex: Int, template: PaperTemplate = .ruled) {
        self.id = id
        self.notebookId = notebookId
        self.pageIndex = pageIndex
        self.template = template
        self.pkCanvasData = nil
    }
}

// MARK: - Notebook

struct Notebook: Codable, Identifiable {
    var id: UUID
    var title: String
    var coverColor: UInt64          // ARGB hex
    var createdAt: Date
    var updatedAt: Date
    var pageCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        coverColor: UInt64,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        pageCount: Int = 1
    ) {
        self.id = id
        self.title = title
        self.coverColor = coverColor
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pageCount = pageCount
    }

    /// SwiftUI Color from packed ARGB
    var swiftUIColor: Color {
        Color(
            red:   Double((coverColor >> 16) & 0xFF) / 255.0,
            green: Double((coverColor >> 8) & 0xFF) / 255.0,
            blue:  Double(coverColor & 0xFF) / 255.0,
            opacity: Double((coverColor >> 24) & 0xFF) / 255.0
        )
    }

    var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "dd/MM"
        return fmt.string(from: updatedAt)
    }
}

// MARK: - Notebook Cover Colors (mirrors Android notebookColors)

let notebookCoverColors: [UInt64] = [
    0xFF22D3EE, // Cyan
    0xFF3B82F6, // Blue
    0xFF8B5CF6, // Violet
    0xFFEC4899, // Pink
    0xFFEF4444, // Red
    0xFFF59E0B, // Amber
    0xFF22C55E, // Green
    0xFF6366F1, // Indigo
]

// MARK: - GoodNotes-style ink preset colors

let presetInkColors: [UInt64] = [
    0xFF1A1A2E, // Near-black (default ink)
    0xFF2563EB, // Royal blue
    0xFFDC2626, // Red ink
    0xFF059669, // Green ink
    0xFF7C3AED, // Purple ink
    0xFFD97706, // Brown/amber
    0xFFDB2777, // Pink
    0xFF64748B, // Slate gray
]

let presetInkColorNames = [
    "Preto", "Azul", "Vermelho", "Verde",
    "Roxo", "Marrom", "Rosa", "Cinza"
]
