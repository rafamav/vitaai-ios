import SwiftUI

// MARK: - ProfileScreen
// Matches perfil-mobile-v1.html mockup exactly:
// 80px avatar ring, bottom-center level badge, XP bar, emoji badges,
// centered stats grid, glass edit button.
// This is the Profile TAB screen. Settings are in ConfiguracoesScreen.

struct ProfileScreen: View {
    let authManager: AuthManager

    var onNavigateToConfiguracoes: (() -> Void)?
    var onNavigateToAchievements:  (() -> Void)?

    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    @State private var gamStats: GamificationStatsResponse?
    @State private var profile: ProfileResponse?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Shell §5.2.1: tab principal não tem chevron back nem cabeçalho redundante.
                // Só ícone gear flutuante no canto direito.
                gearFloatingButton
                    .padding(.top, 8)
                    .padding(.horizontal, 20)

                // AVATAR + NAME
                profileHeader
                    .padding(.top, 12)

                // XP BAR inside glass card
                xpBarSection
                    .padding(.top, 12)
                    .padding(.horizontal, 14)

                // CONQUISTAS
                sectionLabel("Conquistas")
                    .padding(.top, 20)
                conquistas

                // ESTATISTICAS
                sectionLabel("Estatisticas")
                    .padding(.top, 20)
                estatisticas
                    .padding(.horizontal, 14)

