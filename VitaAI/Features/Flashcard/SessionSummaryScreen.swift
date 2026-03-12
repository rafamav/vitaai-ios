import SwiftUI

// MARK: - SessionSummaryScreen

struct SessionSummaryScreen: View {

    let deckTitle: String
    let result: FlashcardSessionResult
    let elapsedSeconds: Int
    var onBack: () -> Void
    var onRestart: () -> Void = {}

    // Count-up animated display values
    @State private var displayedCards: Double = 0
    @State private var displayedAccuracy: Double = 0
    @State private var displayedTime: Double = 0
    @State private var displayedStreak: Double = 0

    // Gradient for primary CTA — gold theme (matches web / Android gold→warm)
    private let ctaGradient = LinearGradient(
        colors: [VitaColors.accent, VitaColors.accentDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Trophy / check icon
            trophyIcon

            Spacer().frame(height: 20)

            // Title + subtitle
            VStack(spacing: 4) {
                Text(titleText)
                    .font(VitaTypography.headlineSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(deckTitle)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }

            if result.totalCards > 0 {
                Spacer().frame(height: 28)

                // 2x2 stats grid
                statsGrid
            }

            Spacer().frame(height: 36)

            // Action buttons
            actionButtons
                .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VitaColors.surface.ignoresSafeArea())
        .onAppear { animateCounters() }
    }

    // MARK: Trophy Icon

    private var trophyIcon: some View {
        let isBg    = result.isPerfect ? VitaColors.accent.opacity(0.12)  : VitaColors.glassBg
        let iBorder = result.isPerfect ? VitaColors.accent.opacity(0.20)  : VitaColors.glassBorder
        let iColor  = result.isPerfect ? VitaColors.accent : VitaColors.textSecondary

        return ZStack {
            Circle()
                .fill(isBg)
                .overlay(Circle().stroke(iBorder, lineWidth: 1))
                .frame(width: 64, height: 64)

            Image(systemName: result.isPerfect ? "star.fill" : "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(iColor)
        }
    }

    // MARK: Title

    private var titleText: String {
        if result.totalCards == 0 { return "Nenhum card para revisar" }
        return result.isPerfect ? "Sessão perfeita!" : "Sessão concluída!"
    }

    // MARK: Stats Grid

    private var statsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatCard(
                    label: "CARDS REVISADOS",
                    value: "\(Int(displayedCards.rounded()))",
                    color: VitaColors.textPrimary
                )
                StatCard(
                    label: "TEMPO",
                    value: formattedDuration(Int(displayedTime.rounded())),
                    color: VitaColors.textSecondary
                )
            }
            HStack(spacing: 10) {
                StatCard(
                    label: "ACERTO",
                    value: "\(Int(displayedAccuracy.rounded()))%",
                    color: VitaColors.dataGreen
                )
                StatCard(
                    label: "MELHOR STREAK",
                    value: "\(Int(displayedStreak.rounded()))",
                    color: VitaColors.dataAmber
                )
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 10) {
            // Secondary: restart
            Button(action: onRestart) {
                Text("Revisar de novo")
                    .font(VitaTypography.labelLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(VitaColors.glassBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            // Primary: back with gradient
            Button(action: onBack) {
                Text("Voltar")
                    .font(VitaTypography.labelLarge)
                    .foregroundStyle(VitaColors.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ctaGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Helpers

    private func formattedDuration(_ secs: Int) -> String {
        let m = secs / 60
        let s = secs % 60
        if m == 0 { return "\(s)s" }
        return "\(m)m \(String(format: "%02d", s))s"
    }

    private func animateCounters() {
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            displayedCards = Double(result.totalCards)
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.3)) {
            displayedTime = Double(elapsedSeconds)
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
            displayedAccuracy = Double(result.accuracy)
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.5)) {
            displayedStreak = Double(result.streakCount)
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(color)
                .monospacedDigit()

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .kerning(0.5)
                .foregroundStyle(VitaColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }
}
