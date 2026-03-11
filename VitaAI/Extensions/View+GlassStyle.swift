import SwiftUI

extension View {
    func glassCard(cornerRadius: CGFloat = VitaTokens.Components.GlassCard.radius) -> some View {
        self
            .background(VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
    }
}
