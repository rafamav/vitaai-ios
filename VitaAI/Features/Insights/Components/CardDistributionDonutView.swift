import SwiftUI
import Charts

/// Donut chart (SectorMark, iOS 17+) showing the distribution of flashcard states:
/// Novo / Aprendendo / Revisão / Dominado.
struct CardDistributionDonutView: View {
    let categories: [CardCategory]

    private var totalCards: Int {
        categories.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Distribuição de Cards")
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)

                HStack(alignment: .center, spacing: 16) {
                    // Donut chart with center label
                    ZStack {
                        Chart(categories) { cat in
                            SectorMark(
                                angle: .value("Qtd", cat.count),
                                innerRadius: .ratio(0.60),
                                angularInset: 2
                            )
                            .foregroundStyle(cat.color)
                            .cornerRadius(3)
                        }
                        .frame(width: 110, height: 110)

                        // Center: total cards
                        VStack(spacing: 0) {
                            Text("\(totalCards)")
                                .font(.system(size: 20, weight: .bold))
                                .monospacedDigit()
                                .foregroundStyle(VitaColors.textPrimary)
                            Text("cards")
                                .font(.system(size: 9))
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                    }

                    // Legend
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(categories) { cat in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(cat.color)
                                    .frame(width: 10, height: 10)

                                Text(cat.name)
                                    .font(VitaTypography.labelSmall)
                                    .foregroundStyle(VitaColors.textSecondary)

                                Spacer()

                                Text("\(cat.count)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .monospacedDigit()
                                    .foregroundStyle(VitaColors.textPrimary)

                                let pct = totalCards > 0
                                    ? Int(Double(cat.count) / Double(totalCards) * 100)
                                    : 0
                                Text("(\(pct)%)")
                                    .font(.system(size: 9))
                                    .foregroundStyle(VitaColors.textTertiary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
        }
    }
}
