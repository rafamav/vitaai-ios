import SwiftUI

// MARK: - VitaMenuPopout
// Glass popout overlay matching mockup .menu-popout CSS
// width: 220px, absolute positioned top-right, gold glassmorphism

struct VitaMenuPopout: View {
    let userName: String?
    let userImageURL: URL?
    let onProfile: () -> Void
    let onNotifications: () -> Void
    let onAgenda: () -> Void
    let onConfiguracoes: () -> Void
    let onAppearance: () -> Void
    let onConnections: () -> Void
    let onPaywall: () -> Void
    let onLogout: () -> Void
    let onDismiss: () -> Void

    @State private var showLogoutConfirm = false
    @State private var isVisible = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Tap-outside dismiss scrim
            Color.black.opacity(0.001)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            popoutContent
                .padding(.trailing, 16)
                .padding(.top, 8)
                .scaleEffect(isVisible ? 1 : 0.85, anchor: .topTrailing)
                .opacity(isVisible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(duration: 0.2, bounce: 0.15)) {
                isVisible = true
            }
        }
        .alert("Sair da conta?", isPresented: $showLogoutConfirm) {
            Button("Cancelar", role: .cancel) {}
            Button("Sair", role: .destructive) {
                dismiss()
                onLogout()
            }
        } message: {
            Text("Você será desconectado do VitaAI.")
        }
    }

    // MARK: - Popout Content

    private var popoutContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Avatar header
            Button(action: { dismiss(); onProfile() }) {
                HStack(spacing: 10) {
                    avatarCircle
                    VStack(alignment: .leading, spacing: 1) {
                        Text(userName ?? "Estudante")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.90))
                            .lineLimit(1)
                        Text("Ver perfil")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.accentHover.opacity(0.50))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menu_ver_perfil")

            menuDivider

            // Navigation items
            // "Perfil" intentionally omitted — the avatar header above already
            // taps into onProfile() and the "Ver perfil" subtitle makes it
            // clear. Having it twice was redundant (Rafael, 2026-04-22).
            menuItem(icon: "bell", label: "Notificações", identifier: "menu_notificacoes") {
                dismiss(); onNotifications()
            }
            menuItem(icon: "calendar", label: "Agenda", identifier: "menu_agenda") {
                dismiss(); onAgenda()
            }

            menuDivider

            menuItem(icon: "gearshape", label: "Configurações", identifier: "menu_config") {
                dismiss(); onConfiguracoes()
            }
            menuItem(icon: "square.3.layers.3d", label: "Conectores", identifier: "menu_conectores") {
                dismiss(); onConnections()
            }
            menuItem(icon: "creditcard", label: "Assinatura", identifier: "menu_assinatura") {
                dismiss(); onPaywall()
            }

            menuDivider

            // Logout — red
            Button(action: { showLogoutConfirm = true }) {

                HStack(spacing: 10) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                        .frame(width: 20, alignment: .center)
                    Text("Sair")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(Color(red: 1.0, green: 0.47, blue: 0.31).opacity(0.65))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menu_sair")

            Spacer().frame(height: 8)
        }
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.055, green: 0.043, blue: 0.035).opacity(0.97),
                            Color(red: 0.039, green: 0.031, blue: 0.024).opacity(0.98)
                        ],
                        startPoint: .init(x: 0.5, y: 0),
                        endPoint: .init(x: 0.48, y: 1)
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(VitaColors.accentHover.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 16)
                .shadow(color: VitaColors.accent.opacity(0.06), radius: 10, x: 0, y: 0)
        )
    }

    // MARK: - Components

    private var avatarCircle: some View {
        Group {
            if let url = userImageURL {
                CachedAsyncImage(url: url) {
                    avatarInitials
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            } else {
                avatarInitials
            }
        }
    }

    private var avatarInitials: some View {
        Text(userName?.prefix(1).uppercased() ?? "R")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(VitaColors.accentLight.opacity(0.80))
            .frame(width: 40, height: 40)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [VitaColors.accent.opacity(0.35), VitaColors.accentDark.opacity(0.25)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            )
            .clipShape(Circle())
    }

    private func menuItem(icon: String, label: String, identifier: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.55))
                    .frame(width: 20, alignment: .center)
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.80))
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? "")
    }

    private var menuDivider: some View {
        Rectangle()
            .fill(VitaColors.accentLight.opacity(0.05))
            .frame(height: 1)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
    }

    // MARK: - Helpers

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onDismiss()
        }
    }
}
