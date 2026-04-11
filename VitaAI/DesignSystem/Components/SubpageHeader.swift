import SwiftUI

// MARK: - subpageHeader
//
// Minimal header for push-navigation subpages. Back chevron on the left,
// title centered. Matches the Vita gold-glass aesthetic without the XP ring
// / avatar weight of VitaTopBar (which is reserved for root tab entries).

@ViewBuilder
func subpageHeader(title: String, onBack: @escaping () -> Void) -> some View {
    HStack(spacing: 8) {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VitaColors.accentHover.opacity(0.85))
                .frame(width: 32, height: 32)
                .background(
                    Circle().fill(VitaColors.glassInnerLight.opacity(0.06))
                )
                .overlay(
                    Circle().stroke(VitaColors.accentHover.opacity(0.14), lineWidth: 0.8)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("backButton")

        Text(title)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(VitaColors.textPrimary)
            .kerning(-0.3)

        Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.top, 8)
    .padding(.bottom, 10)
}
