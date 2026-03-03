import SwiftUI
import Charts

// MARK: - FlashcardStatsView
// Mirrors Android FlashcardStatsScreen. Requires iOS 17+ (Swift Charts, @Observable).

struct FlashcardStatsView: View {

    var onBack: () -> Void
    @Environment(\.appContainer) private var container
    @State private var viewModel: FlashcardStatsViewModel?

    // Staggered entry animation
    @State private var appeared = false

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            if let vm = viewModel {
                VStack(spacing: 0) {
                    statsTopBar
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)

                    if vm.isLoading {
                        StatsLoadingSkeleton()
                    } else {
                        statsContent(vm: vm)
                    }
                }
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = FlashcardStatsViewModel(api: container.api)
                viewModel = vm
                Task { @MainActor in await vm.load() }
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) {
                appeared = true
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Top Bar

    private var statsTopBar: some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
                Image(systemName: "arrow.backward")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("Estatísticas dos Flashcards")
                .font(VitaTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundStyle(VitaColors.textPrimary)

            Spacer()
        }
    }

    // MARK: - Scrollable content

    @ViewBuilder
    private func statsContent(vm: FlashcardStatsViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                // Row 1: Total, Hoje, Taxa de retenção
                topStatRow(vm: vm)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.3), value: appeared)

                // Mapa de Atividade (heatmap)
                if !vm.reviewsPerDay.isEmpty {
                    GlassStatsSection(title: "Mapa de Atividade") {
                        FlashcardHeatmapView(reviewsPerDay: vm.reviewsPerDay)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.3).delay(0.08), value: appeared)
                }

                // Retenção ao longo do tempo
                if !vm.dailyRetention.isEmpty {
                    GlassStatsSection(title: "Retenção ao Longo do Tempo") {
                        RetentionLineChartView(data: vm.dailyRetention)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.3).delay(0.16), value: appeared)
                }

                // Previsão próximos 7 dias
                if vm.forecastNext7Days.contains(where: { $0 > 0 }) {
                    GlassStatsSection(title: "Previsão — Próximos 7 Dias") {
                        ForecastBarChartView(forecast: vm.forecastNext7Days)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.3).delay(0.24), value: appeared)
                }

                // Distribuição dos cards
                if vm.totalCards > 0 {
                    GlassStatsSection(title: "Distribuição dos Cards") {
                        FlashcardDistributionDonutView(
                            newCards: vm.newCards,
                            youngCards: vm.youngCards,
                            matureCards: vm.matureCards
                        )
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 16)
                    .animation(.easeOut(duration: 0.3).delay(0.32), value: appeared)
                }

                // Row 2: Streak, Tempo, Total revisões
                bottomStatRow(vm: vm)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.easeOut(duration: 0.3).delay(0.40), value: appeared)

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Stat Rows

    private func topStatRow(vm: FlashcardStatsViewModel) -> some View {
        HStack(spacing: 10) {
            MiniStatCard(
                label: "TOTAL",
                value: "\(vm.totalCards)",
                subtitle: "cards"
            )
            MiniStatCard(
                label: "HOJE",
                value: "\(vm.todayReviews)",
                subtitle: "revisões"
            )
            MiniStatCard(
                label: "TAXA",
                value: "\(Int(vm.retentionRate.rounded()))%",
                subtitle: "retenção",
                valueColor: VitaColors.dataGreen
            )
        }
    }

    private func bottomStatRow(vm: FlashcardStatsViewModel) -> some View {
        HStack(spacing: 10) {
            MiniStatCard(
                label: "STREAK",
                value: "\(vm.streakDays)",
                subtitle: "dias",
                valueColor: VitaColors.dataAmber
            )
            MiniStatCard(
                label: "TEMPO",
                value: "\(vm.totalStudyMinutes)",
                subtitle: "minutos"
            )
            MiniStatCard(
                label: "REVISÕES",
                value: "\(vm.totalReviews)",
                subtitle: "total"
            )
        }
    }
}

// MARK: - Glass Section Container

private struct GlassStatsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(VitaTypography.labelMedium)
                .fontWeight(.semibold)
                .foregroundStyle(VitaColors.textPrimary)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Mini Stat Card

private struct MiniStatCard: View {
    let label: String
    let value: String
    let subtitle: String
    var valueColor: Color = VitaColors.textPrimary

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .kerning(0.5)
                .foregroundStyle(VitaColors.textTertiary)

