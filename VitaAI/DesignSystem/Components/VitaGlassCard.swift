import SwiftUI

struct VitaGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    private let cornerRadius: CGFloat = VitaTokens.Components.GlassCard.radius  // 14

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background(VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
            .overlay(alignment: .top) {
                // Top-edge highlight
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, VitaColors.glassHighlight, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 24)
            }
            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
    }
}
