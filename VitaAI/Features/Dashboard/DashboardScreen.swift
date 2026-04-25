import SwiftUI

// MARK: - DashboardScreen
// COPIED from mockup dashboard-mobile-v2.html — pixel perfect
// Layout: Hero carousel (always shown, min 1 Revisão card) → Tools Grid 2x2 → Disciplines → Atlas+Agenda

struct DashboardScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    // ViewModel lives in AppContainer (singleton) so cache persists across
    // tab navigations. Reassigned in .onAppear from container.dashboardViewModel.
    @State private var viewModel: DashboardViewModel?
    // XP toasts now shown inline in VitaTopBar

    var onNavigateToFlashcards: (() -> Void)?
    var onNavigateToSimulados: (() -> Void)?
    var onNavigateToPdfs: (() -> Void)?
    var onNavigateToMaterials: (() -> Void)?
    var onNavigateToTranscricao: (() -> Void)?
    var onNavigateToAtlas3D: (() -> Void)?
    var onNavigateToDisciplineDetail: ((String, String) -> Void)?
    var onNavigateToTrabalhos: (() -> Void)?
    var onSubtitleLoaded: ((String) -> Void)?

    @State private var heroIndex: Int = 0
    @State private var heroCardCount: Int = 1
    @State private var heroTimer: Timer?

    var body: some View {
        Group {
            if let viewModel {
                if let error = viewModel.error {
                    // Error state
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "wifi.slash")
                            .font(.system(size: 32))
                            .foregroundStyle(VitaColors.textTertiary)
                        Text(error)
                            .font(VitaTypography.bodyMedium)
                            .foregroundStyle(VitaColors.textSecondary)
                            .multilineTextAlignment(.center)
                        Button("Tentar novamente") {
                            Task { await viewModel.loadDashboard() }
                        }
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.accent)
                        Spacer()
                    }
                    .padding(.horizontal, 32)
                } else {
                    dashboardContent(viewModel: viewModel)
                }
            } else {
                ProgressView().tint(VitaColors.accent)
            }
        }
        .onAppear {
            // Silent sync on every dashboard appear (returns from portal connect, tab switch, etc.)
            SilentPortalSync.shared.syncIfNeeded(api: container.api)

            // Reuse the singleton VM from AppContainer so cached hero/subjects
            // survive tab switches. loadDashboard() is SWR: renders cache
            // instantly if <60s old, refreshes silently in background.
            if viewModel == nil {
                viewModel = container.dashboardViewModel
            }
            Task {
                await viewModel!.loadDashboard()
                ScreenLoadContext.finish(for: "Dashboard")
                if let sub = viewModel?.subtitle, !sub.isEmpty {
                    onSubtitleLoaded?(sub)
                }
                await appData.loadIfNeeded()
            }
            // Silent background sync — keeps Mannesoft/Canvas data fresh
            SilentPortalSync.shared.syncIfNeeded(api: container.api)
        }
        .trackScreen("Dashboard")
        // XP toasts now shown inline in VitaTopBar
    }

    @ViewBuilder
    private func dashboardContent(viewModel: DashboardViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ═══ HERO SECTION — skeleton → carousel (always, min 1 Revisão card) ═══
                heroSection(viewModel: viewModel)
                    .padding(.top, 2)

                // ═══ "Ferramentas de Estudo" ═══
                // Mockup: font-size 10px, font-weight 600, letter-spacing 0.8px, color rgba(255,241,215,0.55)
                Text("Ferramentas de Estudo")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(VitaColors.sectionLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 16)

                // ═══ TOOLS GRID 2x2 ═══
                toolsGrid()
                    .padding(.horizontal, 16)

                // ═══ MATÉRIAS ↔ AGENDA (swipe) ═══
                MateriasAgendaWidget(
                    subjects: appData.gradesResponse?.current ?? [],
                    schedule: appData.classSchedule,
                    evaluations: appData.academicEvaluations,
                    onNavigateToDiscipline: onNavigateToDisciplineDetail
                )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer().frame(height: 120) // Tab bar clearance
            }
        }
        .trackedScroll()
        .refreshable {
            // Pull-to-refresh must also reload AppDataManager (grades, schedule,
            // enrolled subjects). loadDashboard() alone does NOT touch gradesResponse,
            // so the Matérias widget would keep stale cached scores. See shell.md
            // Camada 1: "pull-to-refresh = forceRefresh()".
            async let vm: Void = viewModel.loadDashboard()
            async let data: Void = appData.forceRefresh()
            _ = await (vm, data)
        }
    }

    // MARK: - Hero Section

    @ViewBuilder
    private func heroSection(viewModel: DashboardViewModel) -> some View {
        if viewModel.isLoading {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: VitaColors.textWarm.opacity(0.03), location: 0),
                            .init(color: VitaColors.textWarm.opacity(0.08), location: 0.5),
                            .init(color: VitaColors.textWarm.opacity(0.03), location: 1),
                        ],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
                .frame(height: 165)
                .padding(.horizontal, 16)
                .shimmer()
        } else {
            heroCarousel(viewModel: viewModel)
        }
    }

    // MARK: - Hero Carousel (server-driven cards)

    @ViewBuilder
    // Widget-like carousel: always show at least 3 cards, looping existing
    // ones if the server returned fewer. Keeps the rotation feeling alive
    // even on slow days (e.g., only 1 revision card).
    private func paddedHeroCards(_ raw: [DashboardHeroCard]) -> [DashboardHeroCard] {
        guard !raw.isEmpty else { return [] }
        var out = raw
        while out.count < 3 {
            out.append(raw[out.count % raw.count])
        }
        return out
    }

    @ViewBuilder
    private func heroCarousel(viewModel: DashboardViewModel) -> some View {
        let cards = paddedHeroCards(viewModel.heroCards)
        let cardCount = max(cards.count, 1)

        TabView(selection: $heroIndex) {
            if cards.isEmpty {
                // Fallback: single revision card if server returned nothing
                serverHeroCard(
                    label: "HOJE",
                    labelColor: VitaColors.accentHover,
                    title: "Revisão",
                    pills: [("rectangle.on.rectangle", "\(viewModel.flashcardsDueTotal) cards")],
                    cta: "Revisar flashcards",
                    bgImage: "flashcard-bg-new",
                    action: { onNavigateToFlashcards?() }
                ).tag(0)
            } else {
                ForEach(Array(cards.enumerated()), id: \.offset) { idx, card in
                    heroCardView(card: card, bgIndex: idx)
                        .tag(idx)
                }
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 165)
        .overlay(alignment: .top) {
            HStack(spacing: 5) {
                ForEach(0..<cardCount, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(i == heroIndex ? 0.85 : 0.25))
                        .frame(width: i == heroIndex ? 18 : 6, height: 6)
                        .animation(.easeInOut(duration: 0.25), value: heroIndex)
                }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, 16)
        .onAppear {
            heroCardCount = cardCount
            heroTimer?.invalidate()
            heroTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
                Task { @MainActor in
                    withAnimation(.easeInOut(duration: 0.4)) {
                        heroIndex = (heroIndex + 1) % heroCardCount
                    }
                }
            }
        }
        .onDisappear {
            heroTimer?.invalidate()
            heroTimer = nil
        }
    }

    // MARK: - Server-driven hero card dispatcher

    @ViewBuilder
    private func heroCardView(card: DashboardHeroCard, bgIndex: Int) -> some View {
        // Fully server-driven: label, tone, cta, background all come from backend.
        // Client only maps semantic tone -> design system color.
        let pills = card.pills.map { ($0.icon ?? "circle", $0.text ?? "") }

        Button(action: { handleHeroAction(for: card) }) {
            serverHeroCard(
                label: card.label,
                labelColor: toneColor(card.labelTone),
                title: card.title.uppercased(),
                subtitle: card.subtitle,
                pills: pills,
                cta: card.cta.text,
                bgImage: resolveHeroAsset(card.backgroundImage.asset),
                action: nil
            )
        }
        .buttonStyle(.plain)
    }

    /// Falls back to a known-good local asset when the backend specifies an asset
    /// name that does not exist in the app bundle (e.g. "hero-exam", "hero-revision"
    /// emitted before the media pipeline existed). Keeps the card visible with a
    /// generic background instead of leaving a broken empty Image + log warnings.
    private func resolveHeroAsset(_ name: String) -> String {
        if UIImage(named: name) != nil { return name }
        return "fundo-dashboard"
    }

    /// Maps backend semantic tone to design system color. Single source of truth for hero label color.
    private func toneColor(_ tone: DashboardHeroCard.LabelTone) -> Color {
        switch tone {
        case .danger:  return Color(red: 0.937, green: 0.267, blue: 0.267) // red
        case .warning: return Color(red: 0.980, green: 0.553, blue: 0.235) // orange
        case .info:    return Color(red: 0.957, green: 0.773, blue: 0.275) // yellow
        case .accent:  return VitaColors.accentHover
        case .neutral: return VitaColors.textWarm
        }
    }

    private func handleHeroAction(for card: DashboardHeroCard) {
        guard let target = card.action.target else { return }
        switch target {
        case "flashcards":
            onNavigateToFlashcards?()
        case "trabalhos", "trabalho", "assignments":
            onNavigateToTrabalhos?()
        case "discipline", "disciplineDetail":
            guard let id = card.action.id, !id.isEmpty else { return }
            // For exam/assignment cards, subtitle holds the subject name (when it's an
            // assignment) OR the exam title (when it's an exam with title = "Prova de X").
            // Fall back to title if subtitle is unhelpful.
            let candidate = card.type == .exam ? card.subtitle : card.title
            let name = candidate.isEmpty ? card.title : candidate
            onNavigateToDisciplineDetail?(id, name)
        default:
            break
        }
    }

    // MARK: - Generic Server Hero Card

    @ViewBuilder
    private func serverHeroCard(
        label: String,
        labelColor: Color = VitaColors.accentHover,
        title: String,
        subtitle: String? = nil,
        pills: [(String, String)],
        cta: String,
        bgImage: String,
        action: (() -> Void)? = nil
    ) -> some View {
        let isAlert = labelColor != VitaColors.accentHover

        VStack(alignment: .leading, spacing: 8) {
            Spacer()

            Text(label)
                .font(.system(size: 9, weight: .bold))
                .kerning(1.2)
                .foregroundStyle(labelColor.opacity(isAlert ? 0.95 : 0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(labelColor.opacity(isAlert ? 0.14 : 0.10))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(labelColor.opacity(isAlert ? 0.28 : 0.18), lineWidth: 1))
                )

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .tracking(-0.04 * 20)
                .lineLimit(2)
                .foregroundStyle(Color.white)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.78))
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                ForEach(Array(pills.prefix(3).enumerated()), id: \.offset) { _, pill in
                    heroPill(icon: pill.0, text: pill.1)
                }
            }

            Text(cta)
                .font(.system(size: 12, weight: .semibold))
                .tracking(0.24)
                .foregroundStyle(Color(red: 1, green: 0.902, blue: 0.706).opacity(0.92))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VitaColors.accentHover.opacity(0.18), lineWidth: 1))
                )
        }
        .padding(18)
        .frame(height: 165)
        .glassCard(cornerRadius: 20)
    }

    @ViewBuilder
    private func heroPill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(VitaColors.accentHover.opacity(0.70))
            Text(text)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.06), lineWidth: 1))
        )
    }

    private func formatDays(_ n: Int) -> String {
        if n == 0 { return "hoje" }
        if n == 1 { return "amanhã" }
        return "em \(n) dias"
    }


    // Legacy: kept for reference but unused now
    @ViewBuilder
    private func toolsGrid() -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                toolImage("tool-questoes", identifier: "tool_questoes", bg: Color(red: 0.18, green: 0.10, blue: 0.02)) { onNavigateToMaterials?() }
                toolImage("tool-flashcards", identifier: "tool_flashcards", bg: Color(red: 0.10, green: 0.05, blue: 0.18)) { onNavigateToFlashcards?() }
            }
            HStack(spacing: 8) {
                toolImage("tool-simulados", identifier: "tool_simulados", bg: Color(red: 0.02, green: 0.10, blue: 0.22)) { onNavigateToSimulados?() }
                toolImage("tool-transcricao", identifier: "tool_transcricao", bg: Color(red: 0.02, green: 0.14, blue: 0.14)) { onNavigateToTranscricao?() }
            }
        }
    }

    // Mockup tool card shadows:
    //   0 20px 50px rgba(0,0,0,0.50), 0 6px 16px rgba(0,0,0,0.35)
    //   0 0 0 0.5px rgba(255,200,120,0.16), 0 0 28px rgba(180,140,60,0.07)
    @ViewBuilder
    private func toolImage(_ name: String, identifier: String, bg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 130)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(
                            Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.16),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.40), radius: 12, x: 0, y: 5)
                .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    private func tierDotColor(_ tier: String?) -> Color {
        switch tier {
        case "bronze":  return VitaColors.dataRed       // danger
        case "silver":  return VitaColors.dataAmber      // attention
        case "gold":    return VitaColors.dataGreen      // on track
        case "diamond": return Color(red: 0.68, green: 0.85, blue: 1.0) // safe
        default:        return VitaColors.textTertiary
        }
    }

    private func agendaDotColor(_ daysUntil: Int) -> Color {
        if daysUntil <= 3 { return Color(red: 0.937, green: 0.267, blue: 0.267).opacity(0.70) }
        if daysUntil <= 7 { return Color(red: 0.961, green: 0.620, blue: 0.043).opacity(0.60) }
        return VitaColors.accentHover.opacity(0.25)
    }

    private func agendaTextColor(_ daysUntil: Int) -> Color {
        if daysUntil <= 3 { return Color(red: 1, green: 0.471, blue: 0.314).opacity(0.85) }
        if daysUntil <= 7 { return Color(red: 0.961, green: 0.706, blue: 0.235).opacity(0.75) }
        return VitaColors.textWarm.opacity(0.40)
    }
}
