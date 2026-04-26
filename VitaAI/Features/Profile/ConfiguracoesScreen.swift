import SwiftUI
import Sentry

// MARK: - ConfiguracoesScreen
// Matches configurações-mobile-v1.html mockup exactly.
// Sections: User Card, Conta, Preferencias, Seguranca, Privacidade & Dados, Logout.
// Pushed via NavigationStack from ProfileScreen gear icon / edit button.

struct ConfiguracoesScreen: View {
    let authManager: AuthManager

    var onNavigateToPerfil:           (() -> Void)?
    var onNavigateToAppearance:       (() -> Void)?
    var onNavigateToNotifications:    (() -> Void)?
    var onNavigateToConnections:      (() -> Void)?
    var onNavigateToAbout:            (() -> Void)?
    var onNavigateToAssinatura:       (() -> Void)?
    var onNavigateToDisciplinas:      (() -> Void)?
    var onNavigateToPrivacyDocuments: (() -> Void)?
    var onNavigateToPrivacySettings:  (() -> Void)?
    var onNavigateToExportData:       (() -> Void)?
    var onNavigateToFeedback:         (() -> Void)?
    var onNavigateToFocusSession:     (() -> Void)?
    var onNavigateToReferral:         (() -> Void)?
    var onBack:                       (() -> Void)?

    // Sons + vibração persistem em UserDefaults via SoundManager/HapticManager.
    // @AppStorage espelha a chave pra UI atualizar instantâneo no toggle.
    @AppStorage("vita_sound_enabled")  private var soundEnabled: Bool = true
    @AppStorage("vita_haptic_enabled") private var hapticEnabled: Bool = true

    private let logoutColor = Color(red: 1.0, green: 0.47, blue: 0.31)

    private var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "VitaAI v\(version) (\(build))"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: - Header
                headerBar
                    .padding(.top, 8)

                // MARK: - User Card
                userCard
                    .padding(.top, 12)

                // MARK: - Conta — Shell §5.2.6 + §5.2.14 (Vita extras)
                settingsSectionLabel("Conta")
                VitaGlassCard {
                    VStack(spacing: 0) {
                        settingsRow(
                            icon: "book",
                            label: "Disciplinas",
                            desc: "Gerenciar disciplinas e dificuldade",
                            action: { onNavigateToDisciplinas?() }
                        )
                        rowDivider
                        settingsRow(
                            icon: "link",
                            label: "Conectores",
                            desc: "Portais da faculdade (351+ suportados)",
                            action: { onNavigateToConnections?() }
                        )
                        rowDivider
                        settingsRow(
                            icon: "star",
                            label: "Assinatura",
                            desc: "Vita Pro / Premium",
                            action: { onNavigateToAssinatura?() }
                        )
                        rowDivider
                        settingsRow(
                            icon: "gift",
                            label: "Convide amigos",
                            desc: "Ganhe 7 dias Pro grátis por amigo",
                            action: { onNavigateToReferral?() }
                        )
                    }
                }
                .padding(.horizontal, 14)

                // MARK: - Preferências — Shell §5.2.6
                settingsSectionLabel("Preferencias")
                VitaGlassCard {
                    VStack(spacing: 0) {
                        settingsRow(
                            icon: "bell",
                            label: "Notificações",
                            desc: "Push, email, lembretes de estudo",
                            action: { onNavigateToNotifications?() }
                        )
                        rowDivider
                        settingsRow(
                            icon: "paintbrush",
                            label: "Aparência",
                            desc: "Tema e visual do app",
                            action: { onNavigateToAppearance?() }
                        )
                        rowDivider
                        settingsRow(
                            icon: "hourglass",
                            label: "Modo foco",
                            desc: "Pomodoro com penalidade XP por sair do app",
                            action: { onNavigateToFocusSession?() }
                        )
                        rowDivider
                        toggleRow(
                            icon: "speaker.wave.2",
                            label: "Efeitos sonoros",
                            desc: "Tap, acerto/erro, conquistas",
                            isOn: $soundEnabled
                        )
                        rowDivider
                        toggleRow(
                            icon: "iphone.radiowaves.left.and.right",
                            label: "Vibração",
                            desc: "Feedback tátil em interações",
                            isOn: $hapticEnabled
                        )
                    }
                }
                .padding(.horizontal, 14)

