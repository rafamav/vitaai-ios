import SwiftUI

// MARK: - ProfileScreen
// Matches perfil-mobile-v1.html mockup exactly:
// 80px avatar ring, bottom-center level badge, XP bar, emoji badges,
// centered stats grid (no icons), glass edit button.

struct ProfileScreen: View {
    let authManager: AuthManager

    var onNavigateToConfiguracoes: (() -> Void)?
    var onNavigateToAchievements:  (() -> Void)?

    @Environment(\.appContainer) private var container
    @State private var gamStats: GamificationStatsResponse?
    @State private var profile: ProfileResponse?

    // Gold mockup palette
    private let goldPrimary   = VitaColors.accentHover // → VitaColors
    private let goldAccent    = VitaColors.accent       // → VitaColors.accent
    private let goldSubtle    = VitaColors.accentLight  // → VitaColors.accentLight
    private let cardBg        = Color(red: 0.047, green: 0.035, blue: 0.027).opacity(0.94)
    private let borderColor   = Color(red: 1.0,   green: 0.910, blue: 0.760).opacity(0.14)
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // TOP NAV
                headerBar
                    .padding(.top, 8)

                // AVATAR + NAME (combined, matches .profile-avatar-wrap)
                profileHeader
                    .padding(.top, 20)

                // XP BAR — inside glass card
                xpBarSection
                    .padding(.top, 12)
                    .padding(.horizontal, 14)

                // CONQUISTAS
                sectionLabel("Conquistas")
                    .padding(.top, 20)
                conquistas

                // ESTATISTICAS
                sectionLabel("Estatísticas")
                    .padding(.top, 20)
                estatisticas
                    .padding(.horizontal, 14)

