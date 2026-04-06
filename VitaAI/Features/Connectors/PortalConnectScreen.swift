import SwiftUI

// MARK: - PortalConnectScreen
// Unified connect screen for ALL portal types. Replaces 4 separate screens:
// CanvasConnectScreen, WebAlunoConnectScreen, GoogleCalendarConnectScreen, GoogleDriveConnectScreen.
// Each portal type gets the same chrome (nav bar, status card, toast) with type-specific connect flow.

struct PortalConnectScreen: View {
    let portalType: String
    var onBack: () -> Void

    @Environment(\.appContainer) private var container
    @State private var vm: PortalConnectViewModel?
    @State private var toastState = VitaToastState()

    // WebView state (Canvas inline, WebAluno sheet)
    @State private var cookiesCaptured = false
    @State private var showWebalunoWebView = false

    var body: some View {
        ZStack {
            if let vm {
                mainContent(vm: vm)
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if vm == nil {
                let viewModel = PortalConnectViewModel(portalType: portalType, api: container.api)
                vm = viewModel
                Task { await viewModel.loadStatus() }
            }
        }
        // Google OAuth: reload status when returning from Safari
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guard let vm, vm.isOAuth else { return }
            Task { await vm.loadStatus() }
        }
        // WebAluno WebView sheet
        .fullScreenCover(isPresented: $showWebalunoWebView) {
            WebAlunoWebViewScreen(
                onBack: { showWebalunoWebView = false },
                onSessionCaptured: { cookie in
                    showWebalunoWebView = false
                    vm?.connectWebaluno(cookie: cookie)
                },
                userEmail: container.authManager.userEmail
            )
        }
        .vitaToastHost(toastState)
        .onChange(of: vm?.successMessage) { msg in
            if let msg {
                toastState.show(msg, type: .success)
                vm?.dismissMessages()
            }
        }
        .onChange(of: vm?.error) { err in
            if let err {
                toastState.show(err, type: .error)
                vm?.dismissMessages()
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(vm: PortalConnectViewModel) -> some View {
        VStack(spacing: 0) {
            navBar(vm: vm)

            if vm.isLoading {
                Spacer()
                ProgressView()
                    .tint(VitaColors.accent)
                    .scaleEffect(1.2)
                Spacer()
            } else if vm.isConnected {
                connectedContent(vm: vm)
            } else if portalType == "canvas" && (vm.isSyncing || cookiesCaptured) {
                canvasSyncContent(vm: vm)
            } else if portalType == "canvas" {
                canvasWebViewLogin(vm: vm)
            } else {
                disconnectedContent(vm: vm)
            }
        }
    }

    // MARK: - Nav Bar

    private func navBar(vm: PortalConnectViewModel) -> some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Voltar")
                        .font(VitaTypography.bodyLarge)
                }
                .foregroundColor(VitaColors.accent)
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(vm.displayName)
                .font(VitaTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(VitaColors.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 70, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // MARK: - Connected Content

    @ViewBuilder
    private func connectedContent(vm: PortalConnectViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                statusCard(vm: vm)

                // Sync button
                VitaButton(
                    text: vm.isSyncing ? "Sincronizando..." : "Sincronizar Agora",
                    action: {
                        if portalType == "canvas" {
                            // Canvas re-sync needs fresh cookies
                            cookiesCaptured = false
                            vm.error = "Para re-sincronizar, reconecte ao Canvas"
                        } else {
                            vm.sync()
                        }
                    },
                    variant: .primary,
                    size: .lg,
                    isEnabled: !vm.isSyncing,
                    isLoading: vm.isSyncing,
                    leadingSystemImage: vm.isSyncing ? nil : "arrow.clockwise"
                )
                .frame(maxWidth: .infinity)

                howItWorksCard(vm: vm)

                // Disconnect button
                VitaButton(
                    text: vm.isDisconnecting ? "Desconectando..." : "Desconectar \(vm.displayName)",
                    action: { vm.disconnect() },
                    variant: .danger,
                    size: .lg,
                    isEnabled: !vm.isDisconnecting,
                    isLoading: vm.isDisconnecting
                )
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }

    // MARK: - Disconnected Content (WebAluno + Google)

    @ViewBuilder
    private func disconnectedContent(vm: PortalConnectViewModel) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                statusCard(vm: vm)

                // Instructions card
                VitaGlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Conectar \(vm.displayName)")
                            .font(VitaTypography.titleSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(VitaColors.textPrimary)

                        Text(connectDescription(vm: vm))
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                }

                howItWorksCard(vm: vm)

                // Connect button
                if vm.isOAuth {
                    VitaButton(
                        text: "Conectar com Google",
                        action: {
                            if let url = vm.oauthURL() {
                                UIApplication.shared.open(url)
                            }
                        },
                        variant: .primary,
                        size: .lg,
                        leadingSystemImage: "arrow.up.right.square"
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    // WebAluno: open WebView sheet
                    VitaButton(
                        text: vm.isConnecting ? "Conectando..." : "Entrar no \(vm.displayName)",
                        action: {
                            guard !vm.isConnecting else { return }
                            showWebalunoWebView = true
                        },
                        variant: .primary,
                        size: .lg,
                        isEnabled: !vm.isConnecting,
                        isLoading: vm.isConnecting,
                        leadingSystemImage: vm.isConnecting ? nil : "safari"
                    )
                    .frame(maxWidth: .infinity)

                    // Security info
                    VitaGlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            infoRow("Login via conta Google da sua faculdade")
                            infoRow("Nenhuma senha e armazenada no app")
                            infoRow("Apenas o cookie de sessao e capturado")
                        }
                        .padding(14)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - Canvas WebView Login

    @ViewBuilder
    private func canvasWebViewLogin(vm: PortalConnectViewModel) -> some View {
        VStack(spacing: 12) {
            VitaGlassCard {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                        .foregroundColor(VitaColors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Faca login no Canvas")
                            .font(VitaTypography.titleSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(VitaColors.textPrimary)
                        Text("Vita importa disciplinas, notas e materiais")
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(16)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(VitaColors.textTertiary)
                    Text(vm.instanceUrl.replacingOccurrences(of: "https://", with: ""))
                        .font(.system(size: 10))
                        .foregroundColor(VitaColors.textTertiary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.03))

                PortalWebView(
                    portalType: "canvas",
                    portalURL: vm.instanceUrl.replacingOccurrences(of: "https://", with: ""),
                    onSessionCaptured: { cookie in
                        cookiesCaptured = true
                        vm.connectCanvas(cookies: cookie, instanceUrl: vm.instanceUrl)
                    }
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    // MARK: - Canvas Sync Content

    @ViewBuilder
    private func canvasSyncContent(vm: PortalConnectViewModel) -> some View {
        ConnectorSyncView(
            connectorName: "Canvas",
            steps: SyncStep.canvasSteps(phase: vm.canvasSyncPhase),
            message: vm.canvasSyncMessage,
            progress: vm.isSyncing ? vm.canvasSyncProgress : nil,
            showRetry: !vm.isSyncing && cookiesCaptured,
            errorMessage: vm.error,
            onRetry: { cookiesCaptured = false }
        )
    }

    // MARK: - Status Card

    private func statusCard(vm: PortalConnectViewModel) -> some View {
        VitaGlassCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            vm.isConnected
                                ? VitaColors.dataGreen.opacity(0.15)
                                : VitaColors.textTertiary.opacity(0.12)
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: vm.isConnected ? vm.connectedIcon : vm.disconnectedIcon)
                        .font(.system(size: 22))
                        .foregroundColor(
                            vm.isConnected ? VitaColors.dataGreen : VitaColors.textSecondary
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(vm.displayName) \(vm.isConnected ? "Conectado" : "Desconectado")")
                        .font(VitaTypography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(VitaColors.textPrimary)

                    if let sub = vm.subtitle, !sub.isEmpty {
                        Text(sub)
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.textSecondary)
                    }

                    if vm.isConnected {
                        let statLine = vm.stats
                            .filter { $0.value > 0 }
                            .map { "\($0.value) \($0.label)" }
                            .joined(separator: " · ")
                        if !statLine.isEmpty {
                            Text(statLine)
                                .font(VitaTypography.bodySmall)
                                .foregroundColor(VitaColors.textSecondary)
                        }
                    }

                    if let sync = vm.lastSync {
                        Text("Ultima sinc: \(sync)")
                            .font(VitaTypography.labelSmall)
                            .foregroundColor(VitaColors.textTertiary)
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }

    // MARK: - How It Works Card

    private func howItWorksCard(vm: PortalConnectViewModel) -> some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Como funciona")
                    .font(VitaTypography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(VitaColors.textPrimary)

                ForEach(vm.howItWorks, id: \.self) { item in
                    infoRow(item)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Helpers

    private func connectDescription(vm: PortalConnectViewModel) -> String {
        if vm.isOAuth {
            return "Ao conectar, voce sera redirecionado ao Google para autorizar o acesso. "
                 + "Seus dados serao importados automaticamente apos a autorizacao."
        } else {
            return "Faca login com sua conta no portal oficial. "
                 + "Sua sessao sera capturada automaticamente para importar dados academicos."
        }
    }

    private func infoRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(VitaColors.accent)
                .padding(.top, 1)
            Text(text)
                .font(VitaTypography.bodySmall)
                .foregroundColor(VitaColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Canvas Connect") {
    NavigationStack {
        PortalConnectScreen(portalType: "canvas", onBack: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("WebAluno Connect") {
    NavigationStack {
        PortalConnectScreen(portalType: "webaluno", onBack: {})
    }
    .preferredColorScheme(.dark)
}

#Preview("Google Calendar Connect") {
    NavigationStack {
        PortalConnectScreen(portalType: "google_calendar", onBack: {})
    }
    .preferredColorScheme(.dark)
}
#endif
