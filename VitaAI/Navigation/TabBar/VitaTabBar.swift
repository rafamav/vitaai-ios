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

// MARK: - Gold Glassmorphism Tab Bar
// Matches mockup .bottom-nav-rail CSS:
//   border-radius: 999px
//   border: 1px solid rgba(255,240,214,0.08)
//   bg: linear-gradient(180deg, rgba(34,23,18,0.72), rgba(18,12,11,0.78))
//     + radial-gradient(circle at top, rgba(255,232,187,0.08), transparent 46%)
//   box-shadow: 0 24px 60px rgba(0,0,0,0.42), inset 0 1px 0 rgba(255,245,226,0.08)
//   Shell: padding 0 28px 22px. Inner: padding 10px 14px

struct VitaTabBar: View {
    @Binding var selectedTab: TabItem
    var onCenterTap: () -> Void
    var onTabReselect: ((TabItem) -> Void)? = nil

    var body: some View {
        ZStack {
            // Glass pill background
            Capsule()
                .fill(
                    // rgba(34,23,18,0.72) -> rgba(18,12,11,0.78)
                    LinearGradient(
                        colors: [
                            Color(red: 0.133, green: 0.090, blue: 0.071).opacity(0.72),
                            Color(red: 0.071, green: 0.047, blue: 0.043).opacity(0.78)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    // Radial gold glow at top
                    Capsule()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.910, blue: 0.733).opacity(0.08),
                                    Color.clear
                                ],
                                center: UnitPoint(x: 0.5, y: 0.0),
                                startRadius: 0,
                                endRadius: 100
                            )
                        )
                )
                .overlay(
                    // Border: rgba(255,240,214,0.08)
                    Capsule()
                        .stroke(
                            Color(red: 1.0, green: 0.941, blue: 0.839).opacity(0.08),
                            lineWidth: 1
                        )
                )
                // Top edge highlight: inset 0 1px 0 rgba(255,245,226,0.08)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color(red: 1.0, green: 0.961, blue: 0.886).opacity(0.08), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                }
                // Shadow: 0 24px 60px rgba(0,0,0,0.42)
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
                .accessibilityIdentifier("tab_vita_chat")
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
        .padding(.bottom, 22) // mockup: padding-bottom 22px
    }

    // Mockup .nav-circle: 42x42
    //   default: color rgba(255,244,226,0.52), bg rgba(255,248,236,0.045/0.02), border rgba(255,240,214,0.08)
    //   .active: color rgba(255,230,181,0.92), bg rgba(224,186,117,0.2/0.08), border rgba(224,186,117,0.24)
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
                        ? Color(red: 1.0, green: 0.902, blue: 0.710).opacity(0.92)
                        : Color(red: 1.0, green: 0.957, blue: 0.886).opacity(0.52)
                )
                .frame(width: 42, height: 42)
                .accessibilityIdentifier(item.testID)
                .background(
                    Circle()
                        .fill(
                            isSelected
                                ? LinearGradient(
                                    colors: [
                                        Color(red: 0.878, green: 0.729, blue: 0.459).opacity(0.20),
                                        Color(red: 0.455, green: 0.290, blue: 0.153).opacity(0.08)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                  )
                                : LinearGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.973, blue: 0.925).opacity(0.045),
                                        Color(red: 1.0, green: 0.973, blue: 0.925).opacity(0.02)
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
                                ? Color(red: 0.878, green: 0.729, blue: 0.459).opacity(0.24)
                                : Color(red: 1.0, green: 0.941, blue: 0.839).opacity(0.08),
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
