import SwiftUI

// MARK: - Home content (shell: unified hero + CTA + VitaScore-ordered chips + recent sessions)

struct QBankHomeContent: View {
    @Bindable var vm: QBankViewModel
    @Environment(\.appContainer) private var container
    let onBack: () -> Void

    /// First-load-only empty bounce. Chip selection can legitimately drop
    /// `totalAvailable` to zero for a single discipline — that must NOT
    /// kick the user out of Home.
    @State private var didCheckEmptyBounce = false

    /// Enrolled subjects ordered by VitaScore desc. Matches Dashboard.
    ///
    /// SOT: `AppDataManager.gradesResponse.current` — same source the
    /// Dashboard's MateriasAgendaWidget reads. One canonical disciplines list
    /// across the whole app (per CLAUDE.md §AppDataManager is 4th SOT).
    private var sortedSubjects: [StudySubjectChipItem] {
        let grades = container.dataManager.gradesResponse?.current ?? []
        let dm = container.dataManager
        return grades
            .sorted { dm.vitaScore(for: $0.subjectName) > dm.vitaScore(for: $1.subjectName) }
            .map { StudySubjectChipItem(id: $0.id, name: $0.subjectName) }
    }

    /// Enrolled subjects paired with the catalog `questionCount` from
    /// `vm.state.filters.disciplines`. Slug-matched so "Patologia Medica" on
    /// the dashboard finds "patologia-geral" in the catalog when the backend
    /// aliases them. Count falls back to 0 while filters are still loading.
    private var enrolledWithCounts: [(subject: StudySubjectChipItem, count: Int)] {
        let flatDisc = QBankUiState.flattenDisciplines(vm.state.filters.disciplines)
        return sortedSubjects.map { subj in
            let subjSlug = QBankViewModel.slugifyDisciplineTitle(subj.name)
            let count = flatDisc.first { d in
                QBankViewModel.slugifyDisciplineTitle(d.title) == subjSlug
            }?.questionCount ?? 0
            return (subj, count)
        }
    }

