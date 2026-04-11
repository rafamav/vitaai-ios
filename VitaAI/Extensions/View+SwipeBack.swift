import SwiftUI

// MARK: - Interactive swipe-back from anywhere
//
// Custom DragGesture that pops the navigation stack on a rightward horizontal
// swipe starting from ANYWHERE on the screen (not restricted to the left edge).
// The view follows the finger during the drag; on release past the threshold
// the nav action fires and NavigationStack handles the pop transition.
//
// Rules:
//   - Minimum horizontal drag: 12pt to start tracking
//   - Must be predominantly horizontal (dx > dy * 1.2) and rightward (dx > 0)
//   - Release past 30% screen width → fires onBack
//   - Below threshold → spring snap-back
//   - `.simultaneousGesture` keeps ScrollView vertical pan working

extension View {
    /// Enables interactive swipe-right-from-anywhere to pop the nav stack.
    func swipeBack(onBack: @escaping () -> Void) -> some View {
        modifier(InteractiveSwipeBackModifier(onBack: onBack))
    }
}

private struct InteractiveSwipeBackModifier: ViewModifier {
    let onBack: () -> Void

    @State private var dragX: CGFloat = 0
    @State private var isTracking: Bool = false

    func body(content: Content) -> some View {
        content
            .offset(x: dragX)
            .simultaneousGesture(
                DragGesture(minimumDistance: 12, coordinateSpace: .local)
                    .onChanged { value in
                        let dx = value.translation.width
                        let dy = abs(value.translation.height)

                        // Lock into horizontal-right mode on first qualifying move
                        if !isTracking {
                            if dx > 8 && dx > dy * 1.2 {
                                isTracking = true
                            } else {
                                return
                            }
                        }

                        dragX = max(0, dx)
                    }
                    .onEnded { value in
                        guard isTracking else {
                            dragX = 0
                            return
                        }
                        isTracking = false

                        let dx = value.translation.width
                        let screenW = UIScreen.main.bounds.width
                        let threshold = screenW * 0.30

                        if dx > threshold {
                            // Reset offset immediately so we don't compete with
                            // NavigationStack's native pop animation.
                            dragX = 0
                            onBack()
                        } else {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                                dragX = 0
                            }
                        }
                    }
            )
    }
}
