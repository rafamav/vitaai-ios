import SwiftUI

// MARK: - CanvasConnectScreen

struct CanvasConnectScreen: View {
    var onBack: () -> Void

    @Environment(\.appContainer) private var container
    @State private var viewModel: CanvasConnectViewModel?
    @State private var toastState = VitaToastState()

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            // Ambient glow
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.15, y: size.height * 0.1)
                let gradient = Gradient(colors: [VitaColors.accent.opacity(0.08), .clear])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center.x - size.width * 0.6,
                            y: center.y - size.width * 0.6,
                            width: size.width * 1.2,
                            height: size.width * 1.2
                        )),
                        with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: size.width * 0.6)
                    )
                }
            }
            .ignoresSafeArea()

            if let vm = viewModel {
                mainContent(vm: vm)
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel == nil {
                let vm = CanvasConnectViewModel(api: container.api)
                viewModel = vm
                vm.onAppear()
            }
        }
        .vitaToastHost(toastState)
        .onChange(of: viewModel?.state.successMessage) { _, msg in
            if let msg {
                toastState.show(msg, type: .success)
                viewModel?.dismissMessages()
            }
        }
        .onChange(of: viewModel?.state.error) { _, err in
            if let err {
                toastState.show(err, type: .error)
                viewModel?.dismissMessages()
            }
        }
        .sheet(isPresented: Binding(
            get: { viewModel?.state.showingWebViewSheet ?? false },
            set: { if !$0 { viewModel?.closeWebViewSheet() } }
        )) {
            if let vm = viewModel {
                CanvasWebViewScreen(
                    instanceUrl: vm.state.instanceUrlInput,
                    onBack: { vm.closeWebViewSheet() },
                    onDataScraped: { json, url, cookies in
                        vm.connectWithScrapedData(json: json, instanceUrl: url, nativeCookies: cookies)
                    }
                )
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func mainContent(vm: CanvasConnectViewModel) -> some View {
        VStack(spacing: 0) {
            // Top bar
            navBar

            if vm.state.isLoading {
                Spacer()
                ProgressView()
                    .tint(VitaColors.accent)
                    .scaleEffect(1.2)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        statusCard(state: vm.state)

                        if vm.state.isConnected {
                            connectedSection(vm: vm)
                        } else {
                            connectForm(vm: vm)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
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

            Text("Canvas LMS")
                .font(VitaTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(VitaColors.textPrimary)

            Spacer()

            // Spacer to balance the back button width
            Color.clear
                .frame(width: 70, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // MARK: - Status card

    private func statusCard(state: CanvasConnectViewState) -> some View {
        VitaGlassCard {
            HStack(spacing: 16) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(
                            state.isConnected
                                ? VitaColors.dataGreen.opacity(0.15)
                                : VitaColors.textTertiary.opacity(0.12)
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: state.isConnected ? "cloud.fill" : "cloud.slash.fill")
                        .font(.system(size: 22))
                        .foregroundColor(
                            state.isConnected ? VitaColors.dataGreen : VitaColors.textSecondary
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.isConnected ? "Canvas Conectado" : "Canvas Desconectado")
                        .font(VitaTypography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(VitaColors.textPrimary)

                    if state.isConnected && !state.instanceUrl.isEmpty {
                        Text(state.instanceUrl.replacingOccurrences(of: "https://", with: ""))
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.textSecondary)
                    }

                    if let syncAt = state.lastSyncAt {
                        Text("Última sinc: \(formatSyncDate(syncAt))")
                            .font(VitaTypography.labelSmall)
                            .foregroundColor(VitaColors.textTertiary)
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }

    // MARK: - Connected section

    @ViewBuilder
    private func connectedSection(vm: CanvasConnectViewModel) -> some View {
        // Sync button
        VitaButton(
            text: vm.state.isSyncing ? "Sincronizando..." : "Sincronizar Agora",
            action: { vm.syncNow() },
            variant: .primary,
            size: .lg,
            isEnabled: !vm.state.isSyncing,
            isLoading: vm.state.isSyncing,
            leadingSystemImage: vm.state.isSyncing ? nil : "arrow.clockwise"
        )
        .frame(maxWidth: .infinity)

        // How it works card
        howItWorksCard

        // Disconnect button
        VitaButton(
            text: vm.state.isDisconnecting ? "Desconectando..." : "Desconectar Canvas",
            action: { vm.disconnect() },
            variant: .danger,
            size: .lg,
            isEnabled: !vm.state.isDisconnecting,
            isLoading: vm.state.isDisconnecting
        )
        .frame(maxWidth: .infinity)
    }

    private var howItWorksCard: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Como funciona")
                    .font(VitaTypography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(VitaColors.textPrimary)

                infoRow("Disciplinas, arquivos e atividades são importados do Canvas")
                infoRow("PDFs são processados para gerar flashcards com IA")
                infoRow("Eventos do calendário aparecem na sua agenda")
                infoRow("Sincronize sempre que quiser dados atualizados")
            }
            .padding(16)
        }
    }

    // MARK: - Connect form

    @ViewBuilder
    private func connectForm(vm: CanvasConnectViewModel) -> some View {
        // Primary action: login via WebView (recommended)
        webViewConnectCard(vm: vm)

        // Divider
        HStack(spacing: 12) {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(VitaColors.surfaceBorder)
            Text("ou use token")
                .font(VitaTypography.labelSmall)
                .foregroundColor(VitaColors.textTertiary)
            Rectangle()
                .frame(height: 1)
                .foregroundColor(VitaColors.surfaceBorder)
        }
        .padding(.vertical, 4)

        // Manual token form
        tokenConnectCard(vm: vm)
    }

    // MARK: - WebView connect card

    private func webViewConnectCard(vm: CanvasConnectViewModel) -> some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(VitaColors.accent.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "safari.fill")
                            .font(.system(size: 20))
                            .foregroundColor(VitaColors.accent)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Entrar com conta Canvas")
                            .font(VitaTypography.titleSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(VitaColors.textPrimary)
                        Text("Recomendado — login com Google")
                            .font(VitaTypography.labelSmall)
                            .foregroundColor(VitaColors.textSecondary)
                    }

                    Spacer()
                }

                // Instance URL input (shared between both methods)
                VitaInput(
                    value: Binding(
                        get: { vm.state.instanceUrlInput },
                        set: { vm.updateInstanceUrlInput($0) }
                    ),
                    label: "URL da Instituicao",
                    placeholder: "https://suauni.instructure.com",
                    leadingSystemImage: "link",
                    keyboardType: .URL
                )

                VitaButton(
                    text: vm.state.isIngestingWebView ? "Processando dados..." : "Entrar no Canvas",
                    action: { vm.openWebViewSheet() },
                    variant: .primary,
                    size: .lg,
                    isEnabled: !vm.state.isIngestingWebView,
                    isLoading: vm.state.isIngestingWebView,
                    leadingSystemImage: vm.state.isIngestingWebView ? nil : "arrow.right.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
    }

    // MARK: - Token connect card

    private func tokenConnectCard(vm: CanvasConnectViewModel) -> some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Token de Acesso")
                        .font(VitaTypography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(VitaColors.textPrimary)
                    Text("Canvas → Configuracoes → Token de Acesso → Gerar novo token")
                        .font(VitaTypography.bodySmall)
                        .foregroundColor(VitaColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VitaInput(
                    value: Binding(
                        get: { vm.state.tokenInput },
                        set: { vm.updateTokenInput($0) }
                    ),
                    label: "Token de Acesso",
                    placeholder: "Cole seu token aqui",
                    leadingSystemImage: "key",
                    isSecure: true,
                    submitLabel: .go,
                    onSubmit: { vm.connect() }
                )

                VitaButton(
                    text: vm.state.isConnecting ? "Conectando..." : "Conectar com Token",
                    action: { vm.connect() },
                    variant: .secondary,
                    size: .lg,
                    isEnabled: !vm.state.isConnecting && !vm.state.tokenInput.trimmingCharacters(in: .whitespaces).isEmpty,
                    isLoading: vm.state.isConnecting,
                    leadingSystemImage: vm.state.isConnecting ? nil : "key.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .padding(16)
        }
    }

    // MARK: - Info row

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

    // MARK: - Helpers

    private func formatSyncDate(_ raw: String) -> String {
        let prefix = String(raw.prefix(16))
        return prefix.replacingOccurrences(of: "T", with: " ")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("CanvasConnectScreen") {
    NavigationStack {
        CanvasConnectScreen(onBack: {})
    }
    .preferredColorScheme(.dark)
}
#endif
