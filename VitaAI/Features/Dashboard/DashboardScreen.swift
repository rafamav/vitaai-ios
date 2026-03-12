import SwiftUI

struct DashboardScreen: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: DashboardViewModel?
    @State private var xpToastState = VitaXpToastState()

    // Navigation callbacks injected by AppRouter
    var onNavigateToFlashcards: (() -> Void)?
    var onNavigateToSimulados: (() -> Void)?
    var onNavigateToPdfs: (() -> Void)?
    var onNavigateToMaterials: (() -> Void)?
    var onNavigateToQBank: (() -> Void)?

    var body: some View {
        Group {
            if let viewModel {
                dashboardContent(viewModel: viewModel)
            } else {
                ProgressView().tint(VitaColors.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = DashboardViewModel(api: container.api)
                Task { await viewModel?.loadDashboard() }
            }
        }
        .vitaXpToastHost(xpToastState)
    }

    @ViewBuilder
    private func dashboardContent(viewModel: DashboardViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // MARK: Mini Player — "Continuar estudando"
                if let player = viewModel.miniPlayer {
                    DashMiniPlayer(player: player, onTap: onNavigateToFlashcards)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                        .fadeUpAppear(delay: 0.05)
                }

                // MARK: Acesso Rapido
                DashSectionHeader(
                    title: NSLocalizedString("ACESSO RAPIDO", comment: ""),
                    link: NSLocalizedString("Ver todos", comment: ""),
                    onLink: nil
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .fadeUpAppear(delay: 0.10)

                DashQuickAccessGrid(
                    modules: viewModel.studyModules,
                    onModuleTap: { module in
                        switch module.name {
                        case NSLocalizedString("Questoes", comment: ""):
                            if let qbank = onNavigateToQBank { qbank() } else { onNavigateToSimulados?() }
                        case NSLocalizedString("Flashcards", comment: ""):  onNavigateToFlashcards?()
                        case NSLocalizedString("Simulados", comment: ""):   onNavigateToSimulados?()
                        default: onNavigateToMaterials?()
                        }
                    }
                )
                .padding(.horizontal, 20)
                .fadeUpAppear(delay: 0.15)

                // MARK: Hoje / Semana
                DashSectionHeader(
                    title: NSLocalizedString("HOJE", comment: ""),
                    link: NSLocalizedString("Ver semana", comment: ""),
                    onLink: nil
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)
                .fadeUpAppear(delay: 0.20)

                if !viewModel.weekDays.isEmpty {
                    WeekAgendaSection(
                        days: viewModel.weekDays,
                        todayEvents: viewModel.todayEvents
                    )
                    .fadeUpAppear(delay: 0.25)
                }

                // MARK: Proximas Provas
                if !viewModel.upcomingExams.isEmpty {
                    DashSectionHeader(
                        title: NSLocalizedString("PROXIMAS PROVAS", comment: ""),
                        link: NSLocalizedString("Agenda", comment: ""),
                        onLink: nil
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .fadeUpAppear(delay: 0.30)

                    UpcomingExamsRow(exams: viewModel.upcomingExams)
                        .padding(.horizontal, 20)
                        .fadeUpAppear(delay: 0.35)
                }

                // MARK: Atencao Necessaria
                if !viewModel.weakSubjects.isEmpty {
                    DashSectionHeader(
                        title: NSLocalizedString("ATENCAO NECESSARIA", comment: ""),
                        link: NSLocalizedString("Detalhes", comment: ""),
                        onLink: nil
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .fadeUpAppear(delay: 0.40)

                    DashWeakSubjectsRow(subjects: viewModel.weakSubjects)
                        .padding(.horizontal, 20)
                        .fadeUpAppear(delay: 0.45)
                }

                // MARK: XP / Progresso
                if let userProgress = viewModel.userProgress {
                    DashSectionHeader(
                        title: NSLocalizedString("SEU PROGRESSO", comment: ""),
                        link: nil,
                        onLink: nil
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .fadeUpAppear(delay: 0.50)

                    VitaGlassCard {
                        VStack(spacing: 8) {
                            HStack {
                                Text(NSLocalizedString("Progresso", comment: ""))
                                    .font(VitaTypography.labelLarge)
                                    .foregroundColor(VitaColors.textSecondary)
                                Spacer()
                                VitaStreakBadge(streak: userProgress.currentStreak, size: .sm)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                            VitaXpBar(userProgress: userProgress)
                        }
                        .padding(.bottom, 4)
                    }
                    .padding(.horizontal, 20)
                    .fadeUpAppear(delay: 0.55)
                }

                // MARK: Conquistas
                if let userProgress = viewModel.userProgress, !userProgress.badges.isEmpty {
                    DashSectionHeader(
                        title: NSLocalizedString("CONQUISTAS", comment: ""),
                        link: nil,
                        onLink: nil
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .fadeUpAppear(delay: 0.60)

                    VitaGlassCard {
                        VitaBadgeGrid(badges: userProgress.badges)
                            .padding(16)
                    }
                    .padding(.horizontal, 20)
                    .fadeUpAppear(delay: 0.65)
                }

                // MARK: Dica do Dia
                if !viewModel.studyTip.isEmpty {
                    DashSectionHeader(
                        title: NSLocalizedString("DICA DO DIA", comment: ""),
                        link: nil,
                        onLink: nil
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    .fadeUpAppear(delay: 0.70)

                    StudyTipCard(tip: viewModel.studyTip)
                        .fadeUpAppear(delay: 0.75)
                }

                Spacer().frame(height: 140) // Tab bar clearance (130px bar + safe area)
            }
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
    }
}

// MARK: - Section Header (matches mockup .section-head)
private struct DashSectionHeader: View {
    let title: String
    let link: String?
    let onLink: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.40))
                .kerning(1.0)
            Spacer()
            if let link {
                Button(action: { onLink?() }) {
                    Text(link)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VitaColors.accent.opacity(0.70))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Mini Player (matches mockup .mini-player)
// Layout: [title + subtitle + progress] | [⏮ ▶ ⏭] controls (spec: backward.fill/play.fill/forward.fill)
private struct DashMiniPlayer: View {
    let player: MiniPlayerData
    var onTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            // Left: content info + progress bar
            VStack(alignment: .leading, spacing: 6) {
                // Label pill — "Continuar estudando"
                Text(NSLocalizedString("Continuar estudando", comment: ""))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.70))
                    .textCase(.uppercase)
                    .kerning(0.5)

                // Subject · Tool
                Text("\(player.subject) · \(player.tool)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(1)

                // Progress bar + counter row
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.07))
                                .frame(height: 3)
                            Capsule()
                                .fill(VitaColors.goldBarGradient)
                                .frame(
                                    width: geo.size.width * CGFloat(player.completed) / CGFloat(max(player.total, 1)),
                                    height: 3
                                )
                        }
                    }
                    .frame(height: 3)

                    Text("\(Int(CGFloat(player.completed) / CGFloat(max(player.total, 1)) * 100))%")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.30))
                        .frame(minWidth: 28, alignment: .trailing)
                }
            }

            Spacer(minLength: 0)

            // Right: transport controls — backward | play | forward (SF Symbols per spec)
            HStack(spacing: 16) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.40))

                // Play button — gold accent (tap navigates to session)
                Button(action: { onTap?() }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(VitaColors.accent.opacity(0.18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(VitaColors.accent.opacity(0.28), lineWidth: 1)
                            )
                            .frame(width: 36, height: 36)

                        Image(systemName: "play.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(VitaColors.accent.opacity(0.85))
                    }
                }
                .buttonStyle(.plain)

                Image(systemName: "forward.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.40))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        // Glass: material blur + tint + border (matches mockup .mini-player)
        .background(.ultraThinMaterial)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
    }
}

