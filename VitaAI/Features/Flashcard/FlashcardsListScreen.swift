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
    @State private var decks: [FlashcardDeckEntry] = []
    @State private var recommended: [FlashcardRecommended] = []
    @State private var continueDeck: FlashcardDeckEntry?
    @State private var continueDueCount: Int = 0
    @State private var isLoading = true
    @State private var isEmpty = false

    var body: some View {
        ZStack {
            // Background — fullscreen image (mockup: flashcard-bg-new.png)
            Image("flashcard-bg-new")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Hero image (mockup: flashcard-hero-clean.webp, full width, rounded 18)
                    Image("flashcard-hero-clean")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: .black.opacity(0.40), radius: 20, x: 0, y: 8)
                        .padding(.top, 14)

                    if isLoading {
                        ProgressView()
                            .tint(Color(red: 1, green: 0.784, blue: 0.471))
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
                                // Primary CTA — Gerar com IA
                                Button(action: {
                                    print("[FlashcardsList] Gerar com IA tapped")
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("Gerar com IA")
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

                                // Secondary CTA — Criar manualmente
                                Button(action: {
                                    print("[FlashcardsList] Criar manualmente tapped")
                                }) {
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
                        // Continuar section
                        if let cont = continueDeck {
                            sectionLabel("Continuar")
                            continueCard(cont)
                        }

                        // Recomendados section
                        if !recommended.isEmpty {
                            sectionLabel("Recomendados")
                            recommendedScroll
                        }

                        // Disciplinas / decks
                        if !decks.isEmpty {
                            sectionLabel("Disciplinas / decks")
                            decksGrid
                        }
                    }

                    Spacer().frame(height: 130)
                }
                .padding(.horizontal, 16)
            }
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Load Data

    private func loadData() async {
        isLoading = true
        do {
            // Use recommended endpoint — lightweight, no cards inline
            let recs = try await container.api.getMockupFlashcardsRecommended()
            if recs.isEmpty {
                isEmpty = true
                isLoading = false
                return
            }

            recommended = recs

            // First recommended with dueCount > 0 = continue deck
            if let first = recs.first(where: { $0.dueCount > 0 }) {
                continueDeck = FlashcardDeckEntry(id: first.deckId, title: first.title)
                continueDueCount = first.dueCount
            }

            // All decks for the grid (use recommended as deck list)
            decks = recs.map { FlashcardDeckEntry(id: $0.deckId, title: $0.title) }
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
            .foregroundStyle(Color(red: 1, green: 0.941, blue: 0.843).opacity(0.50))
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
                        .foregroundStyle(Color(red: 1, green: 0.941, blue: 0.843).opacity(0.40))
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
                                Color(red: 0.047, green: 0.035, blue: 0.027).opacity(0.85),
                                Color(red: 0.055, green: 0.043, blue: 0.031).opacity(0.82)
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(red: 1, green: 0.784, blue: 0.471).opacity(0.14), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.40), radius: 18, x: 0, y: 7)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recommended Scroll (mockup: .fc-recs)

    private var recommendedScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(recommended.prefix(8)) { rec in
                    Button(action: { onOpenDeck(rec.deckId) }) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Image placeholder (use discipline hero bg)
                            RoundedRectangle(cornerRadius: 0)
                                .fill(Color(red: 0.1, green: 0.07, blue: 0.05))
                                .frame(height: 72)
                                .overlay(
                                    Image(heroImageFor(rec.title))
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 72)
                                        .clipped()
                                )

                            VStack(alignment: .leading, spacing: 2) {
                                Text(rec.title)
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.90))
                                    .lineLimit(1)
                                Text("\(rec.totalCards) cards\(rec.dueCount > 0 ? " · \(rec.dueCount) pendentes" : "")")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(red: 1, green: 0.941, blue: 0.843).opacity(0.48))
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
                                            Color(red: 0.047, green: 0.035, blue: 0.027).opacity(0.85),
                                            Color(red: 0.055, green: 0.043, blue: 0.031).opacity(0.80)
                                        ],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(red: 1, green: 0.784, blue: 0.471).opacity(0.12), lineWidth: 1)
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
            ForEach(decks) { deck in
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
                                        Color(red: 0.047, green: 0.035, blue: 0.027).opacity(0.82),
                                        Color(red: 0.055, green: 0.043, blue: 0.031).opacity(0.78)
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(red: 1, green: 0.784, blue: 0.471).opacity(0.10), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.30), radius: 11, x: 0, y: 4)
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
