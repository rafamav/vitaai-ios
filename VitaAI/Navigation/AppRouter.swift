import SwiftUI

struct AppRouter: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.appContainer) private var container
    @State private var router = Router()

    var body: some View {
        Group {
            if authManager.isLoading {
                // Splash
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    ProgressView()
                        .tint(VitaColors.accent)
                }
            } else if !authManager.isLoggedIn {
                LoginScreen(authManager: authManager)
            } else if !isOnboarded {
                OnboardingScreen {
                    // Force re-check
                }
            } else {
                MainTabView(router: router, authManager: authManager)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var isOnboarded: Bool {
        UserDefaults.standard.bool(forKey: "vita_is_onboarded")
    }
}

struct MainTabView: View {
    @Bindable var router: Router
    let authManager: AuthManager
    @Environment(\.appContainer) private var container
    @State private var showChat = false

    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack(alignment: .bottom) {
                VitaAmbientBackground {
                    VStack(spacing: 0) {
                        VitaTopBar(
                            title: router.selectedTab.rawValue,
                            userName: authManager.userName,
                            userImageURL: authManager.userImage.flatMap(URL.init(string:)),
                            onAvatarTap: { router.selectedTab = .profile }
                        )

                        TabView(selection: $router.selectedTab) {
                            DashboardScreen()
                                .tag(TabItem.home)

                            EstudosScreen()
                                .tag(TabItem.estudos)

                            AgendaScreen()
                                .tag(TabItem.agenda)

                            ProfileScreen(authManager: authManager)
                                .tag(TabItem.profile)
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }
                }

                VitaTabBar(selectedTab: $router.selectedTab) {
                    showChat = true
                }
            }
            .ignoresSafeArea(.keyboard)
            .navigationBarHidden(true)
            // MARK: - Route destinations
            .navigationDestination(for: Route.self) { route in
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
                case .about:
                    AboutScreen()
                case .appearance:
                    AppearanceScreen()
                case .notifications:
                    NotificationSettingsScreen()
                default:
                    EmptyView()
                }
            }
        }
        .sheet(isPresented: $showChat) {
            VitaChatScreen()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}
