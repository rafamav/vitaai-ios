import SwiftUI

// MARK: - ProgressoScreen (Gold glassmorphism, pill tab navigation, 6 sections)

struct ProgressoScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: ProgressoViewModel?

    var body: some View {
        Group {
            if let vm {
                if vm.isLoading && vm.userProgress == nil {
                    progressoSkeleton
                } else if let error = vm.error {
                    ScrollView {
                        VitaErrorState(
                            title: String(localized: "progresso_error_title"),
                            message: error,
                            systemImage: "wifi.slash",
                            onRetry: { Task { await vm.load() } }
                        )
                    }
                    .refreshable { await vm.load() }
                } else {
                    progressContent(vm: vm)
                }
            } else {
                progressoSkeleton
            }
        }
        .background { VitaScreenBg() }
        .task {
            if vm == nil {
                let newVm = ProgressoViewModel(api: container.api)
                vm = newVm
                await newVm.load()
            }
        }
    }

    // MARK: - Skeleton

    private var progressoSkeleton: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: VitaTokens.Spacing.md) {
                // Pill tabs skeleton
                HStack(spacing: VitaTokens.Spacing.sm) {
                    ForEach(0..<4, id: \.self) { _ in
                        ShimmerBox(height: 32, cornerRadius: VitaTokens.Radius.full)
                            .frame(width: 80)
                    }
                }
                .padding(.horizontal, VitaTokens.Spacing.lg)
                .padding(.top, VitaTokens.Spacing.sm)

                // Stats grid skeleton
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: VitaTokens.Spacing.sm), GridItem(.flexible(), spacing: VitaTokens.Spacing.sm)],
                    spacing: VitaTokens.Spacing.sm
                ) {
                    ForEach(0..<4, id: \.self) { _ in
                        ShimmerBox(height: 80, cornerRadius: VitaTokens.Radius.lg)
                    }
                }
                .padding(.horizontal, VitaTokens.Spacing.lg)

                // Card skeletons
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerBox(height: 120, cornerRadius: VitaTokens.Radius.lg)
                        .padding(.horizontal, VitaTokens.Spacing.lg)
                }
            }
            .padding(.bottom, 120)
        }
        .scrollDisabled(true)
        .allowsHitTesting(false)
    }

    // MARK: - Main Content

    @ViewBuilder
    private func progressContent(vm: ProgressoViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: VitaTokens.Spacing.lg) {
                // Pill tabs
                pillTabBar(vm: vm)

                // Tab content
                tabContent(vm: vm)
            }
            .padding(.bottom, 120)
        }
        .refreshable { await vm.load() }
    }

    // MARK: - Pill Tab Bar

    private func pillTabBar(vm: ProgressoViewModel) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VitaTokens.Spacing.sm) {
                ForEach(ProgressoTab.allCases) { tab in
                    pillTab(tab: tab, isActive: vm.selectedTab == tab) {
                        withAnimation(.easeOut(duration: VitaTokens.Animation.durationNormal)) {
                            vm.selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.vertical, VitaTokens.Spacing.sm)
        }
    }

    private func pillTab(tab: ProgressoTab, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: VitaTokens.Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.system(size: VitaTokens.Typography.fontSizeXs, weight: .semibold))
                Text(tab.localizedTitle)
                    .font(.system(size: VitaTokens.Typography.fontSizeSm, weight: .bold))
            }
            .foregroundStyle(
                isActive
                    ? VitaColors.accentLight.opacity(0.95)
                    : VitaColors.textWarm.opacity(0.40)
            )
            .padding(.horizontal, VitaTokens.Spacing.lg)
            .padding(.vertical, VitaTokens.Spacing.sm)
            .background {
                if isActive {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    VitaColors.accent.opacity(0.18),
                                    VitaColors.accentDark.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    Capsule()
                        .fill(Color.white.opacity(0.02))
                }
            }
            .overlay(
                Capsule()
                    .stroke(
                        isActive
                            ? VitaColors.accent.opacity(0.20)
                            : VitaColors.textWarm.opacity(0.06),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isActive ? VitaColors.accent.opacity(0.10) : .clear,
                radius: 8,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.localizedTitle)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    // MARK: - Tab Content Router

    @ViewBuilder
    private func tabContent(vm: ProgressoViewModel) -> some View {
        switch vm.selectedTab {
        case .resumo:
            ProgressoResumoSection(vm: vm)
        case .disciplinas:
            ProgressoDisciplinasSection(vm: vm)
        case .qbank:
            ProgressoQBankSection(vm: vm)
        case .simulados:
            ProgressoSimuladosSection(vm: vm)
        case .retencao:
            ProgressoRetencaoSection(vm: vm)
        case .gamificacao:
            ProgressoGamificacaoSection(vm: vm)
        }
    }
}

