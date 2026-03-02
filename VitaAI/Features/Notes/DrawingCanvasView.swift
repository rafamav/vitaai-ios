import SwiftUI
import PencilKit

// MARK: - DrawingCanvasView
// Wraps PKCanvasView via UIViewRepresentable for full Apple Pencil support.
// Mirrors DrawingCanvas.kt (Android) but leverages native PencilKit instead
// of manual stroke rendering — GoodNotes-level quality with zero custom
// stroke math needed; PKCanvasView handles velocity-sensitive ink natively.

struct DrawingCanvasView: UIViewRepresentable {

    // MARK: Bindings from EditorViewModel
    var currentBrush: BrushType
    var currentColor: UInt64
    var currentSize: Float
    var paperTemplate: PaperTemplate
    var undoTrigger: Int
    var redoTrigger: Int

    // MARK: Callbacks
    var onDrawingChanged: (PKDrawing) -> Void
    var onUndoStateChanged: (Bool, Bool) -> Void   // (canUndo, canRedo)

    // Initial canvas data to load
    var initialCanvasData: Data?

    // MARK: - Coordinator

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput   // finger + pencil
        canvas.delegate = context.coordinator
        canvas.alwaysBounceVertical = false
        canvas.showsVerticalScrollIndicator = false
        canvas.showsHorizontalScrollIndicator = false

        // Load persisted drawing if available
        if let data = initialCanvasData,
           let drawing = try? PKDrawing(data: data) {
            canvas.drawing = drawing
        }

        // Observe UndoManager notifications
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.undoManagerDidChange(_:)),
            name: .NSUndoManagerDidCloseUndoGroup,
            object: canvas.undoManager
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.undoManagerDidChange(_:)),
            name: .NSUndoManagerDidUndoChange,
            object: canvas.undoManager
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.undoManagerDidChange(_:)),
            name: .NSUndoManagerDidRedoChange,
            object: canvas.undoManager
        )

        context.coordinator.canvas = canvas
        applyTool(to: canvas)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        // Update tool when brush/color/size changes
        applyTool(to: canvas)

        // Undo/redo triggers
        if context.coordinator.lastUndoTrigger != undoTrigger {
            context.coordinator.lastUndoTrigger = undoTrigger
            canvas.undoManager?.undo()
        }
        if context.coordinator.lastRedoTrigger != redoTrigger {
            context.coordinator.lastRedoTrigger = redoTrigger
            canvas.undoManager?.redo()
        }
    }

    // MARK: - Tool construction

    private func applyTool(to canvas: PKCanvasView) {
        let uiColor = UIColor(
            red:   CGFloat((currentColor >> 16) & 0xFF) / 255.0,
            green: CGFloat((currentColor >> 8) & 0xFF) / 255.0,
            blue:  CGFloat(currentColor & 0xFF) / 255.0,
            alpha: CGFloat((currentColor >> 24) & 0xFF) / 255.0
        )
        let width = CGFloat(currentSize)

        switch currentBrush {
        case .pen:
            canvas.tool = PKInkingTool(.pen, color: uiColor, width: width)
        case .marker:
            // Highlighter — semi-transparent, uniform width (mirrors BrushType.MARKER)
            canvas.tool = PKInkingTool(.marker, color: uiColor.withAlphaComponent(0.35), width: width * 3)
        case .eraser:
            canvas.tool = PKEraserTool(.vector)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: DrawingCanvasView
        weak var canvas: PKCanvasView?
        var lastUndoTrigger: Int = 0
        var lastRedoTrigger: Int = 0

        init(_ parent: DrawingCanvasView) {
            self.parent = parent
        }

        // Called whenever user draws, erases, or undo/redo happens
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.onDrawingChanged(canvasView.drawing)
            updateUndoState(canvasView)
        }

        @objc func undoManagerDidChange(_ notification: Notification) {
            guard let canvas = canvas else { return }
            updateUndoState(canvas)
        }

        private func updateUndoState(_ canvas: PKCanvasView) {
            let canUndo = canvas.undoManager?.canUndo ?? false
            let canRedo = canvas.undoManager?.canRedo ?? false
            parent.onUndoStateChanged(canUndo, canRedo)
        }
    }
}

