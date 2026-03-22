import SwiftUI

// MARK: - Fade-Up Appear Animation
// Staggered entrance animation: fade in + slide up from 12pt below.

extension View {
    func fadeUpAppear(delay: Double) -> some View {
        modifier(FadeUpAppearModifier(delay: delay))
    }
}

private struct FadeUpAppearModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 12)
            .animation(.easeOut(duration: 0.35).delay(delay), value: isVisible)
            .onAppear { isVisible = true }
    }
}
