import SwiftUI

// MARK: - Flashcard Session Screen

struct FlashcardSessionScreen: View {

    let deckId: String
    var onBack: () -> Void
    var onFinished: () -> Void = {}

    @Environment(\.appContainer) private var container
    @State private var viewModel: FlashcardViewModel?
    @State private var elapsedSeconds: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Progress bar gradient — purple theme
    private let progressGradient = LinearGradient(
        colors: [VitaColors.flashcardAccent, VitaColors.flashcardAccentLight],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            if let vm = viewModel {
                switch vm.phase {
                case .loading:
                    FlashcardLoadingSkeleton()

                case .empty:
                    emptyState

                case .studying, .reviewing:
                    studyingBody(vm: vm)

                case .finished:
                    if let result = vm.result {
                        SessionSummaryScreen(
                            deckTitle: vm.deckTitle,
                            result: result,
                            elapsedSeconds: elapsedSeconds,
                            onBack: onBack,
                            onRestart: { vm.loadDeck(deckId) }
                        )
                    }

                case .error(let msg):
                    errorState(message: msg)
                }
            } else {
                FlashcardLoadingSkeleton()
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = FlashcardViewModel(api: container.api)
                viewModel = vm
                vm.loadDeck(deckId)
            }
        }
        .onReceive(timer) { _ in
            elapsedSeconds = viewModel?.elapsedSeconds ?? 0
        }
        .navigationBarHidden(true)
    }

    // MARK: Main Study Layout

    @ViewBuilder
    private func studyingBody(vm: FlashcardViewModel) -> some View {
        VStack(spacing: 0) {
            topBar(vm: vm)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            Spacer().frame(height: 20)

            if let card = vm.currentCard {
                FlashcardCardView(
                    front: card.front,
                    back: card.back,
                    deckTitle: vm.deckTitle,
                    isFlipped: vm.isFlipped,
                    onFlip: { vm.flipCard() }
                )
                .padding(.horizontal, 16)
            }

            Spacer().frame(height: 16)

            ratingSection(vm: vm)
                .padding(.horizontal, 16)

            Spacer().frame(height: 8)

            timerLabel
                .padding(.bottom, 20)
        }
    }

    // MARK: Top Bar

    private func topBar(vm: FlashcardViewModel) -> some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(VitaColors.glassBg)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            // Animated progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(VitaColors.surfaceElevated)
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(progressGradient)
                        .frame(width: geo.size.width * vm.progress, height: 4)
                        .animation(.easeInOut(duration: 0.4), value: vm.progress)
                }
            }
            .frame(height: 4)

            Text(vm.progressLabel)
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textSecondary)
                .monospacedDigit()
        }
        .frame(height: 32)
    }

    // MARK: Rating Section

    @ViewBuilder
    private func ratingSection(vm: FlashcardViewModel) -> some View {
        let isReviewing: Bool = {
            if case .reviewing = vm.phase { return true }
            return false
        }()

        if isReviewing {
            ProgressView()
                .tint(VitaColors.flashcardAccent)
                .frame(height: 72)
        } else if vm.isFlipped {
            RatingButtonsView(
                intervalPreviews: vm.intervalPreviews,
                onRate: { rating in vm.rateCard(rating) }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            // Placeholder height so layout doesn't jump when buttons appear
            Color.clear.frame(height: 72)
        }
    }

    // MARK: Timer

    private var timerLabel: some View {
        Text(formattedTimer)
            .font(VitaTypography.labelSmall)
            .foregroundStyle(VitaColors.textTertiary)
            .monospacedDigit()
    }

    private var formattedTimer: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(VitaColors.flashcardAccent)

            VStack(spacing: 8) {
                Text("Nenhum card para revisar")
                    .font(VitaTypography.titleLarge)
                    .foregroundStyle(VitaColors.textPrimary)

                Text("Todos os flashcards deste deck já estão em dia. Volte mais tarde!")
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button("Voltar", action: onBack)
                .font(VitaTypography.labelLarge)
                .foregroundStyle(VitaColors.flashcardAccent)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(VitaColors.flashcardAccent.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(VitaColors.flashcardAccent.opacity(0.18), lineWidth: 1))
        }
        .padding(32)
    }

    // MARK: Error State

    @ViewBuilder
    private func errorState(message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Voltar", action: onBack)
                .font(VitaTypography.labelLarge)
                .foregroundStyle(VitaColors.flashcardAccent)
        }
        .padding(32)
    }
}

// MARK: - Loading Skeleton

private struct FlashcardLoadingSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top bar skeleton
            HStack(spacing: 8) {
                Circle()
                    .fill(VitaColors.surfaceElevated)
                    .frame(width: 32, height: 32)
                    .shimmer()

                RoundedRectangle(cornerRadius: 2)
                    .fill(VitaColors.surfaceElevated)
                    .frame(height: 4)
                    .shimmer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(VitaColors.surfaceElevated)
                    .frame(width: 40, height: 12)
                    .shimmer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .frame(height: 32)

            Spacer().frame(height: 20)

            // Card skeleton
            RoundedRectangle(cornerRadius: 16)
                .fill(VitaColors.surfaceCard)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(VitaColors.glassBorder, lineWidth: 1))
                .shimmer()
                .padding(.horizontal, 16)

            Spacer().frame(height: 16)

            // Rating buttons skeleton
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 14)
                        .fill(VitaColors.surfaceElevated)
                        .frame(height: 72)
                        .shimmer()
                }
            }
            .padding(.horizontal, 16)

            Spacer().frame(height: 8)
        }
    }
}

// Uses ShimmerModifier from VitaShimmer.swift (DesignSystem/Components)

