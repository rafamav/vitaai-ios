import SwiftUI

// MARK: - ContinueStudyingCard
// Hero card displayed on Dashboard when the student has an active study session to resume.
// Design reference: vita-app.html hero card section.
// Model: ContinueStudyingItem is defined in DashboardModels.swift.

struct ContinueStudyingCard: View {
    let item: ContinueStudyingItem
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top: subject + type row
            headerRow

            // Progress bar
            progressRow
                .padding(.top, 14)

            // Insight
            insightRow
                .padding(.top, 12)

            // Badges row
            badgesRow
                .padding(.top, 10)

            // CTA button
            ctaButton
                .padding(.top, 16)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            // Slightly richer background than standard glass card to signal hero status
            LinearGradient(
                colors: [
                    VitaColors.accentSubtle.opacity(0.65),
                    VitaColors.glassBg
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(VitaColors.accent.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: VitaColors.accent.opacity(0.12), radius: 16, y: 6)
        .padding(.horizontal, 20)
    }

    // MARK: Sub-views

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            // Play icon circle
            ZStack {
                Circle()
                    .fill(VitaColors.accent.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: "play.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.accent)
                    .offset(x: 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(NSLocalizedString("continue_studying_title", comment: "Continue Studying"))
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.accent)
                    .kerning(0.8)
                    .textCase(.uppercase)

                Text("\(item.subject) · \(item.sessionType)")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
            }
        }
    }

    private var progressRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [VitaColors.accentLight, VitaColors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * item.progress, height: 6)
                }
            }
            .frame(height: 6)

            // Counter
            HStack {
                Text(String(format: NSLocalizedString("progress_cards_format", comment: "%d de %d cards"), item.cardsDone, item.cardsTotal))
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textTertiary)

                Spacer()

                Text("\(Int(item.progress * 100))%")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }
        }
    }

    private var insightRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.accentLight)

            Text(item.studyInsight)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var badgesRow: some View {
        HStack(spacing: 8) {
            // Streak badge — always shown
            badge(
                icon: "flame.fill",
                label: String(format: NSLocalizedString("streak_days_format", comment: "%d dias"), item.streakDays),
                foreground: VitaColors.badgeStreak,
                background: VitaColors.badgeStreak.opacity(0.15)
            )

            // Urgency badge — only when exam is soon
            if let days = item.daysUntilExam {
                badge(
                    icon: "exclamationmark.circle.fill",
                    label: String(format: NSLocalizedString("exam_days_format", comment: "Prova em %d dias"), days),
                    foreground: VitaColors.badgeUrgency,
                    background: VitaColors.badgeUrgency.opacity(0.15)
                )
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func badge(icon: String, label: String, foreground: Color, background: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(foreground)

            Text(label)
                .font(VitaTypography.labelSmall)
                .foregroundStyle(foreground)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(background)
        .clipShape(Capsule())
    }

    private var ctaButton: some View {
        Button(action: onContinue) {
            HStack(spacing: 8) {
                Text(NSLocalizedString("continue_studying_cta", comment: "CONTINUAR ESTUDANDO"))
                    .font(VitaTypography.labelLarge)
                    .kerning(0.5)

                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(VitaColors.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                LinearGradient(
                    colors: [VitaColors.ctaGold, VitaColors.accentDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: VitaColors.accent.opacity(0.30), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}
