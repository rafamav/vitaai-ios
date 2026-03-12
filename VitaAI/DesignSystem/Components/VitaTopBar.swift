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
            Button(action: { onAvatarTap?() }) {
                ZStack(alignment: .bottom) {
                    // XP ring — thin progress arc around avatar
                    let xpProgress: CGFloat = 0.82 // mock: 82% to next level
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 2.5)
                            .frame(width: 50, height: 50)
                        Circle()
                            .trim(from: 0, to: xpProgress)
                            .stroke(
                                VitaColors.accent.opacity(0.60),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))
                    }

                    // Avatar inside ring
                    Group {
                        if let url = userImageURL {
                            AsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                initialsView
                            }
                            .frame(width: 42, height: 42)
                            .clipShape(Circle())
                        } else {
                            initialsView
                                .frame(width: 42, height: 42)
                        }
                    }

                    // Level badge at bottom of ring (matches mockup .level-badge)
                    let levelValue = userLevel ?? 0
                    if levelValue > 0 {
                        Text("\(levelValue)")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(Color(red: 26/255, green: 20/255, blue: 18/255))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(VitaColors.accent.opacity(0.90))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .offset(y: 8)
                    } else if let streak = userStreak, streak > 0 {
                        // Fallback: show streak if no level
                        HStack(spacing: 1) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 5, weight: .bold))
                                .foregroundStyle(Color(red: 26/255, green: 20/255, blue: 18/255))
                            Text("\(streak)")
                                .font(.system(size: 7, weight: .black))
                                .foregroundStyle(Color(red: 26/255, green: 20/255, blue: 18/255))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(VitaColors.accent.opacity(0.90))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .offset(y: 8)
                    }
                }
                .frame(width: 50, height: 58) // extra height for badge
            }
            .buttonStyle(.plain)

            // Greeting + subtitle
            VStack(alignment: .leading, spacing: 1) {
                if let userName {
                    let firstName = userName.split(separator: " ").first.map(String.init) ?? userName
                    Text("\(timeGreeting), \(firstName)")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.90))
                        .lineLimit(1)
                } else {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.90))
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

            // Notification bell
            Button(action: { onNotificationsTap?() }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.60))
                        .frame(width: 34, height: 34)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())

                    // Notification dot
                    Circle()
                        .fill(Color(red: 255/255, green: 80/255, blue: 60/255))
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: -2)
                }
            }
            .buttonStyle(.plain)

            // Menu (hamburger)
            Button(action: { onMenuTap?() }) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
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