// MARK: - Section 1: Resumo Geral

private struct ProgressoResumoSection: View {
    let vm: ProgressoViewModel

    var body: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            // XP / Level hero
            if let up = vm.userProgress {
                xpHeroCard(up: up)
            }

            // Stats grid 2x2
            statsGrid

            // Weekly chart
            weeklyChart

            // Heatmap
            heatmapSection
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
    }

    // MARK: XP Hero Card

    private func xpHeroCard(up: UserProgress) -> some View {
        let currentXp = up.currentLevelXp
        let totalXp = currentXp + up.xpToNextLevel
        let levelRatio = totalXp > 0 ? Double(currentXp) / Double(totalXp) : 0

        return VitaGlassCard {
            HStack(spacing: VitaTokens.Spacing.lg) {
                // XP Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 4)
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: levelRatio)
                        .stroke(
                            LinearGradient(
                                colors: [VitaColors.accentHover.opacity(0.90), VitaColors.accentDark.opacity(0.70)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: VitaColors.accentDark.opacity(0.20), radius: 6)

                    Text("\(up.level)")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.95))
                        .tracking(-0.5)
                }
                .frame(width: 72, height: 72)

                VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                    Text(String(localized: "progresso_nivel_label \(up.level)"))
                        .font(VitaTypography.titleLarge)
                        .foregroundStyle(VitaColors.textPrimary)

                    Text("\(currentXp) / \(totalXp) XP")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)

                    // XP bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 4)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [VitaColors.accent.opacity(0.70), VitaColors.accentHover.opacity(0.50)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * levelRatio, height: 4)
                        }
                    }
                    .frame(height: 4)
                    .padding(.top, VitaTokens.Spacing.xs)

                    // Streak badge inline
                    HStack(spacing: VitaTokens.Spacing.xs) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: VitaTokens.Typography.fontSizeXs, weight: .bold))
                            .foregroundStyle(VitaColors.dataAmber)
                        Text(String(localized: "progresso_streak_dias \(vm.streakDays)"))
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.dataAmber)
                    }
                    .padding(.top, VitaTokens.Spacing.sm)
                }
            }
            .padding(VitaTokens.Spacing.xl)
        }
    }

    // MARK: Stats Grid

    private var statsGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: VitaTokens.Spacing.sm),
                GridItem(.flexible(), spacing: VitaTokens.Spacing.sm)
            ],
            spacing: VitaTokens.Spacing.sm
        ) {
            ProgressoStatCard(
                icon: "flame.fill",
                value: "\(vm.streakDays)",
                label: String(localized: "progresso_stat_streak"),
                valueColor: VitaColors.dataAmber
            )
            ProgressoStatCard(
                icon: "clock.fill",
                value: formatHours(vm.totalStudyHours),
                label: String(localized: "progresso_stat_horas"),
                valueColor: VitaColors.accentLight.opacity(0.90)
            )
            ProgressoStatCard(
                icon: "checkmark.square.fill",
                value: "\(Int(vm.avgAccuracy))%",
                label: String(localized: "progresso_stat_acerto"),
                valueColor: VitaColors.dataGreen
            )
            ProgressoStatCard(
                icon: "rectangle.stack.fill",
                value: "\(vm.flashcardsDue)",
                label: String(localized: "progresso_stat_cards_pendentes"),
                valueColor: VitaColors.accentLight.opacity(0.90)
            )
        }
    }

    // MARK: Weekly Chart

    private var weeklyChart: some View {
        let maxHour = vm.weeklyHours.max() ?? 1.0
        let normalized: [Double] = vm.weeklyHours.map { maxHour > 0 ? $0 / maxHour : 0 }
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: Date())
        let todayIdx = (weekday + 5) % 7

        return VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            SectionHeader(title: String(localized: "progresso_section_semana"))

            VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                VStack(spacing: VitaTokens.Spacing.md) {
                    HStack {
                        Text(String(format: "%.1f", vm.weeklyActualHours) + "h " + String(localized: "progresso_de") + " \(Int(vm.weeklyGoalHours))h")
                            .font(VitaTypography.titleSmall)
                            .foregroundStyle(VitaColors.textPrimary)
                        Spacer()
                        Text(String(localized: "progresso_meta_semanal"))
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }

                    HStack(alignment: .bottom, spacing: VitaTokens.Spacing.sm) {
                        let labels = ["S", "T", "Q", "Q", "S", "S", "D"]
                        ForEach(0..<7, id: \.self) { idx in
                            ProgressoBarColumn(
                                label: labels[idx],
                                heightFraction: normalized[idx],
                                isToday: idx == todayIdx
                            )
                        }
                    }
                    .frame(height: 90)
                }
                .padding(VitaTokens.Spacing.lg)
            }
        }
    }

    // MARK: Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            SectionHeader(title: String(localized: "progresso_section_heatmap"))

            if vm.heatmap.isEmpty {
                VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                    VitaEmptyState(
                        title: String(localized: "progresso_heatmap_empty_title"),
                        message: String(localized: "progresso_heatmap_empty_message")
                    ) {
                        Image(systemName: "calendar")
                            .font(.system(size: 36))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            } else {
                VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                    let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 13)
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(0..<vm.heatmap.count, id: \.self) { i in
                            Rectangle()
                                .fill(heatmapColor(vm.heatmap[i]))
                                .aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    .padding(VitaTokens.Spacing.lg)
                }
            }
        }
    }

    private func heatmapColor(_ level: Int) -> Color {
        switch level {
        case 1: return VitaColors.accent.opacity(0.15)
        case 2: return VitaColors.accent.opacity(0.30)
        case 3: return VitaColors.accent.opacity(0.48)
        case 4: return VitaColors.accent.opacity(0.65)
        default: return Color.white.opacity(0.03)
        }
    }

    private func formatHours(_ hours: Double) -> String {
        if hours >= 1 { return "\(Int(hours))h" }
        return "\(Int(hours * 60))m"
    }
}

