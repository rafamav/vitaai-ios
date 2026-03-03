import SwiftUI
import Charts

// MARK: - InsightsScreen

struct InsightsScreen: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: InsightsViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                insightsContent(vm: vm)
            } else {
                ProgressView().tint(VitaColors.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = InsightsViewModel(api: container.api)
                Task { await viewModel?.load() }
            }
        }
    }

    @ViewBuilder
    private func insightsContent(vm: InsightsViewModel) -> some View {
        InsightsContentView(vm: vm)
    }
}

// MARK: - InsightsContentView (handles states + animations)

private struct InsightsContentView: View {
    let vm: InsightsViewModel

    // Staggered entrance animations — mirrors Android Animatable chain
    @State private var overviewVisible: Bool = false
    @State private var statsVisible: Bool = false
    @State private var gradesVisible: Bool = false

    var body: some View {
        ZStack {
            if vm.isErrorState {
                // Full-screen error — no data loaded
                ScrollView {
                    VitaErrorState(
                        title: "Erro ao carregar insights",
                        message: vm.error ?? "Ocorreu um erro inesperado. Tente novamente.",
                        onRetry: { Task { await vm.load() } }
                    )
                    .frame(maxWidth: .infinity, minHeight: 400)
                }
                .refreshable { await vm.load() }

            } else if vm.isEmptyState {
                // Full-screen empty state
                ScrollView {
                    VitaEmptyState(
                        title: "Sem dados suficientes",
                        message: "Sem dados de estudo suficientes para gerar insights. Continue estudando e seus resultados aparecerão aqui."
                    ) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 400)
                }
                .refreshable { await vm.load() }

            } else {
                // Normal content — skeleton or populated
                mainScrollContent(vm: vm)
            }
        }
        .onChange(of: vm.studyStats == nil ? 0 : 1) { _, newVal in
            if newVal == 1 {
                // Data arrived: trigger staggered entrance
                Task {
                    withAnimation(.easeOut(duration: 0.4)) { overviewVisible = true }
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    withAnimation(.easeOut(duration: 0.4)) { statsVisible = true }
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    withAnimation(.easeOut(duration: 0.4)) { gradesVisible = true }
                }
            } else {
                // Data cleared (refresh): reset animations instantly
                overviewVisible = false
                statsVisible = false
                gradesVisible = false
            }
        }
    }

    @ViewBuilder
    private func mainScrollContent(vm: InsightsViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {

                // ── Skeleton: show while loading and no studyStats yet ──────────
                if vm.isLoading && vm.studyStats == nil {
                    InsightsSkeleton()
                }

                // ── Overview hero card ──────────────────────────────────────────
                if let stats = vm.studyStats {
                    OverviewCard(
                        stats: StudyStats(
                            totalHoursThisWeek: stats.totalHoursThisWeek,
                            averageGrade: vm.displayAverage,
                            completedAssignments: stats.completedAssignments,
                            pendingAssignments: stats.pendingAssignments,
                            streak: stats.streak
                        )
                    )
                    .staggerTransition(visible: overviewVisible)

                    // ── Stats row (hours / completed / streak) ─────────────────
                    InsightsStatsRow(stats: stats)
                        .staggerTransition(visible: statsVisible)
                }

                // ── Stats 2×2 grid (accuracy, streak, hours, flashcards) ───────
                StatsGrid(vm: vm)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // ── Flashcard charts ───────────────────────────────────────────
                if !vm.cardDistribution.isEmpty || !vm.retentionHistory.isEmpty {
                    SectionHeader(title: "Flashcards")
                        .padding(.top, 4)

                    if !vm.cardDistribution.isEmpty {
                        CardDistributionDonutView(categories: vm.cardDistribution)
                            .padding(.horizontal, 16)
                    }
                    if !vm.forecastData.isEmpty {
                        ForecastBarView(days: vm.forecastData)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                    if !vm.retentionHistory.isEmpty {
                        RetentionChartView(points: vm.retentionHistory)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                }

                // ── Study heatmap ──────────────────────────────────────────────
                if !vm.studyHeatmap.isEmpty {
                    SectionHeader(title: "Histórico")
                        .padding(.top, 4)
                    HeatmapCalendarView(days: vm.studyHeatmap)
                        .padding(.horizontal, 16)
                }

                // ── Today's progress ───────────────────────────────────────────
                if vm.todayTotal > 0 {
                    TodayProgressCard(
                        todayCompleted: vm.todayCompleted,
                        todayTotal: vm.todayTotal,
                        todayMinutes: vm.todayMinutes
                    )
                    .padding(.top, 8)
                }

                // ── Weekly accuracy chart ──────────────────────────────────────
                if !vm.subjects.isEmpty {
                    WeeklyAccuracyChart(subjects: vm.subjects, vm: vm)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                // ── Per-subject breakdown ──────────────────────────────────────
                // Note: SubjectsSection and ExamsSection contain SectionHeader which self-pads (.horizontal, 20).
                // The subject/exam rows inside get .horizontal, 16 padding inside their respective structs.
                SubjectsSection(vm: vm)
                    .padding(.top, 8)

                // ── WebAluno grades ────────────────────────────────────────────
                if !vm.webalunoGrades.isEmpty {
                    SectionHeader(
                        title: "Notas WebAluno",
                        subtitle: "\(vm.webalunoGrades.count) disciplinas"
                            + (vm.webalunoSummary.flatMap { $0.averageGrade }.map { " · Média \(String(format: "%.1f", $0))" } ?? "")
                    )
                    .staggerTransition(visible: gradesVisible)

                    ForEach(Array(vm.webalunoGrades.enumerated()), id: \.element.id) { index, grade in
                        WebalunoGradeRow(grade: grade, index: index)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    }
                }

                // ── Canvas course grades ───────────────────────────────────────
                if !vm.courseGrades.isEmpty {
                    SectionHeader(
                        title: "Notas Canvas",
                        subtitle: "\(vm.courseGrades.count) disciplinas"
                    )
                    .staggerTransition(visible: gradesVisible)

                    ForEach(Array(vm.courseGrades.enumerated()), id: \.element.id) { index, grade in
                        CourseGradeRow(grade: grade, index: index)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    }
                }

                // ── Upcoming exams ─────────────────────────────────────────────
                ExamsSection(exams: vm.upcomingExams)
                    .padding(.top, 8)

                Spacer().frame(height: 100)
            }
            .padding(.top, 8)
        }
        .refreshable { await vm.load() }
    }
}

// MARK: - Stagger transition helper

private extension View {
    /// Fades in + slides up from 20pt — mirrors Android graphicsLayer stagger.
    func staggerTransition(visible: Bool) -> some View {
        self
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 20)
    }
}

