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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Unified study hero stat — themed purple for flashcards
                StudyHeroStat(
                    primary: "\(container.studyOverviewStore.snapshot?.flashcards.dueNow ?? 0)",
                    primaryCaption: "cards pra revisar agora",
                    stats: [
                        .init(
                            value: "\(container.studyOverviewStore.snapshot?.flashcards.totalCards ?? 0)",
                            label: "no baralho"
                        ),
                        .init(
                            value: "\(container.studyOverviewStore.snapshot?.flashcards.reviewedToday ?? 0)",
                            label: "hoje"
                        ),
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
        .refreshable { await loadData() }
        .task {
            await appData.loadIfNeeded()
            await container.studyOverviewStore.loadIfNeeded()
            await loadData()
        }
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

    private func loadData() async {
        isLoading = true
        do {
            var fetched = try await container.api.getFlashcardDecks(cardsLimit: 0)

            // Auto-seed if user has no decks yet (first open)
            if fetched.isEmpty {
                // Trigger autoSeed — generates decks from QBank for user's disciplines
                _ = try? await container.api.generateFlashcardsAutoSeed()
                fetched = try await container.api.getFlashcardDecks(cardsLimit: 0)
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
            // SOT: AppDataManager.gradesResponse.current — same source Dashboard
            // uses. One canonical disciplines list across the app.
            let subjectIds = Set(
                (container.dataManager.gradesResponse?.current ?? [])
                    .compactMap { $0.subjectId }
            )
            let scoreFor: (FlashcardDeckEntry) -> Double = { deck in
                container.dataManager.vitaScore(for: deck.title)
            }
            if subjectIds.isEmpty {
                currentDecks = withCards.sorted { scoreFor($0) > scoreFor($1) }
                historyDecks = []
            } else {
                currentDecks = withCards
                    .filter { $0.subjectId != nil && subjectIds.contains($0.subjectId!) }
                    .sorted { scoreFor($0) > scoreFor($1) }
                historyDecks = withCards
                    .filter { $0.subjectId == nil || !subjectIds.contains($0.subjectId!) }
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

    // MARK: - My Disciplines (vertical list, full names + card count)

    private var myDisciplinesList: some View {
        VStack(spacing: 6) {
            ForEach(filteredCurrentDecks) { deck in
                Button(action: { navigateToDeck(deck) }) {
                    HStack(spacing: 12) {
                        Image(discIconFor(deck.title))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(deck.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.90))
                            .lineLimit(2)

                        Spacer()

                        Text("\(deck.cardCount)")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(StudyShellTheme.flashcards.primaryLight)
                        + Text(" cards")
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
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
                            .stroke(StudyShellTheme.flashcards.primaryMuted.opacity(0.60), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.30), radius: 11, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
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
