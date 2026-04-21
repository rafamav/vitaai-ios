import SwiftUI

// MARK: - FlashcardsListScreen
// CTRL+C from mockup: flashcards-mobile-v1.html
// Background: flashcard-bg-new.png (fullscreen)
// Hero: flashcard-hero-clean.webp (full width image)
// Sections: Continuar, Recomendados (hscroll), Disciplinas/decks (2-col grid)
// Data: GET /api/study/flashcards

struct FlashcardsListScreen: View {
    var initialSubjectId: String? = nil
    var onBack: () -> Void
    var onOpenDeck: (String) -> Void
    var onOpenTopics: ((String, String) -> Void)? = nil  // (deckId, deckTitle)

    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    @State private var decks: [FlashcardDeckEntry] = []
    @State private var currentDecks: [FlashcardDeckEntry] = []
    @State private var historyDecks: [FlashcardDeckEntry] = []
    @State private var continueDeck: FlashcardDeckEntry?
    @State private var continueDueCount: Int = 0
    @State private var isLoading = true
    @State private var isEmpty = false
    @State private var isGenerating = false
    @State private var showLibrary = false
    @State private var searchText = ""
    /// Anki-style accordion: which discipline groups are expanded.
    /// Starts empty (all collapsed) so the screen fits; user taps to expand.
    @State private var expandedDisciplines: Set<String> = []
    // Mirror the study overview snapshot into @State so SwiftUI re-renders
    // the Hero the moment the store finishes loading. Reading the nested
    // @Observable store straight off @Environment(\.appContainer) does not
    // trigger re-render reliably when the outer container is ObservableObject
    // (not @Observable), so the Hero was stuck at 0 on first open.
    @State private var heroDueNow: Int = 0
    @State private var heroTotalCards: Int = 0
    @State private var heroReviewedToday: Int = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Unified study hero stat — themed purple for flashcards
                StudyHeroStat(
                    primary: "\(heroDueNow)",
                    primaryCaption: "cards pra revisar agora",
                    stats: [
                        .init(value: "\(heroTotalCards)", label: "no baralho"),
                        .init(value: "\(heroReviewedToday)", label: "hoje"),
                    ],
                    theme: .flashcards
                )
                .padding(.top, 14)

