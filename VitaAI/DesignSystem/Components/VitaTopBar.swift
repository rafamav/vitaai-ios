import SwiftUI

// MARK: - VitaTopBar — Glass Pill Top Navigation
// Matches mockup .top-nav-rail CSS exactly:
//   border-radius: 999px, border: 1px solid rgba(255,232,194,0.14)
//   bg: linear-gradient(180deg, rgba(36,24,18,0.6), rgba(16,11,10,0.68))
//     + radial-gradient(circle at 50% 0%, rgba(255,228,175,0.1), transparent 42%)
//   box-shadow: 0 20px 42px rgba(0,0,0,0.2), inset 0 1px 0 rgba(255,245,226,0.11)
//   padding: 10px 14px, nav-circle: 42x42

struct VitaTopBar: View {
    var title: String = ""
    var userName: String?
    var userImageURL: URL?
    var subtitle: String = ""
    var level: Int = 0
    var xpProgress: Double = 0
    var notificationCount: Int = 0
    var onAvatarTap: (() -> Void)?
    var onBellTap: (() -> Void)?
    var onMenuTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            // Left: Avatar with XP ring
            Button(action: { onAvatarTap?() }) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 2.5)
                        .frame(width: 40, height: 40)
                    // XP ring: stroke="url(#xpG)" — rgba(255,200,100,0.85) to rgba(200,150,60,0.65)
                    Circle()
                        .trim(from: 0, to: xpProgress)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.784, blue: 0.392).opacity(0.85),
                                    Color(red: 0.784, green: 0.588, blue: 0.235).opacity(0.65)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                        )
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.15), radius: 4)

                    if let url = userImageURL {
                        AsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            avatarInitials
                        }
                        .frame(width: 30, height: 30)
                        .clipShape(Circle())
                    } else {
                        avatarInitials
                    }

                    // Level badge — mockup: rgba(200,160,80,0.35)->rgba(140,100,50,0.25), border rgba(255,220,160,0.30), text rgba(255,220,160,0.95)
                    Text("\(level)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.95))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            Capsule().fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.35),
                                        Color(red: 0.549, green: 0.392, blue: 0.196).opacity(0.25)
                                    ],
                                    startPoint: .top, endPoint: .bottom
                                )
                            )
                        )
                        .overlay(
                            Capsule().stroke(
                                Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.30),
                                lineWidth: 1
                            )
                        )
                        .offset(y: 18)
                }
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Perfil")

            VStack(alignment: .leading, spacing: 1) {
                Text(greeting)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color.white.opacity(0.35))
                        .lineLimit(1)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer()

            HStack(spacing: 8) {
                navCircleButton(icon: "bell", badgeCount: notificationCount) { onBellTap?() }
                    .accessibilityLabel("Notificações")
                    .accessibilityIdentifier("bellButton")
                navCircleButton(icon: "line.3.horizontal") { onMenuTap?() }
                    .accessibilityLabel("Menu")
                    .accessibilityIdentifier("menuButton")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    // Mockup: linear-gradient(180deg, rgba(36,24,18,0.6), rgba(16,11,10,0.68))
                    LinearGradient(
                        colors: [
                            Color(red: 0.141, green: 0.094, blue: 0.071).opacity(0.60),
                            Color(red: 0.063, green: 0.043, blue: 0.039).opacity(0.68)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    // Radial glow: radial-gradient(circle at 50% 0%, rgba(255,228,175,0.1), transparent 42%)
                    Capsule()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.894, blue: 0.686).opacity(0.10),
                                    Color.clear
                                ],
                                center: UnitPoint(x: 0.5, y: 0.0),
                                startRadius: 0,
                                endRadius: 120
                            )
                        )
                )
                .overlay(
                    // Border: 1px solid rgba(255,232,194,0.14)
                    Capsule().stroke(
                        Color(red: 1.0, green: 0.910, blue: 0.761).opacity(0.14),
                        lineWidth: 1
                    )
                )
                // Shadow: 0 20px 42px rgba(0,0,0,0.2)
                .shadow(color: .black.opacity(0.20), radius: 21, x: 0, y: 10)
                // Top highlight: inset 0 1px 0 rgba(255,245,226,0.11)
                .overlay(alignment: .top) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, Color(red: 1.0, green: 0.961, blue: 0.886).opacity(0.11), .clear],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(height: 1)
                        .padding(.horizontal, 20)
                }
        )
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 8)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let period = hour < 12 ? "Bom dia" : hour < 18 ? "Boa tarde" : "Boa noite"
        if let name = userName {
            let first = name.split(separator: " ").first.map(String.init) ?? name
            return "\(period), \(first)"
        }
        return period
    }

    // Mockup .avatar-photo: bg linear-gradient(135deg, rgba(200,160,80,0.3), rgba(160,120,60,0.2)), text rgba(255,241,215,0.7)
    private var avatarInitials: some View {
        Text(userName?.prefix(1).uppercased() ?? "R")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color(red: 1.0, green: 0.945, blue: 0.843).opacity(0.7))
            .frame(width: 30, height: 30)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.3),
                            Color(red: 0.627, green: 0.471, blue: 0.235).opacity(0.2)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            )
            .clipShape(Circle())
    }

    // Mockup .top-nav-rail .nav-circle:
    //   42x42, color rgba(255,244,226,0.68)
    //   bg: linear-gradient(180deg, rgba(255,248,236,0.075), rgba(255,248,236,0.03))
    //   border: rgba(255,224,176,0.16)
    //   shadows: inset 0 1px 0 rgba(255,247,234,0.05), 0 10px 24px rgba(0,0,0,0.2)
    private func navCircleButton(icon: String, badgeCount: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color(red: 1.0, green: 0.957, blue: 0.886).opacity(0.68))
                    .frame(width: 42, height: 42)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.973, blue: 0.925).opacity(0.075),
                                    Color(red: 1.0, green: 0.973, blue: 0.925).opacity(0.03)
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                    )
                    .overlay(
                        Circle().stroke(
                            Color(red: 1.0, green: 0.878, blue: 0.690).opacity(0.16),
                            lineWidth: 1
                        )
                    )
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 5)

                // Badge
                if badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Circle().fill(VitaColors.dataRed))
                        .offset(x: 2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
