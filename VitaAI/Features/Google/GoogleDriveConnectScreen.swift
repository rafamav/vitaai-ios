import SwiftUI

// MARK: - GoogleDriveConnectScreen
// Android parity: GoogleDriveConnectScreen (OAuth-based Google Drive integration)

struct GoogleDriveConnectScreen: View {
    var onBack: () -> Void

    @Environment(\.appContainer) private var container
    @State private var viewModel: GoogleDriveConnectViewModel?
    @State private var toastState = VitaToastState()

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            // Ambient glow
            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.08)
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
                let vm = GoogleDriveConnectViewModel(api: container.api)
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
    private func mainContent(vm: GoogleDriveConnectViewModel) -> some View {
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

            Text("Google Drive")
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

    private func statusCard(state: GoogleDriveConnectViewState) -> some View {
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

                    Image(systemName: state.isConnected ? "externaldrive.fill.badge.checkmark" : "externaldrive.badge.xmark")
                        .font(.system(size: 22))
                        .foregroundColor(
                            state.isConnected ? VitaColors.dataGreen : VitaColors.textSecondary
                        )
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(state.isConnected ? "Google Drive Conectado" : "Google Drive Desconectado")
                        .font(VitaTypography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(VitaColors.textPrimary)

                    if let email = state.googleEmail {
                        Text(email)
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.textSecondary)
                    }

                    if state.isConnected {
                        Text("\(state.fileCount) arquivo(s) importado(s)")
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
    private func connectedSection(vm: GoogleDriveConnectViewModel) -> some View {
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
            text: vm.state.isDisconnecting ? "Desconectando..." : "Desconectar Drive",
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
                Text("Conectar Google Drive")
                    .font(VitaTypography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(VitaColors.textPrimary)

                Text("Importe PDFs, slides e materiais do seu Google Drive diretamente para o VitaAI.")
                    .font(VitaTypography.bodySmall)
                    .foregroundColor(VitaColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer().frame(height: 4)

                infoRow("PDFs e slides importados automaticamente")
                infoRow("Arquivos processados para gerar flashcards com IA")
                infoRow("Sincronizacao periodica mantém materiais atualizados")

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

                infoRow("PDFs e slides importados do seu Drive")
                infoRow("Conteudo processado para gerar flashcards")
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
