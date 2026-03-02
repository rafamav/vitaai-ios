import SwiftUI

/// SwiftUI Canvas overlay for freehand ink drawing.
/// Renders finished strokes and a live preview of the current stroke being drawn.
/// Eraser uses BlendMode.destinationOut for pixel-accurate clearing.
struct InkCanvasView: View {
    let finishedStrokes: [InkStroke]
    let eraserPaths: [EraserPath]
    let isDrawMode: Bool
    let selectedTool: AnnotationTool
    let selectedColor: Color
    let strokeWidth: CGFloat
    let onStrokeFinished: (InkStroke) -> Void
    let onEraserPath: (EraserPath) -> Void

    @State private var livePoints: [StrokePoint] = []
    @State private var liveEraserPoints: [StrokePoint] = []

    private var isEraser: Bool { selectedTool == .eraser }
    private var toolAlpha: CGFloat { selectedTool == .highlighter ? 0.35 : 1.0 }
    private var effectiveEraserWidth: CGFloat { strokeWidth * 3 }

    var body: some View {
        ZStack {
            // Layer 1: Finished strokes + eraser (composited as offscreen group)
            Canvas { ctx, _ in
                // Draw all finished ink strokes
                for stroke in finishedStrokes {
                    guard stroke.points.count >= 2 else { continue }
                    ctx.stroke(
                        strokePath(from: stroke.points),
                        with: .color(stroke.color.opacity(stroke.alpha)),
                        style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round)
                    )
                }
                // Eraser on top with destinationOut blend
                ctx.blendMode = .destinationOut
                for ep in eraserPaths {
                    guard ep.points.count >= 2 else { continue }
                    ctx.stroke(
                        strokePath(from: ep.points),
                        with: .color(.white),
                        style: StrokeStyle(lineWidth: ep.width, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .compositingGroup()
            .allowsHitTesting(false)

            // Layer 2: Live preview while drawing
            Canvas { ctx, _ in
                if isEraser, liveEraserPoints.count >= 2 {
                    ctx.stroke(
                        strokePath(from: liveEraserPoints),
                        with: .color(.white.opacity(0.4)),
                        style: StrokeStyle(lineWidth: effectiveEraserWidth, lineCap: .round, lineJoin: .round)
                    )
                } else if !isEraser, livePoints.count >= 2 {
                    ctx.stroke(
                        strokePath(from: livePoints),
                        with: .color(selectedColor.opacity(toolAlpha)),
                        style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .allowsHitTesting(false)

            // Touch capture layer
            if isDrawMode && selectedTool.isInkTool || isDrawMode && isEraser {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .local)
                            .onChanged { value in
                                let pt = StrokePoint(x: value.location.x, y: value.location.y)
                                if isEraser {
                                    liveEraserPoints.append(pt)
                                } else {
                                    livePoints.append(pt)
                                }
                            }
                            .onEnded { _ in
                                if isEraser {
                                    if liveEraserPoints.count >= 2 {
                                        onEraserPath(EraserPath(points: liveEraserPoints, width: effectiveEraserWidth))
                                    }
                                    liveEraserPoints = []
                                } else {
                                    if livePoints.count >= 2 {
                                        onStrokeFinished(InkStroke(
                                            points: livePoints,
                                            color: selectedColor,
                                            width: strokeWidth,
                                            tool: selectedTool
                                        ))
                                    }
                                    livePoints = []
                                }
                            }
                    )
            }
        }
    }

    private func strokePath(from points: [StrokePoint]) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: points[0].x, y: points[0].y))
        for pt in points.dropFirst() {
            path.addLine(to: CGPoint(x: pt.x, y: pt.y))
        }
        return path
    }
}