// MARK: - Section 2: Desempenho por Disciplina

private struct ProgressoDisciplinasSection: View {
    let vm: ProgressoViewModel

    var body: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            SectionHeader(title: String(localized: "progresso_section_disciplinas"))
                .padding(.horizontal, 0)

            if vm.subjects.isEmpty {
                VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                    VitaEmptyState(
                        title: String(localized: "progresso_disciplinas_empty_title"),
                        message: String(localized: "progresso_disciplinas_empty_message")
                    ) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 36))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            } else {
                VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                    VStack(spacing: 0) {
                        ForEach(Array(vm.sortedSubjectsByAccuracy.enumerated()), id: \.element.subjectId) { idx, subject in
                            disciplineRow(subject: subject, rank: idx + 1)
                            if idx < vm.sortedSubjectsByAccuracy.count - 1 {
                                glassRowDivider
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
    }

    private func disciplineRow(subject: SubjectProgress, rank: Int) -> some View {
        let pct = Int(subject.accuracy)
        let color = accuracyColor(for: subject.accuracy)
        let trend = trendForAccuracy(subject.accuracy)

        return HStack(spacing: VitaTokens.Spacing.md) {
            // Rank
            Text("#\(rank)")
                .font(.system(size: VitaTokens.Typography.fontSizeSm, weight: .heavy))
                .foregroundStyle(rank <= 3 ? VitaColors.accentLight.opacity(0.90) : VitaColors.textTertiary)
                .frame(width: 28)

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: VitaTokens.Radius.sm)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: "book.closed.fill")
                    .font(.system(size: VitaTokens.Typography.fontSizeMd))
                    .foregroundStyle(color.opacity(0.60))
            }

            // Name and meta
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                Text(subjectDisplayName(subject.subjectId))
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                Text(String(localized: "progresso_disciplina_meta \(subject.questionCount) \(String(format: "%.0f", subject.hoursSpent))"))
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }

            Spacer()

            // Trend indicator
            Image(systemName: trend.icon)
                .font(.system(size: VitaTokens.Typography.fontSizeXs))
                .foregroundStyle(trend.color)

            // Accuracy bar + percent
            VStack(alignment: .trailing, spacing: VitaTokens.Spacing.xxs) {
                Text("\(pct)%")
                    .font(.system(size: VitaTokens.Typography.fontSizeSm, weight: .bold))
                    .foregroundStyle(color.opacity(0.85))
                    .monospacedDigit()

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 48, height: 4)
                    Capsule()
                        .fill(color.opacity(0.55))
                        .frame(width: 48 * CGFloat(pct) / 100.0, height: 4)
                }
            }
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.vertical, VitaTokens.Spacing.md)
        .accessibilityLabel("\(subjectDisplayName(subject.subjectId)), \(pct)% de acerto")
    }

    private struct TrendInfo {
        let icon: String
        let color: Color
    }

    private func trendForAccuracy(_ accuracy: Double) -> TrendInfo {
        if accuracy >= 70 { return TrendInfo(icon: "arrow.up.right", color: VitaColors.dataGreen) }
        if accuracy >= 50 { return TrendInfo(icon: "arrow.right", color: VitaColors.dataAmber) }
        return TrendInfo(icon: "arrow.down.right", color: VitaColors.dataRed)
    }
}

// MARK: - Section 3: QBank

private struct ProgressoQBankSection: View {
    let vm: ProgressoViewModel

    var body: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            SectionHeader(title: String(localized: "progresso_section_qbank"))
                .padding(.horizontal, 0)

