import SwiftUI

// Clears ONLY the UINavigationController and its child view controllers' backgrounds.
// Applied as a zero-size overlay inside NavigationStack content so the outer
// VitaAmbientBackground (full screen) shows through seamlessly.
/// Custom UIView that clears all superview backgrounds on every layout pass.
private final class ClearBackgroundUIView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        clearChain()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        clearChain()
    }
    private func clearChain() {
        var view: UIView? = self
        while let parent = view?.superview {
            parent.backgroundColor = .clear
            view = parent
        }
    }
}

/// Placed inside each pushed route to clear UIKit hosting backgrounds.
private struct HostingClearerView: UIViewRepresentable {
    func makeUIView(context: Context) -> ClearBackgroundUIView {
        let v = ClearBackgroundUIView()
        v.backgroundColor = .clear
        v.isHidden = true
        return v
    }
    func updateUIView(_ uiView: ClearBackgroundUIView, context: Context) {}
}

private struct NavControllerBackgroundClearer: UIViewRepresentable {
    var pathCount: Int  // triggers updateUIView on every push/pop

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        clearNavBackgrounds(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        clearNavBackgrounds(from: uiView)
    }

    private func clearNavBackgrounds(from view: UIView) {
        func doClear() {
            var responder: UIResponder? = view
            while let next = responder?.next {
                if let nc = next as? UINavigationController {
                    nc.view.backgroundColor = .clear
                    nc.viewControllers.forEach { $0.view.backgroundColor = .clear }
                    return
                }
                responder = next
            }
        }
        DispatchQueue.main.async { doClear() }
        // Delayed pass catches VCs mid-push that weren't ready on first pass
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { doClear() }
    }
}

struct AppRouter: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.appContainer) private var container
    @AppStorage("vita_is_onboarded") private var isOnboardedStored = false
    @AppStorage("vita_onboarding_done") private var legacyOnboardingStored = false
    @State private var router = Router()
    @State private var profileChecked = false
    @State private var needsOnboarding = false

    var body: some View {
        Group {
            if authManager.isLoading || (authManager.isLoggedIn && !profileChecked) {
                // Show loading while auth is initializing OR profile check is pending.
                // CRITICAL: do NOT show MainTabView before profileChecked — it fires
                // background API calls (gamification, subscriptions) that can 401 and
                // trigger global logout before onboarding even starts.
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    ProgressView()
                        .tint(VitaColors.accent)
                }
            } else if !authManager.isLoggedIn {
                LoginScreen(authManager: authManager)
            } else if needsOnboarding {
                VitaOnboarding(
                    userName: authManager.userName ?? "",
                    onLogout: {
                        Task { await authManager.logout() }
                    }
                ) {
                    isOnboardedStored = true
                    legacyOnboardingStored = true
                    needsOnboarding = false
                }
            } else {
                MainTabView(router: router, authManager: authManager)
            }
        }
        .task(id: authManager.isLoggedIn) {
            guard authManager.isLoggedIn else {
                profileChecked = false
                needsOnboarding = false
                return
            }
            do {
                let profile = try await container.api.getProfile()
                NSLog("[AppRouter] getProfile OK onboardingCompleted=\(String(describing: profile.onboardingCompleted)) university=\(String(describing: profile.university))")
                if profile.onboardingCompleted != true {
                    needsOnboarding = true
                    isOnboardedStored = false
                    legacyOnboardingStored = false
                } else {
                    needsOnboarding = false
                    isOnboardedStored = true
                }
            } catch let error as APIError {
                // 401 = token expired — let the global handler deal with it,
                // but do NOT set needsOnboarding (we're about to be logged out).
                if case .unauthorized = error {
                    NSLog("[AppRouter] getProfile 401 — token expired, logout imminent")
                    profileChecked = true
                    return
                }
                if case .serverError(404) = error {
                    // 404 = no profile exists = genuinely needs onboarding
                    needsOnboarding = true
                    isOnboardedStored = false
                    legacyOnboardingStored = false
                } else {
                    // Other API errors (500, decode, etc) — DON'T assume onboarding.
                    // Show main tab and let normal error handling deal with it.
                    NSLog("[AppRouter] getProfile API error (not 404): \(error) — skipping onboarding check")
                    needsOnboarding = false
                }
            } catch {
                // Network error / timeout — DON'T force onboarding.
                // The user may be fully onboarded but temporarily offline.
                NSLog("[AppRouter] getProfile network error: \(error) — skipping onboarding check")
                needsOnboarding = false
            }
            profileChecked = true
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
                case .paywall:   router.navigate(to: .paywall)
                case .trabalhoDetail:
                    router.selectedTab = .faculdade
                    // Small delay so tab switch completes before push
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        router.navigate(to: route)
                    }
                default:         router.navigate(to: route)
                }
            case .integrationCallback(let provider):
                // OAuth finished — navigate to connections and reload
                router.navigate(to: .connections)
                // Post notification so ConnectorsViewModel reloads
                NotificationCenter.default.post(name: .integrationOAuthCompleted, object: provider)
            case .reviewToken(let token):
                // App Store reviewer deep link — sign into demo account.
                Task { await authManager.signInWithReviewToken(token) }
            default: break
            }
        }
    }


    // Note: onboarding check is now fully handled by the `needsOnboarding` state
    // set from the profile check in `.task(id:)`. The `isOnboardedStored` and
    // `legacyOnboardingStored` flags are kept as fallback for offline launches.
}

