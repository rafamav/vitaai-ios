import SwiftUI
import Foundation

// MARK: - Annotation Tool

enum AnnotationTool: String, CaseIterable {
    case pen
    case highlighter
    case eraser
    case text
    case shapeLine
    case shapeArrow
    case shapeRect
    case shapeCircle

    var isInkTool: Bool { self == .pen || self == .highlighter }

    var isShapeTool: Bool {
        [AnnotationTool.shapeLine, .shapeArrow, .shapeRect, .shapeCircle].contains(self)
    }

    var shapeType: ShapeType? {
        switch self {
        case .shapeLine: return .line
        case .shapeArrow: return .arrow
        case .shapeRect: return .rectangle
        case .shapeCircle: return .circle
        default: return nil
        }
    }

    var displayName: String {
        switch self {
        case .pen: return "Caneta"
        case .highlighter: return "Marca-texto"
        case .eraser: return "Borracha"
        case .text: return "Texto"
        case .shapeLine: return "Linha"
        case .shapeArrow: return "Seta"
        case .shapeRect: return "Retângulo"
        case .shapeCircle: return "Círculo"
        }
    }
}

// MARK: - Shape Type

enum ShapeType: String, Codable, CaseIterable {
    case line, arrow, rectangle, circle
}

// MARK: - Stroke Point

struct StrokePoint: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    var pressure: CGFloat = 1.0
}

// MARK: - Ink Stroke

struct InkStroke: Codable, Identifiable {
    var id: UUID
    var points: [StrokePoint]
    var colorHex: UInt
    var width: CGFloat
    var tool: String     // AnnotationTool.rawValue
    var alpha: CGFloat

    init(
        id: UUID = UUID(),
        points: [StrokePoint],
        color: Color,
        width: CGFloat,
        tool: AnnotationTool
    ) {
        self.id = id
        self.points = points
        self.colorHex = color.vitaHex
        self.width = width
        self.tool = tool.rawValue
        self.alpha = tool == .highlighter ? 0.35 : 1.0
    }

    var color: Color { Color(hex: colorHex) }
}

// MARK: - Eraser Path

struct EraserPath: Codable {
    var points: [StrokePoint]
    var width: CGFloat
}

// MARK: - Text Annotation

struct TextAnnotation: Codable, Identifiable, Equatable {
    var id: UUID
    var x: CGFloat
    var y: CGFloat
    var text: String
    var colorHex: UInt
    var fontSize: CGFloat

    init(
        id: UUID = UUID(),
        x: CGFloat,
        y: CGFloat,
        text: String = "",
        color: Color = .white,
        fontSize: CGFloat = 16
    ) {
        self.id = id
        self.x = x; self.y = y
        self.text = text
        self.colorHex = color.vitaHex
        self.fontSize = fontSize
    }

    var color: Color { Color(hex: colorHex) }
}

// MARK: - Shape Annotation

struct ShapeAnnotation: Codable, Identifiable {
    var id: UUID
    var type: ShapeType
    var startX: CGFloat
    var startY: CGFloat
    var endX: CGFloat
    var endY: CGFloat
    var colorHex: UInt
    var width: CGFloat
    var filled: Bool

    init(
        id: UUID = UUID(),
        type: ShapeType,
        startX: CGFloat, startY: CGFloat,
        endX: CGFloat, endY: CGFloat,
        color: Color, width: CGFloat,
        filled: Bool = false
    ) {
        self.id = id; self.type = type
        self.startX = startX; self.startY = startY
        self.endX = endX; self.endY = endY
        self.colorHex = color.vitaHex
        self.width = width; self.filled = filled
    }

    var color: Color { Color(hex: colorHex) }
}

// MARK: - Page Snapshot (Undo/Redo)

struct PageSnapshot {
    var strokes: [InkStroke]
    var eraserPaths: [EraserPath]
}

// MARK: - Persisted Page Annotations

struct PageAnnotations: Codable {
    var strokes: [InkStroke]
    var eraserPaths: [EraserPath]
    var textAnnotations: [TextAnnotation]
    var shapeAnnotations: [ShapeAnnotation]
}

// MARK: - Color Helper

extension Color {
    /// Extract RRGGBB UInt for storage (reuses existing Color(hex:) initializer).
    var vitaHex: UInt {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        let ri = UInt(max(0, min(255, r * 255)))
        let gi = UInt(max(0, min(255, g * 255)))
        let bi = UInt(max(0, min(255, b * 255)))
        return (ri << 16) | (gi << 8) | bi
    }
}
