import SwiftUI

// MARK: - MindMapCanvasView
// Interactive canvas for rendering mind map nodes with pan/zoom/drag gestures.
// Mirrors MindMapCanvas.kt (Android Compose).
//
// Features:
// - Dot grid background
// - Bezier curves connecting parent→child
// - Rounded rect nodes with text
// - Glow effect on selected node
// - Pan canvas (drag empty area)
// - Zoom (pinch gesture)
// - Drag nodes
// - Double-tap to edit text

struct MindMapCanvasView: View {
    let nodes: [MindMapNode]
    let selectedNodeId: String?
    let scale: Float
    let offsetX: Float
    let offsetY: Float

    let onSelectNode: (String?) -> Void
    let onMoveNode: (String, Float, Float) -> Void
    let onDoubleTapNode: (String) -> Void
    let onTransformChanged: (Float, Float, Float) -> Void

    @State private var dragState: DragState = .idle
    @GestureState private var magnifyScale: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Background
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(VitaColors.surface)
                )

                // Dot grid (for visual reference)
                drawDotGrid(context: context, size: size)

                // Transform context for pan/zoom
                context.translateBy(x: CGFloat(offsetX), y: CGFloat(offsetY))
                context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

                // Draw connections (parent→child bezier curves)
                for node in nodes {
                    if let parentId = node.parentId,
                       let parent = nodes.first(where: { $0.id == parentId }) {
                        drawConnection(
                            context: context,
                            from: (CGFloat(parent.x), CGFloat(parent.y), CGFloat(parent.width), CGFloat(parent.height)),
                            to: (CGFloat(node.x), CGFloat(node.y), CGFloat(node.width), CGFloat(node.height)),
                            color: node.swiftUIColor
                        )
                    }
                }

                // Draw nodes
                for node in nodes {
                    let isSelected = node.id == selectedNodeId
                    drawNode(
                        context: context,
                        node: node,
                        isSelected: isSelected
                    )
                }
            }
            .gesture(
                simultaneousGesture(geometry: geometry)
            )
            .onTapGesture(count: 2) { location in
                handleDoubleTap(at: location, geometry: geometry)
            }
            .onTapGesture { location in
                handleSingleTap(at: location, geometry: geometry)
            }
        }
    }

    // MARK: - Drawing

    private func drawDotGrid(context: GraphicsContext, size: CGSize) {
        let gridSpacing: CGFloat = 40
        let dotRadius: CGFloat = 1.5

        var x: CGFloat = 0
        while x < size.width {
            var y: CGFloat = 0
            while y < size.height {
                let dotPath = Path(ellipseIn: CGRect(
                    x: x - dotRadius,
                    y: y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                ))
                context.fill(dotPath, with: .color(VitaColors.surfaceBorder.opacity(0.3)))
                y += gridSpacing
            }
            x += gridSpacing
        }
    }

    private func drawConnection(
        context: GraphicsContext,
        from: (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat),
        to: (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat),
        color: Color
    ) {
        let startX = from.x + from.w / 2
        let startY = from.y + from.h
        let endX = to.x + to.w / 2
        let endY = to.y

        var path = Path()
        path.move(to: CGPoint(x: startX, y: startY))

        // Cubic bezier curve
        let controlPointOffset = abs(endY - startY) / 2
        path.addCurve(
            to: CGPoint(x: endX, y: endY),
            control1: CGPoint(x: startX, y: startY + controlPointOffset),
            control2: CGPoint(x: endX, y: endY - controlPointOffset)
        )

        context.stroke(
            path,
            with: .color(color.opacity(0.6)),
            lineWidth: 3
        )
    }

    private func drawNode(
        context: GraphicsContext,
        node: MindMapNode,
        isSelected: Bool
    ) {
        let rect = CGRect(
            x: CGFloat(node.x),
            y: CGFloat(node.y),
            width: CGFloat(node.width),
            height: CGFloat(node.height)
        )

        // Glow for selected node
        if isSelected {
            let glowPath = Path(roundedRect: rect.insetBy(dx: -4, dy: -4), cornerRadius: 12)
            context.fill(
                glowPath,
                with: .color(node.swiftUIColor.opacity(0.3))
            )
        }

        // Node background
        let nodePath = Path(roundedRect: rect, cornerRadius: 8)
        context.fill(nodePath, with: .color(node.swiftUIColor))

        // Border
        context.stroke(
            nodePath,
            with: .color(.white.opacity(0.2)),
            lineWidth: 2
        )

        // Text
        let text = Text(node.text)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.white)

        let resolvedText = context.resolve(text)
        context.draw(resolvedText, in: rect.insetBy(dx: 8, dy: 8))
    }

    // MARK: - Gestures

    private func simultaneousGesture(geometry: GeometryProxy) -> some Gesture {
        let drag = DragGesture()
            .onChanged { value in
                handleDragChanged(value: value, geometry: geometry)
            }
            .onEnded { value in
                handleDragEnded(value: value, geometry: geometry)
            }

        let magnify = MagnifyGesture()
            .updating($magnifyScale) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                handleMagnifyEnded(value: value)
            }

        return SimultaneousGesture(drag, magnify)
    }

    private func handleDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        switch dragState {
        case .idle:
            // Determine if dragging a node or panning canvas
            let worldLocation = screenToWorld(
                point: value.startLocation,
                geometry: geometry
            )
            if let nodeId = hitTestNode(at: worldLocation) {
                dragState = .draggingNode(
                    nodeId: nodeId,
                    initialLocation: worldLocation
                )
            } else {
                dragState = .panningCanvas(
                    initialOffset: (offsetX, offsetY)
                )
            }

        case .draggingNode(let nodeId, let initialLocation):
            let currentWorldLocation = screenToWorld(
                point: value.location,
                geometry: geometry
            )
            let dx = Float(currentWorldLocation.x - initialLocation.x)
            let dy = Float(currentWorldLocation.y - initialLocation.y)

            if let node = nodes.first(where: { $0.id == nodeId }) {
                onMoveNode(nodeId, node.x + dx, node.y + dy)
            }

        case .panningCanvas(let initialOffset):
            let translation = value.translation
            onTransformChanged(
                scale,
                initialOffset.x + Float(translation.width),
                initialOffset.y + Float(translation.height)
            )
        }
    }

    private func handleDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        dragState = .idle
    }

    private func handleMagnifyEnded(value: MagnifyGesture.Value) {
        let newScale = max(0.3, min(3.0, scale * Float(value.magnification)))
        onTransformChanged(newScale, offsetX, offsetY)
    }

    private func handleSingleTap(at location: CGPoint, geometry: GeometryProxy) {
        let worldLocation = screenToWorld(point: location, geometry: geometry)
        if let nodeId = hitTestNode(at: worldLocation) {
            onSelectNode(nodeId)
        } else {
            onSelectNode(nil)
        }
    }

    private func handleDoubleTap(at location: CGPoint, geometry: GeometryProxy) {
        let worldLocation = screenToWorld(point: location, geometry: geometry)
        if let nodeId = hitTestNode(at: worldLocation) {
            onDoubleTapNode(nodeId)
        }
    }

    // MARK: - Hit Testing

    private func hitTestNode(at point: CGPoint) -> String? {
        // Reverse order (top nodes first)
        for node in nodes.reversed() {
            let rect = CGRect(
                x: CGFloat(node.x),
                y: CGFloat(node.y),
                width: CGFloat(node.width),
                height: CGFloat(node.height)
            )
            if rect.contains(point) {
                return node.id
            }
        }
        return nil
    }

    // MARK: - Coordinate Transforms

    private func screenToWorld(point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        let x = (point.x - CGFloat(offsetX)) / CGFloat(scale)
        let y = (point.y - CGFloat(offsetY)) / CGFloat(scale)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - DragState

private enum DragState {
    case idle
    case draggingNode(nodeId: String, initialLocation: CGPoint)
    case panningCanvas(initialOffset: (x: Float, y: Float))
}
