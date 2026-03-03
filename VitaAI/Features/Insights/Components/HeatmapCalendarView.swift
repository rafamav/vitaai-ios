import SwiftUI

/// GitHub-style contribution heatmap showing daily study intensity over the last 13 weeks.
/// Columns = weeks (left = oldest, right = newest). Rows = day of week (Sun–Sat).
struct HeatmapCalendarView: View {
    let days: [StudyDay]

    // MARK: - Layout constants
    private let cellSize: CGFloat = 10
    private let cellGap: CGFloat = 2
    private let numWeeks = 13
    /// Day labels: Domingo, Segunda … Sábado
    private let dayLabels = ["D", "S", "T", "Q", "Q", "S", "S"]

    // MARK: - Grid computation

    private var gridCells: [HeatmapCell] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1 // Sunday = first row
        let today = Date()

        // Find the Sunday that starts the current week
        let todayComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        guard
            let currentWeekSunday = calendar.date(from: todayComponents),
            let gridStart = calendar.date(byAdding: .day, value: -(numWeeks - 1) * 7, to: currentWeekSunday)
        else { return [] }

        // Build lookup: date string → minutes studied
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]
        let lookup: [String: Int] = Dictionary(
            uniqueKeysWithValues: days.map { (fmt.string(from: $0.date), $0.minutesStudied) }
        )

        var cells: [HeatmapCell] = []
        let totalCells = numWeeks * 7

        for i in 0..<totalCells {
            guard let date = calendar.date(byAdding: .day, value: i, to: gridStart) else { continue }
            let dateStr = fmt.string(from: date)

            if date > today {
                cells.append(HeatmapCell(id: "future-\(i)", minutes: 0, isFuture: true, isToday: false))
            } else {
                let minutes = lookup[dateStr] ?? 0
                let isToday = calendar.isDateInToday(date)
                cells.append(HeatmapCell(id: dateStr, minutes: minutes, isFuture: false, isToday: isToday))
            }
        }
        return cells
    }

    // MARK: - Color scale

    private func color(for minutes: Int, isFuture: Bool) -> Color {
        if isFuture { return Color.clear }
        switch minutes {
        case 0:        return VitaColors.surfaceElevated
        case 1...30:   return VitaColors.accent.opacity(0.25)
        case 31...60:  return VitaColors.accent.opacity(0.50)
        case 61...90:  return VitaColors.accent.opacity(0.75)
        default:       return VitaColors.accent
        }
    }

    // MARK: - Body

    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Histórico de Estudos")
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textPrimary)
                    Spacer()
                    Text("\(numWeeks)sem")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                HStack(alignment: .top, spacing: 4) {
                    // Day-of-week labels on the left
                    VStack(spacing: cellGap) {
                        ForEach(dayLabels, id: \.self) { label in
                            Text(label)
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(VitaColors.textTertiary)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }

                    // Grid of week columns — LazyHGrid fills left→right per row
                    LazyHGrid(
                        rows: Array(repeating: GridItem(.fixed(cellSize), spacing: cellGap), count: 7),
                        alignment: .top,
                        spacing: cellGap
                    ) {
                        ForEach(gridCells) { cell in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color(for: cell.minutes, isFuture: cell.isFuture))
                                .frame(width: cellSize, height: cellSize)
                                .overlay {
                                    if cell.isToday {
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(VitaColors.accent, lineWidth: 1)
                                    }
                                }
                        }
                    }
                }

                // Intensity legend
                HStack(spacing: 4) {
                    Text("Menos")
                        .font(.system(size: 7))
                        .foregroundStyle(VitaColors.textTertiary)
                    ForEach([0, 30, 60, 90, 120], id: \.self) { mins in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color(for: mins, isFuture: false))
                            .frame(width: cellSize, height: cellSize)
                    }
                    Text("Mais")
                        .font(.system(size: 7))
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            .padding(14)
        }
    }
}

// MARK: - Supporting types

private struct HeatmapCell: Identifiable {
    let id: String
    let minutes: Int
    let isFuture: Bool
    let isToday: Bool
}
