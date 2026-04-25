import SwiftUI

/// Scan overlay shown when the user taps the Vita mascot on a PDF.
/// - Dims the PDF 55%.
/// - Drag on the PDF to draw a rectangle. On release, shows 4 corner handles
///   so the user can refine. A floating toolbar at the bottom offers:
///     [✓ Perguntar ao Vita]  [↺ Página toda]  [✕ Cancelar]
/// - Tap on empty space (no rect yet or outside current rect) starts a new drag.
///
/// Coordinates: `selection` is in the overlay's local coordinate space.
/// Consumer converts it to PDF page space before rendering.
struct PdfScanOverlay: View {
    @Binding var selection: CGRect?

    let onConfirm: () -> Void       // send selection as-is
    let onFullPage: () -> Void      // ignore selection, use full current page
    let onCancel: () -> Void        // exit scan mode

    @State private var dragStart: CGPoint? = nil
    @State private var activeHandle: Handle? = nil
    @State private var hintVisible: Bool = true

    private let handleSize: CGFloat = 24
    private let minRectSize: CGFloat = 60

    enum Handle { case topLeft, topRight, bottomLeft, bottomRight }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dimmed backdrop — fully covers the area so PDF below is muted.
                // vita-modals-ignore: scan-mode-dimmed-overlay — UI mode de seleção de área, não modal dialog
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(drawGesture(in: geo.size))

                // Hint text (centered, fades out after first drag)
                if hintVisible {
                    VStack(spacing: 8) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 36, weight: .light))
                            .foregroundStyle(VitaColors.accent.opacity(0.9))
                        Text("Arraste sobre o que você quer perguntar ao Vita")
                            .font(VitaTypography.bodyMedium)
                            .foregroundStyle(Color.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }

                // The selection rectangle (cut-out + border + handles)
                if let rect = selection {
                    selectionLayer(rect: rect, bounds: geo.size)
                }

                // Floating toolbar at the bottom
                VStack {
                    Spacer()
                    toolbar
                        .padding(.bottom, 24)
                }
            }
        }
        .transition(.opacity)
    }

    // MARK: - Selection layer (cut-out + border + handles)

    @ViewBuilder
    private func selectionLayer(rect: CGRect, bounds: CGSize) -> some View {
        // Clear window over the selection so the PDF is visible unmodified through it.
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)

            // Border
            Rectangle()
                .strokeBorder(VitaColors.accent, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)

            // 4 corner handles
            handleView(.topLeft,    position: CGPoint(x: rect.minX, y: rect.minY), bounds: bounds)
            handleView(.topRight,   position: CGPoint(x: rect.maxX, y: rect.minY), bounds: bounds)
            handleView(.bottomLeft, position: CGPoint(x: rect.minX, y: rect.maxY), bounds: bounds)
            handleView(.bottomRight,position: CGPoint(x: rect.maxX, y: rect.maxY), bounds: bounds)
        }
        .compositingGroup()
    }

    private func handleView(_ handle: Handle, position: CGPoint, bounds: CGSize) -> some View {
        Circle()
            .fill(VitaColors.accent)
            .frame(width: handleSize, height: handleSize)
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            .position(position)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard var rect = selection else { return }
                        let p = value.location
                        let clamped = CGPoint(
                            x: min(max(p.x, 0), bounds.width),
                            y: min(max(p.y, 0), bounds.height)
                        )
                        switch handle {
                        case .topLeft:
                            let newW = rect.maxX - clamped.x
                            let newH = rect.maxY - clamped.y
                            if newW >= minRectSize { rect.origin.x = clamped.x; rect.size.width = newW }
                            if newH >= minRectSize { rect.origin.y = clamped.y; rect.size.height = newH }
                        case .topRight:
                            let newW = clamped.x - rect.minX
                            let newH = rect.maxY - clamped.y
                            if newW >= minRectSize { rect.size.width = newW }
                            if newH >= minRectSize { rect.origin.y = clamped.y; rect.size.height = newH }
                        case .bottomLeft:
                            let newW = rect.maxX - clamped.x
                            let newH = clamped.y - rect.minY
                            if newW >= minRectSize { rect.origin.x = clamped.x; rect.size.width = newW }
                            if newH >= minRectSize { rect.size.height = newH }
                        case .bottomRight:
                            let newW = clamped.x - rect.minX
                            let newH = clamped.y - rect.minY
                            if newW >= minRectSize { rect.size.width = newW }
                            if newH >= minRectSize { rect.size.height = newH }
                        }
                        selection = rect
                    }
            )
    }

    // MARK: - Draw gesture

    private func drawGesture(in bounds: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .local)
            .onChanged { value in
                if hintVisible {
                    withAnimation(.easeOut(duration: 0.2)) { hintVisible = false }
                }
                if dragStart == nil {
                    dragStart = value.startLocation
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                guard let start = dragStart else { return }
                let current = value.location
                let rect = CGRect(
                    x: min(start.x, current.x),
                    y: min(start.y, current.y),
                    width: abs(current.x - start.x),
                    height: abs(current.y - start.y)
                )
                selection = rect
            }
            .onEnded { _ in
                dragStart = nil
                // Discard if rect is too small — user probably just tapped
                if let r = selection, r.width < minRectSize || r.height < minRectSize {
                    selection = nil
                } else {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
            }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    // vita-modals-ignore: scan-mode-dimmed-overlay — UI mode de seleção de área, não modal dialog
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
            }

            Button(action: onFullPage) {
                HStack(spacing: 6) {
                    Image(systemName: "doc")
                    Text("Página toda")
                }
                .font(VitaTypography.labelMedium)
                .foregroundStyle(Color.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                // vita-modals-ignore: scan-mode-dimmed-overlay — UI mode de seleção de área, não modal dialog
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
            }

            Button(action: {
                guard selection != nil else { return }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onConfirm()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                    Text("Perguntar ao Vita")
                }
                .font(VitaTypography.labelMedium.weight(.semibold))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(selection != nil ? VitaColors.accent : VitaColors.accent.opacity(0.35))
                .clipShape(Capsule())
            }
            .disabled(selection == nil)
        }
    }
}
