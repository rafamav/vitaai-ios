import SwiftUI

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        self
            .background(Color.white.opacity(0.04))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
    }

    /// FadeUp entrance animation — matches mockup section-by-section reveal.
    /// Usage: .fadeUpAppear(delay: 0.15)
    func fadeUpAppear(delay: Double = 0) -> some View {
        modifier(FadeUpAppearModifier(delay: delay))
    }
}

// MARK: - FadeUp Appear Modifier
// Animates: opacity 0→1 + translateY +16px→0 (easeOut 0.40s)
// Matches mockup .section fadeInUp keyframe animation
private struct FadeUpAppearModifier: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 0.40).delay(delay)
                ) {
                    appeared = true
                }
            }
    }
}