// MARK: - PaperBackgroundView
// Draws paper template lines/grids using SwiftUI Canvas.
// Sits below the PKCanvasView in a ZStack.

struct PaperBackgroundView: View {
    let template: PaperTemplate

    // Paper/stationery colors — intentionally not from design tokens (real paper simulation)
    private let paperWhite    = Color(red: 1.00, green: 0.996, blue: 0.988)   // 0xFFFFFEFC
    private let lineLightBlue = Color(red: 0.816, green: 0.867, blue: 0.910)  // 0xFFD0DDE8
    private let marginRed     = Color(red: 0.910, green: 0.750, blue: 0.752)  // 0xFFE8BFC0

    var body: some View {
        Canvas { ctx, size in
            // Paper background
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(paperWhite)
            )
            drawTemplate(ctx: ctx, size: size)
        }
        .ignoresSafeArea()
    }

    private func drawTemplate(ctx: GraphicsContext, size: CGSize) {
        let lineSpacing: CGFloat = 32
        switch template {

        case .blank:
            break

        case .ruled:
            // Red margin line
            var marginPath = Path()
            marginPath.move(to: CGPoint(x: 90, y: 0))
            marginPath.addLine(to: CGPoint(x: 90, y: size.height))
            ctx.stroke(marginPath, with: .color(marginRed), lineWidth: 1.5)

            // Blue horizontal lines
            var y: CGFloat = lineSpacing * 3
            while y < size.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(lineLightBlue), lineWidth: 0.8)
                y += lineSpacing
            }

        case .grid:
            let gridSize: CGFloat = 32
            var x: CGFloat = gridSize
            while x < size.width {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(p, with: .color(lineLightBlue.opacity(0.5)), lineWidth: 0.5)
                x += gridSize
            }
            var y: CGFloat = gridSize
            while y < size.height {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(lineLightBlue.opacity(0.5)), lineWidth: 0.5)
                y += gridSize
            }

        case .dotted:
            let dotSpacing: CGFloat = 28
            let dotRadius: CGFloat = 1.2
            let dotColor = Color(red: 0.80, green: 0.835, blue: 0.871) // 0xFFCCD5DE
            var y: CGFloat = dotSpacing
            while y < size.height {
                var x: CGFloat = dotSpacing
                while x < size.width {
                    let dot = Path(ellipseIn: CGRect(
                        x: x - dotRadius, y: y - dotRadius,
                        width: dotRadius * 2, height: dotRadius * 2
                    ))
                    ctx.fill(dot, with: .color(dotColor))
                    x += dotSpacing
                }
                y += dotSpacing
            }

        case .cornell:
            let cueX = size.width * 0.3
            let summaryY = size.height * 0.8

            // Vertical cue column divider
            var cueP = Path()
            cueP.move(to: CGPoint(x: cueX, y: 0))
            cueP.addLine(to: CGPoint(x: cueX, y: summaryY))
            ctx.stroke(cueP, with: .color(marginRed), lineWidth: 1.5)

            // Horizontal summary divider
            var sumP = Path()
            sumP.move(to: CGPoint(x: 0, y: summaryY))
            sumP.addLine(to: CGPoint(x: size.width, y: summaryY))
            ctx.stroke(sumP, with: .color(marginRed), lineWidth: 1.5)

            // Ruled lines in notes area
            var y: CGFloat = lineSpacing * 3
            while y < summaryY {
                var p = Path()
                p.move(to: CGPoint(x: cueX + 8, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(lineLightBlue.opacity(0.4)), lineWidth: 0.5)
                y += lineSpacing
            }
        }
    }
}