                // EDITAR PERFIL — glass style
                Button(action: { onNavigateToConfiguracoes?() }) {
                    Text("Editar Perfil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(red: 1.0, green: 0.902, blue: 0.706).opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(VitaColors.glassInnerLight.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(goldPrimary.opacity(0.16), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.top, 18)

                Spacer().frame(height: 120)
            }
        }
        .vitaScreenBg()
        .task {
            async let statsTask: () = loadStats()
            async let profileTask: () = loadProfile()
            _ = await (statsTask, profileTask)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 10) {
                Button(action: { onNavigateToConfiguracoes?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.80))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Perfil")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.92))
                    Text("Suas informações")
                        .font(.system(size: 11))
                        .foregroundStyle(goldSubtle.opacity(0.40))
                }
            }

            Spacer()

            Button(action: { onNavigateToConfiguracoes?() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(goldSubtle.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Profile Header (avatar + name + email + uni combined)

    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar ring — 80px total, inner 62px, level badge bottom-center
            ZStack(alignment: .bottom) {
                ZStack {
                    // Background ring track
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 3)
                        .frame(width: 74, height: 74)

                    // XP arc
                    let xpFrac: Double = {
                        guard let s = gamStats, (s.currentLevelXp + s.xpToNextLevel) > 0 else { return 0.625 }
                        return Double(s.currentLevelXp) / Double(s.currentLevelXp + s.xpToNextLevel)
                    }()
                    Circle()
                        .trim(from: 0, to: xpFrac)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.784, blue: 0.392).opacity(0.90),
                                    Color(red: 0.784, green: 0.588, blue: 0.235).opacity(0.70)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 74, height: 74)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.20), radius: 8)

                    // Avatar inner — 62px
                    avatarInner
                }
                .frame(width: 80, height: 80)

                // Level badge — bottom-center, overlaps ring by 6pt
                levelBadge
                    .offset(y: 6)
            }
            .padding(.bottom, 6) // space for badge overflow

            // Name / email / uni
            VStack(spacing: 0) {
                Text(authManager.userName ?? "Estudante")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.988, blue: 0.973).opacity(0.96))
                    .kerning(-0.6)

                if let email = authManager.userEmail {
                    Text(email)
                        .font(.system(size: 12))
                        .foregroundStyle(goldSubtle.opacity(0.40))
                        .padding(.top, 2)
                }

                let uni = UserDefaults.standard.string(forKey: "vita_onboarding_university") ?? ""
                let semester = UserDefaults.standard.integer(forKey: "vita_onboarding_semester")
                if !uni.isEmpty {
                    Text("\(uni)\(semester > 0 ? " · \(semester)o Periodo" : "")")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.60))
                        .padding(.top, 4)
                }
            }
            .multilineTextAlignment(.center)
        }
    }

    private var avatarInner: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.35),
                            Color(red: 0.627, green: 0.471, blue: 0.235).opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 62, height: 62)

            if let imageURL = authManager.userImage.flatMap(URL.init(string:)) {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    avatarInitial
                }
                .frame(width: 62, height: 62)
                .clipShape(Circle())
            } else {
                avatarInitial
            }
        }
    }

    private var avatarInitial: some View {
        Text(String((authManager.userName ?? "V").prefix(1)).uppercased())
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(Color(red: 1.0, green: 0.945, blue: 0.843).opacity(0.80))
    }

    @ViewBuilder
    private var levelBadge: some View {
        let level = gamStats?.level ?? 7
        Text("Lv \(level)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.40),
                        Color(red: 0.549, green: 0.392, blue: 0.196).opacity(0.28)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.32), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 5, y: 2)
    }

    // MARK: - XP Bar (inside glass card)

    private var xpBarSection: some View {
        VStack(spacing: 6) {
            let currentXp = gamStats?.currentLevelXp ?? 1250
            let totalXp = (gamStats.map { $0.currentLevelXp + $0.xpToNextLevel }) ?? 2000
            let level = gamStats?.level ?? 7
            let progress: Double = totalXp > 0 ? Double(currentXp) / Double(totalXp) : 0.625

            HStack {
                Text(formatXP(currentXp) + " / " + formatXP(totalXp) + " XP")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.65))

                Spacer()

                Text("Level \(level) → \(level + 1)")
                    .font(.system(size: 10))
                    .foregroundStyle(goldSubtle.opacity(0.35))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(goldAccent.opacity(0.10))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [goldPrimary, goldAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * progress, 4), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(14)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1))
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(goldSubtle.opacity(0.35))
                .kerning(0.4)
            Spacer()
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Conquistas (emoji badges, horizontal scroll inside glass card)

    private var conquistas: some View {
        badgesScrollView
            .padding(14)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1))
            .padding(.horizontal, 14)
            .padding(.top, 10)
    }

    private var badgesScrollView: some View {
        let staticBadges: [(emoji: String, label: String, earned: Bool)] = [
            ("🔥", "7 dias\nseguidos", true),
            ("📚", "500\nquestoes", true),
            ("🎯", "90% em\nsimulado", true),
            ("⚡", "Flash\nmaster", true),
            ("🏆", "Top 10\nturma", false)
        ]

        if let apiBadges = gamStats?.badges, !apiBadges.isEmpty {
            return AnyView(
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(apiBadges.prefix(5)), id: \.id) { badge in
                            apiBadgeItem(badge)
                        }
                    }
                    .padding(.vertical, 2)
                }
            )
        } else {
            return AnyView(
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(staticBadges.indices, id: \.self) { i in
                            let b = staticBadges[i]
                            emojiaBadgeItem(emoji: b.emoji, label: b.label, earned: b.earned)
                        }
                    }
                    .padding(.vertical, 2)
                }
            )
        }
    }

    private func emojiaBadgeItem(emoji: String, label: String, earned: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                VitaColors.glassInnerLight.opacity(earned ? 0.18 : 0.04),
                                Color(red: 0.549, green: 0.392, blue: 0.176).opacity(earned ? 0.08 : 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(goldPrimary.opacity(earned ? 0.14 : 0.06), lineWidth: 1)
                    )
                Text(emoji)
                    .font(.system(size: 20))
                    .opacity(earned ? 1.0 : 0.30)
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(goldSubtle.opacity(earned ? 0.35 : 0.15))
                .multilineTextAlignment(.center)
        }
        .frame(minWidth: 64)
    }

    private func apiBadgeItem(_ badge: BadgeWithStatus) -> some View {
        emojiaBadgeItem(
            emoji: mapBadgeEmoji(badge.icon),
            label: badge.name,
            earned: badge.earned
        )
    }

    // MARK: - Estatisticas (centered, gold values, no icons)

    private var estatisticas: some View {
        let questions = gamStats?.totalQuestionsAnswered ?? 0
        let flashcards = gamStats?.totalCardsReviewed ?? 0
        let studyHours = Int(profile?.totalStudyHours ?? 0)
        let streak = gamStats?.currentStreak ?? 0

        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            statCard(value: formatNumber(questions), label: "Questões")
            statCard(value: formatNumber(flashcards), label: "Flashcards")
            statCard(value: "\(studyHours)h", label: "Horas estudo")
            statCard(
                value: "\(streak)",
                label: "Streak",
                valueColor: Color(red: 1.0, green: 0.627, blue: 0.314).opacity(0.90),
                icon: "flame.fill"
            )
        }
        .padding(.top, 10)
    }

    private func statCard(
        value: String,
        label: String,
        valueColor: Color? = nil,
        icon: String? = nil
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(valueColor ?? Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.90))
                    .kerning(-0.44)
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.627, blue: 0.314).opacity(0.90))
                }
            }

            Text(label.uppercased())
                .font(.system(size: 10))
                .foregroundStyle(goldSubtle.opacity(0.35))
                .kerning(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(
            ZStack {
                // Base fill — matches mockup rgba(12,9,7,0.92)
                RoundedRectangle(cornerRadius: 14)
                    .fill(VitaColors.glassBg)
                // Inner radial glow — subtle gold warmth from center
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        RadialGradient(
                            colors: [
                                VitaColors.accent.opacity(0.06),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func loadStats() async {
        gamStats = try? await container.api.getGamificationStats()
    }

    private func loadProfile() async {
        profile = try? await container.api.getProfile()
    }

    private func mapBadgeEmoji(_ icon: String) -> String {
        let mapping: [String: String] = [
            "trophy": "🏆", "fire": "🔥", "school": "🎓", "moon": "🌙",
            "sword": "⚔️", "star": "⭐", "book": "📚", "target": "🎯",
            "heart": "❤️", "flash": "⚡", "bolt": "⚡"
        ]
        return mapping[icon] ?? "🏅"
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            let v = Double(n) / 1000.0
            let s = String(format: "%.1f", v)
            return s.hasSuffix(".0") ? s.dropLast(2) + "k" : s + "k"
        }
        return "\(n)"
    }

    // Brazilian thousands format: 1250 → "1.250", 2000 → "2.000"
    private func formatXP(_ n: Int) -> String {
        if n >= 1000 {
            return "\(n / 1000).\(String(format: "%03d", n % 1000))"
        }
        return "\(n)"
    }
}
