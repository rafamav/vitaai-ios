import SwiftUI

// MARK: - VitaNotifPopout
// Glass notification popout matching mockup .notif-popout CSS
// width: 300px, max-height: 400px, gold glassmorphism

struct VitaNotifPopout: View {
    let onDismiss: () -> Void
    let onMarkAllRead: () -> Void
    let onSettingsTap: () -> Void

    @State private var notifications: [NotifItem] = NotifItem.mockItems
    @State private var isVisible = false

    private var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

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
    }

    // MARK: - Popout Content

    private var popoutContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("Notificacoes")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.92))

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VitaColors.surface)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(VitaColors.accentHover)
                        )
                }

                Spacer()

                if unreadCount > 0 {
                    Button(action: { markAllRead() }) {
                        Text("Marcar lidas")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(VitaColors.accentHover.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { dismiss(); onSettingsTap() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textTertiary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Divider
            Rectangle()
                .fill(VitaColors.accentLight.opacity(0.05))
                .frame(height: 1)
                .padding(.horizontal, 10)

            // Notification list
            if notifications.isEmpty {
                emptyState
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 3) {
                        ForEach(notifications) { item in
                            notifRow(item)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: 300)
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

    // MARK: - Notification Row

    private func notifRow(_ item: NotifItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Emoji icon
            Text(item.icon)
                .font(.system(size: 18))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .lineLimit(1)

                Text(item.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                    .lineLimit(2)
            }

            Spacer()

            Text(item.time)
                .font(.system(size: 9))
                .foregroundStyle(VitaColors.accentHover.opacity(0.35))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.071, green: 0.055, blue: 0.039).opacity(0.60),
                            Color(red: 0.055, green: 0.043, blue: 0.031).opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            item.isRead
                                ? VitaColors.accentHover.opacity(0.04)
                                : VitaColors.accentHover.opacity(0.12),
                            lineWidth: 1
                        )
                )
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .font(.system(size: 24))
                .foregroundStyle(VitaColors.textTertiary)
            Text("Tudo em dia!")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.60))
            Text("Nenhuma notificacao.")
                .font(.system(size: 10))
                .foregroundStyle(VitaColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Actions

    private func markAllRead() {
        withAnimation(.easeInOut(duration: 0.2)) {
            notifications = notifications.map {
                NotifItem(id: $0.id, icon: $0.icon, title: $0.title, subtitle: $0.subtitle, time: $0.time, isRead: true)
            }
        }
        onMarkAllRead()
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            onDismiss()
        }
    }
}

// MARK: - NotifItem Model

struct NotifItem: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    let time: String
    let isRead: Bool

    static let mockItems: [NotifItem] = [
        NotifItem(
            id: "1",
            icon: "\u{1F4DA}",
            title: "Hora de revisar!",
            subtitle: "15 flashcards de Farmacologia prontos",
            time: "2 min",
            isRead: false
        ),
        NotifItem(
            id: "2",
            icon: "\u{23F0}",
            title: "Prova em 3 dias",
            subtitle: "P2 Patologia Medica — 8 de abril",
            time: "1h",
            isRead: false
        ),
        NotifItem(
            id: "3",
            icon: "\u{1F3C6}",
            title: "Conquista desbloqueada!",
            subtitle: "7 dias seguidos de estudo",
            time: "ontem",
            isRead: true
        ),
        NotifItem(
            id: "4",
            icon: "\u{1F4CA}",
            title: "Relatorio semanal",
            subtitle: "Voce estudou 8.5h esta semana",
            time: "2 dias",
            isRead: true
        ),
    ]
}