// MARK: - InsightsSkeleton

private struct InsightsSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            // Overview card skeleton
            ShimmerBox(height: 140, cornerRadius: 20)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            // Stats row skeleton
            HStack(spacing: 12) {
                ShimmerBox(height: 80, cornerRadius: 14)
                ShimmerBox(height: 80, cornerRadius: 14)
                ShimmerBox(height: 80, cornerRadius: 14)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)

            // Section label skeleton
            ShimmerText(width: 120, height: 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .padding(.top, 8)

            // Grade row skeletons
            ForEach(0..<4, id: \.self) { _ in
                ShimmerBox(height: 70, cornerRadius: 12)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - OverviewCard

private struct OverviewCard: View {
    let stats: StudyStats

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(VitaColors.surfaceCard)

            // Gradient overlay — mirrors Android Brush.linearGradient
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            VitaColors.accent.opacity(0.15),
                            VitaColors.accentDark.opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 20)
                .stroke(VitaColors.glassBorder, lineWidth: 1)

            VStack(spacing: 4) {
                Text("MÉDIA GERAL")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(VitaColors.accent)
                    .accessibilityAddTraits(.isHeader)

                Text(String(format: "%.1f", stats.averageGrade))
                    .font(.system(size: 48, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(VitaColors.textPrimary)

                Text(gradeLabel(stats.averageGrade))
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

// MARK: - InsightsStatsRow (3-card horizontal row: hours / completed / streak)

private struct InsightsStatsRow: View {
    let stats: StudyStats

    var body: some View {
        HStack(spacing: 12) {
            InsightsStatCard(
                icon: "clock.fill",
                value: String(format: "%.1fh", stats.totalHoursThisWeek),
                label: "esta semana",
                iconColor: VitaColors.accent
            )
            InsightsStatCard(
                icon: "checkmark.circle.fill",
                value: "\(stats.completedAssignments)",
                label: "entregues",
                iconColor: VitaColors.dataGreen
            )
            InsightsStatCard(
                icon: "flame.fill",
                value: "\(stats.streak) dias",
                label: "sequência",
                iconColor: VitaColors.textSecondary
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
    }
}

private struct InsightsStatCard: View {
    let icon: String
    let value: String
    let label: String
    let iconColor: Color

    var body: some View {
        VitaGlassCard {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)

                Text(value)
                    .font(VitaTypography.titleMedium)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(VitaColors.textPrimary)

                Text(label)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(14)
        }
        .accessibilityLabel("\(value) \(label)")
    }
}

// MARK: - WeeklyAccuracyChart

/// Horizontal bar chart of accuracy per subject — uses Swift Charts (iOS 16+).
private struct WeeklyAccuracyChart: View {
    let subjects: [SubjectProgress]
    let vm: InsightsViewModel

    // Top 5 subjects by hours for a clean chart
    private var chartData: [(name: String, accuracy: Double, color: Color)] {
        subjects
            .sorted { $0.hoursSpent > $1.hoursSpent }
            .prefix(5)
            .map { subject in
                (
                    name: abbreviate(vm.subjectName(for: subject.subjectId)),
                    accuracy: subject.accuracy,
                    color: vm.accuracyColor(for: subject.accuracy)
                )
            }
    }

    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Precisão por Matéria")
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.textPrimary)
                    Spacer()
                    Text("top 5")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Chart(chartData, id: \.name) { item in
                    BarMark(
                        x: .value("Precisão", item.accuracy),
                        y: .value("Matéria", item.name)
                    )
                    .foregroundStyle(item.color)
                    .cornerRadius(4)
                    .annotation(position: .trailing) {
                        Text("\(Int(item.accuracy))%")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                }
                .chartXScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(VitaColors.surfaceBorder)
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text("\(v)%")
                                    .font(.system(size: 9))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                    }
                }
                .frame(height: CGFloat(chartData.count) * 36 + 20)
            }
            .padding(14)
        }
    }

    private func abbreviate(_ name: String) -> String {
        // Shorten long names to fit bar chart labels
        let words = name.components(separatedBy: " ")
        if words.count == 1 { return name }
        if name.count <= 12 { return name }
        return words.prefix(2).map { $0.prefix(4) }.joined(separator: ".")
    }
}

// MARK: - Stat Item Model

private struct InsightsStatItem: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let subtitle: String
    let icon: String
    let valueColor: Color
}

