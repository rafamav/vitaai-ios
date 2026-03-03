import Foundation
import SwiftUI

// MARK: - MindMapNode
// Domain model for a single node in the mind map graph.
// Codable for JSON serialization (stored in MindMapEntity.nodesJson).
// Identifiable for SwiftUI ForEach.
// Equatable for @Observable change detection.

struct MindMapNode: Codable, Identifiable, Equatable {
    var id: String
    var text: String
    var x: Float
    var y: Float
    var parentId: String?
    var color: UInt64       // ARGB packed (e.g., 0xFF22D3EE = Cyan)
    var width: Float = 160
    var height: Float = 60

    // Convert packed ARGB to SwiftUI Color
    var swiftUIColor: Color {
        let a = Double((color >> 24) & 0xFF) / 255.0
        let r = Double((color >> 16) & 0xFF) / 255.0
        let g = Double((color >> 8) & 0xFF) / 255.0
        let b = Double(color & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    static func == (lhs: MindMapNode, rhs: MindMapNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.text == rhs.text &&
        lhs.x == rhs.x &&
        lhs.y == rhs.y &&
        lhs.parentId == rhs.parentId &&
        lhs.color == rhs.color &&
        lhs.width == rhs.width &&
        lhs.height == rhs.height
    }
}

// MARK: - MindMapData
// Wrapper for JSON serialization (matches Android nodesJson structure).

struct MindMapData: Codable {
    var nodes: [MindMapNode]
}

// MARK: - MindMap
// Presentation model combining SwiftData entity fields + decoded nodes.

struct MindMap: Identifiable {
    let id: String
    var title: String
    var nodes: [MindMapNode]
    var courseId: String?
    var courseName: String?
    var coverColor: UInt64
    var createdAt: Date
    var updatedAt: Date

    var coverSwiftUIColor: Color {
        let a = Double((coverColor >> 24) & 0xFF) / 255.0
        let r = Double((coverColor >> 16) & 0xFF) / 255.0
        let g = Double((coverColor >> 8) & 0xFF) / 255.0
        let b = Double(coverColor & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

// MARK: - Mind Map Node Colors Palette
// Matches Android implementation (8 colors).

let mindMapNodeColors: [UInt64] = [
    0xFF22D3EE, // Cyan (KastTeal)
    0xFF3B82F6, // Blue
    0xFF8B5CF6, // Violet
    0xFFEC4899, // Pink
    0xFFEF4444, // Red
    0xFFF59E0B, // Amber
    0xFF22C55E, // Green
    0xFF6366F1, // Indigo
]