            if let qb = vm.qbankProgress {
                // Main stats
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: VitaTokens.Spacing.sm),
                        GridItem(.flexible(), spacing: VitaTokens.Spacing.sm)
                    ],
                    spacing: VitaTokens.Spacing.sm
                ) {
                    ProgressoStatCard(
                        icon: "checkmark.circle.fill",
                        value: "\(qb.totalAnswered)",
                        label: String(localized: "progresso_qbank_respondidas"),
                        valueColor: VitaColors.accentLight.opacity(0.90)
                    )
                    ProgressoStatCard(
                        icon: "checkmark.seal.fill",
                        value: "\(qb.totalCorrect)",
                        label: String(localized: "progresso_qbank_corretas"),
                        valueColor: VitaColors.dataGreen
                    )
                    ProgressoStatCard(
                        icon: "percent",
                        value: "\(Int(qb.accuracy))%",
                        label: String(localized: "progresso_qbank_acerto"),
                        valueColor: accuracyColor(for: qb.accuracy)
                    )
                    ProgressoStatCard(
                        icon: "tray.full.fill",
                        value: "\(qb.totalAvailable)",
                        label: String(localized: "progresso_qbank_disponiveis"),
                        valueColor: VitaColors.textSecondary
                    )
                }

                // By difficulty
                if !qb.byDifficulty.isEmpty {
                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                        SectionHeader(title: String(localized: "progresso_qbank_por_dificuldade"))
                            .padding(.horizontal, 0)

                        VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                            VStack(spacing: 0) {
                                ForEach(Array(qb.byDifficulty.enumerated()), id: \.element.id) { idx, diff in
                                    difficultyRow(diff: diff)
                                    if idx < qb.byDifficulty.count - 1 {
                                        glassRowDivider
                                    }
                                }
                            }
                        }
                    }
                }

                // By topic (top 5)
                if !qb.byTopic.isEmpty {
                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                        SectionHeader(title: String(localized: "progresso_qbank_por_tema"))
                            .padding(.horizontal, 0)

                        VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                            VStack(spacing: 0) {
                                let topTopics = Array(qb.byTopic.sorted { $0.answered > $1.answered }.prefix(5))
                                ForEach(Array(topTopics.enumerated()), id: \.element.id) { idx, topic in
                                    topicRow(topic: topic)
                                    if idx < topTopics.count - 1 {
                                        glassRowDivider
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                    VitaEmptyState(
                        title: String(localized: "progresso_qbank_empty_title"),
                        message: String(localized: "progresso_qbank_empty_message")
                    ) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 36))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
    }

    private func difficultyRow(diff: QBankProgressByDifficulty) -> some View {
        let pct = Int(diff.accuracy * 100)
        let color = accuracyColor(for: diff.accuracy * 100)
        return HStack(spacing: VitaTokens.Spacing.md) {
            Text(diff.difficulty.capitalized)
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.textPrimary)

            Spacer()

            Text("\(diff.answered)")
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textSecondary)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 48, height: 4)
                Capsule()
                    .fill(color.opacity(0.55))
                    .frame(width: 48 * CGFloat(pct) / 100.0, height: 4)
            }

            Text("\(pct)%")
                .font(.system(size: VitaTokens.Typography.fontSizeSm, weight: .bold))
                .foregroundStyle(color.opacity(0.85))
                .monospacedDigit()
                .frame(minWidth: 32, alignment: .trailing)
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.vertical, VitaTokens.Spacing.md)
    }

    private func topicRow(topic: QBankProgressByTopic) -> some View {
        let pct = Int(topic.accuracy * 100)
        let color = accuracyColor(for: topic.accuracy * 100)
        return HStack(spacing: VitaTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                Text(topic.topicTitle)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
                Text(String(localized: "progresso_qbank_topic_count \(topic.answered)"))
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }

            Spacer()

            Text("\(pct)%")
                .font(.system(size: VitaTokens.Typography.fontSizeSm, weight: .bold))
                .foregroundStyle(color.opacity(0.85))
                .monospacedDigit()
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.vertical, VitaTokens.Spacing.md)
    }
}

// MARK: - Section 4: Simulados

private struct ProgressoSimuladosSection: View {
    let vm: ProgressoViewModel

    var body: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            SectionHeader(title: String(localized: "progresso_section_simulados"))
                .padding(.horizontal, 0)

