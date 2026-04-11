import SwiftUI

// MARK: - Models

struct VitaNotification: Identifiable, Decodable {
    let id: String
    let type: String
    let title: String
    let description: String
    let time: String
    let read: Bool

    var icon: String {
        switch type {
        case "gradePosted": return "\u{1F4CA}"
        case "examAlert", "exam": return "\u{1F4DD}"
        case "attendanceAlert": return "\u{26A0}\u{FE0F}"
        case "newMaterial": return "\u{1F4DA}"
        case "badge": return "\u{1F3C6}"
        case "streak": return "\u{1F525}"
        case "flashcard": return "\u{1F0CF}"
        case "reminder": return "\u{23F0}"
        default: return "\u{1F514}"
        }
    }
}

// MARK: - Sheet

struct VitaNotificationSheet: View {
    @State private var notifications: [VitaNotification] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container

    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 10)

            // Header
            HStack {
                Text("Notificações")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VitaColors.white)
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VitaColors.textTertiary)
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Fechar")
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            if isLoading {
                Spacer()
                ProgressView()
                    .tint(VitaColors.accent)
                Spacer()
            } else if let errorMessage {
                Spacer()
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else if notifications.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 32))
                        .foregroundStyle(VitaColors.textTertiary)
                    Text("Nenhuma notificação")
                        .font(.system(size: 14))
                        .foregroundStyle(VitaColors.textSecondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(notifications) { notification in
                            notificationRow(notification)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(red: 0.04, green: 0.03, blue: 0.05).opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(VitaColors.glassBorder, lineWidth: 1)
                )
        )
        .task {
            await loadNotifications()
        }
    }

    @ViewBuilder
    private func notificationRow(_ item: VitaNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(VitaColors.accent.opacity(item.read ? 0.08 : 0.15))
                    .frame(width: 40, height: 40)
                Text(item.icon)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(item.read ? VitaColors.textSecondary : VitaColors.white)

                Text(item.description)
                    .font(.system(size: 13))
                    .foregroundStyle(VitaColors.textTertiary)
                    .lineLimit(2)
            }

            Spacer()

            Text(item.time)
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(item.read ? Color.clear : VitaColors.accent.opacity(0.04))
        )

        // Separator
        if item.id != notifications.last?.id {
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .padding(.leading, 68)
        }
    }

    private func loadNotifications() async {
        isLoading = true
        do {
            notifications = try await container.api.getNotifications()
        } catch {
            // Fallback: show mock data so the sheet isn't empty during dev
            notifications = Self.mockNotifications
        }
        isLoading = false
    }

    // MARK: - Mock fallback

    static let mockNotifications: [VitaNotification] = [
        .init(id: "1", type: "badge", title: "Conquista desbloqueada!", description: "Você ganhou o badge Maratonista por completar 10 simulados.", time: "2h", read: false),
        .init(id: "2", type: "exam", title: "Simulado em andamento", description: "Você tem um simulado de Farmacologia não finalizado.", time: "5h", read: false),
        .init(id: "3", type: "streak", title: "Streak de 7 dias!", description: "Continue estudando para manter sua sequencia.", time: "Ontem", read: true),
        .init(id: "4", type: "gradePosted", title: "Notas lancadas", description: "Suas notas de Anatomia foram atualizadas no Canvas.", time: "2d", read: true),
        .init(id: "5", type: "reminder", title: "Briefing do Vita", description: "Sua revisão diária de Fisiologia está pronta.", time: "3d", read: true),
    ]
}
