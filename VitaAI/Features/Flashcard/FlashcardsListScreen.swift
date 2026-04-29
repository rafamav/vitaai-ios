import SwiftUI

// MARK: - FlashcardsListScreen
//
// Fase 5 reescrita 2026-04-29: reduzido a APENAS decks grid 2-col.
// Antes: Hero + LensSwitcher + Search + Continuar + Anki accordion + Biblioteca = 800 linhas.
// Agora: grid simples por disciplina, lente-aware via dataManager.
//
// Builder/configuração/mode selector vivem em `FlashcardBuilderScreen` (substitui esta
// tela no AppRouter quando ATLAS Onda 3 fizer o wiring).
// Esta tela permanece como fallback compilável até a troca de rota.

struct FlashcardsListScreen: View {
    var initialSubjectId: String? = nil
    var onBack: () -> Void
    var onOpenDeck: (String) -> Void
    var onOpenTopics: ((String, String) -> Void)? = nil

    @Environment(\.appContainer) private var container
    @State private var decks: [FlashcardDeckEntry] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("BARALHOS \(decks.isEmpty ? "" : "(\(decks.count))")")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(VitaColors.sectionLabel)
                    .padding(.top, 14)

                if isLoading && decks.isEmpty {
                    DashboardSkeleton()
                        .tint(StudyShellTheme.flashcards.primaryLight)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if decks.isEmpty {
                    emptyCard
                } else {
                    decksGrid
                }

                Spacer().frame(height: 130)
            }
            .padding(.horizontal, 16)
        }
        .refreshable { await loadData() }
        .task {
            await loadData()
            ScreenLoadContext.finish(for: "FlashcardsList")
        }
        .trackScreen("FlashcardsList")
    }

    // MARK: - Grid

    private var decksGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ],
            spacing: 10
        ) {
            ForEach(decks) { deck in
                deckCard(deck)
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

    private var emptyCard: some View {
        VitaGlassCard(cornerRadius: 14) {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(VitaColors.textTertiary)
                Text("Sem baralhos ainda")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary.opacity(0.85))
                Text("Conecte um portal ou peça pra Vita gerar")
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        }
    }

    // MARK: - Load

    private func loadData() async {
        let cache = container.flashcardsListCache
        if cache.isFresh {
            decks = cache.decks.filter { $0.cardCount > 0 }
            isLoading = false
            Task { await revalidate() }
            return
        }
        if !cache.decks.isEmpty {
            decks = cache.decks.filter { $0.cardCount > 0 }
        } else {
            isLoading = true
        }
        do {
            var fetched = try await cache.refresh()
            if fetched.isEmpty {
                _ = try? await container.api.generateFlashcardsAutoSeed()
                fetched = try await cache.refresh()
            }
            decks = fetched.filter { $0.cardCount > 0 }
        } catch {
            print("[FlashcardsList] error: \(error)")
        }
        isLoading = false
    }

    private func revalidate() async {
        do {
            let fetched = try await container.flashcardsListCache.refresh()
            decks = fetched.filter { $0.cardCount > 0 }
        } catch {
            print("[FlashcardsList] revalidate error: \(error)")
        }
    }
}
