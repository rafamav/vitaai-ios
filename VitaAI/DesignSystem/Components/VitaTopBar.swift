import SwiftUI

struct VitaTopBar: View {
    let title: String
    var userName: String?
    var userImageURL: URL?
    var userLevel: Int?
    var userStreak: Int?
    var userCourse: String?
    var userSemester: String?
    var onAvatarTap: (() -> Void)?
    var onNotificationsTap: (() -> Void)?
    var onMenuTap: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // Avatar with XP ring + level badge (matches mockup topbar)
            // Mockup: avatar 38x38 inside gold XP ring, level pill badge
            Button(action: { onAvatarTap?() }) {
                ZStack(alignment: .bottom) {
                    // XP ring — AngularGradient conic arc (gold, per task spec)
                    let xpProgress: CGFloat = 0.82 // mock: 82% to next level
                    ZStack {
                        // Track circle
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 2.5)
                            .frame(width: 46, height: 46)
                        // Progress arc — AngularGradient gold (conic: dark→bright gold)
                        Circle()
                            .trim(from: 0, to: xpProgress)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: VitaColors.accentDark.opacity(0.40), location: 0.0),
                                        .init(color: VitaColors.accent.opacity(0.85), location: 0.45),
                                        .init(color: VitaColors.accentLight.opacity(1.00), location: 0.85),
                                        .init(color: VitaColors.accent.opacity(0.55), location: 1.0)
                                    ]),
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .frame(width: 46, height: 46)
                            .rotationEffect(.degrees(-90))
                    }

                    // Avatar inside ring — 38x38 per mockup spec
                    Group {
                        if let url = userImageURL {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                initialsView
                            }
                            .frame(width: 38, height: 38)
                            .clipShape(Circle())
                        } else {
                            initialsView
                                .frame(width: 38, height: 38)
                        }
                    }

                    // Level badge pill at bottom of ring (matches mockup .level-badge exactly)
                    // Spec: background rgba(200,160,80,0.25) + border 1.5px rgba(200,160,80,0.35)
                    //       border-radius 6px + padding 0 5px + font 8px/700 goldText
                    let levelValue = userLevel ?? 0
                    if levelValue > 0 {
                        Text("\(levelValue)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(red: 255/255, green: 220/255, blue: 160/255).opacity(0.90))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(VitaColors.accent.opacity(0.25))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(VitaColors.accent.opacity(0.35), lineWidth: 1.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .offset(y: 9)
                    } else if let streak = userStreak, streak > 0 {
                        // Fallback: show streak pill in same glass style
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(Color(red: 255/255, green: 220/255, blue: 160/255).opacity(0.80))
                            Text("\(streak)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(Color(red: 255/255, green: 220/255, blue: 160/255).opacity(0.90))
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(VitaColors.accent.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(VitaColors.accent.opacity(0.35), lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .offset(y: 9)
                    }
                }
                .frame(width: 46, height: 56) // extra height for badge
            }
            .buttonStyle(.plain)

            // Greeting + subtitle
            VStack(alignment: .leading, spacing: 2) {
                // Greeting row: "Bom dia, Rafael! 🔥42" (streak chip inline — matches mockup)
                HStack(spacing: 6) {
                    if let userName {
                        let firstName = userName.split(separator: " ").first.map(String.init) ?? userName
                        Text("\(timeGreeting), \(firstName)!")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.90))
                            .lineLimit(1)
                    } else {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.90))
                    }
                    // Streak chip inline — matches mockup .streak-chip
                    if let streak = userStreak, streak > 0 {
                        HStack(spacing: 2) {
                            Text("🔥")
                                .font(.system(size: 10))
                            Text("\(streak)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(red: 255/255, green: 200/255, blue: 130/255).opacity(0.95))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VitaColors.accent.opacity(0.14))
                        .overlay(
                            Capsule()
                                .stroke(VitaColors.accent.opacity(0.22), lineWidth: 1)
                        )
                        .clipShape(Capsule())
                    }
                }

                // Subtitle: semestre · curso
                let sub = subtitleText
                if !sub.isEmpty {
                    Text(sub)
                        .font(.system(size: 11.5, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.35))
                }
            }

            Spacer()

            // Notification bell — 38x38 glass circle with border (matches mockup spec)
            Button(action: { onNotificationsTap?() }) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                        Image(systemName: "bell.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white.opacity(0.60))
                    }
                    .frame(width: 38, height: 38)

                    // Notification dot — rgba(255,120,100,0.7) per spec
                    Circle()
                        .fill(Color(red: 255/255, green: 120/255, blue: 100/255).opacity(0.85))
                        .frame(width: 7, height: 7)
                        .offset(x: 1, y: 0)
                }
            }
            .buttonStyle(.plain)

            // Hamburger — 38x38 glass circle with border (matches mockup spec)
            Button(action: { onMenuTap?() }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.55))
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(VitaColors.accent.opacity(0.15))
            Text(userName?.prefix(1).uppercased() ?? "M")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VitaColors.accent)
        }
    }

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return NSLocalizedString("Bom dia", comment: "Morning greeting")
        } else if hour < 18 {
            return NSLocalizedString("Boa tarde", comment: "Afternoon greeting")
        } else {
            return NSLocalizedString("Boa noite", comment: "Evening greeting")
        }
    }

    private var subtitleText: String {
        let parts = [userSemester, userCourse].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }
}
