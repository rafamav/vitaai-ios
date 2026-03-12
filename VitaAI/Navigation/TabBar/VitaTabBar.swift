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

    var localizedName: String {
        switch self {
        case .home:      return NSLocalizedString("Inicio", comment: "Nav tab home")
        case .estudos:   return NSLocalizedString("Estudos", comment: "Nav tab estudos")
        case .faculdade: return NSLocalizedString("Faculdade", comment: "Nav tab faculdade")
        case .historico: return NSLocalizedString("Progresso", comment: "Nav tab progresso")
        }
    }
}

// MARK: - VitaTabBar
// Matches mockup .nav-pill: 4 nav-circles + vita-center medallion
// Style: floating pill with glass fade, neumorphic circles, gold active glow
struct VitaTabBar: View {
    @Binding var selectedTab: TabItem
    var onCenterTap: () -> Void

    var body: some View {
        ZStack {
            // Fade gradient behind nav (matches mockup ::before — glass fade background)
            // Tall gradient + backdrop blur for premium look
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 0.039, green: 0.039, blue: 0.059).opacity(0.70), // #0A0A0F
                    Color(red: 0.039, green: 0.039, blue: 0.059).opacity(0.94)  // #0A0A0F
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)
            .allowsHitTesting(false)

            HStack(spacing: 0) {
                // Left side
                navCircle(.home)
                navCircle(.estudos)

                // Center gap for 100px medallion
                Spacer().frame(width: 108)

                // Right side
                navCircle(.faculdade)
                navCircle(.historico)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)

            // Center Vita medallion (100px — matches mockup .vita-center)
            VStack {
                Spacer()
                Button(action: onCenterTap) {
                    VitaMedallionButton()
                }
                .buttonStyle(.plain)
                .offset(y: -18) // lift above nav row
                .padding(.bottom, 24)
            }
        }
        .frame(height: 130) // taller to fit 100px medallion floating up
    }

    // MARK: - Nav Circle (matches .nav-circle — neumorphic 48x48, nearly transparent)
    // Mockup: rgba(255,255,255,0.03) bg + inset dark shadow + 0.45 opacity inactive
    // Active: rgba(200,160,80,0.08) bg + gold glow + full opacity
    @ViewBuilder
    private func navCircle(_ item: TabItem) -> some View {
        let isActive = selectedTab == item

        Button(action: { selectedTab = item }) {
            ZStack {
                // Base circle — near-transparent glass (matches mockup rgba(255,255,255,0.03))
                Circle()
                    .fill(
                        isActive
                            ? VitaColors.accent.opacity(0.08)          // rgba(200,160,80,0.08) active
                            : Color.white.opacity(0.03)                 // rgba(255,255,255,0.03) inactive
                    )
                    .frame(width: 48, height: 48)

                // Neumorphic inner shadow ring — simulates concave inset
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(isActive ? 0.30 : 0.40),
                                Color.white.opacity(isActive ? 0.04 : 0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .frame(width: 48, height: 48)

                // Gold border ring (active only — matches mockup active border rgba(200,160,80,0.10))
                if isActive {
                    Circle()
                        .stroke(VitaColors.accent.opacity(0.20), lineWidth: 1.5)
                        .frame(width: 48, height: 48)
                }

                // Icon — gold when active, white.35 when inactive (matches mockup stroke colors)
                Image(systemName: isActive ? item.selectedIcon : item.icon)
                    .font(.system(size: 19, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(
                        isActive
                            ? Color(red: 255/255, green: 220/255, blue: 160/255).opacity(0.92) // rgba(255,220,160,0.9)
                            : Color.white.opacity(0.38)                                          // inactive stroke
                    )
            }
            // Outer neumorphic depth shadow
            .shadow(
                color: .black.opacity(isActive ? 0.40 : 0.35),
                radius: 5, x: 2, y: 2
            )
            .shadow(
                color: Color.white.opacity(0.03),
                radius: 3, x: -1, y: -1
            )
            // Gold ambient glow when active (matches mockup 0 0 12px rgba(200,160,80,0.08))
            .shadow(
                color: isActive ? VitaColors.accent.opacity(0.28) : .clear,
                radius: 12, x: 0, y: 0
            )
            // Opacity: 0.45 inactive, 1.0 active (matches mockup)
            .opacity(isActive ? 1.0 : 0.50)
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
            // Outer ambient glow halo (pulsing)
            Circle()
                .fill(VitaColors.accent.opacity(glowing ? 0.22 : 0.12))
                .frame(width: 100, height: 100)
                .blur(radius: glowing ? 20 : 14)

            // Mid glow ring
            Circle()
                .fill(VitaColors.ambientPrimary.opacity(glowing ? 0.14 : 0.07))
                .frame(width: 84, height: 84)
                .blur(radius: 8)

            // Medallion image (asset exists) or premium fallback
            if UIImage(named: "medallion-nav") != nil {
                Image("medallion-nav")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    // Matches mockup: brightness(1.6) drop-shadow gold
                    .colorMultiply(Color(red: 1.0, green: 0.96, blue: 0.85))
                    .shadow(color: VitaColors.accent.opacity(glowing ? 0.65 : 0.50), radius: glowing ? 24 : 18)
                    .shadow(color: VitaColors.accent.opacity(glowing ? 0.28 : 0.18), radius: 40)
            } else {
                // Fallback: 80px neumorphic gold medallion
                ZStack {
                    // Neumorphic base
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.100, green: 0.082, blue: 0.125),
                                    Color(red: 0.059, green: 0.047, blue: 0.082)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                        .shadow(color: .black.opacity(0.55), radius: 8, x: 4, y: 4)
                        .shadow(color: .white.opacity(0.04), radius: 6, x: -3, y: -3)

                    // Gold ring border
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    VitaColors.accentLight.opacity(0.60),
                                    VitaColors.accent.opacity(0.30),
                                    VitaColors.accentDark.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: 72, height: 72)

                    // Gold glow shadow
                    Circle()
                        .fill(.clear)
                        .frame(width: 72, height: 72)
                        .shadow(color: VitaColors.accent.opacity(0.55), radius: 18)
                        .shadow(color: VitaColors.accent.opacity(0.25), radius: 36)

                    // Medical icon — star of life
                    Image(systemName: "staroflife.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 255/255, green: 220/255, blue: 160/255),
                                    VitaColors.accent
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: VitaColors.accent.opacity(0.8), radius: 8)
                }
            }
        }
        .frame(width: 100, height: 100)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowing = true
            }
        }
    }
}
