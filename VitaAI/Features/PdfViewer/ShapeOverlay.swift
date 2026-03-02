import SwiftUI

/// Canvas overlay for drawing shapes (line, arrow, rect, circle) on a PDF page.
/// Drag from start to end; commits shape on finger lift.
struct ShapeOverlay: View {
    let shapes: [ShapeAnnotation]
    let selectedTool: AnnotationTool
    let selectedColor: Color
    let strokeWidth: CGFloat
    let isActive: Bool
    let onAddShape: (ShapeAnnotation) -> Void

    @State private var dragStart: CGPoint? = nil
    @State private var dragEnd: CGPoint? = nil

    private var shapeType: ShapeType { selectedTool.shapeType ?? .rectangle }

    var body: some View {
        Canvas { ctx, _ in
            // Draw committed shapes
            for shape in shapes {
                drawShape(shape, in: &ctx)
            }
            // Draw live preview
            if let start = dragStart, let end = dragEnd {
                let preview = ShapeAnnotation(
                    type: shapeType,
                    startX: start.x, startY: start.y,
                    endX: end.x, endY: end.y,
                    color: selectedColor, width: strokeWidth
                )
                drawShape(preview, in: &ctx)
            }
        }
        .allowsHitTesting(isActive)
        .gesture(
            isActive ? DragGesture(minimumDistance: 4, coordinateSpace: .local)
                .onChanged { value in
                    if dragStart == nil { dragStart = value.startLocation }
                    dragEnd = value.location
                }
                .onEnded { value in
                    if let start = dragStart {
                        let dx = abs(value.location.x - start.x)
                        let dy = abs(value.location.y - start.y)
                        if dx + dy > 10 {
                            onAddShape(ShapeAnnotation(
                                type: shapeType,
                                startX: start.x, startY: start.y,
                                endX: value.location.x, endY: value.location.y,
                                color: selectedColor, width: strokeWidth
                            ))
                        }
                    }
                    dragStart = nil; dragEnd = nil
                }
            : nil
        )
    }

    // MARK: - Drawing

    private func drawShape(_ shape: ShapeAnnotation, in ctx: inout GraphicsContext) {
        let color = shape.color
        let style = StrokeStyle(lineWidth: shape.width, lineCap: .round, lineJoin: .round)
        let start = CGPoint(x: shape.startX, y: shape.startY)
        let end   = CGPoint(x: shape.endX,   y: shape.endY)

        switch shape.type {
        case .line:
            var path = Path()
            path.move(to: start); path.addLine(to: end)
            ctx.stroke(path, with: .color(color), style: style)

        case .arrow:
            var path = Path()
            path.move(to: start); path.addLine(to: end)
            ctx.stroke(path, with: .color(color), style: style)
            // Arrow head
            let arrowPath = arrowHeadPath(from: start, to: end, width: shape.width)
            ctx.stroke(arrowPath, with: .color(color), style: style)

        case .rectangle:
            let rect = CGRect(
                x: min(shape.startX, shape.endX),
                y: min(shape.startY, shape.endY),
                width: abs(shape.endX - shape.startX),
                height: abs(shape.endY - shape.startY)
            )
            if shape.filled {
                ctx.fill(Path(rect), with: .color(color.opacity(0.3)))
            }
            ctx.stroke(Path(rect), with: .color(color), style: style)

        case .circle:
            let cx = (shape.startX + shape.endX) / 2
            let cy = (shape.startY + shape.endY) / 2
            let rx = abs(shape.endX - shape.startX) / 2
            let ry = abs(shape.endY - shape.startY) / 2
            let rect = CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2)
            if shape.filled {
                ctx.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.3)))
            }
            ctx.stroke(Path(ellipseIn: rect), with: .color(color), style: style)
        }
    }

    private func arrowHeadPath(from: CGPoint, to: CGPoint, width: CGFloat) -> Path {
        let arrowLen = width * 4
        let angle = atan2(to.y - from.y, to.x - from.x)
        let a1 = angle + .pi * 5 / 6  // 150°
        let a2 = angle - .pi * 5 / 6

        var path = Path()
        path.move(to: to)
        path.addLine(to: CGPoint(x: to.x + arrowLen * cos(a1), y: to.y + arrowLen * sin(a1)))
        path.move(to: to)
        path.addLine(to: CGPoint(x: to.x + arrowLen * cos(a2), y: to.y + arrowLen * sin(a2)))
        return path
    }
}