// MARK: - Quick Access Grid (matches mockup .tools-grid, 4 colunas)
// Long press → jiggle mode with red remove badge (iOS home screen pattern)
private struct DashQuickAccessGrid: View {
    let modules: [StudyModule]
    var onModuleTap: ((StudyModule) -> Void)?

    // Default quick tools — matches mockup .tools-grid
    @State private var quickTools: [QuickTool] = [
        QuickTool(name: "Questoes",   assetName: "glassv2-exam-paper-nobg",     fallback: "doc.text.fill",          localizedKey: "Questoes"),
        QuickTool(name: "Flashcards", assetName: "glassv2-flashcard-deck-nobg",  fallback: "rectangle.stack.fill",   localizedKey: "Flashcards"),
        QuickTool(name: "Simulados",  assetName: "glassv2-calculator-nobg",      fallback: "list.bullet.clipboard",  localizedKey: "Simulados"),
        QuickTool(name: "Atlas 3D",   assetName: "glassv2-anatomy-3d-nobg",      fallback: "staroflife.fill",        localizedKey: "Atlas 3D"),
    ]

    @State private var isJiggling = false

    // LazyVGrid 4 columns — matches mockup .tools-grid (grid-template-columns: repeat(4, 1fr))
    private let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(quickTools.enumerated()), id: \.element.id) { index, tool in
                QuickToolCell(
                    tool: tool,
                    index: index,
                    isJiggling: isJiggling,
                    onTap: {
                        if isJiggling {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isJiggling = false
                            }
                        } else {
                            let module = index < modules.count ? modules[index] : modules.first
                            if let m = module { onModuleTap?(m) }
                        }
                    },
                    onLongPress: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isJiggling = true
                        }
                    },
                    onRemove: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            quickTools.remove(at: index)
                        }
                    }
                )
            }
        }
        // Tap outside grid to dismiss jiggle
        .contentShape(Rectangle())
        .onTapGesture {
            if isJiggling {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isJiggling = false
                }
            }
        }
    }
}

