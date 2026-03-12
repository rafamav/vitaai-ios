import SwiftUI

// MARK: - VitaButton Variants & Sizes
// Gold theme: primary uses goldGradient from VitaColors.
// Matches mockup .ob-cta: background linear-gradient(135deg, rgba(200,160,80,0.75), rgba(220,180,100,0.65))
// Text on primary: dark (rgba(26,20,18,0.95)) for contrast on gold background.

enum VitaButtonVariant {
    case primary
    case secondary
    case ghost
    case danger
}

enum VitaButtonSize {
    case sm
    case md
    case lg

    var height: CGFloat {
        switch self {
        case .sm: return 32
        case .md: return 44
        case .lg: return 52
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .sm: return 12
        case .md: return 16
        case .lg: return 24
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .sm: return 6
        case .md: return 10
        case .lg: return 14
        }
    }

    var font: Font {
        switch self {
        case .sm: return VitaTypography.labelSmall
        case .md: return VitaTypography.labelLarge
        case .lg: return VitaTypography.titleSmall
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .sm: return 16
        case .md: return 20
        case .lg: return 24
        }
    }
}

// MARK: - VitaButton

/// Unified button component for VitaAI.
///
/// Variants:
/// - `primary`   — filled accent background, dark text
/// - `secondary` — outlined with accent border, accent text
/// - `ghost`     — transparent, accent text, no border
/// - `danger`    — filled red background, white text
///
/// Sizes: `sm` (32pt), `md` (44pt), `lg` (52pt). All enforce 44pt min touch target.
struct VitaButton: View {
    let text: String
    let action: () -> Void
    var variant: VitaButtonVariant = .primary
    var size: VitaButtonSize = .md
    var isEnabled: Bool = true
    var isLoading: Bool = false
    var leadingSystemImage: String? = nil

    private static let dangerColor = VitaColors.dataRed

    private var isInteractable: Bool { isEnabled && !isLoading }

    private var foregroundColor: Color {
        switch variant {
        case .primary:
            // Dark text on gold background (contrast) — rgba(26,20,18,0.95) from mockup
            return isInteractable
                ? Color(red: 0.102, green: 0.078, blue: 0.071).opacity(0.95)
                : Color(red: 0.102, green: 0.078, blue: 0.071).opacity(0.38)
        case .secondary, .ghost:
            return isInteractable ? VitaColors.goldText : VitaColors.goldText.opacity(0.38)
        case .danger:
            return isInteractable ? VitaColors.white : VitaColors.white.opacity(0.38)
        }
    }

    private var borderColor: Color {
        switch variant {
        case .secondary:
            return isInteractable
                ? VitaColors.accent.opacity(0.50)
                : VitaColors.accent.opacity(0.20)
        default:
            return .clear
        }
    }

    var body: some View {
        Button(action: { if isInteractable { action() } }) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .frame(width: size.iconSize, height: size.iconSize)
                        .scaleEffect(size.iconSize / 20)
                } else if let icon = leadingSystemImage {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize - 2, weight: .medium))
                        .foregroundColor(foregroundColor)
                }

                Text(text)
                    .font(size.font)
                    .foregroundColor(foregroundColor)
            }
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: max(size.height, 44))
        }
        .background {
            switch variant {
            case .primary:
                // Gold gradient from mockup .ob-cta
                if isInteractable {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(VitaColors.goldGradient)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(VitaColors.accent.opacity(0.30))
                }
            case .secondary, .ghost:
                Color.clear
            case .danger:
                RoundedRectangle(cornerRadius: 12)
                    .fill(isInteractable ? Self.dangerColor : Self.dangerColor.opacity(0.38))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
        .disabled(!isInteractable)
        .animation(.easeInOut(duration: 0.15), value: isInteractable)
        .animation(.easeInOut(duration: 0.15), value: isLoading)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("VitaButton variants") {
    VStack(spacing: 16) {
        VitaButton(text: "Primary", action: {}, variant: .primary, size: .md)
        VitaButton(text: "Secondary", action: {}, variant: .secondary, size: .md)
        VitaButton(text: "Ghost", action: {}, variant: .ghost, size: .md)
        VitaButton(text: "Danger", action: {}, variant: .danger, size: .md)
        VitaButton(text: "Loading…", action: {}, variant: .primary, size: .md, isLoading: true)
        VitaButton(text: "Disabled", action: {}, variant: .primary, size: .md, isEnabled: false)
        VitaButton(text: "With icon", action: {}, variant: .primary, size: .lg, leadingSystemImage: "arrow.right")
        HStack {
            VitaButton(text: "Sm", action: {}, variant: .secondary, size: .sm)
            VitaButton(text: "Md", action: {}, variant: .secondary, size: .md)
            VitaButton(text: "Lg", action: {}, variant: .secondary, size: .lg)
        }
    }
    .padding()
    .background(VitaColors.surface)
}
#endif