                // MARK: - Privacidade & Segurança — Shell §5.2.6 + §5.2.8
                // "Excluir conta" foi MOVIDA pro Profile (Rafael 2026-04-25, padrão Duolingo).
                // ActiveSessions pendente de endpoint backend (delegate NOVA).
                settingsSectionLabel("Privacidade & Segurança")
                VitaGlassCard {
                    VStack(spacing: 0) {
                        settingsRow(
                            icon: "switch.2",
                            label: "Configurações de privacidade",
                            desc: "Localização, perfil público, ranking, telemetria",
                            action: { onNavigateToPrivacySettings?() }
                        )
                        rowDivider
                        settingsRow(
                            icon: "lock.shield",
                            label: "Privacidade de documentos",
                            desc: "O que coletamos, onde processamos, retenção",
                            action: { onNavigateToPrivacyDocuments?() }
                        )
                        rowDivider
                        settingsRow(
                            icon: "square.and.arrow.down",
                            label: "Exportar meus dados",
                            desc: "Baixar tudo (LGPD art. 18 V)",
                            action: { onNavigateToExportData?() }
                        )
                    }
                }
                .padding(.horizontal, 14)

                // MARK: - Suporte — Shell §5.2.6 + §5.2.10
                settingsSectionLabel("Suporte")
                VitaGlassCard {
                    VStack(spacing: 0) {
                        settingsRow(
                            icon: "ellipsis.message",
                            label: "Feedback",
                            desc: "Bug, sugestão, elogio — vai direto pra equipe",
                            action: { onNavigateToFeedback?() }
                        )
                        rowDivider
                        settingsRow(
                            icon: "info.circle",
                            label: "Sobre",
                            desc: appVersionString,
                            action: { onNavigateToAbout?() }
                        )
                    }
                }
                .padding(.horizontal, 14)

                // MARK: - Logout Button
                logoutButton
                    .padding(.horizontal, 14)
                    .padding(.top, 18)

                // Shell §5.2.7: versão lida de Bundle, NUNCA hardcoded.
                Text(appVersionString)
                    .font(.system(size: 10))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.18))
                    .padding(.top, 14)

                Spacer().frame(height: 120)
            }
        }
        .background(Color.clear)
        .onAppear { SentrySDK.reportFullyDisplayed() }
        .trackScreen("Configuracoes")
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 10) {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.75))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("backButton")

                Text("Configurações")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
            }

            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(VitaColors.textWarm.opacity(0.40))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - User Card

    private var userCard: some View {
        Button(action: { onNavigateToPerfil?() }) {
            VitaGlassCard {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        VitaColors.accent.opacity(0.30),
                                        VitaColors.accentDark.opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().stroke(VitaColors.accentHover.opacity(0.14), lineWidth: 1)
                            )
                        Text(String((authManager.userName ?? "R").prefix(2)).uppercased())
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.75))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(authManager.userName ?? "Estudante")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))
                        Text(authManager.userEmail ?? "")
                            .font(.system(size: 10.5))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.20))
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
    }

    // MARK: - Settings Row

    private func settingsRow(icon: String, label: String, desc: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon container 34x34 rounded rect with gold gradient
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    VitaColors.accentHover.opacity(0.18),
                                    VitaColors.accentDark.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(VitaColors.accentHover.opacity(0.12), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.80))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.88))
                    Text(desc)
                        .font(.system(size: 10.5))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.20))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section Label

    private func settingsSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(VitaColors.textWarm.opacity(0.35))
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(VitaColors.textWarm.opacity(0.04))
            .frame(height: 1)
    }

    /// Linha com label + descrição + Toggle nativo. Persiste @AppStorage,
    /// dispara haptic ao mudar (se haptic habilitado).
    private func toggleRow(icon: String, label: String, desc: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                VitaColors.accentHover.opacity(0.18),
                                VitaColors.accentDark.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(VitaColors.accentHover.opacity(0.12), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.80))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                Text(desc)
                    .font(.system(size: 10.5))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(VitaColors.accent)
                .onChange(of: isOn.wrappedValue) { _, _ in
                    HapticManager.shared.fire(.light)
                }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    // MARK: - Logout Button

    private var logoutButton: some View {
        Button(action: { authManager.logout() }) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .medium))
                Text("Sair da conta")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(logoutColor.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(logoutColor.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(logoutColor.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