private struct QuickTool: Identifiable {
    let id = UUID()
    let name: String
    let assetName: String
    let fallback: String
    let localizedKey: String
}

// MARK: - Quick Tool Cell (with jiggle animation)
private struct QuickToolCell: View {
    let tool: QuickTool
    let index: Int
    let isJiggling: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onRemove: () -> Void

    // Per-cell jiggle phase offset so they don't all move in sync
    @State private var jiggleOffset: Double = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                VStack(spacing: 8) {
                    GlassAssetImage(
                        assetName: tool.assetName,
                        fallbackSymbol: tool.fallback,
                        size: 52
                    )

                    Text(NSLocalizedString(tool.localizedKey, comment: ""))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, 6)
            }
            .buttonStyle(ScaleButtonStyle(enabled: !isJiggling))
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in onLongPress() }
            )
            .rotationEffect(.degrees(isJiggling ? jiggleOffset : 0))

            // Red remove badge — visible only in jiggle mode
            if isJiggling {
                Button(action: onRemove) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 255/255, green: 69/255, blue: 58/255))
                            .frame(width: 20, height: 20)
                        Image(systemName: "minus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .offset(x: -8, y: 4)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onChange(of: isJiggling) { _, jiggles in
            if jiggles {
                // Different start phase per index so they don't all move identically
                let phase = Double(index % 2 == 0 ? 1 : -1) * 1.5
                jiggleOffset = phase
                withAnimation(
                    .easeInOut(duration: 0.12)
                    .repeatForever(autoreverses: true)
                ) {
                    jiggleOffset = -phase
                }
            } else {
                withAnimation(.easeOut(duration: 0.1)) {
                    jiggleOffset = 0
                }
            }
        }
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(enabled && configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Weak Subjects Row (matches mockup .weak-scroll)
private struct DashWeakSubjectsRow: View {
    let subjects: [WeakSubject]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(subjects) { subject in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(subject.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.55))

                        Text("\(Int(subject.score * 100))%")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.70))

                        // Progress bar (red-orange gradient for weak)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 3)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 255/255, green: 120/255, blue: 80/255).opacity(0.50),
                                                Color(red: 255/255, green: 180/255, blue: 100/255).opacity(0.35)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * subject.score, height: 3)
                            }
                        }
                        .frame(height: 3)
                    }
                    .padding(14)
                    .frame(minWidth: 120)
                    // Glass-sm: material blur + tint + border (matches mockup .glass-sm)
                    .background(.ultraThinMaterial)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.07), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
                }
            }
        }
    }
}
