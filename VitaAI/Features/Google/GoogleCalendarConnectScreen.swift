import SwiftUI

// MARK: - GoogleCalendarConnectScreen

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
                let center = CGPoint(x: size.width * 0.85, y: size.height * 0.08)
                let gradient = Gradient(colors: [Color(red: 0.25, green: 0.65, blue: 0.35).opacity(0.08), .clear])
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
                let vm = GoogleCalendarConnectViewModel(api: container.api)
                viewModel = vm
                vm.onAppear()
            }
        }
        // Recarrega status ao voltar do Safari
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            guard let vm = viewModel else { return }
            Task { await vm.loadStatus() }
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

                    if let email = state.googleEmail, !email.isEmpty {
                        Text(email)
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.textSecondary)
                    }

                    if state.isConnected && state.eventCount > 0 {
                        Text("\(state.eventCount) evento(s) sincronizado(s)")
                            .font(VitaTypography.labelSmall)
                            .foregroundColor(VitaColors.textTertiary)
                    }

                    if let syncAt = state.lastSyncAt {
                        Text("Ultima sinc: \(formatSyncDate(syncAt))")
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
            text: vm.state.isDisconnecting ? "Desconectando..." : "Desconectar Google Calendar",
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
        VStack(spacing: 16) {
            VitaGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Conectar Google Calendar")
                        .font(VitaTypography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(VitaColors.textPrimary)

                    Text(
                        "Ao conectar, voce sera redirecionado ao Google para autorizar o acesso. " +
                        "Seus eventos serao importados automaticamente apos a autorizacao."
                    )
                    .font(VitaTypography.bodySmall)
                    .foregroundColor(VitaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
            }

            howItWorksCard

            VitaButton(
                text: "Conectar com Google",
                action: { openOAuth() },
                variant: .primary,
                size: .lg,
                leadingSystemImage: "arrow.up.right.square"
            )
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - How it works card

    private var howItWorksCard: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Como funciona")
                    .font(VitaTypography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(VitaColors.textPrimary)

                infoRow("Eventos e compromissos sao importados do seu Google Calendar")
                infoRow("Provas e deadlines aparecem na sua Agenda no VitaAI")
                infoRow("A sincronizacao e segura via OAuth — sem armazenar sua senha")
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

    // MARK: - OAuth

    private func openOAuth() {
        // authBaseURL = "https://vita-ai.cloud" (sem /api) — o endpoint /api/google/calendar/authorize
        // e uma rota web que redireciona ao Google, entao usamos apiBaseURL diretamente
        guard let url = URL(string: "\(AppConfig.apiBaseURL)/google/calendar/authorize") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Helpers

    private func formatSyncDate(_ raw: String) -> String {
        let prefix = String(raw.prefix(16))
        return prefix.replacingOccurrences(of: "T", with: " ")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("GoogleCalendarConnectScreen") {
    NavigationStack {
        GoogleCalendarConnectScreen(onBack: {})
    }
    .preferredColorScheme(.dark)
}
#endif
