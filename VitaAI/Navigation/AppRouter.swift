import SwiftUI

struct AppRouter: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.appContainer) private var container
    @AppStorage("vita_is_onboarded") private var isOnboardedStored = false
    @AppStorage("vita_onboarding_done") private var legacyOnboardingStored = false
    @State private var router = Router()

    var body: some View {
        Group {
            if authManager.isLoading {
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    ProgressView()
                        .tint(VitaColors.accent)
                }
            } else if !authManager.isLoggedIn {
                LoginScreen(authManager: authManager)
            } else if !isOnboarded {
                VitaOnboarding {
                }
            } else {
                MainTabView(router: router, authManager: authManager)
            }
        }
        .preferredColorScheme(.dark)
        .onOpenURL { url in
            let result = DeepLinkHandler.shared.parse(url: url)
            switch result {
            case .navigate(let route):
                switch route {
                case .home:      router.selectedTab = .home
                case .estudos:   router.selectedTab = .estudos
                case .faculdade: router.selectedTab = .faculdade
                case .progresso: router.selectedTab = .progresso
                case .profile:   router.selectedTab = .progresso
                default:         router.navigate(to: route)
                }
            default: break
            }
        }
    }

    private var isOnboarded: Bool {
        isOnboardedStored || legacyOnboardingStored
    }
}

struct MainTabView: View {
    @Bindable var router: Router
    let authManager: AuthManager
    @Environment(\.appContainer) private var container
    @Environment(\.subscriptionStatus) private var subStatus
    @State private var showChat = false
    @State private var showMenuPopout = false
    @State private var showNotifPopout = false
    @State private var dashboardSubtitle: String = ""

