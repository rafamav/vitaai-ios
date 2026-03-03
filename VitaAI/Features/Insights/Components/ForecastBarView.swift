import SwiftUI
import Charts

/// Bar chart showing the forecasted number of flashcard reviews for the next 7 days.
/// Today's bar is highlighted in accent; future bars use a muted accent variant.
struct ForecastBarView: View {
    let days: [ForecastDay]

    private let calendar = Calendar.current

    // MARK: - Helpers

    private func barColor(for date: Date) -> Color {
        if calendar.isDateInToday(date) { return VitaColors.accent }
        return VitaColors.accent.opacity(0.40)
    }

    private func axisLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Hoje" }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "pt_BR")
        fmt.dateFormat = "EEE"
        // First letter uppercased, 3 chars max
        let raw = fmt.string(from: date)
        return String(raw.prefix(3)).capitalized
    }

    // MARK: - Chart data

    /// Wraps ForecastDay with a stable String label for x-axis ordering.
    private struct BarItem: Identifiable {
        let id: Int
        let label: String
        let cardsCount: Int
        let date: Date
    }

    private var barItems: [BarItem] {
        days.enumerated().map { idx, day in
            BarItem(id: idx, label: axisLabel(for: day.date), cardsCount: day.cardsCount, date: day.date)
        }
    }

    // MARK: - Body

    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Previsão de Revisão")
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textPrimary)
                    Spacer()
                    Text("7 dias")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Chart(barItems) { item in
                    BarMark(
                        x: .value("Dia", item.id),
                        y: .value("Cards", item.cardsCount)
                    )
                    .foregroundStyle(barColor(for: item.date))
                    .cornerRadius(4)
                    .annotation(position: .top, alignment: .center) {
                        if item.cardsCount > 0 {
                            Text("\(item.cardsCount)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(VitaColors.textSecondary)
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: barItems.map(\.id)) { value in
                        AxisValueLabel {
                            if let i = value.as(Int.self), i < barItems.count {
                                Text(barItems[i].label)
                                    .font(.system(size: 9))
                                    .foregroundStyle(
                                        calendar.isDateInToday(barItems[i].date)
                                            ? VitaColors.accent
                                            : VitaColors.textTertiary
                                    )
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(VitaColors.surfaceBorder)
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)")
                                    .font(.system(size: 8))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                        }
                    }
                }
                .frame(height: 110)

                // Legend
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(VitaColors.accent)
                            .frame(width: 10, height: 10)
                        Text("Hoje")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(VitaColors.accent.opacity(0.40))
                            .frame(width: 10, height: 10)
                        Text("Próximos dias")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    Spacer()
                }
            }
            .padding(14)
        }
    }
}
