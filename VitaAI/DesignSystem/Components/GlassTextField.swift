import SwiftUI

struct GlassTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String?

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(VitaColors.textTertiary)
                    .frame(width: 20)
            }

            TextField(placeholder, text: $text)
                .foregroundStyle(VitaColors.textPrimary)
                .font(VitaTypography.bodyMedium)
                .tint(VitaColors.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Components.GlassCard.radius))
        .overlay(
            RoundedRectangle(cornerRadius: VitaTokens.Components.GlassCard.radius)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }
}
