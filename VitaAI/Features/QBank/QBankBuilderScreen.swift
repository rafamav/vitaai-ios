import SwiftUI
import Sentry

// MARK: - QBankBuilderScreen — Fase 3 reescrita gold-standard
//
// Tela única que substitui QBankHomeContent + QBankConfigContent.
// Composição vertical com builder visível inline, lente operacional,
// count dinâmico e CTA sticky. SOT do layout:
// agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md §3.1

struct QBankBuilderScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: QBankBuilderViewModel?
    let onBack: () -> Void
    let onSessionCreated: (String) -> Void

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                DashboardSkeleton().tint(VitaColors.accent)
            }
        }
        .onAppear {
            if vm == nil {
                vm = QBankBuilderViewModel(api: container.api, dataManager: container.dataManager)
                vm?.boot()
                SentrySDK.reportFullyDisplayed()
            }
        }
        .navigationBarHidden(true)
        .trackScreen("QBankBuilder")
    }

    @ViewBuilder
    private func content(vm: QBankBuilderViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {

                    // 1. Hero
                    StudyHeroStat(
                        primary: formatNumber(vm.state.progressAnswered),
                        primaryCaption: "questões respondidas",
                        stats: [
                            .init(value: formatNumber(vm.state.progressTotal), label: "disponíveis"),
                            .init(value: "\(Int((vm.state.progressAccuracy * 100).rounded()))%", label: "acerto"),
                        ],
                        theme: .questoes
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    // 2. Lente
                    LensSwitcher(
                        selection: Binding(
                            get: { vm.state.lens },
                            set: { vm.setLens($0) }
                        ),
                        theme: .questoes
                    )
                    .padding(.horizontal, 16)

                    // 3. Tags removíveis
                    FilterChipsRow(
                        chips: appliedFilterChips(vm: vm),
                        theme: .questoes,
                        onClearAll: { vm.clearAllFilters() }
                    )

                    // 4. Especialidades / Sistemas / Áreas (lente-aware) — breadcrumb drill-down
                    if vm.state.groups.isEmpty && vm.state.filtersLoading {
                        groupsSkeleton
                            .padding(.horizontal, 16)
                    } else {
                    BreadcrumbDrillDown(
                        title: groupTitle(for: vm.state.lens),
                        groups: vm.state.groups,
                        selectedGroupSlugs: Binding(
                            get: { vm.state.selectedGroupSlugs },
                            set: { newSet in
                                let removed = vm.state.selectedGroupSlugs.subtracting(newSet)
                                let added = newSet.subtracting(vm.state.selectedGroupSlugs)
                                for s in removed { vm.toggleGroup(slug: s) }
                                for s in added { vm.toggleGroup(slug: s) }
                            }
                        ),
                        selectedSubgroupIds: Binding(
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
                        theme: .questoes
                    )
                    .padding(.horizontal, 16)
                    }

                    // 5. Quantidade (sempre visível)
                    quantitySection(vm: vm)
                        .padding(.horizontal, 16)

                    // 6. Modo Prática/Simulado
                    modeSection(vm: vm)
                        .padding(.horizontal, 16)

                    // 7. Dificuldade
                    if !vm.state.difficulties.isEmpty {
                        difficultySection(vm: vm)
                            .padding(.horizontal, 16)
                    }

                    // 8. Formato
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
                        theme: .questoes
                    )
                    .padding(.horizontal, 16)

                    // 9. Avançadas (collapsible)
                    AdvancedSection(
                        items: advancedItems(vm: vm),
                        theme: .questoes
                    )
                    .padding(.horizontal, 16)

                    // 10. Recents
                    if !vm.state.recentSessions.isEmpty {
                        recentsSection(vm: vm)
                    }

                }
                .padding(.bottom, 16)
            }
        // CTA sticky via safeAreaInset — pattern canônico SwiftUI
        // (substitui ZStack/Spacer/padding manual). O conteúdo do scroll
        // respeita a altura automaticamente, e o CTA fica acima do tab bar.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StickyBottomCTA(
                title: ctaTitle(vm: vm),
                count: vm.state.displayCount,
                isLoading: vm.state.previewLoading,
                isCreating: vm.state.creatingSession,
                theme: .questoes,
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

    // MARK: - Sections

    private func quantitySection(vm: QBankBuilderViewModel) -> some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("QUANTIDADE")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(VitaColors.sectionLabel)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach([10, 20, 30, 50], id: \.self) { n in
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

    private func modeSection(vm: QBankBuilderViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODO")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            HStack(spacing: 0) {
                ForEach(QBankMode.allCases, id: \.self) { m in
                    let isSelected = vm.state.mode == m
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { vm.setMode(m) }
                    } label: {
                        VStack(spacing: 2) {
                            Text(m.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textSecondary)
                            Text(m == .pratica ? "feedback a cada questão" : "gabarito no final")
                                .font(.system(size: 9))
                                .foregroundStyle(isSelected ? VitaColors.accent.opacity(0.7) : VitaColors.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(isSelected ? VitaColors.accent.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isSelected ? VitaColors.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .glassCard(cornerRadius: 14)
        }
    }

    private func difficultySection(vm: QBankBuilderViewModel) -> some View {
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

    private func recentsSection(vm: QBankBuilderViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SESSÕES RECENTES")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
                .padding(.horizontal, 16)
            VStack(spacing: 8) {
                ForEach(vm.state.recentSessions) { s in
                    QBankSessionCard(session: s, theme: .questoes) {
                        // Tap nas recents: deixa pro coordinator (não suportado nessa onda)
                    }
                }
            }
            .padding(.horizontal, 16)
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

    private func appliedFilterChips(vm: QBankBuilderViewModel) -> [FilterChipsRow.Chip] {
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

    private func advancedItems(vm: QBankBuilderViewModel) -> [AdvancedToggleItem] {
        [
            AdvancedToggleItem(
                icon: "checkmark.circle.fill",
                title: "Ocultar já acertadas",
                description: "Pula questões que você acertou",
                isOn: vm.state.hideAnswered,
                action: { vm.setHideAnswered(!vm.state.hideAnswered) }
            ),
            AdvancedToggleItem(
                icon: "exclamationmark.octagon",
                title: "Ocultar anuladas",
                description: "Remove questões marcadas como erro pelo banco",
                isOn: vm.state.hideAnnulled,
                action: { vm.setHideAnnulled(!vm.state.hideAnnulled) }
            ),
            AdvancedToggleItem(
                icon: "checkmark.seal.fill",
                title: "Apenas com gabarito",
                description: "Só Q com comentário detalhado",
                isOn: vm.state.excludeNoExplanation,
                action: { vm.setExcludeNoExplanation(!vm.state.excludeNoExplanation) }
            ),
            AdvancedToggleItem(
                icon: "rosette",
                title: "Apenas oficiais",
                description: "Exclui Q geradas por IA",
                isOn: !vm.state.includeSynthetic,
                action: { vm.setIncludeSynthetic(!(!vm.state.includeSynthetic)) }
            ),
        ]
    }

    private var groupsSkeleton: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { idx in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(VitaColors.glassBg)
                            .frame(width: 16, height: 16)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(VitaColors.glassBg)
                            .frame(height: 12)
                            .frame(maxWidth: .infinity)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(VitaColors.glassBg)
                            .frame(width: 40, height: 12)
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

    private func ctaTitle(vm: QBankBuilderViewModel) -> String {
        let pool = vm.state.displayCount
        let count = min(vm.state.questionCount, pool)
        if pool == 0 { return "Sem questões disponíveis" }
        if vm.state.previewLoading { return "Iniciar Sessão" }
        return "Iniciar (\(count) de \(formatNumber(pool)))"
    }

    private func parseId(_ id: String) -> (String, String)? {
        let parts = id.split(separator: "/", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        return (parts[0], parts[1])
    }

    private func formatNumber(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "pt_BR")
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}
