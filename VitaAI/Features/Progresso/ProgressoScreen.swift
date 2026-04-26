import SwiftUI

// MARK: - ProgressoScreen (connected to real API via ProgressoViewModel)

struct ProgressoScreen: View {
    @Environment(\.appContainer) private var container

    // Gold palette from VitaColors
    private let goldPrimary = VitaColors.accentHover
    private let goldMuted   = VitaColors.accentLight
    private let textPrimary = VitaColors.textPrimary
    private let textSec     = VitaColors.textSecondary
    private let textDim     = VitaColors.textTertiary
    private let greenStat   = Color(red: 0.51, green: 0.784, blue: 0.549)
    private let glassBg     = VitaColors.glassBg
    private let glassBorder = VitaColors.glassBorder

    @State private var selectedLeaderboardTab = 0

    var body: some View {
        let vm = container.progressoViewModel
        return Group {
            if vm.isLoading && vm.userProgress == nil {
                VitaHeartbeatLoader(orbSize: 88)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = vm.error, vm.userProgress == nil {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(textDim)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(textSec)
                        .multilineTextAlignment(.center)
                    Button("Tentar novamente") {
                        Task { await vm.load() }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(goldMuted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                content(vm: vm)
            }
        }
        .refreshable {
            await vm.load()
        }
        .task {
            await vm.loadIfNeeded()
            ScreenLoadContext.finish(for: "Progresso")
        }
        .trackScreen("Progresso")
    }

    private func content(vm: ProgressoViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                heroCard(vm: vm)
                if hasAnyStats(vm: vm) {
                    statsGrid(vm: vm)
                }
                if hasWeeklyData(vm: vm) {
                    weeklyChart(vm: vm)
                }
                if !vm.subjects.isEmpty {
                    weakAreasSection(vm: vm)
                }
                if !vm.badges.isEmpty {
                    achievementsSection(vm: vm)
                }
                if !vm.activity.isEmpty {
                    activitySection(vm: vm)
                }
                leaderboardSection(vm: vm)
                if !vm.heatmap.isEmpty {
                    heatmapSection(vm: vm)
                }
            }
            .padding(.horizontal, 16)
            // Sem padding-bottom: passa por trás da TabBar Liquid Glass.
        }
    }

    // MARK: - Hero Card (unified with Dashboard/Faculdade style)

    private func heroCard(vm: ProgressoViewModel) -> some View {
        let level = vm.userProgress?.level ?? 1
        let currentXp = vm.userProgress?.currentLevelXp ?? vm.userProgress?.totalXp ?? 0
        let xpToNext = vm.userProgress?.xpToNextLevel ?? 100
        let totalXp = vm.userProgress?.totalXp ?? 0
        let missing = max(xpToNext - currentXp, 0)
        let levelRatio = xpToNext > 0 ? Double(currentXp) / Double(xpToNext) : 0

        let title = missing > 0
            ? "Faltam \(missing) XP pra Nível \(level + 1)"
            : "Pronto pra Nível \(level + 1)"

        var stats: [(text: String, icon: String?)] = [
            ("\(totalXp) XP total", nil)
        ]
        if vm.streakDays > 0 {
            stats.append(("\(vm.streakDays) \(vm.streakDays == 1 ? "dia" : "dias") seguidos", nil))
        }
        if vm.totalQuestions > 0 {
            stats.append(("\(vm.totalQuestions) respondidas", nil))
        }

        return VitaHeroCard(
            label: "NÍVEL \(level)",
            title: title,
            subtitle: "\(currentXp) de \(xpToNext) XP",
            progress: levelRatio,
            stats: stats,
            cta: "Ver ranking",
            bgImage: "fundo-dashboard",
            action: { /* scroll to leaderboard — no-op for now */ }
        )
    }

    // MARK: - Empty-state helpers

    private func hasAnyStats(vm: ProgressoViewModel) -> Bool {
        vm.streakDays > 0 || vm.totalStudyHours > 0 || vm.avgAccuracy > 0 || vm.totalQuestions > 0
    }

    private func hasWeeklyData(vm: ProgressoViewModel) -> Bool {
        vm.weeklyActualHours > 0 || vm.weeklyHours.contains(where: { $0 > 0 })
    }

    // MARK: - Achievements (Conquistas) — grid com inicial do badge, sem SF Symbol decorativo

    private func achievementsSection(vm: ProgressoViewModel) -> some View {
        let unlocked = vm.badges.filter(\.unlocked)
        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Conquistas \(unlocked.count)/\(vm.badges.count)")

            glassCard {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                    spacing: 10
                ) {
                    ForEach(vm.badges.prefix(8)) { badge in
                        badgeTile(badge)
                    }
                }
                .padding(14)
            }
        }
    }

    private func badgeTile(_ badge: BadgeWithStatus) -> some View {
        let initial = String(badge.name.prefix(2)).uppercased()
        let color: Color = badge.unlocked ? goldMuted.opacity(0.90) : VitaColors.textWarm.opacity(0.25)
        return VStack(spacing: 6) {
            Text(initial)
                .font(.system(size: 13, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            badge.unlocked
                                ? VitaColors.glassInnerLight.opacity(0.18)
                                : Color.white.opacity(0.02)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            badge.unlocked
                                ? goldPrimary.opacity(0.22)
                                : VitaColors.textWarm.opacity(0.05),
                            lineWidth: 1
                        )
                )

            Text(badge.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
                .lineLimit(1)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Activity Feed — última atividade real do usuário

    private func activitySection(vm: ProgressoViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Atividade recente")

            glassCard {
                VStack(spacing: 0) {
                    ForEach(Array(vm.activity.prefix(5).enumerated()), id: \.offset) { idx, item in
                        activityRow(item)
                        if idx < min(vm.activity.count, 5) - 1 {
                            dividerLine
                        }
                    }
                }
            }
        }
    }

    private func activityRow(_ item: ActivityFeedItem) -> some View {
        HStack(spacing: 12) {
            Text(item.action)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.80))
                .lineLimit(1)

            Spacer()

            if item.xpAwarded > 0 {
                Text("+\(item.xpAwarded) XP")
                    .font(.system(size: 11, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(goldMuted.opacity(0.75))
            }

            Text(relativeTime(from: item.createdAt))
                .font(.system(size: 10))
                .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func relativeTime(from iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "" }
        let seconds = Date().timeIntervalSince(date)
        if seconds < 60 { return "agora" }
        if seconds < 3600 { return "\(Int(seconds/60))min" }
        if seconds < 86400 { return "\(Int(seconds/3600))h" }
        return "\(Int(seconds/86400))d"
    }

    // MARK: - Stats Grid 2x2

    private func statsGrid(vm: ProgressoViewModel) -> some View {
        let studyHoursText = vm.totalStudyHours < 1
            ? "\(Int(vm.totalStudyHours * 60))min"
            : String(format: "%.0fh", vm.totalStudyHours)
        let accuracyText = "\(Int(vm.avgAccuracy * 100))%"
        let flashcardsText = "\(vm.totalQuestions)"

        let items: [(String, String, Color, Bool)] = [
            ("\(vm.streakDays)", "Dias streak", goldMuted.opacity(0.90), vm.streakDays > 0),
            (studyHoursText, "Estudo total", goldMuted.opacity(0.90), vm.totalStudyHours > 0),
            (accuracyText, "Acerto médio", greenStat.opacity(0.85), vm.avgAccuracy > 0),
            (flashcardsText, "Respondidas", goldMuted.opacity(0.90), vm.totalQuestions > 0)
        ].filter { $0.3 }

        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
            spacing: 8
        ) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                statCard(value: item.0, label: item.1, valueColor: item.2)
            }
        }
    }

    private func statCard(value: String, label: String, valueColor: Color) -> some View {
        glassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(valueColor)
                    .tracking(-0.3)
                    .monospacedDigit()
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VitaColors.sectionLabel)
                    .textCase(.uppercase)
                    .kerning(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
        }
    }

    // MARK: - Weekly Chart

    private func weeklyChart(vm: ProgressoViewModel) -> some View {
        let maxHour = vm.weeklyHours.max() ?? 1
        let normalizedBars = vm.weeklyHours.map { maxHour > 0 ? $0 / maxHour : 0 }
        let calendar = Calendar.current
        let rawWeekday = calendar.component(.weekday, from: Date())
        let todayIdx = (rawWeekday + 5) % 7

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Esta semana")

            glassCard {
                VStack(spacing: 12) {
                    HStack {
                        Text(String(format: "%.1f", vm.weeklyActualHours) + "h de \(Int(vm.weeklyGoalHours))h")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))
                        Spacer()
                        Text("Meta semanal")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        let labels = ["S", "T", "Q", "Q", "S", "S", "D"]
                        ForEach(0..<7, id: \.self) { idx in
                            barColumn(
                                label: labels[idx],
                                heightFraction: normalizedBars[idx],
                                isToday: idx == todayIdx
                            )
                        }
                    }
                    .frame(height: 90)
                }
                .padding(14)
            }
        }
    }

    private func barColumn(label: String, heightFraction: CGFloat, isToday: Bool) -> some View {
        VStack(spacing: 6) {
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
                        colors: [VitaColors.accent.opacity(0.70), goldPrimary.opacity(0.50)],
                        startPoint: .bottom, endPoint: .top
                      )
                    : LinearGradient(
                        colors: [VitaColors.accent.opacity(0.35), VitaColors.accent.opacity(0.15)],
                        startPoint: .bottom, endPoint: .top
                      )
            )
            .frame(height: max(heightFraction * 76, heightFraction > 0 ? 4 : 0))
            .shadow(color: isToday ? VitaColors.accent.opacity(0.18) : .clear, radius: 6, y: -2)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isToday ? goldMuted.opacity(0.70) : VitaColors.textWarm.opacity(0.28))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Weak Areas ("Onde melhorar")

    private func weakAreasSection(vm: ProgressoViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Onde melhorar")

            glassCard {
                VStack(spacing: 0) {
                    ForEach(Array(vm.subjects.sorted(by: { $0.accuracy < $1.accuracy }).prefix(5).enumerated()), id: \.offset) { idx, subject in
                        let pct = Int(subject.accuracy * 100)
                        let color = pct < 60
                            ? Color(red: 1.0, green: 0.471, blue: 0.314)
                            : Color(red: 1.0, green: 0.784, blue: 0.392)
                        let hoursText = subject.hoursSpent < 1
                            ? "\(Int(subject.hoursSpent * 60))min"
                            : String(format: "%.0fh", subject.hoursSpent)
                        weakAreaRow(
                            name: subject.subjectId,
                            meta: "\(subject.questionCount) questões · \(hoursText) estudo",
                            pct: pct,
                            color: color
                        )
                        if idx < min(vm.subjects.count, 5) - 1 {
                            dividerLine
                        }
                    }
                }
            }
        }
    }

    private func weakAreaRow(name: String, meta: String, pct: Int, color: Color) -> some View {
        HStack(spacing: 10) {
            // Subject initial in circle instead of hardcoded image
            Text(String(name.prefix(2)).uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(goldMuted.opacity(0.85))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(VitaColors.glassInnerLight.opacity(0.15))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                Text(meta)
                    .font(.system(size: 10))
                    .foregroundStyle(textSec)
            }

            Spacer()

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 48, height: 4)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.65), color.opacity(0.40)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: 48 * CGFloat(pct) / 100.0, height: 4)
            }

            Text("\(pct)%")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color.opacity(0.75))
                .frame(minWidth: 28, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(VitaColors.textWarm.opacity(0.04))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    // MARK: - Leaderboard

    private func leaderboardSection(vm: ProgressoViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Ranking")

            glassCard {
                VStack(spacing: 0) {
                    // Tabs
                    HStack(spacing: 4) {
                        lbTab("Semanal", index: 0)
                        lbTab("Mensal", index: 1)
                        lbTab("Total", index: 2)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)

                    if vm.leaderboard.isEmpty {
                        Text("Nenhum dado de ranking ainda")
                            .font(.system(size: 12))
                            .foregroundStyle(textSec)
                            .padding(.vertical, 20)
                    } else {
                        // Other users (not me)
                        let others = vm.leaderboard.filter { !$0.isMe }.prefix(5)
                        ForEach(Array(others.enumerated()), id: \.offset) { idx, entry in
                            lbRow(
                                rank: entry.rank,
                                initials: entry.initials,
                                name: entry.name,
                                xp: "\(entry.xp) XP",
                                rankColor: rankColorForPosition(entry.rank),
                                avatarBg: avatarColorForPosition(entry.rank),
                                isMe: false
                            )
                            if idx < others.count - 1 {
                                lbDivider
                            }
                        }

                        // My entry
                        if let me = vm.myLeaderboardEntry {
                            Rectangle()
                                .fill(goldPrimary.opacity(0.08))
                                .frame(height: 1)
                                .padding(.horizontal, 14)
                                .padding(.top, 6)

                            HStack {
                                Text("SUA POSICAO")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(VitaColors.textWarm.opacity(0.25))
                                    .tracking(0.5)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.top, 2)

                            lbRow(
                                rank: me.rank,
                                initials: me.initials,
                                name: me.name,
                                xp: "\(me.xp) XP",
                                rankColor: goldMuted.opacity(0.80),
                                avatarBg: goldPrimary,
                                isMe: true
                            )
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
    }

    private func lbTab(_ text: String, index: Int) -> some View {
        Button {
            selectedLeaderboardTab = index
            let period = ["weekly", "monthly", "total"][index]
            Task { await container.progressoViewModel.loadLeaderboard(period: period) }
        } label: {
            Text(text)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(
                    selectedLeaderboardTab == index
                        ? goldMuted.opacity(0.85)
                        : VitaColors.textWarm.opacity(0.35)
                )
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(
                            selectedLeaderboardTab == index
                                ? VitaColors.glassInnerLight.opacity(0.12)
                                : Color.white.opacity(0.02)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            selectedLeaderboardTab == index
                                ? goldPrimary.opacity(0.18)
                                : VitaColors.textWarm.opacity(0.06),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func lbRow(rank: Int, initials: String, name: String, xp: String, rankColor: Color, avatarBg: Color, isMe: Bool = false) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(rankColor)
                .frame(width: 22)

            Text(initials)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VitaColors.textWarm.opacity(0.7))
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [avatarBg.opacity(0.30), avatarBg.opacity(0.15)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                )

            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isMe ? goldMuted.opacity(0.90) : Color.white.opacity(0.85))

            Spacer()

            Text(xp)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(goldMuted.opacity(0.70))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isMe ? AnyShapeStyle(VitaColors.glassInnerLight.opacity(0.06)) : AnyShapeStyle(.clear))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var lbDivider: some View {
        Rectangle()
            .fill(VitaColors.textWarm.opacity(0.04))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    // MARK: - Heatmap

    private func heatmapSection(vm: ProgressoViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Últimos \(vm.heatmap.count) dias")

            glassCard {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 13)

                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<vm.heatmap.count, id: \.self) { i in
                        Rectangle()
                            .fill(heatmapColor(vm.heatmap[i]))
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }
                .padding(14)
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

    // MARK: - Shared Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(VitaColors.sectionLabel)
            .textCase(.uppercase)
            .kerning(0.8)
    }

    private func glassCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VitaGlassCard(cornerRadius: 16) { content() }
    }

    private func rankColorForPosition(_ rank: Int) -> Color {
        switch rank {
        case 1: return goldMuted.opacity(0.90)
        case 2: return Color(red: 0.784, green: 0.784, blue: 0.824).opacity(0.70)
        case 3: return Color(red: 0.706, green: 0.549, blue: 0.392).opacity(0.65)
        default: return textDim
        }
    }

    private func avatarColorForPosition(_ rank: Int) -> Color {
        switch rank {
        case 1: return goldPrimary
        case 2: return Color(red: 0.784, green: 0.784, blue: 0.824)
        case 3: return Color(red: 0.706, green: 0.549, blue: 0.392)
        default: return Color.white
        }
    }
}
