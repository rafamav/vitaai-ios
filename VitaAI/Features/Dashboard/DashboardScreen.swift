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

                DashQuickAccessGrid(
                    modules: viewModel.studyModules,
                    onModuleTap: { module in
                        switch module.name {
                        case NSLocalizedString("Questoes", comment: ""):    onNavigateToSimulados?()
                        case NSLocalizedString("Flashcards", comment: ""):  onNavigateToFlashcards?()
                        case NSLocalizedString("Simulados", comment: ""):   onNavigateToSimulados?()
                        default: onNavigateToMaterials?()
                        }
                    }
                )
                .padding(.horizontal, 20)

                // MARK: Hoje / Semana
                DashSectionHeader(
                    title: NSLocalizedString("HOJE", comment: ""),
                    link: NSLocalizedString("Ver semana", comment: ""),
                    onLink: nil
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 10)

                if !viewModel.weekDays.isEmpty {
                    WeekAgendaSection(
                        days: viewModel.weekDays,
                        todayEvents: viewModel.todayEvents
                    )
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

                    UpcomingExamsRow(exams: viewModel.upcomingExams)
                        .padding(.horizontal, 20)
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

                    DashWeakSubjectsRow(subjects: viewModel.weakSubjects)
                        .padding(.horizontal, 20)
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

                    VitaGlassCard {
                        VitaBadgeGrid(badges: userProgress.badges)
                            .padding(16)
                    }
                    .padding(.horizontal, 20)
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

                    StudyTipCard(tip: viewModel.studyTip)
                }

                Spacer().frame(height: 110) // Tab bar clearance
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
private struct DashMiniPlayer: View {
    let player: MiniPlayerData
    var onTap: (() -> Void)?

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 10) {
                // Play button
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VitaColors.accent.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(VitaColors.accent.opacity(0.20), lineWidth: 1)
                        )
                        .frame(width: 32, height: 32)

                    Image(systemName: "play.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.accent.opacity(0.70))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(player.subject) · \(player.tool)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(1)

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                                .frame(height: 3)
                            Capsule()
                                .fill(VitaColors.goldGradient)
                                .frame(
                                    width: geo.size.width * CGFloat(player.completed) / CGFloat(max(player.total, 1)),
                                    height: 3
                                )
                        }
                    }
                    .frame(height: 3)
                }

                Spacer()

                Text("\(player.completed)/\(player.total)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VitaColors.accent.opacity(0.80))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Access Grid (matches mockup .tools-grid, 4 colunas)
private struct DashQuickAccessGrid: View {
    let modules: [StudyModule]
    var onModuleTap: ((StudyModule) -> Void)?

        // Quick access tools matching mockup .tools-grid
    private let quickTools: [(name: String, assetName: String, fallback: String, localizedKey: String)] = [
        ("Questoes",   "glassv2-exam-paper-nobg",     "doc.text.fill",          "Questoes"),
        ("Flashcards", "glassv2-flashcard-deck-nobg",  "rectangle.stack.fill",   "Flashcards"),
        ("Simulados",  "glassv2-calculator-nobg",      "list.bullet.clipboard",  "Simulados"),
        ("Atlas 3D",   "glassv2-anatomy-3d-nobg",      "staroflife.fill",        "Atlas 3D"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(quickTools.enumerated()), id: \.offset) { index, tool in
                Button(action: {
                    // Match by index for reliability (mock data order matches quickTools order)
                    let module = index < modules.count ? modules[index] : modules.first
                    if let m = module { onModuleTap?(m) }
                }) {
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
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
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
                    .background(Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.06), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
}