    var body: some View {
        // Shell OUTSIDE NavigationStack
        ZStack {
            // TopBar + Content (respects safe area)
            VStack(spacing: 0) {
                VitaTopBar(
                    userName: authManager.userName,
                    userImageURL: authManager.userImage.flatMap(URL.init(string:)),
                    subtitle: dashboardSubtitle,
                    onAvatarTap: { router.selectedTab = .progresso },
                    onBellTap: { showMenuPopout = false; showNotifPopout.toggle() },
                    onMenuTap: { showNotifPopout = false; showMenuPopout.toggle() }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                NavigationStack(path: $router.path) {
                    activeTabView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            Color.clear.frame(height: 80)
                        }
                        .navigationDestination(for: Route.self) { route in
                            routeDestination(for: route)
                        }
                }
                .toolbar(.hidden, for: .navigationBar)
            }

            // TabBar always visible at bottom
            VStack {
                Spacer()
                VitaTabBar(selectedTab: $router.selectedTab, onCenterTap: {
                    showChat = true
                }, onTabReselect: { _ in
                    router.popToRoot()
                })
            }
            .ignoresSafeArea(.keyboard)

            // MARK: - Menu Popout Overlay
            if showMenuPopout {
                VitaMenuPopout(
                    userName: authManager.userName,
                    userImageURL: authManager.userImage.flatMap(URL.init(string:)),
                    onProfile: { router.navigate(to: .profile) },
                    onNotifications: { showNotifPopout = true },
                    onAgenda: { router.selectedTab = .faculdade },
                    onConfiguracoes: { router.navigate(to: .configuracoes) },
                    onAppearance: { router.navigate(to: .appearance) },
                    onConnections: { router.navigate(to: .connections) },
                    onPaywall: { router.navigate(to: .paywall) },
                    onLogout: { Task { await authManager.logout() } },
                    onDismiss: { showMenuPopout = false }
                )
                .transition(.opacity)
                .zIndex(200)
            }

            // MARK: - Notification Popout Overlay
            if showNotifPopout {
                VitaNotifPopout(
                    onDismiss: { showNotifPopout = false },
                    onMarkAllRead: { /* TODO: API call */ },
                    onSettingsTap: {
                        showNotifPopout = false
                        router.navigate(to: .notifications)
                    }
                )
                .transition(.opacity)
                .zIndex(200)
            }
        }
        .background {
            VitaAmbientBackground { Color.clear }
                .ignoresSafeArea()
        }
        .onChange(of: router.selectedTab) { _, _ in
            // Dismiss popouts on tab change
            showMenuPopout = false
            showNotifPopout = false
            // When switching tabs, pop all pushed routes so user sees the tab root
            if !router.path.isEmpty {
                router.popToRoot()
            }
        }
        .sheet(isPresented: $showChat) {
            VitaChatScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .vitaXpToastHost(container.gamificationEvents.xpToast)
        .overlay {
            ZStack {
                VitaLevelUpOverlay(event: container.gamificationEvents.levelUpEvent)
                VitaBadgeUnlockOverlay(event: container.gamificationEvents.badgeEvent)
            }
            .allowsHitTesting(false)
        }
        .task {
            await subStatus.refresh()
            // await PushManager.shared.requestPermission()
            Task {
                let stats = try? await container.api.getGamificationStats()
                let previousLevel = stats?.level
                if let result = try? await container.api.logActivity(action: "daily_login") {
                    container.gamificationEvents.handleActivityResponse(result, previousLevel: previousLevel)
                }
            }
        }
    }

    // MARK: - Active Tab Content

    @ViewBuilder
    private var activeTabView: some View {
        switch router.selectedTab {
        case .home:
            DashboardScreen(
                onNavigateToFlashcards: { router.navigate(to: .flashcardHome) },
                onNavigateToSimulados: { router.navigate(to: .simuladoHome) },
                onNavigateToPdfs: { router.selectedTab = .estudos },
                onNavigateToMaterials: { router.navigate(to: .qbank) },
                onNavigateToTranscricao: { router.navigate(to: .transcricao) },
                onNavigateToAtlas3D: { router.navigate(to: .atlas3D) },
                onNavigateToDisciplineDetail: { id, name in router.navigate(to: .disciplineDetail(disciplineId: id, disciplineName: name)) },
                onSubtitleLoaded: { subtitle in dashboardSubtitle = subtitle }
            )
        case .estudos:
            EstudosScreen(
                onNavigateToCanvasConnect: { router.navigate(to: .canvasConnect) },
                onNavigateToNotebooks: { router.navigate(to: .notebookList) },
                onNavigateToMindMaps: { router.navigate(to: .mindMapList) },
                onNavigateToFlashcardSession: { deckId in router.navigate(to: .flashcardSession(deckId: deckId)) },
                onNavigateToFlashcardStats: { router.navigate(to: .flashcardStats) },
                onNavigateToPdfViewer: { url in router.navigate(to: .pdfViewer(url: url.absoluteString)) },
                onNavigateToSimulados: { router.navigate(to: .simuladoHome) },
                onNavigateToOsce: { router.navigate(to: .osce) },
                onNavigateToAtlas: { router.navigate(to: .atlas3D) },
                onNavigateToCourseDetail: { courseId, colorIdx in router.navigate(to: .courseDetail(courseId: courseId, colorIndex: colorIdx)) },
                onNavigateToProvas: { router.navigate(to: .provas) }
            )
        case .faculdade:
            AgendaScreen()
        case .progresso:
            ProfileScreen(
                authManager: authManager,
                onNavigateToConfiguracoes: { router.navigate(to: .configuracoes) },
                onNavigateToAchievements: { router.navigate(to: .achievements) }
            )
        }
    }

    // MARK: - Route Destination

    @ViewBuilder
    private func routeDestination(for route: Route) -> some View {
        routeView(for: route)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
    }

    @ViewBuilder
    private func routeView(for route: Route) -> some View {
        switch route {
        case .notebookList:
            NotebookListScreen(
                store: container.notebookStore,
                onBack: { router.goBack() },
                onOpenNotebook: { id in
                    router.navigate(to: .notebookEditor(notebookId: id.uuidString))
                }
            )
        case .notebookEditor(let idString):
            let uuid = UUID(uuidString: idString) ?? UUID()
            EditorScreen(
                notebookId: uuid,
                store: container.notebookStore,
                onBack: { router.goBack() }
            )
        case .mindMapList:
            MindMapListView(
                store: container.mindMapStore,
                onBack: { router.goBack() },
                onOpenMindMap: { id in
                    router.navigate(to: .mindMapEditor(id: id))
                }
            )
        case .mindMapEditor(let id):
            MindMapEditorView(
                mindMapId: id,
                store: container.mindMapStore,
                onBack: { router.goBack() }
            )
        case .pdfViewer(let urlString):
            if let url = URL(string: urlString) {
                PdfViewerScreen(url: url, onBack: { router.goBack() })
            } else {
                EmptyView()
            }
        case .flashcardSession(let deckId):
            FlashcardSessionScreen(
                deckId: deckId,
                onBack: { router.goBack() },
                onFinished: { router.goBack() }
            )
        case .flashcardStats:
            FlashcardStatsView(onBack: { router.goBack() })
        case .simuladoHome:
            SimuladoHomeScreen(
                onBack: { router.goBack() },
                onNewSimulado: { router.navigate(to: .simuladoConfig) },
                onOpenSession: { id in router.navigate(to: .simuladoSession(attemptId: id)) },
                onOpenResult: { id in router.navigate(to: .simuladoResult(attemptId: id)) },
                onOpenDiagnostics: { router.navigate(to: .simuladoDiagnostics) }
            )
        case .simuladoConfig:
            SimuladoConfigScreen(
                onBack: { router.goBack() },
                onStartSession: { id in
                    router.path.removeLast()
                    router.navigate(to: .simuladoSession(attemptId: id))
                }
            )
        case .simuladoSession(let attemptId):
            SimuladoSessionScreen(
                attemptId: attemptId,
                onBack: { router.goBack() },
                onFinished: { id in
                    router.path.removeLast()
                    router.navigate(to: .simuladoResult(attemptId: id))
                }
            )
        case .simuladoResult(let attemptId):
            SimuladoResultScreen(
                attemptId: attemptId,
                onBack: { router.goBack() },
                onReview: { router.navigate(to: .simuladoReview(attemptId: attemptId)) },
                onNewSimulado: {
                    router.path.removeLast()
                    router.navigate(to: .simuladoConfig)
                }
            )
        case .simuladoReview(let attemptId):
            SimuladoReviewScreen(
                attemptId: attemptId,
                onBack: { router.goBack() }
            )
        case .simuladoDiagnostics:
            SimuladoDiagnosticsScreen(
                onBack: { router.goBack() }
            )
        case .canvasConnect:
            CanvasConnectScreen(
                onBack: { router.goBack() }
            )
        case .webalunoConnect:
            WebAlunoConnectScreen(
                onBack: { router.goBack() }
            )
        case .googleCalendarConnect:
            GoogleCalendarConnectScreen(
                onBack: { router.goBack() }
            )
        case .googleDriveConnect:
            GoogleDriveConnectScreen(
                onBack: { router.goBack() }
            )
        case .insights:
            InsightsScreen()
        case .trabalhos:
            TrabalhoScreen()
        case .about:
            AboutScreen()
        case .appearance:
            AppearanceScreen()
        case .notifications:
            NotificationSettingsScreen()
        case .connections:
            ConnectionsScreen(
                onCanvasConnect: { router.navigate(to: .canvasConnect) },
                onWebAlunoConnect: { router.navigate(to: .webalunoConnect) },
                onGoogleCalendarConnect: { router.navigate(to: .googleCalendarConnect) },
                onGoogleDriveConnect: { router.navigate(to: .googleDriveConnect) },
                onBack: { router.goBack() }
            )
        case .paywall:
            VitaPaywallScreen(onDismiss: { router.goBack() })
        case .atlas3D:
            AtlasWebViewScreen(onBack: { router.goBack() })
        case .osce:
            OsceScreen(onBack: { router.goBack() })
        case .activityFeed:
            ActivityFeedScreen(
                onBack: { router.goBack() },
                onLeaderboard: { router.navigate(to: .leaderboard) }
            )
        case .leaderboard:
            LeaderboardScreen(onBack: { router.goBack() })
        case .courseDetail(let courseId, let colorIndex):
            CourseDetailScreen(
                courseId: courseId,
                folderColor: FolderPalette.color(forIndex: colorIndex),
                onBack: { router.goBack() },
                onNavigateToPdfViewer: { url in
                    router.navigate(to: .pdfViewer(url: url.absoluteString))
                },
                onNavigateToCanvasConnect: { router.navigate(to: .canvasConnect) }
            )
        case .provas:
            ProvasScreen(onBack: { router.goBack() })
        case .achievements:
            AchievementsScreen(onBack: { router.goBack() })
        case .planner:
            PlannerScreen(
                onBack: { router.goBack() },
                onNavigate: { route in router.navigate(to: route) }
            )
        case .toolManager:
            ToolManagerScreen(
                onBack: { router.goBack() },
                onSave: { _ in router.goBack() }
            )
        case .configuracoes:
            ConfiguracoesScreen(
                authManager: container.authManager,
                onNavigateToPerfil: { router.navigate(to: .profile) },
                onNavigateToAppearance: { router.navigate(to: .appearance) },
                onNavigateToNotifications: { router.navigate(to: .notifications) },
                onNavigateToConnections: { router.navigate(to: .connections) },
                onNavigateToAbout: { router.navigate(to: .about) },
                onNavigateToAssinatura: { router.navigate(to: .paywall) },
                onBack: { router.goBack() }
            )
        case .qbank:
            QBankCoordinatorScreen(onBack: { router.goBack() })
        case .transcricao:
            TranscricaoScreen(onBack: { router.goBack() })
        case .flashcardHome:
            FlashcardsListScreen(
                onBack: { router.goBack() },
                onOpenDeck: { deckId in router.navigate(to: .flashcardSession(deckId: deckId)) }
            )
        case .disciplineDetail(let disciplineId, let disciplineName):
            DisciplineDetailScreen(
                disciplineId: disciplineId,
                disciplineName: disciplineName,
                onBack: { router.goBack() },
                onNavigateToFlashcards: { deckId in router.navigate(to: .flashcardSession(deckId: deckId)) },
                onNavigateToQBank: { router.navigate(to: .qbank) },
                onNavigateToSimulado: { router.navigate(to: .simuladoHome) }
            )
        default:
            EmptyView()
        }
    }
}
