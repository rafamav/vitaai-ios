import SwiftUI

// MARK: - VitaStreakBadge

/// Streak badge with animated flame for active streaks.
///
/// - Active (streak > 0): amber flame with infinite pulse scale 1.0→1.12 at 800ms
/// - Inactive (streak == 0): gray outline capsule
///
/// Mirrors Android VitaStreakBadge.kt:
/// - Active: DataAmber + FastOutSlowInEasing infinite pulse
/// - Inactive: gray outline variant
///
/// Usage:
/// ```swift
/// VitaStreakBadge(streak: userProgress.currentStreak)
/// VitaStreakBadge(streak: userProgress.currentStreak, size: .sm)
/// ```
struct VitaStreakBadge: View {
    let streak: Int
    var size: VitaStreakBadgeSize = .md

    @State private var pulseScale: CGFloat = 1.0

    private var isActive: Bool { streak > 0 }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundColor(isActive ? VitaColors.dataAmber : VitaColors.textTertiary)
                .scaleEffect(pulseScale)
                .animation(
                    isActive
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: pulseScale
                )

            Text("\(streak)")
                .font(size.labelFont)
                .foregroundColor(isActive ? VitaColors.dataAmber : VitaColors.textTertiary)
                .monospacedDigit()
        }
        .padding(.horizontal, size.horizontalPadding)
        .padding(.vertical, size.verticalPadding)
        .background(
            isActive
                ? VitaColors.dataAmber.opacity(0.12)
                : VitaColors.surfaceBorder.opacity(0.5)
        )
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(
                    isActive ? VitaColors.dataAmber.opacity(0.3) : VitaColors.surfaceBorder,
                    lineWidth: 1
                )
        )
        .accessibilityLabel(
            isActive
                ? "Sequência de \(streak) \(streak == 1 ? "dia" : "dias")"
                : "Sem sequência ativa"
        )
        .task {
            if isActive {
                // Brief delay so animation starts after view settles
                try? await Task.sleep(for: .milliseconds(200))
                pulseScale = 1.12
            }
        }
        .onChange(of: isActive) { _, active in
            pulseScale = active ? 1.12 : 1.0
        }
    }
}

// MARK: - VitaStreakBadgeSize

enum VitaStreakBadgeSize {
    case sm
    case md

    var iconSize: CGFloat {
        switch self {
        case .sm: return 12
        case .md: return 16
        }
    }

    var labelFont: Font {
        switch self {
        case .sm: return VitaTypography.labelSmall
        case .md: return VitaTypography.labelLarge
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .sm: return 8
        case .md: return 12
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .sm: return 4
        case .md: return 7
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("VitaStreakBadge") {
    ZStack {
        VitaColors.surface.ignoresSafeArea()

        VStack(spacing: 24) {
            Group {
                Text("Active streaks").font(VitaTypography.labelMedium).foregroundColor(VitaColors.textSecondary)
                HStack(spacing: 12) {
                    VitaStreakBadge(streak: 1)
                    VitaStreakBadge(streak: 7)
                    VitaStreakBadge(streak: 30)
                    VitaStreakBadge(streak: 365)
                }
            }

            Group {
                Text("Small size").font(VitaTypography.labelMedium).foregroundColor(VitaColors.textSecondary)
                HStack(spacing: 12) {
                    VitaStreakBadge(streak: 7, size: .sm)
                    VitaStreakBadge(streak: 0, size: .sm)
                }
            }

            Group {
                Text("Inactive").font(VitaTypography.labelMedium).foregroundColor(VitaColors.textSecondary)
                VitaStreakBadge(streak: 0)
            }
        }
        .padding()
    }
}
#endif
