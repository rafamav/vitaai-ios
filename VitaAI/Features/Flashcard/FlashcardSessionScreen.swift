import SwiftUI
import Combine
import Sentry

// MARK: - Flashcard Session accent colors (from flashcard-session-v1.html mockup)
// Purple accent: rgba(148,75,220), rgba(100,40,180), rgba(120,50,200)
private let flashcardAccent     = Color(red: 148/255, green: 75/255, blue: 220/255)
private let flashcardAccentDark = Color(red: 100/255, green: 40/255, blue: 180/255)
// Screen bg: #08060a + purple ambient per mockup .app-shell
private let flashcardScreenBg   = Color(red: 8/255, green: 6/255, blue: 10/255) // #08060a

// MARK: - Flashcard Session Screen

struct FlashcardSessionScreen: View {

    let deckId: String
    var tagFilter: String? = nil
    var onBack: () -> Void
    var onFinished: () -> Void = {}
    var onOpenSettings: () -> Void = {}

    @Environment(\.appContainer) private var container
    @Environment(Router.self) private var router
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel: FlashcardViewModel?
    @State private var elapsedSeconds: Int = 0
    @State private var timerCancellable: (any Cancellable)?
    @State private var settings = FlashcardSettings()
    private let timer = Timer.publish(every: 1, on: .main, in: .common)

    // Progress bar gradient — gold accent
    private let progressGradient = LinearGradient(
        colors: [
            VitaColors.accent.opacity(0.70),
            VitaColors.accentHover.opacity(0.50)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        ZStack {
            // Background handled by shell VitaAmbientBackground — no duplicate here

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
                            onRestart: { vm.loadDeck(deckId, tagFilter: tagFilter) }
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
                let vm = FlashcardViewModel(api: container.api, gamificationEvents: container.gamificationEvents)
                viewModel = vm
                Task {
                    vm.loadDeck(deckId, tagFilter: tagFilter)
                    SentrySDK.reportFullyDisplayed()
                }
            }
            // Share VM + settings with router so pushed settings screen can access them
            router.activeFlashcardVM = viewModel
            router.activeFlashcardSettings = settings
            timerCancellable = timer.connect()
        }
        .onDisappear {
            timerCancellable?.cancel()
            timerCancellable = nil
        }
        .onReceive(timer) { _ in
            elapsedSeconds = viewModel?.elapsedSeconds ?? 0
        }
        .navigationBarHidden(true)
        .onChange(of: viewModel != nil) {
            router.activeFlashcardVM = viewModel
            router.activeFlashcardSettings = settings
        }
        .trackScreen("FlashcardSession", extra: ["deck_id": deckId])
    }

    // MARK: Main Study Layout

    @ViewBuilder
    private func studyingBody(vm: FlashcardViewModel) -> some View {
        VStack(spacing: 0) {
            // Session header: back | title | count  (per mockup .session-header)
            sessionHeader(vm: vm)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 14)

            // Progress bar — separate 3px bar below header
            sessionProgressBar(vm: vm)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

            if let card = vm.currentCard {
                FlashcardCardView(
                    front: card.front,
                    back: card.back,
                    deckTitle: vm.deckTitle,
                    isFlipped: vm.isFlipped,
                    onFlip: { vm.flipCard() }
                )
                // Card scene height: 380pt iPhone, 520pt iPad
                .frame(height: horizontalSizeClass == .regular ? 520 : 380)
                .padding(.horizontal, 16)
            }

            Spacer().frame(height: 16)

            ratingSection(vm: vm)
                .padding(.horizontal, 16)

            Spacer().frame(height: 8)

            if settings.showTimer {
                timerLabel
                    .padding(.bottom, 20)
            } else {
                Spacer().frame(height: 20)
            }
        }
    }

    // MARK: Session Header — chevron+Voltar | title | count (purple)

    private func sessionHeader(vm: FlashcardViewModel) -> some View {
        HStack(spacing: 0) {
            // Back — chevron.left + "Voltar", rgba(255,240,215,0.50)
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Voltar")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(VitaColors.textWarm.opacity(0.70))
                .frame(minWidth: 60, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("backButton")

            Spacer()

            // Center title — 14px semibold, rgba(255,252,248,0.90)
            Text(vm.deckTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1)

            Spacer()

            // Right side: count + undo + gear
            HStack(spacing: 10) {
                Text(vm.progressLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VitaColors.accent.opacity(0.60))
                    .monospacedDigit()

                if vm.canUndo {
                    Button(action: { vm.undoLastRating() }) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(VitaColors.accent.opacity(0.70))
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }

                Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            .frame(minWidth: 80, alignment: .trailing)
            .animation(.easeOut(duration: 0.2), value: vm.canUndo)
        }
    }

    // MARK: Progress Bar — 3px, rgba(255,255,255,0.06) bg, purple gradient fill

    private func sessionProgressBar(vm: FlashcardViewModel) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 3)

                RoundedRectangle(cornerRadius: 999)
                    .fill(progressGradient)
                    .frame(width: geo.size.width * vm.progress, height: 3)
                    .animation(.easeInOut(duration: 0.4), value: vm.progress)
            }
        }
        .frame(height: 3)
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
                .tint(flashcardAccent)
                .frame(height: 72)
        } else if vm.isFlipped {
            RatingButtonsView(
                intervalPreviews: vm.intervalPreviews,
                showIntervals: settings.showIntervalPreview,
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
                .foregroundStyle(flashcardAccent)

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
                .foregroundStyle(flashcardAccent)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(flashcardAccent.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(flashcardAccent.opacity(0.18), lineWidth: 1))
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
                .foregroundStyle(flashcardAccent)
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

            // Card skeleton — 380pt per mockup .card-scene
            RoundedRectangle(cornerRadius: 22)
                .fill(VitaColors.surfaceCard)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(VitaColors.glassBorder, lineWidth: 1))
                .frame(height: 380)
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

