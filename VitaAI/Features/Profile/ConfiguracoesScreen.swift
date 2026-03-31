import SwiftUI

// MARK: - ConfiguracoesScreen
// Matches configuracoes-mobile-v1.html mockup exactly.
// Sections: User Card, Conta, Preferencias, Seguranca, Privacidade & Dados, Logout.
// Portuguese accents: Configuracoes->Configurações, Preferencias->Preferências, etc.

struct ConfiguracoesScreen: View {
    let authManager: AuthManager

    var onNavigateToPerfil:        (() -> Void)?
    var onNavigateToAppearance:    (() -> Void)?
    var onNavigateToNotifications: (() -> Void)?
    var onNavigateToConnections:   (() -> Void)?
    var onNavigateToAbout:         (() -> Void)?
    var onNavigateToAssinatura:    (() -> Void)?
    var onBack:                    (() -> Void)?

    @State private var aiConsent: Bool = true

    // Gold mockup colors
    private let goldText = VitaColors.accentLight       // → VitaColors.accentLight
    private let goldBorder = VitaColors.accentHover     // → VitaColors.accentHover
    private let subtleText = VitaColors.textWarm
    private let logoutColor = Color(red: 1.0, green: 0.47, blue: 0.31) // rgba(255,120,80)
    private let greenToggle = Color(red: 0.51, green: 0.78, blue: 0.55) // rgba(130,200,140)

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: - Header
                headerBar
                    .padding(.top, 8)


                // MARK: - User Card
                userCard
                    .padding(.top, 12)

                // MARK: - Conta
                settingsSectionLabel("Conta")
                VitaGlassCard {
                    VStack(spacing: 0) {
                        settingsRow(
                            icon: "person",
                            label: "Perfil",
                            desc: "\(authManager.userName ?? "Estudante") - \(authManager.userEmail ?? "")",
                            action: { onNavigateToPerfil?() }
                        )
                        settingsDivider
                        settingsRow(
                            icon: "book",
                            label: "Disciplinas",
                            desc: "Gerenciar disciplinas ativas",
                            action: { }
                        )
                    }
                }
                .padding(.horizontal, 14)

                // MARK: - Preferências
                settingsSectionLabel("Preferências")
                VitaGlassCard {
                    VStack(spacing: 0) {
                        settingsRow(
                            icon: "sun.max",
                            label: "Aparência",
                            desc: "Tema, cores, tamanho de fonte",
                            action: { onNavigateToAppearance?() }
                        )
                        settingsDivider
                        settingsRow(
                            icon: "bell",
                            label: "Notificações",
                            desc: "Push, email, lembretes de estudo",
                            action: { onNavigateToNotifications?() }
                        )
                        settingsDivider
                        settingsRow(
                            icon: "globe",
                            label: "Idioma",
                            desc: "Português (BR)",
                            action: { }
                        )
                    }
                }
                .padding(.horizontal, 14)

                // MARK: - Segurança
                settingsSectionLabel("Segurança")
                VitaGlassCard {
                    VStack(spacing: 0) {
                        settingsRow(
                            icon: "shield",
                            label: "Privacidade",
                            desc: "Política de privacidade e dados",
                            action: { }
                        )
                        settingsDivider
                        settingsRow(
                            icon: "info.circle",
                            label: "Sobre",
                            desc: "VitaAI v1.0",
                            action: { onNavigateToAbout?() }
                        )
                    }
                }
                .padding(.horizontal, 14)

                // MARK: - Privacidade & Dados
                settingsSectionLabel("Privacidade & Dados")
                VitaGlassCard {
                    VStack(spacing: 0) {
                        // AI Consent with toggle
                        aiConsentRow
                        settingsDivider
                        settingsRow(
                            icon: "circle.grid.2x2",
                            label: "Gerenciar cookies",
                            desc: "Redefinir preferências de cookies",
                            action: { }
                        )
                    }
                }
                .padding(.horizontal, 14)

                // MARK: - Logout Button
                logoutButton
                    .padding(.horizontal, 14)
                    .padding(.top, 18)

                // Version
                Text("VitaAI v1.0.0 - Build 2026.03")
                    .font(.system(size: 10))
                    .foregroundStyle(subtleText.opacity(0.18))
                    .padding(.top, 14)

                Spacer().frame(height: 120)
            }
        }
        .vitaScreenBg()
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 10) {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(subtleText.opacity(0.75))
                }
                .buttonStyle(.plain)

                Text("Configurações")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
            }

            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(subtleText.opacity(0.40))
        }
        .padding(.horizontal, 20)
    }

    // MARK: - User Card

    private var userCard: some View {
        Button(action: { onNavigateToPerfil?() }) {
            VitaGlassCard {
                HStack(spacing: 12) {
                    // Avatar circle
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.78, green: 0.63, blue: 0.31).opacity(0.30),
                                        Color(red: 0.63, green: 0.47, blue: 0.24).opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle().stroke(goldBorder.opacity(0.14), lineWidth: 1)
                            )
                        Text(String((authManager.userName ?? "R").prefix(2)).uppercased())
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(subtleText.opacity(0.75))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(authManager.userName ?? "Estudante")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.88))
                        Text(authManager.userEmail ?? "")
                            .font(.system(size: 10.5))
                            .foregroundStyle(subtleText.opacity(0.35))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(subtleText.opacity(0.20))
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
                // Icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    VitaColors.accentHover.opacity(0.18),
                                    Color(red: 0.55, green: 0.39, blue: 0.18).opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(goldBorder.opacity(0.12), lineWidth: 1)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(goldText.opacity(0.80))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.88))
                    Text(desc)
                        .font(.system(size: 10.5))
                        .foregroundStyle(subtleText.opacity(0.35))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(subtleText.opacity(0.20))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - AI Consent Row (with toggle)

    private var aiConsentRow: some View {
        HStack(spacing: 12) {
            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                VitaColors.accentHover.opacity(0.18),
                                Color(red: 0.55, green: 0.39, blue: 0.18).opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(goldBorder.opacity(0.12), lineWidth: 1)
                    )
                Image(systemName: "message")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(goldText.opacity(0.80))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Consentimento IA")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                Text(aiConsent ? "Concedido" : "Negado")
                    .font(.system(size: 10.5))
                    .foregroundStyle(aiConsent ? greenToggle.opacity(0.65) : subtleText.opacity(0.35))
            }

            Spacer()

            // Custom toggle matching mockup
            Toggle("", isOn: $aiConsent)
                .toggleStyle(GoldToggleStyle())
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    // MARK: - Section Label

    private func settingsSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(subtleText.opacity(0.35))
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }

    // MARK: - Divider

    private var settingsDivider: some View {
        Rectangle()
            .fill(subtleText.opacity(0.04))
            .frame(height: 1)
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

// MARK: - Gold Toggle Style (matches mockup)

private struct GoldToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(
                        configuration.isOn
                            ? VitaColors.accent.opacity(0.25)
                            : Color.white.opacity(0.08)
                    )
                    .frame(width: 44, height: 24)
                    .overlay(
                        Capsule().stroke(
                            configuration.isOn
                                ? VitaColors.accentHover.opacity(0.25)
                                : VitaColors.textTertiary.opacity(0.08),
                            lineWidth: 1
                        )
                    )

                Circle()
                    .fill(
                        configuration.isOn
                            ? VitaColors.accentLight.opacity(0.90)
                            : VitaColors.sectionLabel.opacity(0.50)
                    )
                    .frame(width: 18, height: 18)
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                    .padding(3)
            }
            .animation(.easeInOut(duration: 0.2), value: configuration.isOn)
        }
        .buttonStyle(.plain)
    }
}
