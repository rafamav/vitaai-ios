import SwiftUI

// MARK: - DashboardScreen
// COPIED from mockup dashboard-mobile-v2.html — pixel perfect
// Layout: Hero carousel (always shown, min 1 Revisão card) → Tools Grid 2x2 → Disciplines → Atlas+Agenda

struct DashboardScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    @State private var viewModel: DashboardViewModel?
    @State private var xpToastState = VitaXpToastState()

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
            if viewModel == nil {
                viewModel = DashboardViewModel(api: container.api, dataManager: container.dataManager)
                Task {
                    // Load dashboard and appData in PARALLEL so disciplines
                    // are available immediately, not after dashboard finishes
                    async let dash: () = viewModel!.loadDashboard()
                    async let data: () = appData.loadIfNeeded()
                    _ = await (dash, data)
                    if let sub = viewModel?.subtitle, !sub.isEmpty {
                        onSubtitleLoaded?(sub)
                    }
                }
            }
        }
        .vitaXpToastHost(xpToastState)
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

                // ═══ TOOLS GRID 2x2 — IMAGES ONLY ═══
                toolsGrid()
                    .padding(.horizontal, 16)

                // ═══ "Minhas Disciplinas" ═══
                Text("Minhas Disciplinas")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(VitaColors.sectionLabel)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .padding(.horizontal, 16)

                // ═══ DISCIPLINES — skeleton → scroll ═══
                if viewModel.isLoading {
                    disciplinesSkeleton()
                } else {
                    disciplinesScroll()
                }

                // ═══ ATLAS 3D + AGENDA side by side ═══
                atlasAgendaRow(viewModel: viewModel)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                Spacer().frame(height: 120) // Tab bar clearance
            }
        }
        .refreshable {
            await viewModel.loadDashboard()
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
                bgImage: card.backgroundImage.asset,
                action: nil
            )
        }
        .buttonStyle(.plain)
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

        ZStack(alignment: .leading) {
            Image(bgImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 165)
                .clipped()

            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.031, green: 0.024, blue: 0.016).opacity(isAlert ? 0.92 : 0.85), location: 0),
                    .init(color: Color(red: 0.031, green: 0.024, blue: 0.016).opacity(isAlert ? 0.55 : 0.40), location: 0.45),
                    .init(color: Color(red: 0.031, green: 0.024, blue: 0.016).opacity(isAlert ? 0.20 : 0.10), location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )

            VStack(alignment: .leading, spacing: 8) {
                Spacer()

                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(labelColor.opacity(isAlert ? 0.85 : 0.70))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(labelColor.opacity(isAlert ? 0.10 : 0.06))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(labelColor.opacity(isAlert ? 0.20 : 0.12), lineWidth: 1))
                    )

                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.04 * 20)
                    .lineLimit(2)
                    .foregroundStyle(Color(red: 1, green: 0.988, blue: 0.973).opacity(0.97))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
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
                    .foregroundStyle(Color(red: 1, green: 0.902, blue: 0.706).opacity(0.80))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.04))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(VitaColors.accentHover.opacity(0.12), lineWidth: 1))
                    )
            }
            .padding(18)
        }
        .frame(height: 165)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: (isAlert ? labelColor : VitaColors.accentHover).opacity(0.40), location: 0.0),
                            .init(color: VitaColors.accentHover.opacity(0.12), location: 0.19),
                            .init(color: Color.white.opacity(0.04), location: 0.33),
                            .init(color: Color.white.opacity(0.025), location: 0.50),
                            .init(color: Color.white.opacity(0.04), location: 0.64),
                            .init(color: VitaColors.accentHover.opacity(0.12), location: 0.78),
                            .init(color: (isAlert ? labelColor : VitaColors.accentHover).opacity(0.40), location: 1.0),
                        ]),
                        center: UnitPoint(x: 0.4, y: 0.8)
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.50), radius: 28, x: 0, y: 11)
        .shadow(color: Color(red: 0.706, green: 0.549, blue: 0.235).opacity(0.08), radius: 22, x: 0, y: 5)
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

    private func shortSubjectName(_ subject: String) -> String {
        subject
            .replacingOccurrences(of: "(?i)\\bMÉDICA\\b", with: "", options: .regularExpression)
            .replacingOccurrences(of: "(?i)\\bMÉDICO\\b", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\b(III|II|I)\\b", with: "", options: .regularExpression)
            .replacingOccurrences(of: ",.*$", with: "", options: .regularExpression)
            .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private func formatDays(_ n: Int) -> String {
        if n == 0 { return "hoje" }
        if n == 1 { return "amanhã" }
        return "em \(n) dias"
    }

    // MARK: - Tools Grid 2x2

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
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(
                            Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.16),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(0.50), radius: 25, x: 0, y: 10)
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 3)
                .shadow(color: Color(red: 0.706, green: 0.549, blue: 0.235).opacity(0.07), radius: 14, x: 0, y: 0)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Disciplines Skeleton

    @ViewBuilder
    private func disciplinesSkeleton() -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
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
                        .frame(width: 100, height: 67)
                        .shimmer()
                }
            }
            .padding(.horizontal, 16)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.75),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
    }

    private func disciplineImage(for name: String) -> String {
        let s = name.lowercased()
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "pt_BR"))
        if s.contains("farmacologia")  { return "disc-farmacologia" }
        if s.contains("patologia")     { return "disc-patologia-geral" }
        if s.contains("fisiologia")    { return "disc-fisiologia-1" }
        if s.contains("bioquimica")    { return "disc-bioquimica" }
        if s.contains("anatomia")      { return "disc-anatomia" }
        if s.contains("histologia")    { return "disc-histologia" }
        if s.contains("legal") || s.contains("etica") { return "disc-medicina-legal" }
        return "disc-interprofissional"
    }

    @ViewBuilder
    private func disciplinesScroll() -> some View {
        // appData.gradesResponse is the reliable source (from /api/grades/current)
        // viewModel.subjects from /api/dashboard is unreliable fallback
        let gradeSubjects = appData.gradesResponse?.current ?? []
        let dashSubjects = viewModel?.subjects ?? []

        if !gradeSubjects.isEmpty {
            disciplineCards(names: gradeSubjects.map(\.subjectName), tierFor: { name in
                dashSubjects.first(where: { $0.name == name })?.vitaTier
            })
        } else if !dashSubjects.isEmpty {
            disciplineCards(names: dashSubjects.compactMap(\.name), tierFor: { name in
                dashSubjects.first(where: { $0.name == name })?.vitaTier
            })
        } else {
            HStack(spacing: 8) {
                Image(systemName: "graduationcap")
                    .font(.system(size: 18))
                    .foregroundStyle(VitaColors.accent.opacity(0.35))
                Text("Nenhuma disciplina encontrada")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private func disciplineCards(names: [String], tierFor: @escaping (String) -> String?) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(names, id: \.self) { name in
                    let img = disciplineImage(for: name)
                    let tier = tierFor(name)
                    Button {
                        onNavigateToDisciplineDetail?(name, name)
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 67)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .shadow(color: .black.opacity(0.30), radius: 5, x: 0, y: 2)

                            Circle()
                                .fill(tierDotColor(tier))
                                .frame(width: 8, height: 8)
                                .shadow(color: tierDotColor(tier).opacity(0.6), radius: 3)
                                .padding(6)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.75),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
    }

    // MARK: - Atlas 3D + Agenda Row

    @ViewBuilder
    private func atlasAgendaRow(viewModel: DashboardViewModel) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Button(action: { onNavigateToAtlas3D?() }) {
                Image("tool-atlas3d")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 110)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tool_atlas3d")

            VStack(alignment: .leading, spacing: 5) {
                Text("Agenda")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(VitaColors.sectionLabel)

                if viewModel.isLoading {
                    agendaSkeleton()
                } else if viewModel.agenda.isEmpty && viewModel.upcomingExams.isEmpty {
                    agendaEmptyState()
                } else {
                    agendaList(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func agendaSkeleton() -> some View {
        VStack(spacing: 6) {
            ForEach([1.0, 0.8, 0.6], id: \.self) { _ in
                RoundedRectangle(cornerRadius: 4)
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 12)
                    .shimmer()
            }
        }
    }

    @ViewBuilder
    private func agendaEmptyState() -> some View {
        VStack(spacing: 6) {
            Image(systemName: "clipboard.fill")
                .font(.system(size: 22))
                .foregroundStyle(VitaColors.accent.opacity(0.35))

            Text("Nenhuma prova próxima")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(red: 1, green: 0.988, blue: 0.973).opacity(0.55))

            Text("Aproveite para revisar!")
                .font(.system(size: 10))
                .foregroundStyle(VitaColors.textWarm.opacity(0.28))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .multilineTextAlignment(.center)
    }

    // MARK: - Agenda List (v2: dot + title + date, up to 5, urgency colors)

    @ViewBuilder
    private func agendaList(viewModel: DashboardViewModel) -> some View {
        VStack(spacing: 4) {
            if !viewModel.agenda.isEmpty {
                ForEach(viewModel.agenda.prefix(5), id: \.title) { item in
                    agendaItemRow(title: item.title ?? "", dateStr: item.date ?? "", daysUntil: item.daysUntil ?? 0)
                }
            } else {
                ForEach(viewModel.upcomingExams.prefix(5)) { exam in
                    agendaItemRow(
                        title: "\(exam.type) · \(exam.subject)",
                        dateStr: formatDays(exam.daysUntil),
                        daysUntil: exam.daysUntil
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func agendaItemRow(title: String, dateStr: String, daysUntil: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(agendaDotColor(daysUntil))
                .frame(width: 5, height: 5)

            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(red: 1, green: 0.988, blue: 0.973).opacity(0.70))
                .lineLimit(1)

            Spacer()

            Text(dateStr)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(agendaTextColor(daysUntil))
                .lineLimit(1)
        }
        .padding(.vertical, 4)
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
