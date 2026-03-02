import SwiftUI

// MARK: - Shimmer Modifier

/// A shimmer animation modifier that sweeps a highlight gradient across any view.
///
/// Usage:
/// ```swift
/// RoundedRectangle(cornerRadius: 10)
///     .shimmer()
/// ```
struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            VitaColors.glassHighlight,
                            .clear,
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: phase * geo.size.width * 2)
                }
                .clipped()
                .allowsHitTesting(false)
            )
            .onAppear {
                withAnimation(
                    .linear(duration: 1.2)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
            .accessibilityLabel("Carregando")
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - ShimmerBox

/// Rectangular shimmer placeholder — mirrors Android ShimmerBox.
///
/// Parameters match Android defaults: height=48, cornerRadius=14.
struct ShimmerBox: View {
    var height: CGFloat = 48
    var cornerRadius: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(VitaColors.surfaceElevated)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .shimmer()
    }
}

// MARK: - ShimmerText

/// Text-line shimmer placeholder — mirrors Android ShimmerText.
struct ShimmerText: View {
    var width: CGFloat = 120
    var height: CGFloat = 14

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(VitaColors.surfaceElevated)
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - ShimmerCircle

/// Circular shimmer placeholder — mirrors Android ShimmerCircle.
struct ShimmerCircle: View {
    var size: CGFloat = 40

    var body: some View {
        Circle()
            .fill(VitaColors.surfaceElevated)
            .frame(width: size, height: size)
            .shimmer()
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Shimmer primitives") {
    VStack(spacing: 20) {
        ShimmerBox(height: 48, cornerRadius: 14)
            .padding(.horizontal, 24)

        HStack(spacing: 12) {
            ShimmerCircle(size: 44)
            VStack(alignment: .leading, spacing: 6) {
                ShimmerText(width: 130, height: 14)
                ShimmerText(width: 80, height: 10)
            }
        }
        .padding(.horizontal, 24)

        ShimmerBox(height: 96, cornerRadius: 18)
            .padding(.horizontal, 24)
    }
    .padding(.vertical, 32)
    .background(VitaColors.surface)
}
#endif