                // Search bar
                if !isLoading && !isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        TextField("Buscar disciplina...", text: $searchText)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.90))
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VitaColors.surfaceCard.opacity(0.70))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
                    .padding(.top, 16)
                }

                if isLoading {
                        ProgressView()
                            .tint(VitaColors.accentHover)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else if isEmpty {
                        // Empty state (mockup: #emptyState)
                        VStack(spacing: 16) {
                            VStack(spacing: 6) {
                                Text("Sem flashcards ainda")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.80))
                                Text("Peça pra Vita gerar ou crie manualmente")
                                    .font(.system(size: 12))
                                    .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                            }

                            VStack(spacing: 10) {
                                // Primary CTA — Gerar com IA (themed purple, liquid-glass)
                                let theme = StudyShellTheme.flashcards
                                Button(action: { Task { await generateWithAI() } }) {
                                    HStack(spacing: 8) {
                                        if isGenerating {
                                            ProgressView().tint(theme.primaryLight).scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        Text(isGenerating ? "Gerando..." : "Gerar com IA")
                                            .font(.system(size: 15, weight: .semibold))
                                            .tracking(-0.1)
                                    }
                                    .foregroundStyle(theme.primaryLight.opacity(0.98))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 15)
                                    .background(
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(.ultraThinMaterial)
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [
                                                            theme.primary.opacity(0.32),
                                                            theme.primary.opacity(0.18),
                                                            theme.primary.opacity(0.10),
                                                        ],
                                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                                    )
                                                )
                                        }
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(alignment: .top) {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.18), .clear],
                                                    startPoint: .top, endPoint: .init(x: 0.5, y: 0.20)
                                                )
                                            )
                                            .frame(height: 10)
                                            .padding(.horizontal, 1)
                                            .allowsHitTesting(false)
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(
                                                LinearGradient(
                                                    colors: [
                                                        theme.primaryLight.opacity(0.45),
                                                        theme.primary.opacity(0.08),
                                                        theme.primaryLight.opacity(0.22),
                                                    ],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                                ),
                                                lineWidth: 0.75
                                            )
                                    )
                                    .shadow(color: theme.primary.opacity(0.18), radius: 10, y: 5)
                                }
                                .buttonStyle(.plain)

                                // Secondary CTA — Criar manualmente (themed outline)
                                Button(action: { Task { await createManualDeck() } }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Criar manualmente")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundStyle(theme.primaryLight.opacity(0.90))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(VitaColors.glassBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(theme.primaryMuted, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        // Continuar studying
                        if let cont = continueDeck {
                            sectionLabel("Continuar")
                            continueCard(cont)
                        }

                        // Suas disciplinas — vertical list, full names
                        if !filteredCurrentDecks.isEmpty {
                            sectionLabel("Suas disciplinas")
                            myDisciplinesList
                        }

                        // Biblioteca — collapsed, tap to expand, alphabetical
                        if !filteredHistoryDecks.isEmpty {
                            librarySection
                        }
                    }

                    Spacer().frame(height: 130)
                }
                .padding(.horizontal, 16)
            }
        .refreshable {
            async let overviewRefresh: Void = container.studyOverviewStore.refresh()
            async let dataRefresh: Void = loadData()
            _ = await (overviewRefresh, dataRefresh)
            hydrateHeroFromStore()
        }
        .task {
            // Progressive render: kick off all independent network work in
            // parallel and paint as each finishes. Before this change, the
            // task ran serially:
            //   appData.loadIfNeeded (6 paralell requests, ~2-3s)
            //     → studyOverview (~0.5s)
            //       → loadData (~0.5s)
            // Worst case Rafael saw was ~15s because of backend contention
            // (same endpoint hit 3× by different screens in parallel). Now:
            // hero hydrates as soon as studyOverview returns, disciplines
            // render as soon as loadData returns. appData cache may still
            // be warming but currentDecks already shows.
            async let overviewTask: Void = container.studyOverviewStore.loadIfNeeded()
            async let appDataTask: Void = appData.loadIfNeeded()
            async let decksTask: Void = loadData()

            await overviewTask
            hydrateHeroFromStore()

            // Wait for the other two so the accordion has enrolledDisciplines
            // and the filtered currentDecks list.
            _ = await (appDataTask, decksTask)
            ScreenLoadContext.finish(for: "FlashcardsList")
        }
        .trackScreen("FlashcardsList")
    }

    // MARK: - Filtered decks

    private var filteredCurrentDecks: [FlashcardDeckEntry] {
        guard !searchText.isEmpty else { return currentDecks }
        let q = searchText.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        return currentDecks.filter { $0.title.lowercased().folding(options: .diacriticInsensitive, locale: nil).contains(q) }
    }

    private var filteredHistoryDecks: [FlashcardDeckEntry] {
        guard !searchText.isEmpty else { return historyDecks }
        let q = searchText.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        return historyDecks.filter { $0.title.lowercased().folding(options: .diacriticInsensitive, locale: nil).contains(q) }
    }

    // MARK: - Actions

    /// Run QBank-backed autoSeed then refresh both local state + overview store.
    @MainActor
    private func generateWithAI() async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        do {
            _ = try await container.api.generateFlashcardsAutoSeed()
            await container.studyOverviewStore.refresh()
            await loadData()
        } catch {
            print("[FlashcardsList] generateWithAI error: \(error)")
        }
    }

    /// Manual creation — placeholder until a dedicated create-deck sheet exists.
    /// Opens the first current-semester deck so the user isn't stranded; when
    /// the blank-deck editor lands, replace this with a real navigation.
    @MainActor
    private func createManualDeck() async {
        if let first = currentDecks.first {
            onOpenDeck(first.id)
        } else {
            await generateWithAI()
        }
    }

    // MARK: - Load Data

    private func hydrateHeroFromStore() {
        guard let snap = container.studyOverviewStore.snapshot?.flashcards else { return }
        heroDueNow = snap.dueNow
        heroTotalCards = snap.totalCards
        heroReviewedToday = snap.reviewedToday
    }

    private func loadData() async {
        isLoading = true
        do {
            // summary=true: backend returns deck metadata + totalCards + dueCount
            // WITHOUT the cards[] array. 182KB JSON for 534 decks vs ~5.6MB when
            // cards are hydrated. First-paint of Flashcards list drops from ~5s
            // to <500ms. Cards load on-demand when the user taps a deck
            // (FlashcardViewModel.fetchDeck uses the full path).
            var fetched = try await container.api.getFlashcardDecks(deckLimit: 1000, summary: true)

            // Auto-seed if user has no decks yet (first open)
            if fetched.isEmpty {
                // Trigger autoSeed — generates decks from QBank for user's disciplines
                _ = try? await container.api.generateFlashcardsAutoSeed()
                fetched = try await container.api.getFlashcardDecks(deckLimit: 1000, summary: true)
            }

            // Filter out empty decks
            let withCards = fetched.filter { $0.cardCount > 0 }

            if withCards.isEmpty {
                isEmpty = true
                isLoading = false
                return
            }

            decks = withCards

            // "Suas disciplinas" = only decks matching user's current semester subjects
            // "Biblioteca" = everything else (AnKing library, other disciplines)
            //
            // Match by BOTH subjectId (old decks) AND disciplineSlug (auto-seeded
            // decks with subjectId=null). Pre-fix, only subjectId was matched,
            // which caused 0 visible decks for users whose entire library came
            // from autoSeed (subjectId null, disciplineSlug populated).
            let subjectIds = Set(
                (container.dataManager.gradesResponse?.current ?? [])
                    .compactMap { $0.subjectId }
            )
            let subjectSlugs = Set(
                container.dataManager.enrolledDisciplines
                    .compactMap { $0.disciplineSlug }
            )
            let scoreFor: (FlashcardDeckEntry) -> Double = { deck in
                container.dataManager.vitaScore(for: deck.title)
            }
            let isCurrent: (FlashcardDeckEntry) -> Bool = { deck in
                if let sid = deck.subjectId, subjectIds.contains(sid) { return true }
                if let slug = deck.disciplineSlug, subjectSlugs.contains(slug) { return true }
                return false
            }
            if subjectIds.isEmpty && subjectSlugs.isEmpty {
                // User has no subjects registered — treat everything as "current"
                // so the library never shows empty when data exists.
                currentDecks = withCards.sorted { scoreFor($0) > scoreFor($1) }
                historyDecks = []
            } else {
                currentDecks = withCards
                    .filter(isCurrent)
                    .sorted { scoreFor($0) > scoreFor($1) }
                historyDecks = withCards
                    .filter { !isCurrent($0) }
                    .sorted { scoreFor($0) > scoreFor($1) }
            }

            // First CURRENT deck with due cards = continue deck
            if let first = currentDecks.first(where: { ($0.dueCount ?? 0) > 0 }) {
                continueDeck = first
                continueDueCount = first.dueCount ?? 0
            }
        } catch {
            print("[FlashcardsList] error: \(error)")
            isEmpty = true
        }
        isLoading = false
    }

    // MARK: - Section Label (mockup: .fc-label — italic, 14px, gold)

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .italic()
            .foregroundStyle(VitaColors.textWarm.opacity(0.50))
            .padding(.top, 22)
            .padding(.bottom, 10)
    }

    // MARK: - Continue Card (mockup: .fc-cont)

    private func continueCard(_ deck: FlashcardDeckEntry) -> some View {
        Button(action: { onOpenDeck(deck.id) }) {
            HStack(spacing: 14) {
                Image("asset-book-purple")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.25), radius: 5, x: 0, y: 2)

                VStack(alignment: .leading, spacing: 1) {
                    Text(deck.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.93))
                    Text("\(continueDueCount) pendentes")
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                VitaColors.surfaceCard.opacity(0.85),
                                VitaColors.surfaceElevated.opacity(0.82)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(StudyShellTheme.flashcards.primaryMuted, lineWidth: 0.75)
            )
            .shadow(color: StudyShellTheme.flashcards.primary.opacity(0.22), radius: 18, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recommended Scroll (mockup: .fc-recs)

    private var recommendedScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(currentDecks.prefix(8)) { deck in
                    let dueCount = deck.dueCount ?? 0
                    Button(action: { navigateToDeck(deck) }) {
                        VStack(alignment: .leading, spacing: 0) {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(Color(red: 0.1, green: 0.07, blue: 0.05))
                                .frame(height: 72)
                                .overlay(
                                    Image(heroImageFor(deck.title))
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 72)
                                        .clipped()
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(deck.title)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.90))
                                    .lineLimit(1)
                                Text("\(deck.cardCount) cards\(dueCount > 0 ? " · \(dueCount) pendentes" : "")")
                                    .font(.system(size: 10))
                                    .foregroundStyle(VitaColors.textWarm.opacity(0.48))
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                        }
                        .frame(width: 112)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            VitaColors.surfaceCard.opacity(0.85),
                                            VitaColors.surfaceElevated.opacity(0.80)
                                        ],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(VitaColors.accentHover.opacity(0.12), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mask(
            LinearGradient(
                stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.85), .init(color: .clear, location: 1)],
                startPoint: .leading, endPoint: .trailing
            )
        )
    }

    // MARK: - My Disciplines (Anki-style accordion grouped by disciplineSlug)
    //
    // Mockup-refactor 2026-04-20 night: Rafael hated the flat list of decks
    // ("farmacologia sistema nervoso autonomo" showing as a standalone card
    // with no parent discipline context). Anki-style grouping:
    //   [▸ farmacologia  26 decks · 695 cards · 695 due]
    //     └ Sistema Nervoso Autônomo        25 cards
    //     └ Toxicologia                     8 cards
    //     ...
    // Tap the group header toggles expand. Tap a deck row opens the session
    // directly (onOpenDeck, not onOpenTopics — that intermediate screen
    // was removed in AppRouter for the same reason).

    private struct DisciplineGroup: Identifiable {
        let slug: String
        let canonicalName: String
        let icon: String
        let decks: [FlashcardDeckEntry]
        var id: String { slug }
        var totalCards: Int { decks.reduce(0) { $0 + $1.cardCount } }
        var totalDue: Int { decks.reduce(0) { $0 + ($1.dueCount ?? 0) } }
    }

    /// Group filteredCurrentDecks by disciplineSlug. One section per slug.
    /// Prefer the user's raw subject name (as seen on Canvas/Mannesoft) over
    /// the catalog canonicalName — Rafael saw "Humanidades Médicas" and said
    /// "de onde tiraram, não é subject meu". His real subjects for that slug
    /// are "PRÁTICAS INTERPROFISSIONAIS..." and "SOCIEDADE E CONTEMPORANEIDADE".
    /// When 2+ subjects share the same slug we concatenate titles.
    private var disciplineGroups: [DisciplineGroup] {
        let enrolledBySlug = Dictionary(
            grouping: container.dataManager.enrolledDisciplines,
            by: { $0.disciplineSlug ?? "" }
        )
        let grouped = Dictionary(grouping: filteredCurrentDecks, by: { $0.disciplineSlug ?? "" })
        return grouped
            .map { slug, decks -> DisciplineGroup in
                let enrolled = enrolledBySlug[slug] ?? []
                // Use raw subject names (what the user recognizes from the portal).
                let realNames = enrolled.map { $0.name }.filter { !$0.isEmpty }
                let displayName: String
                if realNames.isEmpty {
                    displayName = slug.replacingOccurrences(of: "-", with: " ").capitalized
                } else if realNames.count == 1 {
                    displayName = realNames[0]
                } else {
                    // 2+ subjects share the same slug — show both so the user
                    // understands they pull from the same pool.
                    displayName = realNames.joined(separator: " + ")
                }
                let icon = enrolled.first?.icon ?? "\(slug).webp"
                let sorted = decks.sorted { $0.title < $1.title }
                return DisciplineGroup(slug: slug, canonicalName: displayName, icon: icon, decks: sorted)
            }
            .sorted { $0.totalDue > $1.totalDue }  // most due first
    }

    private var myDisciplinesList: some View {
        VStack(spacing: 8) {
            ForEach(disciplineGroups) { group in
                disciplineGroupCard(group)
            }
        }
    }

    @ViewBuilder
    private func disciplineGroupCard(_ group: DisciplineGroup) -> some View {
        let isOpen = expandedDisciplines.contains(group.slug)
        VStack(spacing: 0) {
            // HEADER — tap to expand/collapse
            Button(action: {
                withAnimation(.easeInOut(duration: 0.22)) {
                    if isOpen { expandedDisciplines.remove(group.slug) }
                    else { expandedDisciplines.insert(group.slug) }
                }
            }) {
                HStack(spacing: 12) {
                    Image(iconAssetName(for: group))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.canonicalName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .lineLimit(1)
                        Text("\(group.decks.count) decks · \(group.totalCards) cards")
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.42))
                    }

                    Spacer()

                    if group.totalDue > 0 {
                        Text("\(group.totalDue)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(StudyShellTheme.flashcards.primaryLight)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(StudyShellTheme.flashcards.primary.opacity(0.18))
                            )
                    }

                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            // DECKS — visible only when expanded
            if isOpen {
                VStack(spacing: 1) {
                    ForEach(group.decks) { deck in
                        Button(action: { onOpenDeck(deck.id) }) {
                            HStack(spacing: 10) {
                                Image(systemName: "rectangle.on.rectangle")
                                    .font(.system(size: 11))
                                    .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                                    .frame(width: 20)

                                Text(deck.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.82))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)

                                Spacer(minLength: 8)

                                if let due = deck.dueCount, due > 0 {
                                    Text("\(due)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(StudyShellTheme.flashcards.primaryLight)
                                } else {
                                    Text("\(deck.cardCount)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                                }
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if deck.id != group.decks.last?.id {
                            Divider()
                                .background(Color.white.opacity(0.04))
                                .padding(.leading, 48)
                        }
                    }
                }
                .padding(.bottom, 6)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            VitaColors.surfaceCard.opacity(0.85),
                            VitaColors.surfaceElevated.opacity(0.80)
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

    /// Resolve group icon → asset name with bundled fallback. Many slugs have
    /// an explicit asset (farmacologia.webp) but humanidades/mfc-1 etc may not.
    private func iconAssetName(for group: DisciplineGroup) -> String {
        if UIImage(named: group.icon) != nil { return group.icon }
        let bare = group.icon.replacingOccurrences(of: ".webp", with: "")
        if UIImage(named: bare) != nil { return bare }
        let fromSlug = "\(group.slug)"
        if UIImage(named: fromSlug) != nil { return fromSlug }
        return "asset-book-purple"
    }

    private func navigateToDeck(_ deck: FlashcardDeckEntry) {
        if let onOpenTopics {
            onOpenTopics(deck.id, deck.title)
        } else {
            onOpenDeck(deck.id)
        }
    }

    // MARK: - Library Section (collapsed by default, alphabetical)

    private var librarySection: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showLibrary.toggle() } }) {
                HStack(spacing: 8) {
                    Text("Biblioteca")
                        .font(.system(size: 14, weight: .medium))
                        .italic()
                        .foregroundStyle(VitaColors.textWarm.opacity(0.50))

                    Text("\(filteredHistoryDecks.count) disciplinas")
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.30))

                    Spacer()

                    Image(systemName: showLibrary ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                }
                .padding(.top, 22)
                .padding(.bottom, 10)
            }
            .buttonStyle(.plain)

            if showLibrary || !searchText.isEmpty {
                VStack(spacing: 4) {
                    ForEach(filteredHistoryDecks.sorted { container.dataManager.vitaScore(for: $0.title) > container.dataManager.vitaScore(for: $1.title) }) { deck in
                        Button(action: { navigateToDeck(deck) }) {
                            HStack(spacing: 10) {
                                Text(deck.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Color.white.opacity(0.65))
                                    .lineLimit(1)

                                Spacer()

                                Text("\(deck.cardCount)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(StudyShellTheme.flashcards.primaryLight.opacity(0.80))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(VitaColors.surfaceCard.opacity(0.50))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Image Helpers (same logic as mockup JS)

    private func heroImageFor(_ title: String) -> String {
        DisciplineImages.imageAsset(for: title)
    }

    private func discIconFor(_ title: String) -> String {
        DisciplineImages.imageAsset(for: title)
    }
}
