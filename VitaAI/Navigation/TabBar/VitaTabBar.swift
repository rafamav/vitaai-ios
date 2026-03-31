import SwiftUI

enum TabItem: String, CaseIterable {
    case home = "Home"
    case estudos = "Estudos"
    case faculdade = "Faculdade"
    case progresso = "Progresso"

    var icon: String {
        switch self {
        case .home: return "house" // TestID.tabHome
        case .estudos: return "book"
        case .faculdade: return "graduationcap"
        case .progresso: return "chart.bar"
        }
    }

    var testID: String {
        switch self {
        case .home: return "tab_home"
        case .estudos: return "tab_estudos"
        case .faculdade: return "tab_faculdade"
        case .progresso: return "tab_progresso"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .estudos: return "book.fill"
        case .faculdade: return "graduationcap.fill"
        case .progresso: return "chart.bar.fill"
        }
    }
}

// MARK: - Gold Glassmorphism Tab Bar (matches web mockup bottom-nav-rail)

struct VitaTabBar: View {
    @Binding var selectedTab: TabItem
    var onCenterTap: () -> Void
    var onTabReselect: ((TabItem) -> Void)? = nil

    // Gold palette → VitaColors
    private let goldAccent = VitaColors.accentHover
    private let goldMuted  = VitaColors.accentLight
    private let textDim    = VitaColors.textTertiary

    var body: some View {
        ZStack {
            // Glass pill
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            VitaColors.surfaceElevated.opacity(0.72),
                            VitaColors.surfaceCard.opacity(0.78)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.42), radius: 30, y: 12)

            HStack(spacing: 0) {
                // Left: Home, Estudos
                tabButton(.home)
                tabButton(.estudos)

                // Center: Vita button
                Button(action: onCenterTap) {
                    Image("vita-btn-idle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                }
                .accessibilityIdentifier("tab_vita")
                .accessibilityLabel("Abrir Vita Chat")
                .frame(minWidth: 52, minHeight: 44)

                // Right: Faculdade, Progresso
                tabButton(.faculdade)
                tabButton(.progresso)
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 52)
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
    }

    private func tabButton(_ item: TabItem) -> some View {
        let isSelected = selectedTab == item
        return Button(action: {
            if isSelected {
                onTabReselect?(item)
            } else {
                selectedTab = item
            }
        }) {
            Image(systemName: isSelected ? item.selectedIcon : item.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(
                    isSelected
                        ? goldAccent.opacity(0.92)
                        : textDim
                )
                .frame(width: 44, height: 44)
                .accessibilityIdentifier(item.testID)
                .background(
                    Circle()
                        .fill(
                            isSelected
                                ? LinearGradient(
                                    colors: [
                                        goldAccent.opacity(0.20),
                                        VitaColors.accent.opacity(0.08)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                  )
                                : LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.06),
                                        Color.white.opacity(0.06)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                  )
                        )
                )
                .overlay(
                    Circle()
                        .stroke(
                            isSelected
                                ? goldAccent.opacity(0.24)
                                : goldMuted.opacity(0.16),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(item.testID)
        .accessibilityLabel(item.rawValue)
        .frame(maxWidth: .infinity)
    }
}