            if let diag = vm.simuladoDiagnostics {
                // Main stats
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: VitaTokens.Spacing.sm),
                        GridItem(.flexible(), spacing: VitaTokens.Spacing.sm)
                    ],
                    spacing: VitaTokens.Spacing.sm
                ) {
                    ProgressoStatCard(
                        icon: "doc.text.fill",
                        value: "\(diag.overall.totalAttempts)",
                        label: String(localized: "progresso_simulados_tentativas"),
                        valueColor: VitaColors.accentLight.opacity(0.90)
                    )
                    ProgressoStatCard(
                        icon: "chart.line.uptrend.xyaxis",
                        value: String(format: "%.0f%%", diag.overall.avgScore),
                        label: String(localized: "progresso_simulados_media"),
                        valueColor: accuracyColor(for: diag.overall.avgScore)
                    )
                    ProgressoStatCard(
                        icon: "star.fill",
                        value: String(format: "%.0f%%", diag.overall.bestScore),
                        label: String(localized: "progresso_simulados_melhor"),
                        valueColor: VitaColors.dataGreen
                    )
                    ProgressoStatCard(
                        icon: "checkmark.circle.fill",
                        value: String(format: "%.0f%%", diag.overall.correctRate * 100),
                        label: String(localized: "progresso_simulados_taxa_acerto"),
                        valueColor: accuracyColor(for: diag.overall.correctRate * 100)
                    )
                }

                // Evolution (recent history)
                if !diag.recentHistory.isEmpty {
                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                        SectionHeader(title: String(localized: "progresso_simulados_evolucao"))
                            .padding(.horizontal, 0)

                        VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                            VStack(spacing: 0) {
                                ForEach(Array(diag.recentHistory.prefix(5).enumerated()), id: \.element.id) { idx, entry in
                                    historyRow(entry: entry)
                                    if idx < min(diag.recentHistory.count, 5) - 1 {
                                        glassRowDivider
                                    }
                                }
                            }
                        }
                    }
                }

                // Weak topics
                if !diag.weakTopics.isEmpty {
                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                        SectionHeader(title: String(localized: "progresso_simulados_erros"))
                            .padding(.horizontal, 0)

                        VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                            VStack(spacing: 0) {
                                ForEach(Array(diag.weakTopics.prefix(5).enumerated()), id: \.element.id) { idx, weak in
                                    weakTopicRow(topic: weak)
                                    if idx < min(diag.weakTopics.count, 5) - 1 {
                                        glassRowDivider
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                    VitaEmptyState(
                        title: String(localized: "progresso_simulados_empty_title"),
                        message: String(localized: "progresso_simulados_empty_message")
                    ) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 36))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
    }

    private func historyRow(entry: HistoryEntry) -> some View {
        let color = accuracyColor(for: entry.score)
        return HStack(spacing: VitaTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                Text(entry.subject ?? entry.mode.capitalized)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
                Text(entry.date)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }

            Spacer()

            Text(String(format: "%.0f%%", entry.score))
                .font(.system(size: VitaTokens.Typography.fontSizeMd, weight: .bold))
                .foregroundStyle(color.opacity(0.85))
                .monospacedDigit()
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.vertical, VitaTokens.Spacing.md)
    }

    private func weakTopicRow(topic: WeakTopic) -> some View {
        let pct = Int(topic.correctRate * 100)
        let color = accuracyColor(for: topic.correctRate * 100)
        return HStack(spacing: VitaTokens.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: VitaTokens.Typography.fontSizeSm))
                .foregroundStyle(VitaColors.dataRed.opacity(0.70))

            VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                Text(topic.subject)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
                Text(topic.suggestion)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Text("\(pct)%")
                .font(.system(size: VitaTokens.Typography.fontSizeSm, weight: .bold))
                .foregroundStyle(color.opacity(0.85))
                .monospacedDigit()
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.vertical, VitaTokens.Spacing.md)
    }
}

// MARK: - Section 5: Retencao

private struct ProgressoRetencaoSection: View {
    let vm: ProgressoViewModel

    var body: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            SectionHeader(title: String(localized: "progresso_section_retencao"))
                .padding(.horizontal, 0)

