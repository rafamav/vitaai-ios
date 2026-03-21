import SwiftUI

// MARK: - AchievementsScreen
// Full achievements/badges page. Glassmorphism gold design.
// Source of truth: VitaDomain.allBadges + API (GET /api/activity/stats)
// Ref: Android AchievementsScreen.kt

struct AchievementsScreen: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: AchievementsViewModel?
    let onBack: () -> Void

    var body: some View {
        Group {
            if let vm = viewModel {
                AchievementsContent(vm: vm, onBack: onBack)
            } else {
                ZStack {
                    Color.clear
                    ProgressView()
                        .tint(VitaColors.accent)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel == nil {
                viewModel = AchievementsViewModel(api: container.api)
                Task { await viewModel?.load() }
            }
        }
    }
}

// MARK: - Content

private struct AchievementsContent: View {
    let vm: AchievementsViewModel
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            AchievementsTopBar(onBack: onBack)

            if vm.isLoading {
                Spacer()
                ProgressView()
                    .tint(VitaColors.accent)
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero summary
                        AchievementsHero(vm: vm)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .fadeUpAppear(delay: 0.05)

                        // Category sections
                        ForEach(Array(vm.categories.enumerated()), id: \.element.id) { idx, group in
                            AchievementsCategorySection(group: group, onBadgeTap: { badge in
                                vm.selectedBadge = badge
                            })
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .fadeUpAppear(delay: 0.12 + Double(idx) * 0.07)
                        }

                        Spacer().frame(height: 140)
                    }
                }
                .refreshable {
                    await vm.load()
                }
            }
        }
        .sheet(item: Binding(
            get: { vm.selectedBadge },
            set: { vm.selectedBadge = $0 }
        )) { badge in
            AchievementDetailSheet(badge: badge)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Top Bar

private struct AchievementsTopBar: View {
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.04))
                    .clipShape(Circle())
            }

            Text(NSLocalizedString("Conquistas", comment: "Achievements title"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.85))

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Hero Summary

private struct AchievementsHero: View {
    let vm: AchievementsViewModel

    var body: some View {
        VStack(spacing: 16) {
            // Trophy with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [VitaColors.accent.opacity(0.12), .clear],
                            center: .center, startRadius: 0, endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "trophy.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                VitaColors.accentLight.opacity(0.85),
                                VitaColors.accent.opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: VitaColors.accent.opacity(0.30), radius: 12)
            }

            // Count
            HStack(spacing: 4) {
                Text("\(vm.earnedCount)")
                    .font(.system(size: 28, weight: .heavy))
                    .foregroundStyle(VitaColors.accent.opacity(0.90))
                Text("/ \(vm.totalCount)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.25))
            }

            // Progress bar
            GeometryReader { geo in
                let progress = vm.totalCount > 0 ? CGFloat(vm.earnedCount) / CGFloat(vm.totalCount) : 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.04))
                        .frame(height: 4)
                    Capsule()
                        .fill(VitaColors.goldBarGradient)
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(width: 200, height: 4)

            // Stats row
            HStack(spacing: 20) {
                AchievementStatPill(
                    icon: "flame.fill",
                    value: "\(vm.currentStreak)",
                    label: NSLocalizedString("Streak", comment: ""),
                    color: VitaColors.dataAmber
                )
                AchievementStatPill(
                    icon: "arrow.up.right",
                    value: "Nv. \(vm.level)",
                    label: NSLocalizedString("Nivel", comment: ""),
                    color: VitaColors.accent
                )
                AchievementStatPill(
                    icon: "star.fill",
                    value: "\(vm.totalXp)",
                    label: NSLocalizedString("XP Total", comment: ""),
                    color: VitaColors.dataGreen
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}

private struct AchievementStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(color.opacity(0.60))
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.72))
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.25))
                .textCase(.uppercase)
        }
    }
}

// MARK: - Category Section

private struct AchievementsCategorySection: View {
    let group: BadgeCategoryGroup
    let onBadgeTap: (AchievementBadge) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack(spacing: 8) {
                Image(systemName: group.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(group.color.opacity(0.55))
                Text(group.displayName.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.40))
                    .kerning(1.0)
                Spacer()
                Text("\(group.earnedCount) / \(group.badges.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(group.color.opacity(0.45))
            }
            .padding(.bottom, 10)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(group.badges) { badge in
                    Button(action: { onBadgeTap(badge) }) {
                        AchievementBadgeCell(badge: badge, categoryColor: group.color)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .glassCard()
        }
    }
}

private struct AchievementBadgeCell: View {
    let badge: AchievementBadge
    let categoryColor: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if badge.isEarned {
                    // Earned — gold gradient background
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    categoryColor.opacity(0.20),
                                    categoryColor.opacity(0.06)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(categoryColor.opacity(0.18), lineWidth: 1)
                        )
                        .shadow(color: categoryColor.opacity(0.10), radius: 8)

                    Image(systemName: badge.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(categoryColor.opacity(0.75))
                } else {
                    // Locked
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.02))
                        .frame(width: 56, height: 56)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                        )

                    Image(systemName: "lock.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.white.opacity(0.18))
                }
            }

            Text(badge.name)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(
                    badge.isEarned
                        ? Color.white.opacity(0.45)
                        : Color.white.opacity(0.18)
                )
                .lineLimit(2)
                .multilineTextAlignment(.center)

            if badge.isEarned {
                Text("+\(badge.xpReward) XP")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(categoryColor.opacity(0.50))
            }
        }
        .opacity(badge.isEarned ? 1.0 : 0.40)
    }
}

// MARK: - Detail Sheet

private struct AchievementDetailSheet: View {
    let badge: AchievementBadge

    var body: some View {
        VStack(spacing: 20) {
            // Badge icon large
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                badge.isEarned ? VitaColors.accent.opacity(0.12) : Color.white.opacity(0.04),
                                .clear
                            ],
                            center: .center, startRadius: 0, endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                if badge.isEarned {
                    Image(systemName: badge.icon)
                        .font(.system(size: 44))
                        .foregroundStyle(VitaColors.accent.opacity(0.80))
                        .shadow(color: VitaColors.accent.opacity(0.25), radius: 12)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.white.opacity(0.25))
                }
            }
            .padding(.top, 20)

            // Name
            Text(badge.name)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(
                    badge.isEarned
                        ? VitaColors.goldText
                        : Color.white.opacity(0.50)
                )

            // Description
            Text(badge.description)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            // XP reward
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.accent.opacity(0.60))
                Text("+\(badge.xpReward) XP")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(VitaColors.accent.opacity(0.75))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(VitaColors.accent.opacity(0.08))
            .clipShape(Capsule())

            // Earned date
            if let dateStr = badge.earnedDateString {
                Text(String(format: NSLocalizedString("Conquistado em %@", comment: "Badge earned date"), dateStr))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.30))
            } else {
                Text(NSLocalizedString("Ainda nao conquistado", comment: "Badge not earned"))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.20))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(VitaColors.surface)
    }
}
