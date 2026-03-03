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
        // XP toast overlay — anchored to top of screen, above all content
        .vitaXpToastHost(xpToastState)
    }

    @ViewBuilder
    private func dashboardContent(viewModel: DashboardViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Greeting Card with progress ring
                if let progress = viewModel.progress {
                    GreetingCard(progress: progress)
                }

                // XP Bar — level progress + daily goal
                if let userProgress = viewModel.userProgress {
                    VitaGlassCard {
                        VStack(spacing: 8) {
                            // Header row: title + streak badge
                            HStack {
                                Text("Progresso")
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

                // Upcoming Exams
                if !viewModel.upcomingExams.isEmpty {
                    SectionHeader(title: "Próximas Provas")
                    UpcomingExamsRow(exams: viewModel.upcomingExams)
                }

                // Week Agenda
                if !viewModel.weekDays.isEmpty {
                    SectionHeader(title: "Sua Semana")
                    WeekAgendaSection(days: viewModel.weekDays)
                }

                // Study Modules — taps navigate to Estudos screen sections
                if !viewModel.studyModules.isEmpty {
                    SectionHeader(title: "Módulos de Estudo")
                    StudyModulesGrid(
                        modules: viewModel.studyModules,
                        onModuleTap: { module in
                            switch module.name {
                            case "Flashcards": onNavigateToFlashcards?()
                            case "Simulados":  onNavigateToSimulados?()
                            case "PDFs":       onNavigateToPdfs?()
                            default:           onNavigateToMaterials?()
                            }
                        }
                    )
                }

                // Achievements section
                if let userProgress = viewModel.userProgress, !userProgress.badges.isEmpty {
                    SectionHeader(title: "Conquistas")
                    VitaGlassCard {
                        VitaBadgeGrid(badges: userProgress.badges)
                            .padding(16)
                    }
                    .padding(.horizontal, 20)
                }

                // Study Tip
                if !viewModel.studyTip.isEmpty {
                    SectionHeader(title: "Dica do Dia")
                    StudyTipCard(tip: viewModel.studyTip)
                }

                Spacer().frame(height: 100) // Tab bar clearance
            }
        }
        .refreshable {
            await viewModel.loadDashboard()
        }
    }
}