            if let stats = vm.flashcardStats {
                // Main stats
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: VitaTokens.Spacing.sm),
                        GridItem(.flexible(), spacing: VitaTokens.Spacing.sm)
                    ],
                    spacing: VitaTokens.Spacing.sm
                ) {
                    ProgressoStatCard(
                        icon: "rectangle.stack.fill",
                        value: "\(stats.totalCards)",
                        label: String(localized: "progresso_retencao_total_cards"),
                        valueColor: VitaColors.accentLight.opacity(0.90)
                    )
                    ProgressoStatCard(
                        icon: "brain.fill",
                        value: "\(Int(stats.retentionRate))%",
                        label: String(localized: "progresso_retencao_taxa"),
                        valueColor: accuracyColor(for: stats.retentionRate)
                    )
                    ProgressoStatCard(
                        icon: "arrow.counterclockwise",
                        value: "\(stats.totalReviews)",
                        label: String(localized: "progresso_retencao_revisoes"),
                        valueColor: VitaColors.textSecondary
                    )
                    ProgressoStatCard(
                        icon: "calendar.badge.clock",
                        value: "\(stats.todayReviews)",
                        label: String(localized: "progresso_retencao_hoje"),
                        valueColor: VitaColors.dataAmber
                    )
                }

                // Card maturity breakdown
                VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                    SectionHeader(title: String(localized: "progresso_retencao_maturidade"))
                        .padding(.horizontal, 0)

                    VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                        VStack(spacing: VitaTokens.Spacing.md) {
                            maturityRow(
                                label: String(localized: "progresso_retencao_novos"),
                                count: stats.newCards,
                                total: stats.totalCards,
                                color: VitaColors.dataBlue
                            )
                            maturityRow(
                                label: String(localized: "progresso_retencao_aprendendo"),
                                count: stats.youngCards,
                                total: stats.totalCards,
                                color: VitaColors.dataAmber
                            )
                            maturityRow(
                                label: String(localized: "progresso_retencao_maduros"),
                                count: stats.matureCards,
                                total: stats.totalCards,
                                color: VitaColors.dataGreen
                            )
                        }
                        .padding(VitaTokens.Spacing.lg)
                    }
                }

                // 7-day forecast
                if !stats.forecastNext7Days.isEmpty {
                    VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
                        SectionHeader(title: String(localized: "progresso_retencao_previsao"))
                            .padding(.horizontal, 0)

                        VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                            forecastChart(forecast: stats.forecastNext7Days)
                                .padding(VitaTokens.Spacing.lg)
                        }
                    }
                }
            } else {
                VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                    VitaEmptyState(
                        title: String(localized: "progresso_retencao_empty_title"),
                        message: String(localized: "progresso_retencao_empty_message")
                    ) {
                        Image(systemName: "brain")
                            .font(.system(size: 36))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            }
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
    }

    private func maturityRow(label: String, count: Int, total: Int, color: Color) -> some View {
        let fraction = total > 0 ? Double(count) / Double(total) : 0
        return HStack(spacing: VitaTokens.Spacing.md) {
            Circle()
                .fill(color.opacity(0.60))
                .frame(width: 8, height: 8)

            Text(label)
                .font(VitaTypography.labelMedium)
                .foregroundStyle(VitaColors.textPrimary)

            Spacer()

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)
                    Capsule()
                        .fill(color.opacity(0.50))
                        .frame(width: geo.size.width * fraction, height: 6)
                }
            }
            .frame(width: 80, height: 6)

            Text("\(count)")
                .font(.system(size: VitaTokens.Typography.fontSizeSm, weight: .bold))
                .foregroundStyle(color.opacity(0.85))
                .monospacedDigit()
                .frame(minWidth: 32, alignment: .trailing)
        }
    }

    private func forecastChart(forecast: [Int]) -> some View {
        let maxVal = forecast.max() ?? 1
        let dayLabels = [
            String(localized: "progresso_dia_dom_abbr"),
            String(localized: "progresso_dia_seg_abbr"),
            String(localized: "progresso_dia_ter_abbr"),
            String(localized: "progresso_dia_qua_abbr"),
            String(localized: "progresso_dia_qui_abbr"),
            String(localized: "progresso_dia_sex_abbr"),
            String(localized: "progresso_dia_sab_abbr")
        ]
        let calendar = Calendar.current
        let startWeekday = calendar.component(.weekday, from: Date())

        return HStack(alignment: .bottom, spacing: VitaTokens.Spacing.sm) {
            ForEach(0..<min(forecast.count, 7), id: \.self) { idx in
                let val = forecast[idx]
                let fraction = maxVal > 0 ? CGFloat(val) / CGFloat(maxVal) : 0
                let dayIdx = (startWeekday - 1 + idx) % 7

                VStack(spacing: VitaTokens.Spacing.xs) {
                    Text("\(val)")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textSecondary)
                        .monospacedDigit()

                    UnevenRoundedRectangle(
                        topLeadingRadius: 4,
                        bottomLeadingRadius: 2,
                        bottomTrailingRadius: 2,
                        topTrailingRadius: 4
                    )
                    .fill(
                        LinearGradient(
                            colors: [VitaColors.accent.opacity(0.50), VitaColors.accent.opacity(0.25)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(height: max(fraction * 60, val > 0 ? 4 : 0))

                    Text(dayLabels[dayIdx])
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.28))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 90)
    }
}

// MARK: - Section 6: Gamificacao

private struct ProgressoGamificacaoSection: View {
    let vm: ProgressoViewModel

    var body: some View {
        VStack(spacing: VitaTokens.Spacing.md) {
            // Badges
            badgesSection

            // Leaderboard
            leaderboardSection
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
    }

    // MARK: Badges

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            SectionHeader(title: String(localized: "progresso_section_conquistas"))
                .padding(.horizontal, 0)

            if vm.allBadges.isEmpty {
                VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                    VitaEmptyState(
                        title: String(localized: "progresso_badges_empty_title"),
                        message: String(localized: "progresso_badges_empty_message")
                    ) {
                        Image(systemName: "medal")
                            .font(.system(size: 36))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            } else {
                VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                    VitaBadgeGrid(badges: vm.allBadges)
                        .padding(VitaTokens.Spacing.lg)
                }
            }
        }
    }

    // MARK: Leaderboard

    private var leaderboardSection: some View {
        VStack(alignment: .leading, spacing: VitaTokens.Spacing.sm) {
            SectionHeader(title: String(localized: "progresso_section_ranking"))
                .padding(.horizontal, 0)

            VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
                VStack(spacing: 0) {
                    // Period tabs
                    HStack(spacing: VitaTokens.Spacing.xs) {
                        leaderboardPeriodPill(
                            label: String(localized: "progresso_lb_semanal"),
                            period: "weekly"
                        )
                        leaderboardPeriodPill(
                            label: String(localized: "progresso_lb_mensal"),
                            period: "monthly"
                        )
                        leaderboardPeriodPill(
                            label: String(localized: "progresso_lb_total"),
                            period: "all-time"
                        )
                        Spacer()
                    }
                    .padding(.horizontal, VitaTokens.Spacing.lg)
                    .padding(.top, VitaTokens.Spacing.md)

                    if vm.leaderboard.isEmpty {
                        VitaEmptyState(
                            title: String(localized: "progresso_lb_empty_title"),
                            message: String(localized: "progresso_lb_empty_message")
                        ) {
                            Image(systemName: "trophy")
                                .font(.system(size: 28))
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                    } else {
                        let otherEntries = vm.leaderboard.filter { !$0.isMe }.prefix(5)
                        ForEach(Array(otherEntries.enumerated()), id: \.element.id) { idx, entry in
                            leaderboardRow(entry: entry, isMe: false)
                            if idx < otherEntries.count - 1 {
                                glassRowDivider
                            }
                        }

                        if let myEntry = vm.myLeaderboardEntry {
                            Rectangle()
                                .fill(VitaColors.accentHover.opacity(0.08))
                                .frame(height: 1)
                                .padding(.horizontal, VitaTokens.Spacing.lg)
                                .padding(.top, VitaTokens.Spacing.xs)

                            HStack {
                                Text(String(localized: "progresso_lb_sua_posicao"))
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(VitaColors.textWarm.opacity(0.25))
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                                Spacer()
                            }
                            .padding(.horizontal, VitaTokens.Spacing.lg)
                            .padding(.top, VitaTokens.Spacing.xxs)

                            leaderboardRow(entry: myEntry, isMe: true)
                        }
                    }
                }
                .padding(.bottom, VitaTokens.Spacing.md)
            }
        }
    }

    private func leaderboardPeriodPill(label: String, period: String) -> some View {
        let isActive = vm.selectedLeaderboardPeriod == period
        return Button {
            Task { await vm.reloadLeaderboard(period: period) }
        } label: {
            Text(label)
                .font(.system(size: VitaTokens.Typography.fontSizeXs, weight: .bold))
                .foregroundStyle(
                    isActive
                        ? VitaColors.accentLight.opacity(0.85)
                        : VitaColors.textWarm.opacity(0.35)
                )
                .padding(.horizontal, VitaTokens.Spacing.md)
                .padding(.vertical, VitaTokens.Spacing.xs + 1)
                .background(
                    Capsule()
                        .fill(
                            isActive
                                ? VitaColors.glassInnerLight.opacity(0.12)
                                : Color.white.opacity(0.02)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isActive
                                ? VitaColors.accentHover.opacity(0.18)
                                : VitaColors.textWarm.opacity(0.06),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func leaderboardRow(entry: LeaderboardEntry, isMe: Bool) -> some View {
        HStack(spacing: VitaTokens.Spacing.md) {
            Text("\(entry.rank)")
                .font(.system(size: VitaTokens.Typography.fontSizeBase, weight: .heavy))
                .foregroundStyle(rankColor(entry.rank, isMe: isMe))
                .frame(width: 22)

            // Avatar circle
            Text(initials(from: entry.displayName))
                .font(.system(size: VitaTokens.Typography.fontSizeXs, weight: .bold))
                .foregroundStyle(VitaColors.textWarm.opacity(0.7))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    avatarColor(entry.rank).opacity(0.30),
                                    avatarColor(entry.rank).opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )

            Text(entry.displayName)
                .font(VitaTypography.labelMedium)
                .foregroundStyle(
                    isMe ? VitaColors.accentLight.opacity(0.90) : VitaColors.textPrimary
                )

            Spacer()

            Text("\(entry.xp) XP")
                .font(.system(size: VitaTokens.Typography.fontSizeSm, weight: .bold))
                .foregroundStyle(VitaColors.accentLight.opacity(0.70))
                .monospacedDigit()
        }
        .padding(.horizontal, VitaTokens.Spacing.lg)
        .padding(.vertical, VitaTokens.Spacing.md)
        .background(
            isMe
                ? VitaColors.glassInnerLight.opacity(0.06)
                : Color.clear
        )
        .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.sm))
    }

    private func rankColor(_ rank: Int, isMe: Bool) -> Color {
        if isMe { return VitaColors.accentLight.opacity(0.80) }
        switch rank {
        case 1: return VitaColors.medalGold
        case 2: return VitaColors.progressoSilver.opacity(0.70)
        case 3: return VitaColors.progressoBronze.opacity(0.65)
        default: return VitaColors.textTertiary
        }
    }

    private func avatarColor(_ rank: Int) -> Color {
        switch rank {
        case 1: return VitaColors.accentHover
        case 2: return VitaColors.progressoSilver
        case 3: return VitaColors.progressoBronze
        default: return Color.white
        }
    }

    private func initials(from name: String) -> String {
        let words = name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1)) + String(words[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Shared Components

private struct ProgressoStatCard: View {
    let icon: String
    let value: String
    let label: String
    let valueColor: Color

    var body: some View {
        VitaGlassCard(cornerRadius: VitaTokens.Radius.lg) {
            HStack(spacing: VitaTokens.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: VitaTokens.Spacing.lg))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.85))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.sm)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        VitaColors.glassInnerLight.opacity(0.25),
                                        VitaColors.accentDark.opacity(0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: VitaTokens.Radius.sm)
                            .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.25), radius: 5)

                VStack(alignment: .leading, spacing: VitaTokens.Spacing.xxs) {
                    Text(value)
                        .font(.system(size: VitaTokens.Typography.fontSizeXl, weight: .bold))
                        .foregroundStyle(valueColor)
                        .tracking(VitaTokens.Typography.letterSpacingTight)
                        .monospacedDigit()
                    Text(label)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        .textCase(.uppercase)
                        .tracking(VitaTokens.Typography.letterSpacingWide)
                }
            }
            .padding(VitaTokens.Spacing.lg)
        }
    }
}