// MARK: - Stats Grid (2×2: accuracy, streak, hours, flashcards)

private struct StatsGrid: View {
    let vm: InsightsViewModel

    private var stats: [InsightsStatItem] {
        let accuracyColor = vm.accuracyColor(for: vm.avgAccuracy)
        let accuracySubtitle: String
        if vm.avgAccuracy >= 70 { accuracySubtitle = "Excelente!" }
        else if vm.avgAccuracy >= 50 { accuracySubtitle = "Razoável" }
        else { accuracySubtitle = "Precisa melhorar" }

        return [
            InsightsStatItem(
                label: "PRECISÃO",
                value: "\(Int(vm.avgAccuracy))%",
                subtitle: accuracySubtitle,
                icon: "target",
                valueColor: accuracyColor
            ),
            InsightsStatItem(
                label: "SEQUÊNCIA",
                value: "\(vm.streakDays)d",
                subtitle: "dias seguidos",
                icon: "flame.fill",
                valueColor: VitaColors.textTertiary
            ),
            InsightsStatItem(
                label: "HORAS",
                value: String(format: "%.1fh", vm.totalHours),
                subtitle: "de estudo",
                icon: "clock.fill",
                valueColor: VitaColors.textTertiary
            ),
            InsightsStatItem(
                label: "FLASHCARDS",
                value: "\(vm.totalCards)",
                subtitle: "\(vm.flashcardsDue) pendentes",
                icon: "brain.fill",
                valueColor: VitaColors.textTertiary
            ),
        ]
    }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(stats) { stat in
                SmallStatCard(stat: stat)
            }
        }
    }
}

