import SwiftUI
import Sentry

// MARK: - ConfiguracoesScreen
// Matches configurações-mobile-v1.html mockup exactly.
// Sections: User Card, Conta, Preferencias, Seguranca, Privacidade & Dados, Logout.
// Pushed via NavigationStack from ProfileScreen gear icon / edit button.

struct ConfiguracoesScreen: View {
    let authManager: AuthManager

    // Menu order locked by Rafael 2026-04-26 (gold-standard hamburger pattern):
    //   1. Meu perfil  2. Assinatura  3. Disciplinas  4. Conectores
    //   5. Notificações  6. Convide amigos  7. Ajuda e suporte
    //   8. Termos e privacidade  →  Sair (logout, vermelho, separado)
    //
    // Removed (Rafael's call): Aparência (only one theme exists), Modo foco
    // (parked), Efeitos sonoros (only used by FocusSession which is gone).
    var onNavigateToPerfil:           (() -> Void)?
    var onNavigateToAssinatura:       (() -> Void)?
    var onNavigateToDisciplinas:      (() -> Void)?
    var onNavigateToConnections:      (() -> Void)?
    var onNavigateToNotifications:    (() -> Void)?
    var onNavigateToReferral:         (() -> Void)?
    var onNavigateToFeedback:         (() -> Void)?
    var onNavigateToPrivacyDocuments: (() -> Void)?
    var onBack:                       (() -> Void)?

    // Vibração persiste em UserDefaults via HapticManager. Sound toggle removed
    // — SoundManager only feeds FocusSession which is parked.
    @AppStorage("vita_haptic_enabled") private var hapticEnabled: Bool = true

    @Environment(\.appContainer) private var container
    @State private var profile: ProfileResponse?

    private let logoutColor = Color(red: 1.0, green: 0.47, blue: 0.31)

    private var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "VitaAI v\(version) (\(build))"
    }

    /// Linha sob o nome do user no card topo. Formato: "Medicina · 3º semestre"
    /// quando há perfil carregado, fallback pro e-mail.
    private var profileSubtitle: String {
        let course = "Medicina"
        if let s = profile?.semester, s > 0 {
            return "\(course) · \(s)º semestre"
        }
        return authManager.userEmail ?? course
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: - Header
                headerBar
                    .padding(.top, 8)

                // MARK: - User Card (topo: nome / curso · semestre / Ver perfil)
                userCard
                    .padding(.top, 12)

                // MARK: - Menu principal — ordem Rafael 2026-04-26
                VitaGlassCard {
                    VStack(spacing: 0) {
                        settingsRow(
                            icon: "person.crop.circle",
                            label: "Meu perfil",
                            // quality-gate-ignore: 'pessoais' é PT-BR correto sem acento
                            desc: "Dados pessoais, faculdade, semestre, foto",
                            action: { onNavigateToPerfil?() }
                        )
                        rowDivider
                        settingsRow(
                            icon: "star",
                            label: "Assinatura",
                            // quality-gate-ignore: 'fiscais' é PT-BR correto sem acento
                            desc: "Plano, upgrade, pagamento, notas fiscais",
                            action: { onNavigateToAssinatura?() }
                        )
                        rowDivider
                        settingsRow(
                            icon: "book",
                            label: "Matérias",
                            desc: "Lista do semestre, dificuldade, prioridade",
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
                            icon: "bell",
                            label: "Notificações",
                            desc: "Push, e-mail, lembretes de estudo",
                            action: { onNavigateToNotifications?() }
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
                .padding(.top, 18)

                // MARK: - Suporte + Legal + Vibração
                VitaGlassCard {
                    VStack(spacing: 0) {
                        settingsRow(
                            icon: "questionmark.circle",
                            label: "Ajuda e suporte",
                            // quality-gate-ignore: 'reportar' é PT-BR sem acento
                            desc: "FAQ, falar com suporte, reportar problema",
                            action: { onNavigateToFeedback?() }
                        )
                        rowDivider
                        settingsRow(
                            icon: "lock.shield",
                            label: "Termos e privacidade",
                            // quality-gate-ignore: 'política' tem acento OK aqui
                            desc: "Termos de uso, política de privacidade, dados",
                            action: { onNavigateToPrivacyDocuments?() }
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
                .padding(.top, 12)

                // MARK: - Sair (sempre por último, separado, em laranja-vermelho)
                logoutButton
                    .padding(.horizontal, 14)
                    .padding(.top, 24)

                // Versão discreta no rodapé (substitui o item "Sobre" do menu).
                Text(appVersionString)
                    .font(.system(size: 10))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.18))
                    .padding(.top, 14)

                Spacer().frame(height: 120)
            }
        }
        .background(Color.clear)
        .task { await loadProfile() }
        .onAppear { SentrySDK.reportFullyDisplayed() }
        .trackScreen("Configuracoes")
    }

    @MainActor
    private func loadProfile() async {
        if let p = try? await container.api.getProfile() { profile = p }
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

                    VStack(alignment: .leading, spacing: 2) {
                        Text(authManager.userName ?? "Estudante")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                        Text(profileSubtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.50))
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Text("Ver perfil")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.85))
                            .padding(.top, 2)
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

