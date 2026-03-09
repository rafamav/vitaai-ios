import SwiftUI

// MARK: - GoogleCalendarConnectScreen
// Android parity: GoogleCalendarConnectScreen (OAuth-based Google Calendar integration)

struct GoogleCalendarConnectScreen: View {
    var onBack: () -> Void

    @Environment(\.appContainer) private var container
    @State private var viewModel: GoogleCalendarConnectViewModel?
    @State private var toastState = VitaToastState()

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            // Ambient glow
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.85, y: size.height * 0.1)
                let gradient = Gradient(colors: [VitaColors.accent.opacity(0.07), .clear])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center.x - size.width * 0.5,
                            y: center.y - size.width * 0.5,
                            width: size.width,
                            height: size.width
                        )),
                        with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: size.width * 0.5)
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
                let vm = GoogleCalendarConnectViewModel(api: container.api)
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
    }

    // MARK: - Main content

    @ViewBuilder
    private func mainContent(vm: GoogleCalendarConnectViewModel) -> some View {
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
                            disconnectedSection
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

            Text("Google Calendar")
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

    private func statusCard(state: GoogleCalendarConnectViewState) -> some View {
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

                    Image(systemName: state.isConnected ? "calendar.badge.checkmark" : "calendar.badge.exclamationmark")
                        .font(.system(size: 22))
                        .foregroundColor(
                            state.isConnected ? VitaColors.dataGreen : VitaColors.textSecondary
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.isConnected ? "Google Calendar Conectado" : "Google Calendar Desconectado")
                        .font(VitaTypography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(VitaColors.textPrimary)

                    if let email = state.googleEmail {
                        Text(email)
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.textSecondary)
                    }

                    if state.isConnected {
                        Text("\(state.eventCount) evento(s) sincronizado(s)")
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
    private func connectedSection(vm: GoogleCalendarConnectViewModel) -> some View {
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

        howItWorksCard

        VitaButton(
            text: vm.state.isDisconnecting ? "Desconectando..." : "Desconectar Calendar",
            action: { vm.disconnect() },
            variant: .danger,
            size: .lg,
            isEnabled: !vm.state.isDisconnecting,
            isLoading: vm.state.isDisconnecting
        )
        .frame(maxWidth: .infinity)
    }

    // MARK: - Disconnected section

    private var disconnectedSection: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Conectar Google Calendar")
                    .font(VitaTypography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(VitaColors.textPrimary)

                Text("Sincronize suas provas, aulas e compromissos diretamente do Google Calendar.")
                    .font(VitaTypography.bodySmall)
                    .foregroundColor(VitaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 4)

                infoRow("Provas e eventos importados automaticamente")
                infoRow("Compromissos aparecem na sua agenda VitaAI")
                infoRow("Sincronizacao automatica periodica")

                Spacer().frame(height: 8)

                Text("A conexao OAuth sera configurada em breve.")
                    .font(VitaTypography.labelSmall)
                    .foregroundColor(VitaColors.textTertiary)
                    .italic()
            }
            .padding(16)
        }
    }

    private var howItWorksCard: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Como funciona")
                    .font(VitaTypography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(VitaColors.textPrimary)

                infoRow("Eventos e provas sao importados do Calendar")
                infoRow("Compromissos aparecem na sua agenda VitaAI")
                infoRow("Sincronize sempre que quiser dados atualizados")
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
}