private struct SmallStatCard: View {
    let stat: InsightsStatItem

    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: stat.icon)
                        .font(.system(size: 10))
                        .foregroundStyle(VitaColors.textTertiary)
                    Text(stat.label)
                        .font(.system(size: 9))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(VitaColors.textTertiary)
                }
                Text(stat.value)
                    .font(.system(size: 24, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(VitaColors.textPrimary)
                Text(stat.subtitle)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(stat.valueColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
        .accessibilityLabel("\(stat.label): \(stat.value), \(stat.subtitle)")
    }
}

// MARK: - Today Progress Card

private struct TodayProgressCard: View {
    let todayCompleted: Int
    let todayTotal: Int
    let todayMinutes: Int

    var body: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Hoje")

            VitaGlassCard {
                HStack(spacing: 12) {
                    Text("\(todayCompleted)/\(todayTotal)")
                        .font(.system(size: 20, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(VitaColors.textPrimary)

                    GeometryReader { geo in
                        let pct: CGFloat = todayTotal > 0
                            ? CGFloat(todayCompleted) / CGFloat(todayTotal)
                            : 0
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(VitaColors.surfaceElevated)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(VitaColors.dataGreen)
                                .frame(width: geo.size.width * pct, height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("\(todayMinutes) min")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .monospacedDigit()
                }
                .padding(14)
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Subjects Section

private struct SubjectsSection: View {
    let vm: InsightsViewModel

    private var sortedSubjects: [SubjectProgress] {
        vm.subjects.sorted { $0.accuracy > $1.accuracy }
    }

    var body: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Por Matéria")

            if sortedSubjects.isEmpty {
                InsightsEmptyCard(
                    icon: "book.closed.fill",
                    message: "Nenhuma matéria registrada ainda"
                )
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedSubjects, id: \.subjectId) { subject in
                        SubjectRow(
                            subject: subject,
                            subjectName: vm.subjectName(for: subject.subjectId),
                            accuracyColor: vm.accuracyColor(for: subject.accuracy)
                        )
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}

private struct SubjectRow: View {
    let subject: SubjectProgress
    let subjectName: String
    let accuracyColor: Color

    private var detailText: String {
        let hoursStr = String(format: "%.1f", subject.hoursSpent) + "h"
        if subject.cardsDue > 0 {
            return "\(hoursStr) · \(subject.cardsDue) pendentes"
        }
        return hoursStr
    }

    var body: some View {
        VitaGlassCard {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(VitaColors.surfaceElevated)
                            .frame(width: 32, height: 32)
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(VitaColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(subjectName)
                            .font(VitaTypography.labelMedium)
                            .foregroundStyle(VitaColors.textPrimary)
                        Text(detailText)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }

                    Spacer()

                    Text("\(Int(subject.accuracy))%")
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(accuracyColor)
                }

                // Accuracy progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(VitaColors.surfaceElevated)
                            .frame(height: 2)
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(accuracyColor)
                            .frame(
                                width: geo.size.width * CGFloat(subject.accuracy) / 100,
                                height: 2
                            )
                    }
                }
                .frame(height: 2)
            }
            .padding(14)
        }
    }
}

// MARK: - WebalunoGradeRow

private struct WebalunoGradeRow: View {
    let grade: WebalunoGrade
    let index: Int

    @State private var appeared = false

    private var displayGrade: Double {
        grade.finalGrade ?? grade.grade1 ?? 0.0
    }

    private var statusText: String {
        grade.status ?? "Cursando"
    }

    private var statusColor: Color {
        let s = statusText.lowercased()
        if s.contains("aprovado") || s.contains("dispensado") { return VitaColors.dataGreen }
        if s.contains("reprovado") { return VitaColors.dataRed }
        return VitaColors.accent
    }

    private var gradePartsParts: String {
        var parts: [String] = []
        if let g1 = grade.grade1 { parts.append("N1: \(String(format: "%.1f", g1))") }
        if let g2 = grade.grade2 { parts.append("N2: \(String(format: "%.1f", g2))") }
        if let g3 = grade.grade3 { parts.append("N3: \(String(format: "%.1f", g3))") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                // Grade badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(gradeColor(displayGrade).opacity(0.12))
                        .frame(width: 44, height: 44)
                    Text(displayGrade > 0 ? String(format: "%.1f", displayGrade) : "—")
                        .font(VitaTypography.labelLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(displayGrade > 0 ? gradeColor(displayGrade) : VitaColors.textTertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(grade.subjectName)
                        .font(VitaTypography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)

                    if !gradePartsParts.isEmpty {
                        Text(gradePartsParts)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }

                    if let att = grade.attendance {
                        Text("Frequência: \(Int(att))%")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(att >= 75 ? VitaColors.dataGreen : VitaColors.dataRed)
                    }
                }

                Spacer()

                // Status badge
                Text(statusText)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }
            .padding(14)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            let delay = Double(index) * 0.04
            withAnimation(.easeOut(duration: 0.3).delay(delay)) {
                appeared = true
            }
        }
    }
}

// MARK: - CourseGradeRow (Canvas)

private struct CourseGradeRow: View {
    let grade: CourseGrade
    let index: Int

    @State private var appeared = false

    private var progress: Double {
        guard grade.assignments > 0 else { return 0 }
        return Double(grade.completed) / Double(grade.assignments)
    }

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                // Grade badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(gradeColor(grade.grade).opacity(0.12))
                        .frame(width: 44, height: 44)
                    Text(String(format: "%.1f", grade.grade))
                        .font(VitaTypography.labelLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(gradeColor(grade.grade))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(grade.courseName)
                        .font(VitaTypography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(VitaColors.surfaceElevated)
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(gradeColor(grade.grade))
                                .frame(width: geo.size.width * CGFloat(progress), height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("\(grade.completed)/\(grade.assignments) atividades")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            .padding(14)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            let delay = Double(index) * 0.04
            withAnimation(.easeOut(duration: 0.3).delay(delay)) {
                appeared = true
            }
        }
    }
}

// MARK: - Exams Section

private struct ExamsSection: View {
    let exams: [ExamEntry]

    var body: some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Próximas Provas")

            if exams.isEmpty {
                InsightsEmptyCard(
                    icon: "calendar.badge.clock",
                    message: "Nenhuma prova agendada"
                )
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 8) {
                    ForEach(exams) { exam in
                        ExamRow(exam: exam)
                            .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
}

private struct ExamRow: View {
    let exam: ExamEntry

    private var countdownColor: Color {
        if exam.daysUntil <= 7 { return VitaColors.dataRed }
        if exam.daysUntil <= 14 { return VitaColors.dataAmber }
        return VitaColors.textSecondary
    }

    private var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        guard let date = formatter.date(from: exam.date) else { return exam.date }
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateStyle = .medium
        return df.string(from: date)
    }

    var body: some View {
        VitaGlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exam.subjectName)
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text(formattedDate)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer()

                Text("\(exam.daysUntil)d")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(countdownColor)
            }
            .padding(14)
        }
    }
}

// MARK: - Empty card (inline, inside a section)

private struct InsightsEmptyCard: View {
    let icon: String
    let message: String

    var body: some View {
        VitaGlassCard {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(VitaColors.textTertiary)
                Text(message)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Grade helpers (mirrors Android gradeColor / gradeLabel)

private func gradeColor(_ grade: Double) -> Color {
    if grade >= 8.0 { return VitaColors.dataGreen }
    if grade >= 6.0 { return VitaColors.dataAmber }
    return VitaColors.dataRed
}

private func gradeLabel(_ grade: Double) -> String {
    switch grade {
    case 9.0...: return "Excelente"
    case 8.0...: return "Muito bom"
    case 7.0...: return "Bom"
    case 6.0...: return "Regular"
    default: return "Precisa melhorar"
    }
}
