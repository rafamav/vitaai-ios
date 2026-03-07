import SwiftUI

// MARK: - Gamification Event Manager
// Central hub for XP toasts, level up, and badge unlock overlays.
// Registered in AppContainer, used as global overlay in AppRouter.

@MainActor @Observable
final class GamificationEventManager {
    // Uses the existing VitaXpToastState from DesignSystem
    let xpToast = VitaXpToastState()

    var levelUpEvent: LevelUpEvent?
    var badgeEvent: BadgeUnlockEvent?

    struct LevelUpEvent: Identifiable {
        let id = UUID()
        let newLevel: Int
    }

    struct BadgeUnlockEvent: Identifiable {
        let id = UUID()
        let name: String
        let description: String
        let icon: String
    }

    /// Process the response from POST /api/activity
    func handleActivityResponse(_ data: LogActivityResponse, previousLevel: Int?) {
        if data.xpAwarded > 0 {
            let source = XpSource.dailyLogin // generic — the toast shows XP amount
            xpToast.show(XpEvent(amount: data.xpAwarded, source: source))
        }

        if let prev = previousLevel, data.level > prev {
            Task {
                try? await Task.sleep(for: .seconds(2.2))
                levelUpEvent = LevelUpEvent(newLevel: data.level)
            }
        }

        for badge in data.newBadges {
            Task {
                let delay: Double = (previousLevel != nil && data.level > previousLevel!) ? 5.5 : 2.2
                try? await Task.sleep(for: .seconds(delay))
                badgeEvent = BadgeUnlockEvent(name: badge.name, description: badge.description, icon: badge.icon)
            }
        }
    }
}

// MARK: - Level Up Overlay

struct VitaLevelUpOverlay: View {
    let event: GamificationEventManager.LevelUpEvent?
    @State private var visible = false
    @State private var ringProgress: CGFloat = 0
    @State private var numberScale: CGFloat = 0.3

    var body: some View {
        ZStack {
            if visible, let ev = event {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [VitaColors.accent.opacity(0.3), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)
                            .scaleEffect(visible ? 1.5 : 0.5)

                        ProgressRingView(
                            progress: ringProgress,
                            size: 100,
                            strokeWidth: 4,
                            trackColor: VitaColors.surfaceBorder.opacity(0.3),
                            progressColor: VitaColors.accent
                        )

                        Text("\(ev.newLevel)")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(.white)
                            .scaleEffect(numberScale)
                    }

                    VStack(spacing: 4) {
                        Text("LEVEL UP!")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VitaColors.accent)
                            .tracking(3)

                        Text("Nivel \(ev.newLevel) alcancado")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: visible)
        .onChange(of: event?.id) { _, _ in
            guard event != nil else { return }
            ringProgress = 0
            numberScale = 0.3
            visible = true
            withAnimation(.easeOut(duration: 1.5)) {
                ringProgress = 1
            }
            withAnimation(.spring(response: 0.5)) {
                numberScale = 1
            }
            Task {
                try? await Task.sleep(for: .seconds(3.5))
                visible = false
            }
        }
    }
}

// MARK: - Badge Unlock Overlay

struct VitaBadgeUnlockOverlay: View {
    let event: GamificationEventManager.BadgeUnlockEvent?
    @State private var visible = false
    @State private var emojiScale: CGFloat = 0

    private static let badgeEmoji: [String: String] = [
        "school": "\u{1F393}", "style": "\u{1F0CF}", "auto_awesome": "\u{2728}",
        "emoji_events": "\u{1F3C6}", "menu_book": "\u{1F4DA}",
        "local_fire_department": "\u{1F525}", "whatshot": "\u{1F525}",
        "military_tech": "\u{1F396}\u{FE0F}", "trending_up": "\u{1F4C8}",
        "workspace_premium": "\u{1F48E}", "edit_note": "\u{1F4DD}",
        "dark_mode": "\u{1F989}", "wb_sunny": "\u{1F305}",
        "sports_esports": "\u{1F3AE}", "chat": "\u{1F4AC}",
    ]

    var body: some View {
        ZStack {
            if visible, let ev = event {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [VitaColors.accent.opacity(0.25), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 130, height: 130)

                        Text(Self.badgeEmoji[ev.icon] ?? "\u{1F3C5}")
                            .font(.system(size: 56))
                            .scaleEffect(emojiScale)
                    }

                    VStack(spacing: 4) {
                        Text("CONQUISTA DESBLOQUEADA")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VitaColors.accent)
                            .tracking(2)

                        Text(ev.name)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)

                        Text(ev.description)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: visible)
        .onChange(of: event?.id) { _, _ in
            guard event != nil else { return }
            emojiScale = 0
            visible = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                emojiScale = 1
            }
            Task {
                try? await Task.sleep(for: .seconds(3.5))
                visible = false
            }
        }
    }
}