                // EDITAR PERFIL glass button
                Button(action: { onNavigateToConfiguracoes?() }) {
                    Text("Editar Perfil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(VitaColors.glassInnerLight.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(VitaColors.accentHover.opacity(0.16), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.top, 18)

                Spacer().frame(height: 120)
            }
        }
        .refreshable {
            async let statsTask: () = loadStats()
            async let profileTask: () = loadProfile()
            _ = await (statsTask, profileTask)
        }
        .task {
            async let statsTask: () = loadStats()
            async let profileTask: () = loadProfile()
            _ = await (statsTask, profileTask)
            ScreenLoadContext.finish(for: "Profile")
        }
        .trackScreen("Profile")
    }

    // MARK: - Header (gear-only, sem chevron back, sem título redundante)

    private var gearFloatingButton: some View {
        HStack {
            Spacer()
            Button(action: { onNavigateToConfiguracoes?() }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Configurações")
        }
    }

    // MARK: - Profile Header (avatar + name + email + uni)

    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Avatar ring 80px total, inner 62px, level badge bottom-center
            ZStack(alignment: .bottom) {
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.06), lineWidth: 3)
                        .frame(width: 74, height: 74)

                    let xpFrac: Double = {
                        guard let s = gamStats, (s.currentLevelXp + s.xpToNextLevel) > 0 else { return 0.625 }
                        return Double(s.currentLevelXp) / Double(s.currentLevelXp + s.xpToNextLevel)
                    }()
                    Circle()
                        .trim(from: 0, to: xpFrac)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    VitaColors.accentHover.opacity(0.90),
                                    VitaColors.accent.opacity(0.70)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .frame(width: 74, height: 74)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: VitaColors.accent.opacity(0.20), radius: 8)

                    avatarInner
                }
                .frame(width: 80, height: 80)

                levelBadge
                    .offset(y: 6)
            }
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                Text(authManager.userName ?? "Estudante")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .kerning(-0.6)

                if let email = authManager.userEmail {
                    Text(email)
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textSecondary)
                        .padding(.top, 2)
                }

                let uni = profile?.university ?? ""
                let semester = profile?.semester ?? 0
                if !uni.isEmpty {
                    Text("\(uni)\(semester > 0 ? " - \(semester)o Periodo" : "")")
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.60))
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
                            VitaColors.accent.opacity(0.35),
                            VitaColors.accentDark.opacity(0.22)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 62, height: 62)

            if let imageURL = authManager.userImage.flatMap(URL.init(string:)) {
                CachedAsyncImage(url: imageURL) {
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
            .foregroundStyle(VitaColors.accentLight.opacity(0.80))
    }

    @ViewBuilder
    private var levelBadge: some View {
        let level = gamStats?.level ?? 7
        Text("Lv \(level)")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(VitaColors.accentLight.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [
                        VitaColors.accent.opacity(0.40),
                        VitaColors.accentDark.opacity(0.28)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(VitaColors.accentLight.opacity(0.32), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.35), radius: 5, y: 2)
    }

    // MARK: - XP Bar (inside glass card)

    private var xpBarSection: some View {
        VitaGlassCard(cornerRadius: 14) { VStack(spacing: 6) {
            let currentXp = gamStats?.currentLevelXp ?? 1250
            let totalXp = (gamStats.map { $0.currentLevelXp + $0.xpToNextLevel }) ?? 2000
            let level = gamStats?.level ?? 7
            let progress: Double = totalXp > 0 ? Double(currentXp) / Double(totalXp) : 0.625

            HStack {
                Text(formatXP(currentXp) + " / " + formatXP(totalXp) + " XP")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.65))

                Spacer()

                Text("Level \(level) \u{2192} \(level + 1)")
                    .font(.system(size: 10))
                    .foregroundStyle(VitaColors.textTertiary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(VitaColors.accent.opacity(0.10))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(VitaColors.goldBarGradient)
                        .frame(width: max(geo.size.width * progress, 4), height: 6)
                }
            }
            .frame(height: 6)
        } }
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(VitaColors.sectionLabel)
                .kerning(0.8)
            Spacer()
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Conquistas (emoji badges, horizontal scroll inside glass card)

    private var conquistas: some View {
        VitaGlassCard(cornerRadius: 14) {
            badgesScrollView.padding(14)
        }
        .padding(.horizontal, 14)
        .padding(.top, 10)
    }

    @ViewBuilder
    private var badgesScrollView: some View {
        let staticBadges: [(emoji: String, label: String, earned: Bool)] = [
            ("\u{1F525}", "7 dias\nseguidos", true),
            ("\u{1F4DA}", "500\nquestoes", true),
            ("\u{1F3AF}", "90% em\nsimulado", true),
            ("\u{26A1}", "Flash\nmaster", true),
            ("\u{1F3C6}", "Top 10\nturma", false)
        ]

        if let apiBadges = gamStats?.badges, !apiBadges.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(apiBadges.prefix(5)), id: \.id) { badge in
                        emojiBadgeItem(
                            emoji: mapBadgeEmoji(badge.icon),
                            label: badge.name,
                            earned: badge.earned
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(staticBadges.indices, id: \.self) { i in
                        let b = staticBadges[i]
                        emojiBadgeItem(emoji: b.emoji, label: b.label, earned: b.earned)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func emojiBadgeItem(emoji: String, label: String, earned: Bool) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                VitaColors.glassInnerLight.opacity(earned ? 0.18 : 0.04),
                                VitaColors.accentDark.opacity(earned ? 0.08 : 0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(VitaColors.accentHover.opacity(earned ? 0.14 : 0.06), lineWidth: 1)
                    )
                Text(emoji)
                    .font(.system(size: 20))
                    .opacity(earned ? 1.0 : 0.30)
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(VitaColors.textTertiary.opacity(earned ? 1.0 : 0.50))
                .multilineTextAlignment(.center)
        }
        .frame(minWidth: 64)
    }

    // MARK: - Estatisticas (centered, gold values, no icons — matches mockup 2x2)

    private var estatisticas: some View {
        let questions = gamStats?.totalQuestionsAnswered ?? 1847
        let flashcards = gamStats?.totalCardsReviewed ?? 623
        let studyHours = 48  // TODO: load from getProgress() — was incorrectly on ProfileResponse
        let streak = gamStats?.currentStreak ?? 7

        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            statCard(value: formatNumber(questions), label: "Questões")
            statCard(value: formatNumber(flashcards), label: "Flashcards")
            statCard(value: "\(studyHours)h", label: "Horas estudo")
            statCard(
                value: "\(streak) \u{1F525}",
                label: "Streak",
                valueColor: VitaColors.dataAmber.opacity(0.90)
            )
        }
        .padding(.top, 10)
    }

    private func statCard(
        value: String,
        label: String,
        valueColor: Color? = nil
    ) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(valueColor ?? VitaColors.accentLight.opacity(0.90))
                .kerning(-0.44)

            Text(label.uppercased())
                .font(.system(size: 10))
                .foregroundStyle(VitaColors.textTertiary)
                .kerning(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .vitaGlassCard(cornerRadius: 14)
    }

    // MARK: - Helpers

    private func loadStats() async {
        gamStats = try? await container.api.getGamificationStats()
    }

    private func loadProfile() async {
        // Read from the shared AppDataManager so this tab doesn't issue a
        // duplicate /api/profile call when Faculdade/Dashboard already
        // hydrated the cache. Falls back to a direct fetch if the store is
        // still empty (e.g. user opens Perfil before any other tab loads).
        if let cached = appData.profile {
            profile = cached
            return
        }
        profile = try? await container.api.getProfile()
    }

    private func mapBadgeEmoji(_ icon: String) -> String {
        let mapping: [String: String] = [
            "trophy": "\u{1F3C6}", "fire": "\u{1F525}", "school": "\u{1F393}", "moon": "\u{1F319}",
            "sword": "\u{2694}\u{FE0F}", "star": "\u{2B50}", "book": "\u{1F4DA}", "target": "\u{1F3AF}",
            "heart": "\u{2764}\u{FE0F}", "flash": "\u{26A1}", "bolt": "\u{26A1}"
        ]
        return mapping[icon] ?? "\u{1F3C5}"
    }

    private func formatNumber(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%d.%03d", n / 1000, n % 1000)
        }
        return "\(n)"
    }

    private func formatXP(_ n: Int) -> String {
        if n >= 1000 {
            return "\(n / 1000).\(String(format: "%03d", n % 1000))"
        }
        return "\(n)"
    }
}
