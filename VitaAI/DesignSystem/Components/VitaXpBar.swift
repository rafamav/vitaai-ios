import SwiftUI

// MARK: - VitaXpBar

/// XP progress bar showing level progress and daily goal.
///
/// Renders two animated horizontal bars:
/// - **Level bar** (8pt, cyan gradient): progress through current level (800ms ease-out cubic)
/// - **Daily bar** (4pt, amber): daily XP goal progress (600ms, 100ms delay)
///
/// Mirrors Android VitaXpBar.kt — teal gradient + EaseOutCubic timing.
///
/// Usage:
/// ```swift
/// VitaXpBar(userProgress: viewModel.userProgress)
/// ```
struct VitaXpBar: View {
    let userProgress: UserProgress

    @State private var levelAnimated: Double = 0
    @State private var dailyAnimated: Double = 0

    // EaseOutCubic equivalent: cubic-bezier(0.22, 1, 0.36, 1)
    private var easeOutCubic: Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: 0.8)
    }
    private var dailyAnimation: Animation {
        .timingCurve(0.22, 1, 0.36, 1, duration: 0.6).delay(0.1)
    }

    var body: some View {
        VStack(spacing: 10) {
            levelRow
            dailyGoalRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear { animate() }
        .onChange(of: userProgress.currentLevelXp) { _, _ in animateLevel() }
        .onChange(of: userProgress.dailyXp) { _, _ in animateDaily() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Level Row

    private var levelRow: some View {
        HStack(alignment: .center, spacing: 10) {
            levelBadge(level: userProgress.level)

            VStack(alignment: .leading, spacing: 5) {
                levelProgressBar
                xpLabel
            }

            nextLevelBadge(level: userProgress.level + 1)
        }
    }

    private var levelProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 4)
                    .fill(VitaColors.surfaceBorder)
                    .frame(height: 8)

                // Animated fill — cyan gradient
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [VitaColors.accentDark, VitaColors.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(geo.size.width * levelAnimated, levelAnimated > 0 ? 8 : 0), height: 8)
                    .shadow(color: VitaColors.accent.opacity(0.35), radius: 4, y: 0)
            }
        }
        .frame(height: 8)
    }

    private var xpLabel: some View {
        HStack {
            Text("Nível \(userProgress.level)")
                .font(VitaTypography.labelSmall)
                .foregroundColor(VitaColors.textSecondary)
            Spacer()
            Text("\(userProgress.currentLevelXp) / \(userProgress.currentLevelXp + userProgress.xpToNextLevel) XP")
                .font(VitaTypography.labelSmall)
                .foregroundColor(VitaColors.textTertiary)
        }
    }

    // MARK: - Daily Goal Row

    private var dailyGoalRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(VitaColors.dataAmber)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(VitaColors.surfaceBorder)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(VitaColors.dataAmber)
                        .frame(width: max(geo.size.width * dailyAnimated, dailyAnimated > 0 ? 4 : 0), height: 4)
                        .shadow(color: VitaColors.dataAmber.opacity(0.4), radius: 3, y: 0)
                }
            }
            .frame(height: 4)

            Text("\(userProgress.dailyXp)/\(userProgress.dailyGoal) XP")
                .font(VitaTypography.labelSmall)
                .foregroundColor(VitaColors.textTertiary)
                .fixedSize()
        }
    }

    // MARK: - Sub-views

    private func levelBadge(level: Int) -> some View {
        ZStack {
            Circle()
                .fill(VitaColors.accent.opacity(0.12))
                .frame(width: 38, height: 38)
            Circle()
                .stroke(VitaColors.accent, lineWidth: 1.5)
                .frame(width: 38, height: 38)
            Text("\(level)")
                .font(VitaTypography.titleSmall)
                .foregroundColor(VitaColors.accent)
                .monospacedDigit()
        }
    }

    private func nextLevelBadge(level: Int) -> some View {
        ZStack {
            Circle()
                .fill(VitaColors.surfaceBorder)
                .frame(width: 28, height: 28)
            Text("\(level)")
                .font(VitaTypography.labelSmall)
                .foregroundColor(VitaColors.textTertiary)
                .monospacedDigit()
        }
    }

    // MARK: - Animation

    private func animate() {
        withAnimation(easeOutCubic) { levelAnimated = userProgress.levelProgress }
        withAnimation(dailyAnimation) { dailyAnimated = userProgress.dailyProgress }
    }

    private func animateLevel() {
        withAnimation(easeOutCubic) { levelAnimated = userProgress.levelProgress }
    }

    private func animateDaily() {
        withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.6)) {
            dailyAnimated = userProgress.dailyProgress
        }
    }

    private var accessibilityDescription: String {
        "Nível \(userProgress.level), \(userProgress.currentLevelXp) de \(userProgress.currentLevelXp + userProgress.xpToNextLevel) XP. Meta diária: \(userProgress.dailyXp) de \(userProgress.dailyGoal) XP."
    }
}

// MARK: - Preview

#if DEBUG
#Preview("VitaXpBar") {
    let progress = UserProgress(
        totalXp: 1_250,
        level: 5,
        currentLevelXp: 400,
        xpToNextLevel: 450,
        currentStreak: 7,
        badges: [],
        dailyXp: 35,
        dailyGoal: 50
    )

    ZStack {
        VitaColors.surface.ignoresSafeArea()
        VStack(spacing: 20) {
            VitaGlassCard {
                VitaXpBar(userProgress: progress)
            }
            .padding(.horizontal, 20)

            // Edge cases
            VitaGlassCard {
                VitaXpBar(userProgress: UserProgress(level: 1, currentLevelXp: 0, xpToNextLevel: 100, dailyXp: 0))
            }
            .padding(.horizontal, 20)

            VitaGlassCard {
                VitaXpBar(userProgress: UserProgress(level: 16, currentLevelXp: 980, xpToNextLevel: 20, dailyXp: 50, dailyGoal: 50))
            }
            .padding(.horizontal, 20)
        }
    }
}
#endif
