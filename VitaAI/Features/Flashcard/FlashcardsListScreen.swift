import SwiftUI

// MARK: - FlashcardsListScreen
// CTRL+C from mockup: flashcards-mobile-v1.html
// Background: flashcard-bg-new.png (fullscreen)
// Hero: flashcard-hero-clean.webp (full width image)
// Sections: Continuar, Recomendados (hscroll), Disciplinas/decks (2-col grid)
// Data: /api/mockup/flashcards + /api/mockup/flashcards/recommended

struct FlashcardsListScreen: View {
    var onBack: () -> Void
    var onOpenDeck: (String) -> Void

    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    @State private var decks: [FlashcardDeckEntry] = []
    @State private var currentDecks: [FlashcardDeckEntry] = []
    @State private var historyDecks: [FlashcardDeckEntry] = []
    @State private var continueDeck: FlashcardDeckEntry?
    @State private var continueDueCount: Int = 0
    @State private var isLoading = true
    @State private var isEmpty = false
    @State private var selectedSubjectId: String? = nil
    @State private var isGenerating = false

    /// Filtered deck list based on the selected subject chip.
    /// When nil (= "Todas"), the original currentDecks list is returned.
    private var visibleCurrentDecks: [FlashcardDeckEntry] {
        guard let id = selectedSubjectId,
              let subject = container.studyOverviewStore.snapshot?.subjects.first(where: { $0.id == id }) else {
            return currentDecks
        }
        let target = subject.name.uppercased()
        return currentDecks.filter { $0.title.uppercased() == target }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // Unified study hero stat (replaces the standalone banner image)
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
                    subtitle: "Flashcards"
                )
                .padding(.top, 14)

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
                                // Primary CTA — Gerar com IA (calls autoSeed)
                                Button(action: { Task { await generateWithAI() } }) {
                                    HStack(spacing: 8) {
                                        if isGenerating {
                                            ProgressView().tint(VitaColors.surface).scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        Text(isGenerating ? "Gerando..." : "Gerar com IA")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundStyle(VitaColors.surface)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(
                                        LinearGradient(
                                            colors: [VitaColors.accentHover, VitaColors.accent],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(color: VitaColors.accent.opacity(0.25), radius: 12, x: 0, y: 4)
                                }
                                .buttonStyle(.plain)

                                // Secondary CTA — Criar manualmente (opens the first
                                // deck's editor if one exists; otherwise creates a
                                // blank-titled deck and opens it). Keeps the "everything
                                // navigates" rule of the unified screens.
                                Button(action: { Task { await createManualDeck() } }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Criar manualmente")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    .foregroundStyle(VitaColors.accentLight.opacity(0.80))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(VitaColors.glassBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(VitaColors.glassBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        // Subject chips — unified filter strip driven by the
                        // study overview snapshot. Uses the real academic_subjects
                        // IDs so taps can also drive deep-links later.
                        if let subjects = container.studyOverviewStore.snapshot?.subjects, !subjects.isEmpty {
                            StudySubjectChips(subjects: subjects, selectedId: $selectedSubjectId)
                                .padding(.top, 18)
                                .padding(.horizontal, -16) // chips manage their own insets
                        }

                        // Continuar section (current semester only) — hides when
                        // a chip filter is active so the hero matches the section.
                        if selectedSubjectId == nil, let cont = continueDeck {
                            sectionLabel("Continuar")
                            continueCard(cont)
                        }

                        // Recomendados section (current semester, top 8)
                        if selectedSubjectId == nil, currentDecks.count > 1 {
                            sectionLabel("Recomendados")
                            recommendedScroll
                        }

                        // Suas disciplinas (current semester or filtered subject)
                        if !visibleCurrentDecks.isEmpty {
                            sectionLabel(selectedSubjectId == nil ? "Suas disciplinas" : "Desta disciplina")
                            decksGrid
                        }

                        // Histórico (past semesters) — only shown in unfiltered view.
                        if selectedSubjectId == nil, !historyDecks.isEmpty {
                            sectionLabel("Histórico")
                            historyGrid
                        }
                    }

                    Spacer().frame(height: 130)
                }
                .padding(.horizontal, 16)
            }
        .task {
            await appData.loadIfNeeded()
            await container.studyOverviewStore.loadIfNeeded()
            await loadData()
        }
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
            var fetched = try await container.api.getFlashcardDecks()

            // Auto-seed if user has no decks yet (first open)
            if fetched.isEmpty {
                // Trigger autoSeed — generates decks from QBank for user's disciplines
                _ = try? await container.api.generateFlashcardsAutoSeed()
                fetched = try await container.api.getFlashcardDecks()
            }

            // Filter out empty decks
            let withCards = fetched.filter { !$0.cards.isEmpty }

            if withCards.isEmpty {
                isEmpty = true
                isLoading = false
                return
            }

            decks = withCards

            // Split into current semester vs history
            let subjectNames = Set(appData.dashboardSubjects.compactMap { $0.name?.uppercased() })
            if subjectNames.isEmpty {
                // No subjects loaded — treat all as current
                currentDecks = withCards
                historyDecks = []
            } else {
                currentDecks = withCards.filter { deck in
                    subjectNames.contains(deck.title.uppercased())
                }
                historyDecks = withCards.filter { deck in
                    !subjectNames.contains(deck.title.uppercased())
                }
            }

            // First CURRENT deck with due cards = continue deck
            if let first = currentDecks.first(where: { deck in
                deck.cards.contains { card in
                    guard let next = card.nextReviewAt else { return true }
                    // Cards with no nextReviewAt or past due
                    return ISO8601DateFormatter().date(from: next).map { $0 <= Date() } ?? true
                }
            }) {
                continueDeck = first
                continueDueCount = first.cards.filter { card in
                    guard let next = card.nextReviewAt else { return true }
                    return ISO8601DateFormatter().date(from: next).map { $0 <= Date() } ?? true
                }.count
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
                    .stroke(VitaColors.accentHover.opacity(0.14), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.40), radius: 18, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recommended Scroll (mockup: .fc-recs)

    private var recommendedScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(currentDecks.prefix(8)) { deck in
                    let dueCount = deck.cards.filter { card in
                        guard let next = card.nextReviewAt else { return true }
                        return ISO8601DateFormatter().date(from: next).map { $0 <= Date() } ?? true
                    }.count
                    Button(action: { onOpenDeck(deck.id) }) {
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
                                Text("\(deck.cards.count) cards\(dueCount > 0 ? " · \(dueCount) pendentes" : "")")
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

    // MARK: - Decks Grid (mockup: .fc-decks — 2 columns)

    private var decksGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(visibleCurrentDecks) { deck in
                Button(action: { onOpenDeck(deck.id) }) {
                    HStack(spacing: 10) {
                        Image(discIconFor(deck.title))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Text(deck.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.80))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        VitaColors.surfaceCard.opacity(0.82),
                                        VitaColors.surfaceElevated.opacity(0.78)
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(VitaColors.accentHover.opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.30), radius: 11, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - History Grid (past semesters, same style but dimmed)

    private var historyGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(historyDecks) { deck in
                Button(action: { onOpenDeck(deck.id) }) {
                    HStack(spacing: 10) {
                        Image(discIconFor(deck.title))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .opacity(0.6)

                        Text(deck.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.50))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        VitaColors.surfaceCard.opacity(0.60),
                                        VitaColors.surfaceElevated.opacity(0.55)
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(VitaColors.accentHover.opacity(0.06), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.20), radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Image Helpers (same logic as mockup JS)

    private func heroImageFor(_ title: String) -> String {
        let t = title.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        if t.contains("farmacologia") { return "hero-farmacologia" }
        if t.contains("histologia") || t.contains("patologia") { return "hero-histologia" }
        if t.contains("anatomia") { return "hero-anatomia" }
        if t.contains("cardiologia") || t.contains("fisiologia") { return "hero-patologia" }
        return "hero-farmacologia"
    }

    private func discIconFor(_ title: String) -> String {
        let t = title.lowercased().folding(options: .diacriticInsensitive, locale: nil)
        if t.contains("farmacologia") { return "disc-farmacologia" }
        if t.contains("histologia") { return "disc-histologia" }
        if t.contains("anatomia") { return "disc-anatomia" }
        if t.contains("patologia") { return "disc-patologia-geral" }
        return "disc-farmacologia"
    }
}
