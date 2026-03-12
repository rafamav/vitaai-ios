import SwiftUI

// MARK: - TabItem
// Matches mockup nav: home | estudos | [vita center] | faculdade | historico
enum TabItem: String, CaseIterable {
    case home       = "Home"
    case estudos    = "Estudos"
    case faculdade  = "Faculdade"
    case historico  = "Progresso"

    var icon: String {
        switch self {
        case .home:      return "house"
        case .estudos:   return "books.vertical"
        case .faculdade: return "graduationcap"
        case .historico: return "chart.bar"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home:      return "house.fill"
        case .estudos:   return "books.vertical.fill"
        case .faculdade: return "graduationcap.fill"
        case .historico: return "chart.bar.fill"
        }
    }
}

// MARK: - VitaTabBar
// Matches mockup .nav-pill: 4 nav-circles + vita-center medallion
// Style: floating pill with blur, no background bar, just circles
struct VitaTabBar: View {
    @Binding var selectedTab: TabItem
    var onCenterTap: () -> Void

    var body: some View {
        ZStack {
            // Fade gradient behind nav (matches mockup ::before pseudo-element)
            LinearGradient(
                colors: [Color.clear, VitaColors.surface.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 140)
            .allowsHitTesting(false)

            HStack(spacing: 0) {
                // Left side
                navCircle(.home)
                navCircle(.estudos)

                // Center gap for medallion
                Spacer().frame(width: 90)

                // Right side
                navCircle(.faculdade)
                navCircle(.historico)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
            .frame(maxWidth: .infinity)

            // Center Vita medallion (matches mockup .vita-center / .vita-snake)
            VStack {
                Spacer()
                Button(action: onCenterTap) {
                    VitaMedallionButton()
                }
                .buttonStyle(.plain)
                .offset(y: -12)
                .padding(.bottom, 22)
            }
        }
        .frame(height: 110)
    }

    // MARK: - Nav Circle (matches .nav-circle)
    @ViewBuilder
    private func navCircle(_ item: TabItem) -> some View {
        let isActive = selectedTab == item

        Button(action: { selectedTab = item }) {
            Image(systemName: isActive ? item.selectedIcon : item.icon)
                .font(.system(size: 20, weight: isActive ? .medium : .regular))
                .foregroundStyle(
                    isActive
                        ? Color(red: 255/255, green: 220/255, blue: 160/255).opacity(0.9)
                        : Color.white.opacity(0.55)
                )
                .frame(width: 48, height: 48)
                .background(
                    isActive
                        ? VitaColors.accent.opacity(0.08)
                        : Color.clear
                )
                .overlay(
                    Circle().stroke(
                        isActive ? VitaColors.accent.opacity(0.10) : Color.clear,
                        lineWidth: 1
                    )
                )
                .clipShape(Circle())
                .shadow(
                    color: isActive ? VitaColors.accent.opacity(0.08) : .clear,
                    radius: 12
                )
                .opacity(isActive ? 1.0 : 0.45)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Vita Medallion Center Button
// Matches mockup .vita-center + .vita-snake (medalha PNG com glow dourado)
private struct VitaMedallionButton: View {
    @State private var glowing = false

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .fill(VitaColors.accent.opacity(glowing ? 0.15 : 0.08))
                .frame(width: 72, height: 72)
                .blur(radius: glowing ? 12 : 8)

            // Medallion image or gold circle fallback
            if UIImage(named: "medallion-nav") != nil {
                Image("medallion-nav")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .shadow(color: VitaColors.accent.opacity(0.5), radius: 16)
                    .shadow(color: VitaColors.accent.opacity(0.2), radius: 35)
            } else {
                // Fallback: gold gradient circle with snake/caduceus
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [VitaColors.accent, VitaColors.accentDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .shadow(color: VitaColors.accent.opacity(0.50), radius: 16)
                        .shadow(color: VitaColors.accent.opacity(0.20), radius: 35)

                    Image(systemName: "staroflife.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
        .frame(width: 72, height: 72)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}