struct MainTabView: View {
    @Bindable var router: Router
    let authManager: AuthManager
    @Environment(\.appContainer) private var container
    @Environment(\.subscriptionStatus) private var subStatus
    @ObservedObject private var pushManager = PushManager.shared
    @State private var showChat = false
    @State private var showMenuPopout = false
    @State private var showNotifPopout = false
    @State private var dashboardSubtitle: String = ""
    /// True when a descendant screen (e.g. PdfViewerScreen fullscreen) asks for
    /// the chrome to go away. Hides TopBar, Breadcrumb, TabBar, safe-area inset.
    @State private var isImmersiveMode: Bool = false
    @State private var navVisibility = NavVisibility()

    var body: some View {
        // Shell OUTSIDE NavigationStack
        ZStack {
            // TopBar + Content (respects safe area)
            VStack(spacing: 0) {
                Color.clear.frame(height: 0)
                    .onChange(of: router.selectedTab) { _, _ in navVisibility.reset() }
                    .onChange(of: router.path.count) { _, _ in navVisibility.reset() }
                if !isImmersiveMode && navVisibility.isVisible {
                    VitaTopBar(
                        userName: authManager.userName,
                        userImageURL: authManager.userImage.flatMap(URL.init(string:)),
                        subtitle: dashboardSubtitle,
                        level: container.gamificationEvents.currentLevel,
                        xpProgress: container.gamificationEvents.currentXpProgress,
                        xpToast: container.gamificationEvents.xpToast,
                        notificationCount: pushManager.unreadNotificationCount,
                        onAvatarTap: { router.selectedTab = .progresso },
                        onBellTap: {
                            showMenuPopout = false
                            withAnimation(.spring(duration: 0.3, bounce: 0.12)) { showNotifPopout.toggle() }
                        },
                        onMenuTap: {
                            withAnimation(.spring(duration: 0.3, bounce: 0.12)) { showNotifPopout = false }
                            showMenuPopout.toggle()
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))

                    VitaBreadcrumb()
                        .transition(.opacity)
                }

                ZStack(alignment: .topTrailing) {
                    NavigationStack(path: $router.path) {
                        activeTabView
                            .environment(\.navVisibility, navVisibility)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                            .overlay(alignment: .topLeading) {
                                NavControllerBackgroundClearer(pathCount: router.path.count)
                                    .frame(width: 0, height: 0)
                            }
                            .safeAreaInset(edge: .bottom, spacing: 0) {
                                Color.clear.frame(height: isImmersiveMode ? 0 : 80)
                            }
                            .navigationDestination(for: Route.self) { route in
                                routeDestination(for: route)
                            }
                    }
                    .background(.clear)
                    .scrollContentBackground(.hidden)
                    .toolbar(.hidden, for: .navigationBar)
                    .enableSwipeBack()

                    // Chat overlay — sits in content area (below top bar, above tab bar)
                    if showChat {
                        VitaChatScreen(onClose: { withAnimation(.easeInOut(duration: 0.25)) { showChat = false } })
                            .padding(.bottom, 80) // space for tab bar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                }
            }
            .overlay(alignment: .topTrailing) {
                // MARK: - Notification Popout (fixed position below TopNav)
                if showNotifPopout {
                    VitaNotifPopout(
                        onDismiss: {
                            withAnimation(.spring(duration: 0.3, bounce: 0.12)) { showNotifPopout = false }
                        },
                        onSettingsTap: {
                            withAnimation(.spring(duration: 0.3, bounce: 0.12)) { showNotifPopout = false }
                            router.navigate(to: .notifications)
                        },
                        onNavigate: { route in
                            withAnimation(.spring(duration: 0.3, bounce: 0.12)) { showNotifPopout = false }
                            router.navigateToRoute(route)
                        }
                    )
                    // Fixed offset: TopBar height (~56pt) + padding (16pt)
                    .padding(.top, 72)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.88, anchor: .topTrailing)).combined(with: .offset(y: -12)),
                        removal: .opacity.combined(with: .scale(scale: 0.88, anchor: .topTrailing)).combined(with: .offset(y: -12))
                    ))
                    .animation(.spring(duration: 0.3, bounce: 0.12), value: showNotifPopout)
                    .zIndex(200)
                }
            }