private struct ProgressoBarColumn: View {
    let label: String
    let heightFraction: CGFloat
    let isToday: Bool

    var body: some View {
        VStack(spacing: VitaTokens.Spacing.xs + 2) {
            Spacer(minLength: 0)

            UnevenRoundedRectangle(
                topLeadingRadius: 6,
                bottomLeadingRadius: 2,
                bottomTrailingRadius: 2,
                topTrailingRadius: 6
            )
            .fill(
                isToday
                    ? LinearGradient(
                        colors: [VitaColors.accent.opacity(0.70), VitaColors.accentHover.opacity(0.50)],
                        startPoint: .bottom,
                        endPoint: .top
                      )
                    : LinearGradient(
                        colors: [VitaColors.accent.opacity(0.35), VitaColors.accent.opacity(0.15)],
                        startPoint: .bottom,
                        endPoint: .top
                      )
            )
            .frame(height: max(heightFraction * 76, heightFraction > 0 ? 4 : 0))
            .shadow(
                color: isToday ? VitaColors.accent.opacity(0.18) : .clear,
                radius: 6,
                y: -2
            )

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(
                    isToday
                        ? VitaColors.accentLight.opacity(0.70)
                        : VitaColors.textWarm.opacity(0.28)
                )
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Shared helpers

private var glassRowDivider: some View {
    Rectangle()
        .fill(VitaColors.textWarm.opacity(0.04))
        .frame(height: 1)
        .padding(.horizontal, VitaTokens.Spacing.lg)
}

private func accuracyColor(for accuracy: Double) -> Color {
    if accuracy >= 70 { return VitaColors.dataGreen }
    if accuracy >= 50 { return VitaColors.dataAmber }
    return VitaColors.dataRed
}

private func subjectDisplayName(_ id: String) -> String {
    let names: [String: String] = [
        "cm-cardio": "Cardiologia",
        "cm-pneumo": "Pneumologia",
        "cm-gastro": "Gastroenterologia",
        "cm-nefro": "Nefrologia",
        "cm-endocrino": "Endocrinologia",
        "cm-reumato": "Reumatologia",
        "cm-hemato": "Hematologia",
        "cm-infecto": "Infectologia",
        "cm-neuro": "Neurologia",
        "cir-geral": "Cirurgia Geral",
        "cir-trauma": "Cirurgia do Trauma",
        "ped-geral": "Pediatria",
        "go-obstetricia": "Obstetricia",
        "go-ginecologia": "Ginecologia",
        "prev-epidemio": "Epidemiologia",
        "prev-bioestat": "Bioestatistica",
    ]
    return names[id] ?? id.replacingOccurrences(of: "-", with: " ").capitalized
}
