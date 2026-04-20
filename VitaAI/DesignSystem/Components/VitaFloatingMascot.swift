import SwiftUI

/// Draggable floating Vita mascot button. Reusable overlay control.
///
/// - Position persisted per screen via `positionKey` (UserDefaults).
/// - Tap → `onTap`. Long-press (0.4s) minimizes toward nearest edge (30% visible),
///   tap on the minimized stub restores it.
/// - Visual: `vita-btn-active` asset (same as VitaChat center tab).
///
/// Call via `.overlay { VitaFloatingMascot(...) }` on your screen's ROOT
/// (not nested inside a bottom bar) so it draws above other chrome.
struct VitaFloatingMascot: View {
    let positionKey: String
    /// Extra space reserved below the mascot (e.g. for the app tab bar).
    /// Default 16pt for edge padding only.
    var bottomInset: CGFloat = 16
    var isActive: Bool = false     // visual pulse when scan mode is live
    let onTap: () -> Void

    private let size: CGFloat = 58

    // Offset from the anchor corner (bottomTrailing). Negative x = left, negative y = up.
    // nil = not loaded yet → use a sensible default (right-center) on first layout.
    @State private var offset: CGSize? = nil
    @State private var dragStart: CGSize = .zero
    @State private var isDragging = false
    @State private var isMinimized = false
    @State private var minimizedSide: HorizontalEdge = .trailing
    @State private var pulse: Bool = false

    enum HorizontalEdge { case leading, trailing }

    var body: some View {
        GeometryReader { geo in
            mascotView
                .position(
                    x: currentAnchorX(in: geo.size),
                    y: currentAnchorY(in: geo.size)
                )
                .animation(isDragging ? nil : .spring(response: 0.35, dampingFraction: 0.75), value: isMinimized)
                .animation(isDragging ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: offset)
                .onAppear {
                    loadPosition(defaultFor: geo.size)
                    startPulseIfNeeded()
                }
        }
        .ignoresSafeArea(.keyboard)
        .onChange(of: isActive) { _, newValue in
            pulse = newValue
        }
    }

    private var mascotView: some View {
        Image("vita-btn-active")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .scaleEffect(isDragging ? 1.1 : (pulse ? 1.05 : 1.0))
            .animation(
                pulse ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default,
                value: pulse
            )
            .shadow(color: VitaColors.accent.opacity(isDragging ? 0.6 : 0.3), radius: isDragging ? 18 : 10, y: 4)
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDragging {
                            dragStart = offset ?? .zero
                            isDragging = true
                            if isMinimized { isMinimized = false }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        offset = CGSize(
                            width: dragStart.width + value.translation.width,
                            height: dragStart.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        isDragging = false
                        savePosition()
                    }
            )
            .onTapGesture {
                if isMinimized {
                    isMinimized = false
                } else {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onTap()
                }
            }
            .onLongPressGesture(minimumDuration: 0.4) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                // Side = nearest horizontal edge to current position
                minimizedSide = (offset?.width ?? 0) < -150 ? .leading : .trailing
                isMinimized.toggle()
            }
    }

    private func currentAnchorX(in bounds: CGSize) -> CGFloat {
        let anchor = bounds.width - size / 2
        var x = anchor + clampedX(in: bounds)
        if isMinimized {
            let edge: CGFloat = size * 0.7
            x = minimizedSide == .trailing ? (bounds.width - size / 2 + edge) : (size / 2 - edge)
        }
        return x
    }

    private func currentAnchorY(in bounds: CGSize) -> CGFloat {
        let anchor = bounds.height - size / 2
        return anchor + clampedY(in: bounds)
    }

    private func clampedX(in bounds: CGSize) -> CGFloat {
        let ox = offset?.width ?? -16
        let maxNegative = -(bounds.width - size - 16)  // 16pt margin left
        let maxPositive: CGFloat = -16                  // 16pt margin right
        return min(max(ox, maxNegative), maxPositive)
    }

    private func clampedY(in bounds: CGSize) -> CGFloat {
        let oy = offset?.height ?? 0
        let maxNegative = -(bounds.height - size - 16) // 16pt margin top
        let maxPositive: CGFloat = -bottomInset         // reserve space for tab bar
        return min(max(oy, maxNegative), maxPositive)
    }

    // MARK: - Persistence

    private func savePosition() {
        guard let o = offset else { return }
        let d = UserDefaults.standard
        d.set(Double(o.width), forKey: "\(positionKey).x")
        d.set(Double(o.height), forKey: "\(positionKey).y")
    }

    /// Load saved position; if none stored, default to vertical CENTER on the
    /// right edge (most ergonomic for right-thumb reach on iPhone).
    private func loadPosition(defaultFor bounds: CGSize) {
        let d = UserDefaults.standard
        if let x = d.object(forKey: "\(positionKey).x") as? Double,
           let y = d.object(forKey: "\(positionKey).y") as? Double {
            offset = CGSize(width: x, height: y)
        } else {
            // Bottom-trailing anchor → offset.height negative moves up.
            // Center vertical = -(bounds.height / 2 - size / 2 - bottomInset / 2)
            let centerY = -(bounds.height / 2 - size / 2)
            offset = CGSize(width: -16, height: centerY)
        }
    }

    private func startPulseIfNeeded() {
        if isActive { pulse = true }
    }
}
