import SwiftUI

// MARK: - WebAlunoConnectScreen

struct WebAlunoConnectScreen: View {
    var onBack: () -> Void

    @Environment(\.appContainer) private var container
    @State private var viewModel: WebAlunoConnectViewModel?
    @State private var toastState = VitaToastState()
    @State private var showWebView: Bool = false

    var body: some View {
        ZStack {
            VitaScreenBg()

            // Ambient glow
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.85, y: size.height * 0.15)
                let gradient = Gradient(colors: [VitaColors.accent.opacity(0.07), .clear])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center.x - size.width * 0.55,
                            y: center.y - size.width * 0.55,
                            width: size.width * 1.1,
                            height: size.width * 1.1
                        )),
                        with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: size.width * 0.55)
                    )
                }
            }
            .ignoresSafeArea()

            if let vm = viewModel {
                mainContent(vm: vm)
                    .sheet(isPresented: $showWebView) {
                        WebAlunoWebViewScreen(
                            onBack: { showWebView = false },
                            onSessionCaptured: { cookie in
                                showWebView = false
                                vm.connectWithSession(cookie)
                            },
                            userEmail: container.authManager.userEmail
                        )
                        .interactiveDismissDisabled(vm.state.isConnecting)
                    }
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel == nil {
                let vm = WebAlunoConnectViewModel(api: container.api)
                viewModel = vm
                vm.onAppear()
            }
        }
        .vitaToastHost(toastState)
        .onChange(of: viewModel?.state.successMessage) { msg in
            if let msg {
                toastState.show(msg, type: .success)
                viewModel?.dismissMessages()
            }
        }
        .onChange(of: viewModel?.state.error) { err in
            if let err {
                toastState.show(err, type: .error)
                viewModel?.dismissMessages()
            }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func mainContent(vm: WebAlunoConnectViewModel) -> some View {
        VStack(spacing: 0) {
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
                            disconnectedSection(vm: vm)
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

            Text("WebAluno")
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

    // MARK: - Status card

    private func statusCard(state: WebAlunoConnectViewState) -> some View {
        VitaGlassCard {
            HStack(spacing: 16) {
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
                    Text(state.isConnected ? "WebAluno Conectado" : "WebAluno Desconectado")
                        .font(VitaTypography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(VitaColors.textPrimary)

                    if state.isConnected {
                        Text("\(state.gradesCount) notas · \(state.scheduleCount) aulas · \(state.semestersCount) semestres")
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.textSecondary)

                        if let syncAt = state.lastSyncAt {
                            Text("Última sinc: \(formatSyncDate(syncAt))")
                                .font(VitaTypography.labelSmall)
                                .foregroundColor(VitaColors.textTertiary)
                        }
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }

    // MARK: - Connected section

    @ViewBuilder
    private func connectedSection(vm: WebAlunoConnectViewModel) -> some View {
        // Sync button
        VitaButton(
            text: vm.state.isSyncing ? "Sincronizando..." : "Sincronizar Agora",
            action: { vm.sync() },
            variant: .primary,
            size: .lg,
            isEnabled: !vm.state.isSyncing,
            isLoading: vm.state.isSyncing,
            leadingSystemImage: vm.state.isSyncing ? nil : "arrow.clockwise"
        )
        .frame(maxWidth: .infinity)

        // Imported data card
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Dados importados")
                    .font(VitaTypography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(VitaColors.textPrimary)

                infoRow("Notas parciais e finais aparecem em Insights")
                infoRow("Grade horária aparece na sua Agenda")
                infoRow("Sessão pode expirar — reconecte se necessário")
            }
            .padding(16)
        }
    }

    // MARK: - Disconnected section

    @ViewBuilder
    private func disconnectedSection(vm: WebAlunoConnectViewModel) -> some View {
        // Instructions card
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Conectar WebAluno")
                    .font(VitaTypography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(VitaColors.textPrimary)

                Text(
                    "Faça login com sua conta Google da ULBRA no portal oficial. " +
                    "Sua sessão será capturada automaticamente para importar notas e grade horária."
                )
                .font(VitaTypography.bodySmall)
                .foregroundColor(VitaColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }

        // Open WebView button
        VitaButton(
            text: vm.state.isConnecting ? "Conectando..." : "Entrar no WebAluno",
            action: {
                guard !vm.state.isConnecting else { return }
                showWebView = true
            },
            variant: .primary,
            size: .lg,
            isEnabled: !vm.state.isConnecting,
            isLoading: vm.state.isConnecting,
            leadingSystemImage: vm.state.isConnecting ? nil : "safari"
        )
        .frame(maxWidth: .infinity)

        // Security info card
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                infoRow("Login via conta Google da sua faculdade")
                infoRow("Nenhuma senha é armazenada no app")
                infoRow("Apenas o cookie de sessão é capturado")
            }
            .padding(14)
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
#Preview("WebAlunoConnectScreen") {
    NavigationStack {
        WebAlunoConnectScreen(onBack: {})
    }
    .preferredColorScheme(.dark)
}
#endif