            Spacer().frame(height: 2)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Flashcard Heatmap Calendar

/// Renders the last 13 weeks (91 days) as a compact activity grid.
/// Matches Android HeatmapCalendar — columns = weeks (Sun→Sat).
private struct FlashcardHeatmapView: View {
    let reviewsPerDay: [String: Int]

    private let weeks = 13
    private let cellSize: CGFloat = 14
    private let gap: CGFloat = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Grid: 13 columns (weeks) × 7 rows (days)
            HStack(alignment: .top, spacing: gap) {
                ForEach(0..<weeks, id: \.self) { weekOffset in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { dayOfWeek in
                            let dayDate = dateFor(weekOffset: weekOffset, dayOfWeek: dayOfWeek)
                            let count = reviewsPerDay[isoDate(dayDate)] ?? 0
                            RoundedRectangle(cornerRadius: 3)
                                .fill(heatmapColor(count: count))
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }

            // Legend
            HStack(spacing: 6) {
                Text("Menos")
                    .font(.system(size: 9))
                    .foregroundStyle(VitaColors.textTertiary)
                ForEach([0, 1, 4, 8, 15], id: \.self) { n in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(heatmapColor(count: n))
                        .frame(width: 10, height: 10)
                }
                Text("Mais")
                    .font(.system(size: 9))
                    .foregroundStyle(VitaColors.textTertiary)
            }
        }
    }

    private func dateFor(weekOffset: Int, dayOfWeek: Int) -> Date {
        let calendar = Calendar.current
        // Start from 13 weeks ago, aligned to Sunday
        let today = calendar.startOfDay(for: Date())
        let todayWeekday = calendar.component(.weekday, from: today) - 1 // 0=Sun
        let startOfGrid = calendar.date(byAdding: .day, value: -(weeks * 7 - 1 + todayWeekday), to: today) ?? today
        return calendar.date(byAdding: .day, value: weekOffset * 7 + dayOfWeek, to: startOfGrid) ?? today
    }

    private func isoDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    private func heatmapColor(count: Int) -> Color {
        switch count {
        case 0:        return VitaColors.surfaceElevated
        case 1...3:    return VitaColors.accent.opacity(0.25)
        case 4...7:    return VitaColors.accent.opacity(0.50)
        case 8...14:   return VitaColors.accent.opacity(0.75)
        default:       return VitaColors.accent
        }
    }
}

// MARK: - Retention Line Chart

/// Daily retention percentage over the last 30 days using Swift Charts.
private struct RetentionLineChartView: View {
    let data: [DailyRetentionEntry]

    var body: some View {
        Chart(data) { entry in
            LineMark(
                x: .value("Data", entry.date),
                y: .value("Retenção", entry.retention)
            )
            .foregroundStyle(VitaColors.accent)
            .lineStyle(StrokeStyle(lineWidth: 2))
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Data", entry.date),
                yStart: .value("Zero", 0),
                yEnd: .value("Retenção", entry.retention)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [VitaColors.accent.opacity(0.25), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Data", entry.date),
                y: .value("Retenção", entry.retention)
            )
            .foregroundStyle(VitaColors.accent)
            .symbolSize(20)
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: 7)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(VitaColors.glassBorder)
                AxisValueLabel()
                    .foregroundStyle(VitaColors.textTertiary)
                    .font(.system(size: 9))
            }
        }
        .chartYAxis {
            AxisMarks(values: [0, 50, 100]) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(VitaColors.glassBorder)
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))%")
                            .foregroundStyle(VitaColors.textTertiary)
                            .font(.system(size: 9))
                    }
                }
            }
        }
        .frame(height: 160)
    }
}

// MARK: - Forecast Bar Chart

/// 7-day forecast of due cards using Swift Charts.
private struct ForecastBarChartView: View {
    let forecast: [Int]

    private var forecastEntries: [(day: String, count: Int)] {
        let calendar = Calendar.current
        let today = Date()
        let df = DateFormatter()
        df.dateFormat = "E"  // Short weekday: "Seg", "Ter"
        df.locale = Locale(identifier: "pt_BR")

        return forecast.enumerated().map { (i, count) in
            let date = calendar.date(byAdding: .day, value: i, to: today) ?? today
            let label = i == 0 ? "Hoje" : df.string(from: date)
            return (day: label, count: count)
        }
    }

