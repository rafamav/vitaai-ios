import SwiftUI

// MARK: - VitaBadgeGrid

/// 4-column grid of achievement badges.
///
/// - **Earned** badges: colored icon + full opacity
/// - **Locked** badges: lock icon + grayscale (0.4 opacity)
/// - **Tap** any badge to show a detail bottom sheet with icon, name, description and earned date
///
/// Mirrors Android VitaBadgeGrid.kt:
/// - 4-column LazyVerticalGrid
/// - Circular 52pt icons (Android: 48dp)
/// - Detail sheet with 80pt icon (Android: 72dp)
/// - Haptic feedback on tap
///
/// Usage:
/// ```swift
/// VitaBadgeGrid(badges: userProgress.badges)
/// ```
struct VitaBadgeGrid: View {
    let badges: [VitaBadge]

    @State private var selectedBadge: VitaBadge?

    private let columns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: 4
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(badges) { badge in
                _BadgeCell(badge: badge)
                    .onTapGesture {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        selectedBadge = badge
                    }
            }
        }
        .sheet(item: $selectedBadge) { badge in
            _BadgeDetailSheet(badge: badge)
                .presentationDetents([.medium])
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(24)
        }
        .accessibilityIdentifier("vitaBadgeGrid")
    }
}

// MARK: - _BadgeCell

private struct _BadgeCell: View {
    let badge: VitaBadge

    var body: some View {
        VStack(spacing: 6) {
            // Icon circle
            ZStack {
                Circle()
                    .fill(badge.isEarned ? badge.category.color.opacity(0.15) : VitaColors.surfaceBorder)
                    .frame(width: 52, height: 52)

                if badge.isEarned {
                    Image(systemName: badge.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(badge.category.color)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(VitaColors.textTertiary)
                }
            }
            .overlay(
                Circle()
                    .stroke(
                        badge.isEarned ? badge.category.color.opacity(0.3) : Color.clear,
                        lineWidth: 1.5
                    )
            )

            // Name label
            Text(badge.name)
                .font(VitaTypography.labelSmall)
                .foregroundColor(badge.isEarned ? VitaColors.textPrimary : VitaColors.textTertiary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(badge.isEarned ? 1.0 : 0.4)
        .accessibilityLabel(
            badge.isEarned
                ? "\(badge.name), conquistado"
                : "\(badge.name), bloqueado"
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Toque para ver detalhes")
    }
}

// MARK: - _BadgeDetailSheet

private struct _BadgeDetailSheet: View {
    let badge: VitaBadge
    @Environment(\.dismiss) private var dismiss

    private var earnedDateText: String? {
        guard let date = badge.earnedAt else { return nil }
        let f = DateFormatter()
        f.dateStyle = .long
        f.locale = Locale(identifier: "pt_BR")
        return "Conquistado em \(f.string(from: date))"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            RoundedRectangle(cornerRadius: 2.5)
                .fill(VitaColors.textTertiary)
                .frame(width: 36, height: 4)
                .padding(.top, 14)
                .padding(.bottom, 28)

            // Large badge icon (80pt — Android: 72dp)
            ZStack {
                Circle()
                    .fill(badge.isEarned ? badge.category.color.opacity(0.15) : VitaColors.surfaceBorder)
                    .frame(width: 80, height: 80)

                if badge.isEarned {
                    Image(systemName: badge.icon)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundColor(badge.category.color)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(VitaColors.textTertiary)
                }
            }
            .overlay(
                Circle()
                    .stroke(
                        badge.isEarned ? badge.category.color.opacity(0.3) : Color.clear,
                        lineWidth: 2
                    )
            )
            .padding(.bottom, 20)

            // Info
            VStack(spacing: 8) {
                Text(badge.name)
                    .font(VitaTypography.headlineSmall)
                    .foregroundColor(VitaColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(badge.description)
                    .font(VitaTypography.bodyMedium)
                    .foregroundColor(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if let dateText = earnedDateText {
                    Text(dateText)
                        .font(VitaTypography.labelMedium)
                        .foregroundColor(badge.category.color)
                        .padding(.top, 6)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .accessibilityIdentifier("vitaBadgeDetailSheet")
    }
}

// MARK: - Preview

#if DEBUG
private let previewBadges: [VitaBadge] = [
    VitaBadge(id: "first_review", name: "Primeira Revisão", description: "Complete sua primeira sessão de flashcards.", icon: "rectangle.stack.fill", earnedAt: Date().addingTimeInterval(-86_400 * 3), category: .cards),
    VitaBadge(id: "streak_3", name: "3 Dias Seguidos", description: "Mantenha uma sequência de 3 dias.", icon: "flame.fill", earnedAt: Date().addingTimeInterval(-86_400), category: .streak),
    VitaBadge(id: "streak_7", name: "Semana Perfeita", description: "Mantenha uma sequência de 7 dias.", icon: "flame.fill", earnedAt: nil, category: .streak),
    VitaBadge(id: "streak_30", name: "Mês Dedicado", description: "Mantenha uma sequência de 30 dias.", icon: "flame.fill", earnedAt: nil, category: .streak),
    VitaBadge(id: "cards_100", name: "Centurião", description: "Revise 100 flashcards.", icon: "100.circle.fill", earnedAt: nil, category: .cards),
    VitaBadge(id: "cards_500", name: "Mestre dos Cards", description: "Revise 500 flashcards.", icon: "star.circle.fill", earnedAt: nil, category: .cards),
    VitaBadge(id: "level_5", name: "Estudante Dedicado", description: "Alcance o nível 5.", icon: "graduationcap.fill", earnedAt: nil, category: .milestone),
    VitaBadge(id: "first_note", name: "Anotador", description: "Crie sua primeira nota.", icon: "note.text", earnedAt: Date(), category: .study),
    VitaBadge(id: "first_chat", name: "Curioso", description: "Envie sua primeira mensagem para Vita.", icon: "bubble.left.fill", earnedAt: Date().addingTimeInterval(-3600), category: .social),
    VitaBadge(id: "night_owl", name: "Coruja", description: "Estude após as 22h.", icon: "moon.fill", earnedAt: nil, category: .study),
    VitaBadge(id: "early_bird", name: "Madrugador", description: "Estude antes das 7h.", icon: "sunrise.fill", earnedAt: nil, category: .study),
    VitaBadge(id: "level_10", name: "Residente", description: "Alcance o nível 10.", icon: "cross.case.fill", earnedAt: nil, category: .milestone),
]

#Preview("VitaBadgeGrid") {
    ZStack {
        VitaColors.surface.ignoresSafeArea()
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Conquistas")
                    .font(VitaTypography.headlineSmall)
                    .foregroundColor(VitaColors.textPrimary)
                    .padding(.horizontal, 20)

                VitaBadgeGrid(badges: previewBadges)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 24)
        }
    }
}
#endif
