import SwiftUI

enum TabItem: String, CaseIterable {
    case home = "Home"
    case estudos = "Estudo"
    case agenda = "Agenda"
    case profile = "Perfil"

    var icon: String {
        switch self {
        case .home: return "house"
        case .estudos: return "book"
        case .agenda: return "calendar"
        case .profile: return "person"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .estudos: return "book.fill"
        case .agenda: return "calendar.fill"
        case .profile: return "person.fill"
        }
    }
}

struct VitaTabBar: View {
    @Binding var selectedTab: TabItem
    var onCenterTap: () -> Void

    private let tabBarHeight: CGFloat = 68

    var body: some View {
        VStack(spacing: 0) {
            // Top border
            Rectangle()
                .fill(VitaColors.surfaceBorder)
                .frame(height: 1)

            HStack(spacing: 0) {
                // Left side: Home, Estudo
                tabButton(.home)
                tabButton(.estudos)

                // Center: Chat (raised gold circle — vita medallion)
                Button(action: onCenterTap) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [VitaColors.accent, VitaColors.accentDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .shadow(color: VitaColors.accent.opacity(0.35), radius: 12, x: 0, y: 4)

                        Image(systemName: "message.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                    }
                }
                .offset(y: -10)
                .frame(maxWidth: .infinity)

                // Right side: Agenda, Perfil
                tabButton(.agenda)
                tabButton(.profile)
            }
            .padding(.horizontal, 8)
            .frame(height: tabBarHeight)
            .background(VitaColors.surfaceCard.opacity(0.92))
        }
    }

    private func tabButton(_ item: TabItem) -> some View {
        Button(action: { selectedTab = item }) {
            VStack(spacing: 3) {
                Image(systemName: selectedTab == item ? item.selectedIcon : item.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(selectedTab == item ? VitaColors.accent : VitaColors.textTertiary)
                Text(item.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(selectedTab == item ? VitaColors.textPrimary : VitaColors.textTertiary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
