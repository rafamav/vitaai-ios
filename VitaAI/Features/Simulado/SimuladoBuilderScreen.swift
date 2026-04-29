import SwiftUI
import Sentry

// MARK: - SimuladoBuilderScreen — Fase 4 reescrita gold-standard
//
// Tela única que substitui SimuladoHomeScreen + SimuladoConfigScreen.
// Composição vertical com toggle Template/Custom no topo, Hero + Lente +
// Filtros lente-aware (Custom) + Cronômetro visível + Quantidade + Recents
// + CTA sticky. Theme `.simulados` (azul).
//
// SOT layout: agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md §3.2 + §11.3
// Espelha QBankBuilderScreen (Fase 3). Diff principal:
//  - toggle Template/Custom grande no topo
//  - section Cronômetro visível (não em Avançadas)
//  - defaults Qtd [20,30,50,100]
//  - recents = SimuladoAttemptEntry (não QBankSessionSummary)

struct SimuladoBuilderScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: SimuladoBuilderViewModel?
    let onBack: () -> Void
    let onSessionCreated: (String) -> Void
    let onOpenAttempt: (SimuladoAttemptEntry) -> Void

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                DashboardSkeleton().tint(StudyShellTheme.simulados.primaryLight)
            }
        }
        .onAppear {
            if vm == nil {
                vm = SimuladoBuilderViewModel(api: container.api, dataManager: container.dataManager)
                vm?.boot()
                SentrySDK.reportFullyDisplayed()
            }
        }
        .navigationBarHidden(true)
        .trackScreen("SimuladoBuilder")
    }

    @ViewBuilder
    private func content(vm: SimuladoBuilderViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {

                // 1. Hero — score médio + simulados completos + total questões
                StudyHeroStat(
                    primary: heroPrimary(avgScore: vm.state.statsAvgScore),
                    primaryCaption: "score médio",
                    stats: [
                        .init(value: "\(vm.state.statsCompletedAttempts)", label: "simulados"),
                        .init(value: formatNumber(vm.state.statsTotalQuestions), label: "questões"),
                    ],
                    theme: .simulados
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // 2. Toggle Template ⇄ Custom — mode selector grande no topo
                modeSelector(vm: vm)
                    .padding(.horizontal, 16)

                if vm.state.mode == .template {
                    // ── Modo TEMPLATE ──
                    templatesSection(vm: vm)
                        .padding(.horizontal, 16)
                } else {
                    // ── Modo CUSTOM ──

                    // 3. Lente
                    LensSwitcher(
                        selection: Binding(
                            get: { vm.state.lens },
                            set: { vm.setLens($0) }
                        ),
                        theme: .simulados
                    )
                    .padding(.horizontal, 16)

                    // 4. Tags removíveis
                    FilterChipsRow(
                        chips: appliedFilterChips(vm: vm),
                        theme: .simulados,
                        onClearAll: { vm.clearAllFilters() }
                    )

                    // 5. Especialidades / Sistemas / Áreas — drill 3 níveis (Onda 4)
                    if vm.state.groups.isEmpty && vm.state.filtersLoading {
                        groupsSkeleton.padding(.horizontal, 16)
                    } else {
                        HorizontalDrillDown(
                            n1Title: groupTitle(for: vm.state.lens),
                            n2Title: n2Title(for: vm.state.lens),
                            n3Title: "Conteúdos",
                            theme: .simulados,
                            n1Items: vm.state.groups.map { g in
                                DrillItem(id: g.slug, name: g.name, count: g.count, hasChildren: !g.children.isEmpty)
                            },
                            selectedN1Ids: Binding(
                                get: { vm.state.selectedGroupSlugs },
                                set: { newSet in
                                    let removed = vm.state.selectedGroupSlugs.subtracting(newSet)
                                    let added = newSet.subtracting(vm.state.selectedGroupSlugs)
                                    for s in removed { vm.toggleGroup(slug: s) }
                                    for s in added { vm.toggleGroup(slug: s) }
                                }
                            ),
                            n2ItemsFor: { n1Id in
                                guard let group = vm.state.groups.first(where: { $0.slug == n1Id }) else { return [] }
                                return group.children.map { c in
                                    DrillItem(
                                        id: "\(c.parentSlug)/\(c.slug)",
                                        name: c.name,
                                        count: c.count,
                                        // N3 (conteúdos) não vem ainda no payload — quando
                                        // backend expor children.children ou ?parentSlug=,
                                        // troca pra `true`. Hoje N2 é folha selecionável.
                                        hasChildren: false
                                    )
                                }
                            },
                            selectedN2Ids: Binding(
                                get: { vm.state.selectedSubgroupIds },
                                set: { newSet in
                                    let removed = vm.state.selectedSubgroupIds.subtracting(newSet)
                                    let added = newSet.subtracting(vm.state.selectedSubgroupIds)
                                    for id in removed {
                                        if let parts = parseId(id) {
                                            vm.toggleSubgroup(parentSlug: parts.0, childSlug: parts.1)
                                        }
                                    }
                                    for id in added {
                                        if let parts = parseId(id) {
                                            vm.toggleSubgroup(parentSlug: parts.0, childSlug: parts.1)
                                        }
                                    }
                                }
                            ),
                            n3ItemsFor: { _ in [] },
                            selectedN3Ids: .constant([]),
                            onSelectionChange: { /* ViewModel já dispara scheduleRefreshPreview no toggle */ }
                        )
                        .padding(.horizontal, 16)
                    }

                    // 6. Formato
                    FormatPills(
                        selected: Binding(
                            get: { vm.state.selectedFormats },
                            set: { newSet in
                                let removed = vm.state.selectedFormats.subtracting(newSet)
                                let added = newSet.subtracting(vm.state.selectedFormats)
                                for f in removed { vm.toggleFormat(f) }
                                for f in added { vm.toggleFormat(f) }
                            }
                        ),
                        theme: .simulados
                    )
                    .padding(.horizontal, 16)

                    // 7. Dificuldade
                    if !vm.state.difficulties.isEmpty {
                        difficultySection(vm: vm)
                            .padding(.horizontal, 16)
                    }
                }

                // 8. Cronômetro — VISÍVEL sempre (decisão central simulado, spec §11.3)
                timerSection(vm: vm)
                    .padding(.horizontal, 16)

                // 9. Quantidade — defaults [20,30,50,100]
                quantitySection(vm: vm)
                    .padding(.horizontal, 16)

                // 10. Recents (sessões/tentativas)
                if !vm.state.recentAttempts.isEmpty {
                    recentsSection(vm: vm)
                }
            }
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StickyBottomCTA(
                title: ctaTitle(vm: vm),
                count: vm.state.mode == .template ? templateCount(vm: vm) : vm.state.displayCount,
                isLoading: vm.state.previewLoading,
                isCreating: vm.state.creatingSession,
                theme: .simulados,
                action: {
                    Task {
                        if let id = await vm.createSession() {
                            onSessionCreated(id)
                        }
                    }
                }
            )
        }
        .background(Color.clear)
    }

    // MARK: - Mode selector (Template ⇄ Custom)

    private func modeSelector(vm: SimuladoBuilderViewModel) -> some View {
        HStack(spacing: 0) {
            ForEach(SimuladoBuilderMode.allCases) { m in
                let isSelected = vm.state.mode == m
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { vm.setMode(m) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: m.icon)
                            .font(.system(size: 13, weight: .semibold))
                        Text(m.label)
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(isSelected ? StudyShellTheme.simulados.primaryLight : VitaColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 11)
                            .fill(isSelected ? StudyShellTheme.simulados.primary.opacity(0.20) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(isSelected ? StudyShellTheme.simulados.primaryLight.opacity(0.32) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(VitaColors.surfaceElevated.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VitaColors.glassBorder.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Templates section

    private func templatesSection(vm: SimuladoBuilderViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TEMPLATES OFICIAIS")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)

            if vm.state.templates.isEmpty {
                VitaGlassCard(cornerRadius: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: vm.state.screenLoading ? "hourglass" : "exclamationmark.triangle")
                            .font(.system(size: 14))
                            .foregroundStyle(VitaColors.textTertiary)
                        Text(vm.state.screenLoading ? "Carregando templates..." : "Sem templates disponíveis. Use Custom.")
                            .font(.system(size: 12))
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    .padding(14)
                }
            } else {
                VStack(spacing: 8) {
                    ForEach(vm.state.templates) { tpl in
                        templateRow(tpl: tpl, vm: vm)
                    }
                }
            }
        }
    }

    private func templateRow(tpl: SimuladoTemplateDTO, vm: SimuladoBuilderViewModel) -> some View {
        let isSelected = vm.state.selectedTemplateSlug == tpl.slug
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { vm.selectTemplate(slug: tpl.slug) }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(StudyShellTheme.simulados.primary.opacity(0.22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(StudyShellTheme.simulados.primaryLight.opacity(0.30), lineWidth: 1)
                        )
                    Image(systemName: tpl.iconName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(StudyShellTheme.simulados.primaryLight.opacity(0.92))
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tpl.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    let meta = "\(tpl.totalQuestions) Q" +
                        (tpl.timeLimitMinutes.map { " · \($0) min" } ?? "") +
                        (tpl.isOfficial == true ? " · oficial" : "")
                    Text(meta)
                        .font(.system(size: 10))
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected
                        ? StudyShellTheme.simulados.primaryLight
                        : VitaColors.textTertiary.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .vitaGlassCard(cornerRadius: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? StudyShellTheme.simulados.primaryLight.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timer section (visível, não em Avançadas)

    private func timerSection(vm: SimuladoBuilderViewModel) -> some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "timer")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(StudyShellTheme.simulados.primaryLight.opacity(0.9))
                    Text("CRONÔMETRO")
                        .font(.system(size: 11, weight: .bold))
                        .tracking(0.8)
                        .foregroundStyle(VitaColors.sectionLabel)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { vm.state.timerEnabled },
                        set: { vm.setTimerEnabled($0) }
                    ))
                    .labelsHidden()
                    .tint(StudyShellTheme.simulados.primaryLight)
                }

                if vm.state.timerEnabled {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach([15, 30, 60, 90, 120, 180], id: \.self) { mins in
                                let isSelected = vm.state.timerMinutes == mins
                                Button {
                                    vm.setTimerMinutes(mins)
                                } label: {
                                    Text("\(mins) min")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(isSelected
                                            ? StudyShellTheme.simulados.primaryLight
                                            : VitaColors.textSecondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            Capsule().fill(isSelected
                                                ? StudyShellTheme.simulados.primary.opacity(0.22)
                                                : Color.clear)
                                        )
                                        .overlay(
                                            Capsule().stroke(isSelected
                                                ? StudyShellTheme.simulados.primaryLight.opacity(0.32)
                                                : VitaColors.glassBorder, lineWidth: 0.75)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                } else {
                    Text("Sem limite de tempo — modo livre")
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            .padding(14)
        }
    }

    // MARK: - Quantity section

    private func quantitySection(vm: SimuladoBuilderViewModel) -> some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("QUANTIDADE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(VitaColors.sectionLabel)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([20, 30, 50, 100], id: \.self) { n in
                            QBankChip(
                                label: "\(n)",
                                isSelected: vm.state.questionCount == n
                            ) { vm.setQuestionCount(n) }
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: - Difficulty section

    private func difficultySection(vm: SimuladoBuilderViewModel) -> some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("DIFICULDADE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(VitaColors.sectionLabel)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.state.difficulties) { dc in
                            let label = "\(dc.displayLabel) (\(dc.count))"
                            QBankChip(
                                label: label,
                                isSelected: vm.state.selectedDifficulties.contains(dc.difficulty)
                            ) { vm.toggleDifficulty(dc.difficulty) }
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: - Recents section

    private func recentsSection(vm: SimuladoBuilderViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RECENTES")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
                .padding(.horizontal, 16)
            VStack(spacing: 8) {
                ForEach(vm.state.recentAttempts) { attempt in
                    SimuladoBuilderAttemptCard(attempt: attempt) {
                        onOpenAttempt(attempt)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Helpers

    private func groupTitle(for lens: ContentOrganizationMode) -> String {
        switch lens {
        case .tradicional: return "Disciplinas"
        case .pbl: return "Sistemas"
        case .greatAreas: return "Áreas"
        }
    }

    /// Label genérico do nível 2 — usado pelo HorizontalDrillDown.
    private func n2Title(for lens: ContentOrganizationMode) -> String {
        switch lens {
        case .tradicional: return "Temas"
        case .pbl: return "Clusters"
        case .greatAreas: return "Subáreas"
        }
    }

    private func appliedFilterChips(vm: SimuladoBuilderViewModel) -> [FilterChipsRow.Chip] {
        var chips: [FilterChipsRow.Chip] = []
        for slug in vm.state.selectedGroupSlugs {
            let name = vm.state.groups.first(where: { $0.slug == slug })?.name ?? slug
            chips.append(.init(id: "g-\(slug)", label: name, onRemove: { vm.toggleGroup(slug: slug) }))
        }
        for d in vm.state.selectedDifficulties {
            let label = d == "easy" ? "Fácil" : d == "hard" ? "Difícil" : "Médio"
            chips.append(.init(id: "d-\(d)", label: label, onRemove: { vm.toggleDifficulty(d) }))
        }
        for f in vm.state.selectedFormats {
            let label = f == "objective" ? "Objetivas" : f == "discursive" ? "Discursivas" : "C/Imagem"
            chips.append(.init(id: "f-\(f)", label: label, onRemove: { vm.toggleFormat(f) }))
        }
        for id in vm.state.selectedInstitutionIds {
            if let inst = vm.state.institutions.first(where: { $0.id == id }) {
                chips.append(.init(id: "i-\(id)", label: inst.name, onRemove: { vm.toggleInstitution(id: id) }))
            }
        }
        return chips
    }

    private func ctaTitle(vm: SimuladoBuilderViewModel) -> String {
        switch vm.state.mode {
        case .template:
            if let slug = vm.state.selectedTemplateSlug,
               let tpl = vm.state.templates.first(where: { $0.slug == slug }) {
                let mins = tpl.timeLimitMinutes.map { " · \($0) min" } ?? ""
                return "Gerar Simulado (\(tpl.totalQuestions) Q\(mins))"
            }
            return "Escolher Template"
        case .custom:
            let pool = vm.state.displayCount
            let count = min(vm.state.questionCount, pool == 0 ? vm.state.questionCount : pool)
            let mins = vm.state.timerEnabled ? " · \(vm.state.timerMinutes) min" : ""
            if pool == 0 && !vm.state.previewLoading { return "Sem questões disponíveis" }
            if vm.state.previewLoading { return "Gerar Simulado" }
            return "Gerar Simulado (\(count) Q\(mins))"
        }
    }

    private func templateCount(vm: SimuladoBuilderViewModel) -> Int {
        guard let slug = vm.state.selectedTemplateSlug,
              let tpl = vm.state.templates.first(where: { $0.slug == slug }) else { return 0 }
        return tpl.totalQuestions
    }

    private func parseId(_ id: String) -> (String, String)? {
        let parts = id.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }

    private var groupsSkeleton: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { idx in
                    HStack(spacing: 10) {
                        Circle().fill(VitaColors.glassBg).frame(width: 16, height: 16)
                        RoundedRectangle(cornerRadius: 4).fill(VitaColors.glassBg).frame(height: 12).frame(maxWidth: .infinity)
                        RoundedRectangle(cornerRadius: 4).fill(VitaColors.glassBg).frame(width: 40, height: 12)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .opacity(0.4)
                    if idx < 4 {
                        Divider().background(VitaColors.glassBorder.opacity(0.3))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func heroPrimary(avgScore: Double) -> String {
        let pct = avgScore * 100
        if pct == pct.rounded() { return "\(Int(pct))%" }
        return String(format: "%.1f%%", pct)
    }

    private func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Recent attempt card

private struct SimuladoBuilderAttemptCard: View {
    let attempt: SimuladoAttemptEntry
    let onTap: () -> Void

    private var isFinished: Bool { attempt.status == "finished" }
    private var scoreDisplay: String {
        if isFinished { return "\(Int(attempt.score * 100))%" }
        return "\(attempt.correctQ)/\(attempt.totalQ)"
    }

    private var dateDisplay: String {
        guard let raw = attempt.startedAt, raw.count >= 10 else { return "" }
        let parts = String(raw.prefix(10)).split(separator: "-")
        guard parts.count == 3 else { return "" }
        let months = ["", "jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
        let day = String(parts[2])
        if let m = Int(parts[1]), m > 0, m <= 12 {
            return "\(day) \(months[m])"
        }
        return "\(day)/\(parts[1])"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(StudyShellTheme.simulados.primary.opacity(0.20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(StudyShellTheme.simulados.primaryMuted.opacity(0.55), lineWidth: 1)
                        )
                    Image(systemName: isFinished ? "checkmark.square" : "clock")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(StudyShellTheme.simulados.primaryLight.opacity(0.85))
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(attempt.title.isEmpty ? (attempt.subject ?? "Simulado") : attempt.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    Text("\(attempt.totalQ) questões · \(dateDisplay)")
                        .font(.system(size: 10))
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(scoreDisplay)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(StudyShellTheme.simulados.primaryLight.opacity(0.92))
                    Text(isFinished ? "Concluído" : "Em andamento")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            isFinished
                                ? VitaColors.dataGreen.opacity(0.15)
                                : StudyShellTheme.simulados.primary.opacity(0.18)
                        )
                        .foregroundStyle(
                            isFinished
                                ? VitaColors.dataGreen.opacity(0.85)
                                : StudyShellTheme.simulados.primaryLight.opacity(0.90)
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .vitaGlassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }
}