    var body: some View {
        Group {
            if vm.state.progressLoading && vm.state.progress.totalAvailable == 0
                && vm.state.recentSessions.isEmpty {
                ProgressView().tint(VitaColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // HERO — themed rich (questoes = amber)
                        StudyHeroStat(
                            primary: formatNumber(vm.state.progress.totalAnswered),
                            primaryCaption: primaryCaption,
                            stats: heroStats,
                            theme: .questoes
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                        // CTA — themed shell button (amber gradient for questoes)
                        StudyShellCTA(
                            title: "Nova Sess\u{e3}o",
                            theme: .questoes,
                            action: { vm.goToDisciplines() },
                            systemImage: "plus.circle.fill"
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        // DISCIPLINAS — VitaScore-ordered chips (inline filter)
                        if !sortedSubjects.isEmpty {
                            StudySubjectChips(
                                subjects: sortedSubjects,
                                selectedId: Binding(
                                    get: { vm.state.selectedSubjectId },
                                    set: { id in
                                        let name = sortedSubjects.first(where: { $0.id == id })?.name
                                        vm.setSelectedSubject(id: id, name: name)
                                    }
                                ),
                                theme: .questoes
                            )
                            .padding(.top, 14)
                        }

                        // DISCIPLINAS — detailed list with question counts per enrolled subject
                        if !enrolledWithCounts.isEmpty {
                            QBankSectionLabel(title: "Disciplinas")
                                .padding(.horizontal, 16)
                                .padding(.top, 18)

                            VStack(spacing: 8) {
                                ForEach(enrolledWithCounts, id: \.subject.id) { entry in
                                    QBankDisciplineRow(
                                        name: entry.subject.name,
                                        count: entry.count,
                                        isSelected: vm.state.selectedSubjectId == entry.subject.id,
                                        isLoading: vm.state.filtersLoading && entry.count == 0,
                                        theme: .questoes,
                                        action: {
                                            let sameSelected = vm.state.selectedSubjectId == entry.subject.id
                                            vm.setSelectedSubject(
                                                id: sameSelected ? nil : entry.subject.id,
                                                name: sameSelected ? nil : entry.subject.name
                                            )
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }

                        // SESS\u{d5}ES RECENTES
                        QBankSectionLabel(title: "Sess\u{f5}es recentes")
                            .padding(.horizontal, 16)
                            .padding(.top, 18)

                        if filteredSessions.isEmpty {
                            QBankInfoCard(
                                icon: "clock",
                                message: emptySessionsMessage
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(filteredSessions) { session in
                                    QBankSessionCard(session: session, theme: .questoes) {
                                        vm.resumeSession(session)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }

                        if let error = vm.state.error {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.dataRed)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }

                        Spacer(minLength: 120)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .task {
            vm.loadHomeData()
            // Warm filters so the Disciplinas list can render question counts
            // without forcing the user to tap "Nova Sessão" first.
            if vm.state.filters.disciplines.isEmpty {
                vm.loadFilters()
            }
        }
        .onChange(of: vm.state.progressLoading) { _, loading in
            // Fresh-install bounce: first-load only. If the student has zero
            // enrolled questions AND zero sessions on arrival, jump to
            // Disciplinas so Home never shows a lie like "0 / 95.424".
            // Skipped when a chip is selected (selection legitimately narrows
            // totals) and after the first check (chip flips should not bounce).
            guard !loading, !didCheckEmptyBounce else { return }
            didCheckEmptyBounce = true
            if vm.state.selectedSubjectId == nil
                && vm.state.progress.totalAvailable == 0
                && vm.state.recentSessions.isEmpty {
                vm.goToDisciplines()
            }
        }
    }

    // MARK: - Hero helpers

    private var primaryCaption: String {
        if let name = vm.state.selectedSubjectName, !name.isEmpty {
            return "respondidas em \(name.lowercased())"
        }
        return "quest\u{f5}es respondidas"
    }

    private var heroStats: [StudyHeroStat.Stat] {
        let p = vm.state.progress
        let acc = Int((p.normalizedAccuracy * 100).rounded())
        let availLabel = vm.state.selectedSubjectId == nil ? "dispon\u{ed}veis" : "na mat\u{e9}ria"
        return [
            .init(value: formatNumber(p.totalAvailable), label: availLabel),
            .init(value: "\(acc)%", label: "acerto"),
        ]
    }

    // MARK: - Session filter (client-side scope when a chip is active)

    private var filteredSessions: [QBankSessionSummary] {
        guard let name = vm.state.selectedSubjectName, !name.isEmpty else {
            return vm.state.recentSessions
        }
        let key = name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return vm.state.recentSessions.filter { session in
            (session.disciplineTitles ?? []).contains { t in
                t.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current) == key
            }
        }
    }

    private var emptySessionsMessage: String {
        if let name = vm.state.selectedSubjectName, !name.isEmpty {
            return "Nenhuma sess\u{e3}o de \(name) ainda."
        }
        return "Suas sess\u{f5}es recentes aparecer\u{e3}o aqui."
    }

    // MARK: - Number formatting (pt_BR)

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - QBank Info Card (shared empty state)

private struct QBankInfoCard: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(VitaColors.textSecondary)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(VitaColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.surfaceBorder, lineWidth: 1)
        )
    }
}

// MARK: - QBank Background (bg-qbank fullscreen + dark overlay)

struct QBankBackground: View {
    var body: some View {
        ZStack {
            VitaColors.surface

            Image("bg-qbank")
                .resizable()
                .aspectRatio(contentMode: .fill)

            // Dark gradient overlay
            LinearGradient(
                stops: [
                    .init(color: VitaColors.surface.opacity(0.15), location: 0),
                    .init(color: VitaColors.surface.opacity(0.15), location: 0.40),
                    .init(color: VitaColors.surface.opacity(0.55), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Section Label (uppercase, matches .section-label CSS)

struct QBankSectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(VitaColors.sectionLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Discipline Row (enrolled subject + available question count)

/// Glass row showing one enrolled discipline and how many questions the
/// catalog has for it. Tap toggles the home chip filter (scopes progress
/// and recent sessions to that discipline).
struct QBankDisciplineRow: View {
    let name: String
    let count: Int
    let isSelected: Bool
    let isLoading: Bool
    var theme: StudyShellTheme = .questoes
    let action: () -> Void

    private var countLabel: String {
        if isLoading { return "\u{2014}" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Theme bullet — tinted capsule dot
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.primary.opacity(0.35),
                                    theme.primary.opacity(0.12),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    Circle()
                        .stroke(theme.primaryLight.opacity(0.45), lineWidth: 1)
                    Circle()
                        .fill(theme.primaryLight.opacity(isSelected ? 0.95 : 0.55))
                        .frame(width: 7, height: 7)
                }
                .frame(width: 22, height: 22)

                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(isSelected ? 0.95 : 0.85))
                    .lineLimit(1)

                Spacer(minLength: 8)

                // Question count pill
                HStack(spacing: 4) {
                    Text(countLabel)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primaryLight.opacity(isLoading ? 0.45 : 0.92))
                        .contentTransition(.numericText())
                    Text("quest\u{f5}es")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.primary.opacity(isSelected ? 0.22 : 0.08),
                                    theme.primary.opacity(isSelected ? 0.10 : 0.02),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        theme.primaryLight.opacity(isSelected ? 0.55 : 0.18),
                        lineWidth: isSelected ? 1.0 : 0.6
                    )
            )
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Card (matches .glass-card.session-card CSS)

struct QBankSessionCard: View {
    let session: QBankSessionSummary
    var theme: StudyShellTheme = .questoes
    let action: () -> Void

    private var pct: Int {
        guard !session.isActive, session.totalQuestions > 0 else { return 0 }
        return Int(Double(session.correctCount) / Double(session.totalQuestions) * 100)
    }

    private var displayTitle: String {
        if let t = session.title, !t.isEmpty { return t }
        if let first = session.disciplineTitles?.first, !first.isEmpty {
            let count = session.disciplineTitles?.count ?? 1
            return count > 1 ? "\(first) +\(count - 1)" : first
        }
        return "Sess\u{e3}o de \(session.totalQuestions) quest\u{f5}es"
    }

    private var metaText: String {
        let when = Self.formatRelative(session.createdAt)
        if session.isActive {
            return "\(session.currentIndex)/\(session.totalQuestions) \u{b7} \(when)"
        }
        return "\(session.correctCount)/\(session.totalQuestions) \u{b7} \(pct)% \u{b7} \(when)"
    }

    var body: some View {
        Button(action: action) {
            VitaGlassCard(cornerRadius: 18) {
                HStack(spacing: 12) {
                    // Session icon — tinted by shell theme
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        theme.primary.opacity(0.28),
                                        theme.primary.opacity(0.08),
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(theme.primaryLight.opacity(0.30), lineWidth: 1)
                        Image(systemName: session.isActive ? "clock" : "checkmark.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(theme.primaryLight.opacity(0.90))
                    }
                    .frame(width: 40, height: 40)

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.90))
                            .lineLimit(1)
                        Text(metaText)
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Accuracy % (only for finished sessions)
                    if !session.isActive {
                        Text("\(pct)%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(theme.primaryLight.opacity(0.92))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VitaColors.textSecondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date formatting (pt_BR)

    private static let iso8601WithFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd MMM HH:mm"
        return f
    }()

    static func formatRelative(_ raw: String, now: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        guard !raw.isEmpty else { return "" }
        let date = iso8601WithFrac.date(from: raw) ?? iso8601.date(from: raw)
        guard let date else { return "" }
        var cal = calendar
        cal.locale = Locale(identifier: "pt_BR")
        cal.timeZone = TimeZone.current
        let today = cal.startOfDay(for: now)
        let sessionDay = cal.startOfDay(for: date)
        if let diff = cal.dateComponents([.day], from: sessionDay, to: today).day {
            if diff == 0 { return "hoje \(timeFormatter.string(from: date))" }
            if diff == 1 { return "ontem \(timeFormatter.string(from: date))" }
        }
        return shortDateFormatter.string(from: date)
    }
}
