import SwiftUI

// MARK: - CanvasConnectScreen

struct CanvasConnectScreen: View {
    var onBack: () -> Void

    @Environment(\.appContainer) private var container
    @State private var viewModel: CanvasConnectViewModel?
    @State private var toastState = VitaToastState()
    @State private var cookiesCaptured = false

    var body: some View {
        ZStack {
            VitaScreenBg()

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
        .onChange(of: viewModel?.state.error) { err in
            if let err {
                toastState.show(err, type: .error)
                viewModel?.dismissMessages()
            }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func mainContent(vm: CanvasConnectViewModel) -> some View {
        VStack(spacing: 0) {
            navBar

            if vm.state.isLoading {
                Spacer()
                ProgressView()
                    .tint(VitaColors.accent)
                    .scaleEffect(1.2)
                Spacer()
            } else if vm.state.isConnected {
                ScrollView {
                    VStack(spacing: 16) {
                        statusCard(state: vm.state)
                        connectedSection(vm: vm)
                    }
                    .padding(20)
                }
            } else if vm.state.isSyncing || cookiesCaptured {
                syncingView(vm: vm)
            } else {
                webViewLogin(vm: vm)
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

            Color.clear
                .frame(width: 70, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // MARK: - WebView login

    @ViewBuilder
    private func webViewLogin(vm: CanvasConnectViewModel) -> some View {
        VStack(spacing: 12) {
            VitaGlassCard {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                        .foregroundColor(VitaColors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Faça login no Canvas")
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
                    Text(vm.state.instanceUrl.replacingOccurrences(of: "https://", with: ""))
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
                    portalURL: vm.state.instanceUrl.replacingOccurrences(of: "https://", with: ""),
                    onSessionCaptured: { cookie in
                        cookiesCaptured = true
                        vm.syncWithWebView(cookies: cookie, instanceUrl: vm.state.instanceUrl)
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

    // MARK: - Syncing view (Vita mascot + granular progress)

    @ViewBuilder
    private func syncingView(vm: CanvasConnectViewModel) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VitaMascot(state: .thinking, size: 100, showStaff: true)
                .padding(.bottom, 24)

            Text(vm.state.successMessage ?? "Vita conectando ao Canvas...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(VitaColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .animation(.easeInOut(duration: 0.3), value: vm.state.successMessage)

            // Progress bar
            if vm.state.isSyncing {
                ProgressView(value: vm.state.syncPercent, total: 100)
                    .tint(VitaColors.accent)
                    .padding(.horizontal, 48)
                    .padding(.top, 16)
                    .animation(.easeInOut(duration: 0.5), value: vm.state.syncPercent)
            }

            // Sync steps
            VStack(alignment: .leading, spacing: 12) {
                let phase = vm.state.syncPhase
                syncStepRow("Login detectado", done: true)
                syncStepRow("Buscando disciplinas",
                            done: phase.isAfter(.fetchingCourses),
                            active: phase == .fetchingCourses)
                syncStepRow("Buscando atividades e arquivos",
                            done: phase.isAfter(.fetchingData),
                            active: phase == .fetchingData)
                syncStepRow("Identificando planos de ensino",
                            done: phase.isAfter(.filteringPDFs),
                            active: phase == .filteringPDFs)
                syncStepRow("Baixando planos de ensino",
                            done: phase.isAfter(.downloadingPDFs),
                            active: phase == .downloadingPDFs)
                syncStepRow("Enviando para Vita processar",
                            done: phase.isAfter(.uploading),
                            active: phase == .uploading)
                syncStepRow("Extração completa",
                            done: phase == .done)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
            )
            .padding(.horizontal, 32)
            .padding(.top, 24)

            // Retry button when sync failed
            if !vm.state.isSyncing && cookiesCaptured {
                VStack(spacing: 12) {
                    if let error = vm.state.error {
                        Text(error)
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }

                    VitaButton(
                        text: "Tentar Novamente",
                        action: {
                            cookiesCaptured = false
                        },
                        variant: .primary,
                        size: .lg,
                        isEnabled: true,
                        leadingSystemImage: "arrow.clockwise"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                }
                .padding(.top, 20)
            }

            Spacer()
        }
        .padding(.bottom, 100) // Clear bottom nav bar
    }

    private func syncStepRow(_ text: String, done: Bool = false, active: Bool = false) -> some View {
        HStack(spacing: 10) {
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color.green)
            } else if active {
                ProgressView()
                    .tint(VitaColors.accent)
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            } else {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
            }

            Text(text)
                .font(.system(size: 13, weight: done || active ? .medium : .regular))
                .foregroundColor(done ? .white.opacity(0.7) : active ? .white.opacity(0.9) : .white.opacity(0.3))
        }
    }

    // MARK: - Status card

    private func statusCard(state: CanvasConnectViewState) -> some View {
        VitaGlassCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(VitaColors.dataGreen.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 22))
                        .foregroundColor(VitaColors.dataGreen)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Canvas Conectado")
                        .font(VitaTypography.titleSmall)
                        .fontWeight(.semibold)
                        .foregroundColor(VitaColors.textPrimary)

                    if !state.instanceUrl.isEmpty {
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
        VitaButton(
            text: "Sincronizar Agora",
            action: { vm.syncNow() },
            variant: .primary,
            size: .lg,
            isEnabled: true,
            leadingSystemImage: "arrow.clockwise"
        )
        .frame(maxWidth: .infinity)

        howItWorksCard

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

                infoRow("Disciplinas, arquivos e atividades importados")
                infoRow("Planos de ensino processados pela IA Vita")
                infoRow("Eventos do calendário na sua agenda")
                infoRow("Sincronize quando quiser dados atualizados")
            }
            .padding(16)
        }
    }

    // MARK: - Helpers

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

    private func formatSyncDate(_ raw: String) -> String {
        let prefix = String(raw.prefix(16))
        return prefix.replacingOccurrences(of: "T", with: " ")
    }
}

// MARK: - Phase ordering helper

extension CanvasSyncOrchestrator.Phase {
    private var order: Int {
        switch self {
        case .starting: return 0
        case .fetchingCourses: return 1
        case .fetchingData: return 2
        case .filteringPDFs: return 3
        case .downloadingPDFs: return 4
        case .uploading: return 5
        case .done: return 6
        case .error: return -1
        }
    }

    func isAfter(_ other: CanvasSyncOrchestrator.Phase) -> Bool {
        order > other.order
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