    var body: some View {
        Chart(forecastEntries, id: \.day) { entry in
            BarMark(
                x: .value("Dia", entry.day),
                y: .value("Cards", entry.count)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [VitaColors.accent, VitaColors.dataBlue],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .cornerRadius(4)

            if entry.count > 0 {
                RuleMark(x: .value("Dia", entry.day))
                    .annotation(position: .top, alignment: .center) {
                        Text("\(entry.count)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    .foregroundStyle(.clear)
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel()
                    .foregroundStyle(VitaColors.textTertiary)
                    .font(.system(size: 10))
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(VitaColors.glassBorder)
                AxisValueLabel()
                    .foregroundStyle(VitaColors.textTertiary)
                    .font(.system(size: 9))
            }
        }
        .frame(height: 140)
    }
}

// MARK: - Flashcard Distribution Donut

/// Donut chart showing new / young / mature card split using Swift Charts SectorMark (iOS 17+).
private struct FlashcardDistributionDonutView: View {
    let newCards: Int
    let youngCards: Int
    let matureCards: Int

    private struct Segment: Identifiable {
        let id = UUID()
        let label: String
        let count: Int
        let color: Color
    }

    private var segments: [Segment] {
        [
            Segment(label: "Novo",       count: newCards,    color: VitaColors.dataBlue),
            Segment(label: "Aprendendo", count: youngCards,  color: VitaColors.dataAmber),
            Segment(label: "Dominado",   count: matureCards, color: VitaColors.dataGreen),
        ].filter { $0.count > 0 }
    }

    private var total: Int { newCards + youngCards + matureCards }

    var body: some View {
        HStack(spacing: 20) {
            // Donut
            Chart(segments) { seg in
                SectorMark(
                    angle: .value("Cards", seg.count),
                    innerRadius: .ratio(0.58),
                    angularInset: 1.5
                )
                .foregroundStyle(seg.color)
                .cornerRadius(3)
            }
            .frame(width: 120, height: 120)
            .overlay {
                VStack(spacing: 2) {
                    Text("\(total)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .monospacedDigit()
                    Text("total")
                        .font(.system(size: 10))
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }

            // Legend
            VStack(alignment: .leading, spacing: 10) {
                ForEach([
                    ("Novo", newCards, VitaColors.dataBlue),
                    ("Aprendendo", youngCards, VitaColors.dataAmber),
                    ("Dominado", matureCards, VitaColors.dataGreen),
                ], id: \.0) { label, count, color in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)

                        Text(label)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)

                        Spacer()

                        Text("\(count)")
                            .font(VitaTypography.labelMedium)
                            .fontWeight(.semibold)
                            .foregroundStyle(VitaColors.textPrimary)
                            .monospacedDigit()
                    }
                }
            }
        }
    }
}

// MARK: - Loading Skeleton

private struct StatsLoadingSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            // Top mini cards row
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerBox(height: 80, cornerRadius: 12)
                }
            }

            ShimmerBox(height: 140, cornerRadius: 14)  // Heatmap placeholder
            ShimmerBox(height: 180, cornerRadius: 14)  // Retention chart placeholder
            ShimmerBox(height: 160, cornerRadius: 14)  // Forecast placeholder
            ShimmerBox(height: 160, cornerRadius: 14)  // Donut placeholder

            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerBox(height: 80, cornerRadius: 12)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("FlashcardStats") {
    NavigationStack {
        FlashcardStatsView(onBack: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("Charts — Retention") {
    let data = (0..<14).map { i -> DailyRetentionEntry in
        let date = Calendar.current.date(byAdding: .day, value: -(14 - i), to: Date())!
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return DailyRetentionEntry(date: df.string(from: date), count: Int.random(in: 5...20), retention: Double.random(in: 60...95))
    }
    return GlassStatsSection(title: "Retenção ao Longo do Tempo") {
        RetentionLineChartView(data: data)
    }
    .padding()
    .background(VitaColors.surface)
    .preferredColorScheme(.dark)
}

#Preview("Charts — Donut") {
    GlassStatsSection(title: "Distribuição") {
        FlashcardDistributionDonutView(newCards: 12, youngCards: 34, matureCards: 54)
    }
    .padding()
    .background(VitaColors.surface)
    .preferredColorScheme(.dark)
}
#endif
