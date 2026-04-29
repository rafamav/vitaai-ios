import SwiftUI
import Sentry

// MARK: - FlashcardBuilderScreen — Fase 5 reescrita gold-standard
//
// Tela única que substitui o builder embutido em FlashcardsListScreen.
// Composição vertical com mode selector visivel inline (Revisao/Especifico/Novos),
// lente operacional só quando mode=.specific, decks grid embaixo, e CTA sticky.
// SOT: agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md §3.3 + §11.3
//
// Layout vertical mirror do QBankBuilderScreen mas com diff por pagina conforme
// spec §11.3:
//   Hero → Mode → (Lente só se Specific) → Tags → Especialidades → [colapsadas]
//   → Limite → Decks Grid → CTA

struct FlashcardBuilderScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: FlashcardBuilderViewModel?
    // Default state §11.2 — colapsadas: Origem
    // (Instituições, Anos quando A7 publicar wrappers ficam colapsados também;
    // Avançadas (AdvancedSection) já é collapsible nativo com default false)
    @State private var originExpanded: Bool = false
    /// Quando vem de DisciplineDetailScreen → flashcardHome(subjectId), pré-seleciona
    /// essa disciplina e abre em mode `.specific`. nil = comportamento padrão (mode `.due`).
    var initialSubjectId: String? = nil
    let onBack: () -> Void
    let onOpenDeck: (String) -> Void

    var body: some View {
        Group {
            if let vm {
                content(vm: vm)
            } else {
                DashboardSkeleton().tint(StudyShellTheme.flashcards.primaryLight)
            }
        }
        .onAppear {
            if vm == nil {
                vm = FlashcardBuilderViewModel(api: container.api, dataManager: container.dataManager)
                vm?.boot()
                vm?.setInitialSubject(slug: initialSubjectId)
                SentrySDK.reportFullyDisplayed()
            }
        }
        .navigationBarHidden(true)
        .trackScreen("FlashcardBuilder")
    }

    @ViewBuilder
    private func content(vm: FlashcardBuilderViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {

                // 1. Hero (theme flashcards roxo)
                StudyHeroStat(
                    primary: "\(vm.state.dueNow)",
                    primaryCaption: "cards pra revisar agora",
                    stats: [
                        .init(value: formatNumber(vm.state.totalCards), label: "no baralho"),
                        .init(value: "\(vm.state.reviewedToday)", label: "hoje"),
                        .init(value: "\(vm.state.streakDays)d", label: "ofensiva"),
                    ],
                    theme: .flashcards
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // 2. Mode selector (Revisão / Específico / Novos) — sempre visível
                modeSelector(vm: vm)
                    .padding(.horizontal, 16)

                // 3. Lente — só quando mode = .specific (spec §11.3)
                if vm.state.mode == .specific {
                    LensSwitcher(
                        selection: Binding(
                            get: { vm.state.lens },
                            set: { vm.setLens($0) }
                        ),
                        theme: .flashcards
                    )
                    .padding(.horizontal, 16)

                    // 3a. Tags removíveis dos filtros aplicados
                    FilterChipsRow(
                        chips: appliedFilterChips(vm: vm),
                        theme: .flashcards,
                        onClearAll: { vm.clearAllFilters() }
                    )

                    // 3b. Drill 3 níveis (Disciplinas → Temas → Conteúdos) — Onda 4
                    if vm.state.groups.isEmpty {
                        groupsSkeleton
                            .padding(.horizontal, 16)
                    } else {
                        HorizontalDrillDown(
                            n1Title: groupTitle(for: vm.state.lens),
                            n2Title: n2Title(for: vm.state.lens),
                            n3Title: "Conteúdos",
                            theme: .flashcards,
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
                            onSelectionChange: { /* ViewModel já dispara refreshPreview no toggle */ }
                        )
                        .padding(.horizontal, 16)
                    }

                    // 3c. Origem — colapsada por default §11.2
                    originCollapsible(vm: vm)
                        .padding(.horizontal, 16)
                }

                // 4. Avançadas (collapsible) — flashcard-only items
                AdvancedSection(
                    items: advancedItems(vm: vm),
                    theme: .flashcards
                )
                .padding(.horizontal, 16)

                // 5. Limite por sessão (visível, não em avançadas — decisão central)
                limitSection(vm: vm)
                    .padding(.horizontal, 16)

                // 6. Decks Grid (sempre embaixo, 2 col, lente-aware via visibleDecks)
                decksSection(vm: vm)
                    .padding(.horizontal, 16)
            }
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            StickyBottomCTA(
                title: ctaTitle(vm: vm),
                count: vm.state.displayCount,
                isLoading: vm.state.statsLoading || vm.state.decksLoading,
                isCreating: vm.state.creatingSession,
                theme: .flashcards,
                action: {
                    Task {
                        if let id = await vm.createSession() {
                            onOpenDeck(id)
                        }
                    }
                }
            )
        }
        .background(Color.clear)
    }

    // MARK: - Mode selector (3 opções: Revisão / Específico / Novos)

    private func modeSelector(vm: FlashcardBuilderViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MODO")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            HStack(spacing: 6) {
                ForEach(FlashcardSessionMode.allCases) { m in
                    let isSelected = vm.state.mode == m
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.setMode(m) }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: m.systemIcon)
                                .font(.system(size: 16, weight: .semibold))
                            Text(m.displayName)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Text(m.subtitle)
                                .font(.system(size: 9))
                                .foregroundStyle(
                                    isSelected
                                    ? StudyShellTheme.flashcards.primaryLight.opacity(0.7)
                                    : VitaColors.textTertiary
                                )
                        }
                        .foregroundStyle(
                            isSelected
                            ? StudyShellTheme.flashcards.primaryLight.opacity(0.98)
                            : VitaColors.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 11)
                                .fill(isSelected ? StudyShellTheme.flashcards.primary.opacity(0.22) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 11)
                                .stroke(
                                    isSelected
                                    ? StudyShellTheme.flashcards.primaryLight.opacity(0.32)
                                    : VitaColors.glassBorder,
                                    lineWidth: 0.75
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Origem collapsible (default colapsado §11.2)
    // Usa CollapsibleSectionCard shared (A7 publicou em EstudosBuilderComponents).

    private func originCollapsible(vm: FlashcardBuilderViewModel) -> some View {
        CollapsibleSectionCard(
            title: "Origem",
            icon: "tag",
            summary: vm.state.origin == .all ? "Todas" : vm.state.origin.displayName,
            theme: .flashcards,
            expanded: $originExpanded
        ) {
            originSection(vm: vm)
        }
    }

    // MARK: - Origem (só quando .specific)

    private func originSection(vm: FlashcardBuilderViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ForEach(FlashcardOrigin.allCases) { o in
                    let isSelected = vm.state.origin == o
                    Button {
                        vm.setOrigin(o)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: o.systemIcon)
                                .font(.system(size: 11, weight: .semibold))
                            Text(o.displayName)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundStyle(
                            isSelected
                            ? StudyShellTheme.flashcards.primaryLight.opacity(0.98)
                            : VitaColors.textSecondary
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 9)
                                .fill(isSelected ? StudyShellTheme.flashcards.primary.opacity(0.22) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(
                                    isSelected
                                    ? StudyShellTheme.flashcards.primaryLight.opacity(0.32)
                                    : VitaColors.glassBorder,
                                    lineWidth: 0.75
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Limite

    private func limitSection(vm: FlashcardBuilderViewModel) -> some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("LIMITE POR SESSÃO")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(VitaColors.sectionLabel)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FlashcardSessionLimit.allCases) { l in
                            QBankChip(
                                label: l.displayName,
                                isSelected: vm.state.sessionLimit == l
                            ) { vm.setSessionLimit(l) }
                        }
                    }
                }
            }
            .padding(14)
        }
    }

    // MARK: - Decks grid 2-col

    private func decksSection(vm: FlashcardBuilderViewModel) -> some View {
        let visible = vm.visibleDecks()
        return VStack(alignment: .leading, spacing: 10) {
            Text("BARALHOS \(visible.isEmpty ? "" : "(\(visible.count))")")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(VitaColors.sectionLabel)

            if vm.state.decksLoading && visible.isEmpty {
                decksGridSkeleton
            } else if visible.isEmpty {
                emptyDecksCard
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 10),
                        GridItem(.flexible(), spacing: 10),
                    ],
                    spacing: 10
                ) {
                    ForEach(visible) { deck in
                        deckCard(deck)
                    }
                }
            }
        }
    }

    private func deckCard(_ deck: FlashcardDeckEntry) -> some View {
        Button(action: { onOpenDeck(deck.id) }) {
            VStack(alignment: .leading, spacing: 8) {
                Text(deck.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 4)
                HStack(spacing: 8) {
                    let due = deck.dueCount ?? 0
                    if due > 0 {
                        Text("\(due) due")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(StudyShellTheme.flashcards.primaryLight)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(StudyShellTheme.flashcards.primary.opacity(0.20))
                            )
                    }
                    Spacer()
                    Text("\(deck.cardCount)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }
            .padding(12)
            .frame(minHeight: 90, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                VitaColors.surfaceCard.opacity(0.85),
                                VitaColors.surfaceElevated.opacity(0.80),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(StudyShellTheme.flashcards.primaryMuted.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var emptyDecksCard: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(VitaColors.textTertiary)
                Text("Sem baralhos pra esse modo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary.opacity(0.85))
                Text("Tenta outro modo ou ajusta filtros")
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
    }

    private var decksGridSkeleton: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ],
            spacing: 10
        ) {
            ForEach(0..<6, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 14)
                    .fill(VitaColors.glassBg)
                    .frame(height: 90)
                    .opacity(0.5)
            }
        }
    }

    private var groupsSkeleton: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { idx in
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
                    if idx < 3 {
                        Divider().background(VitaColors.glassBorder.opacity(0.3))
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Helpers

    private func appliedFilterChips(vm: FlashcardBuilderViewModel) -> [FilterChipsRow.Chip] {
        var chips: [FilterChipsRow.Chip] = []
        for slug in vm.state.selectedGroupSlugs {
            let name = vm.state.groups.first(where: { $0.slug == slug })?.name ?? slug
            chips.append(.init(id: "g-\(slug)", label: name, onRemove: { vm.toggleGroup(slug: slug) }))
        }
        if vm.state.origin != .all {
            chips.append(.init(
                id: "o-\(vm.state.origin.rawValue)",
                label: vm.state.origin.displayName,
                onRemove: { vm.setOrigin(.all) }
            ))
        }
        return chips
    }

    private func advancedItems(vm: FlashcardBuilderViewModel) -> [AdvancedToggleItem] {
        [
            AdvancedToggleItem(
                icon: "lightbulb",
                title: "Mostrar dicas",
                description: "Hint na frente do card antes de virar",
                isOn: vm.state.showHints,
                action: { vm.setShowHints(!vm.state.showHints) }
            ),
            AdvancedToggleItem(
                icon: "hare",
                title: "Pular cards muito fáceis",
                description: "Cards com stability alta são adiados",
                isOn: vm.state.skipTooEasy,
                action: { vm.setSkipTooEasy(!vm.state.skipTooEasy) }
            ),
        ]
    }

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

    private func ctaTitle(vm: FlashcardBuilderViewModel) -> String {
        let count = vm.state.displayCount
        if count == 0 {
            switch vm.state.mode {
            case .due: return "Sem cards pendentes"
            case .specific: return "Sem cards nesses filtros"
            case .newCards: return "Sem cards novos"
            }
        }
        let limit = vm.state.sessionLimit.rawValue
        let effective = limit == 0 ? count : min(limit, count)
        return "Estudar Agora (\(effective))"
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