            // TabBar — hidden in immersive mode (e.g. PDF fullscreen)
            if !isImmersiveMode {
                VStack {
                    Spacer()
                    VitaTabBar(selectedTab: $router.selectedTab, onCenterTap: {
                        withAnimation(.easeInOut(duration: 0.25)) { showChat.toggle() }
                    }, onTabReselect: { _ in
                        router.popToRoot()
                    })
                }
                .ignoresSafeArea(.keyboard)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // MARK: - Menu Popout Overlay
            if showMenuPopout {
                VitaMenuPopout(
                    userName: authManager.userName,
                    userImageURL: authManager.userImage.flatMap(URL.init(string:)),
                    onProfile: { router.navigateFromMenu(to: .profile) },
                    onNotifications: { showMenuPopout = false; showNotifPopout = true },
                    onAgenda: { router.navigateFromMenu(to: .agenda) },
                    onConfiguracoes: { router.navigateFromMenu(to: .configuracoes) },
                    onAppearance: { router.navigateFromMenu(to: .appearance) },
                    onConnections: { router.navigateFromMenu(to: .connections) },
                    onPaywall: { router.navigateFromMenu(to: .paywall) },
                    onLogout: { Task { await authManager.logout() } },
                    onDismiss: { showMenuPopout = false }
                )
                .transition(.opacity)
                .zIndex(200)
            }

            // Notification popout moved inside content ZStack (below TopNav)
        }
        .environment(router)
        .background {
            VitaAmbientBackground { Color.clear }
                .ignoresSafeArea()
        }
        .onPreferenceChange(ImmersivePreferenceKey.self) { value in
            withAnimation(.easeInOut(duration: 0.25)) {
                isImmersiveMode = value
            }
        }
        .onChange(of: router.path.count) { _, _ in
            // Sync routeStack when user swipes back (UIKit modifies path directly)
            router.syncStackToPath()
        }
        .onChange(of: router.selectedTab) { _, _ in
            // Dismiss popouts and chat on tab change
            showMenuPopout = false
            withAnimation(.spring(duration: 0.3, bounce: 0.12)) { showNotifPopout = false }
            if showChat {
                withAnimation(.easeInOut(duration: 0.25)) { showChat = false }
            }
            // When switching tabs, pop all pushed routes so user sees the tab root
            if !router.path.isEmpty {
                router.popToRoot()
            }
        }
        .overlay {
            ZStack {
                VitaLevelUpOverlay(event: container.gamificationEvents.levelUpEvent)
                VitaBadgeUnlockOverlay(event: container.gamificationEvents.badgeEvent)
            }
            .allowsHitTesting(false)
        }
        .task {
            // Populate subtitle from profile API (reliable source)
            if dashboardSubtitle.isEmpty {
                if let profile = try? await container.api.getProfile(),
                   let uni = profile.university, !uni.isEmpty {
                    let sem = profile.semester.map { " · \($0)º Semestre" } ?? ""
                    dashboardSubtitle = uni + sem
                }
            }
            await subStatus.refresh()
            await PushManager.shared.requestPermission()
            Task {
                let stats = try? await container.api.getGamificationStats()
                if let stats {
                    container.gamificationEvents.updateFromStats(stats)
                }
                let previousLevel = stats?.level
                if let result = try? await container.api.logActivity(action: "daily_login") {
                    container.gamificationEvents.handleActivityResponse(result, previousLevel: previousLevel)
                }
            }
            // Deferred from AppContainer.init — only sync notes/mindmaps when
            // user is fully onboarded and MainTabView is actually visible.
            if #available(iOS 17, *) {
                Task {
                    await container.noteSyncManager.pull()
                    await container.mindMapSyncManager.pull()
                }
            }
        }
        // Paywall now navigated via router.navigate(to: .paywall) — no fullScreenCover
    }

    // MARK: - Active Tab Content

    @ViewBuilder
    private var activeTabView: some View {
        switch router.selectedTab {
        case .home:
            DashboardScreen(
                // Breadcrumb hierarchy: Flashcards/Simulados/QBank/Transcrição/Atlas
                // belong under Estudos — switch tab so the crumb reads
                // "Home > Estudos > Flashcards" instead of "Home > Flashcards".
                onNavigateToFlashcards: {
                    router.selectedTab = .estudos
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        router.navigate(to: .flashcardHome())
                    }
                },
                onNavigateToSimulados: {
                    router.selectedTab = .estudos
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        router.navigate(to: .simuladoHome)
                    }
                },
                onNavigateToPdfs: { router.selectedTab = .estudos },
                onNavigateToMaterials: {
                    router.selectedTab = .estudos
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        router.navigate(to: .qbank)
                    }
                },
                onNavigateToTranscricao: {
                    router.selectedTab = .estudos
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        router.navigate(to: .transcricao)
                    }
                },
                onNavigateToAtlas3D: {
                    router.selectedTab = .estudos
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        router.navigate(to: .atlas3D)
                    }
                },
                onNavigateToDisciplineDetail: { id, name in router.navigateToDiscipline(id: id, name: name) },
                // Trabalhos lives under Faculdade (provas/agenda/trabalhos group).
                onNavigateToTrabalhos: {
                    router.selectedTab = .faculdade
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        router.navigate(to: .trabalhos)
                    }
                },
                onSubtitleLoaded: { subtitle in dashboardSubtitle = subtitle }
            )
        case .estudos:
            EstudosScreen(
                onNavigateToCanvasConnect: { router.navigate(to: .portalConnect(type: "canvas")) },
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
            FaculdadeHomeScreen()
        case .progresso:
            ProgressoScreen()
        }
    }

    // MARK: - Route Destination

    @ViewBuilder
    private func routeDestination(for route: Route) -> some View {
        routeView(for: route)
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topLeading) {
                // Clears UIKit hosting view backgrounds so the single
                // shell VitaAmbientBackground shows through seamlessly
                HostingClearerView()
                    .frame(width: 0, height: 0)
            }
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
        case .pdfViewer(let urlString, let title):
            if let url = URL(string: urlString) {
                PdfViewerScreen(url: url, initialTitle: title, onBack: { router.goBack() })
            } else {
                EmptyView()
            }
        case .flashcardTopics(let deckId, let deckTitle):
            FlashcardTopicsScreen(
                deckId: deckId,
                deckTitle: deckTitle,
                onBack: { router.goBack() },
                onSelectTopic: { tagPrefix in
                    router.navigate(to: .flashcardSession(deckId: deckId, tagFilter: tagPrefix))
                }
            )
        case .flashcardSession(let deckId, let tagFilter):
            FlashcardSessionScreen(
                deckId: deckId,
                tagFilter: tagFilter,
                onBack: { router.goBack() },
                onFinished: { router.goBack() },
                onOpenSettings: { router.navigate(to: .flashcardSettings) }
            )
        case .flashcardSettings:
            FlashcardSettingsScreen(
                onBack: { router.goBack() }
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
        case .portalConnect(let type):
            PortalConnectScreen(
                portalType: type,
                onBack: { router.goBack() }
            )
        // Legacy routes → unified PortalConnectScreen
        case .canvasConnect:
            PortalConnectScreen(portalType: "canvas", onBack: { router.goBack() })
        case .webalunoConnect:
            PortalConnectScreen(portalType: "webaluno", onBack: { router.goBack() })
        case .googleCalendarConnect:
            PortalConnectScreen(portalType: "google_calendar", onBack: { router.goBack() })
        case .googleDriveConnect:
            PortalConnectScreen(portalType: "google_drive", onBack: { router.goBack() })
        case .insights:
            InsightsScreen()
        case .trabalhos:
            TrabalhoScreen(onOpenDetail: { id in router.navigate(to: .trabalhoDetail(id: id)) })
        case .trabalhoDetail(let id):
            TrabalhoDetailScreen(
                assignmentId: id,
                onBack: { router.goBack() },
                onOpenEditor: { assignmentId in
                    // Editor is presented as fullScreenCover inside TrabalhoDetailScreen
                }
            )
        case .about:
            AboutScreen()
        case .agenda:
            AgendaScreen()
        case .appearance:
            AppearanceScreen()
        case .notifications:
            NotificationSettingsScreen()
        case .connections:
            ConnectionsScreen(
                onPortalConnect: { type in router.navigate(to: .portalConnect(type: type)) },
                onBack: { router.goBack() }
            )
        case .paywall:
            VitaPaywallScreen(onDismiss: { router.goBack() })
        case .atlas3D:
            AtlasWebViewScreen(
                onBack: { router.goBack() },
                onAskVita: { _ in
                    router.goBack()
                    withAnimation(.easeInOut(duration: 0.25)) { showChat = true }
                }
            )
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
                onNavigateToCanvasConnect: { router.navigate(to: .portalConnect(type: "canvas")) }
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
        case .profile:
            ProfileScreen(
                authManager: authManager,
                onNavigateToConfiguracoes: { router.navigate(to: .configuracoes) },
                onNavigateToAchievements: { router.navigate(to: .achievements) }
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
                onNavigateToDisciplinas: { router.navigate(to: .disciplinasConfig) },
                onBack: { router.goBack() }
            )
        case .disciplinasConfig:
            DisciplinasConfigScreen(onBack: { router.goBack() })
        case .qbank:
            QBankCoordinatorScreen(onBack: { router.goBack() })
        case .transcricao:
            TranscricaoScreen(onBack: { router.goBack() })
        case .flashcardHome(let subjectId):
            FlashcardsListScreen(
                initialSubjectId: subjectId,
                onBack: { router.goBack() },
                onOpenDeck: { deckId in router.navigate(to: .flashcardSession(deckId: deckId)) },
                onOpenTopics: nil  // Anki pattern: tap deck → session directly, no topics screen
            )
        case .disciplineDetail(let disciplineId, let disciplineName):
            DisciplineDetailScreen(
                disciplineId: disciplineId,
                disciplineName: disciplineName,
                onBack: { router.goBack() },
                onNavigateToFlashcards: { _ in router.navigate(to: .flashcardHome(subjectId: disciplineId)) },
                onNavigateToQBank: { router.navigate(to: .qbank) },
                onNavigateToSimulado: { router.navigate(to: .simuladoHome) }
            )
        case .faculdadeDisciplinas:
            FaculdadeDisciplinasScreen()
        case .faculdadeMaterias:
            FaculdadeMateriasScreen(
                onBack: { router.goBack() },
                onNavigateToDiscipline: { id, name in router.navigate(to: .disciplineDetail(disciplineId: id, disciplineName: name)) }
            )
        case .faculdadeDocumentos:
            FaculdadeDocumentosScreen(onBack: { router.goBack() })
        case .faculdadeProfessores:
            FaculdadeProfessoresScreen()
        default:
            EmptyView()
        }
    }
}
