import SwiftUI

private let ACTION_LABELS: [String: String] = [
    "flashcard_review": "Revisou flashcard",
    "flashcard_easy": "Flashcard facil",
    "question_answered": "Respondeu questao",
    "chat_message": "Mensagem no chat",
    "note_created": "Criou nota",
    "simulado_complete": "Completou simulado",
    "daily_login": "Login diario",
    "deck_completed": "Deck completo",
    "osce_completed": "OSCE completo",
    "qbank_session_complete": "Sessao QBank",
    "studio_generated": "Conteudo gerado",
]

private let ACTION_ICONS: [String: String] = [
    "flashcard_review": "graduationcap.fill",
    "flashcard_easy": "graduationcap.fill",
    "question_answered": "star.fill",
    "chat_message": "bubble.left.fill",
    "note_created": "note.text",
    "simulado_complete": "trophy.fill",
    "daily_login": "flame.fill",
    "deck_completed": "trophy.fill",
    "osce_completed": "stethoscope",
    "qbank_session_complete": "list.bullet.clipboard.fill",
    "studio_generated": "wand.and.stars",
]

struct ActivityFeedScreen: View {
    let onBack: () -> Void
    let onLeaderboard: () -> Void

    @Environment(\.appContainer) private var container
    @State private var vm: ActivityFeedViewModel?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                }
                Text("Atividade")
                    .font(VitaTypography.titleLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                Button(action: onLeaderboard) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(VitaColors.accent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            if let vm, !vm.isLoading {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Stats card
                        if let stats = vm.stats {
                            StatsCard(stats: stats)
                                .padding(.horizontal, 20)
                        }

                        // Feed
                        if vm.feed.isEmpty {
                            Text("Nenhuma atividade ainda")
                                .font(VitaTypography.bodyMedium)
                                .foregroundStyle(VitaColors.textTertiary)
                                .padding(.top, 48)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(vm.feed) { item in
                                    FeedRow(item: item)
                                }
                            }
                            .padding(.horizontal, 20)
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 8)
                }
            } else {
                Spacer()
                ProgressView()
                    .tint(VitaColors.accent)
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .task {
            if vm == nil {
                vm = ActivityFeedViewModel(api: container.api)
            }
            await vm?.load()
        }
    }
}

// MARK: - Stats Card

private struct StatsCard: View {
    let stats: GamificationStatsResponse

    var body: some View {
        VitaGlassCard {
            VStack(spacing: 12) {
                HStack {
                    Text("Nivel \(stats.level)")
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                    Spacer()
                    Text("+\(stats.dailyXp) XP hoje")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.accent)
                }

                // XP progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(VitaColors.surfaceElevated)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(VitaColors.accent)
                            .frame(
                                width: geo.size.width * progressFraction,
                                height: 6
                            )
                    }
                }
                .frame(height: 6)

                Text("\(stats.currentLevelXp) / \(stats.xpToNextLevel) XP")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    MiniStat(label: "Sequencia", value: "\(stats.currentStreak)d")
                    Spacer()
                    MiniStat(label: "Cards", value: "\(stats.totalCardsReviewed)")
                    Spacer()
                    MiniStat(label: "Questoes", value: "\(stats.totalQuestionsAnswered)")
                }
            }
            .padding(16)
        }
    }

    private var progressFraction: CGFloat {
        guard stats.xpToNextLevel > 0 else { return 0 }
        return min(1, CGFloat(stats.currentLevelXp) / CGFloat(stats.xpToNextLevel))
    }
}

private struct MiniStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(VitaTypography.titleSmall)
                .foregroundStyle(VitaColors.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(VitaColors.textTertiary)
        }
    }
}

// MARK: - Feed Row

private struct FeedRow: View {
    let item: ActivityFeedItem

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VitaColors.surfaceElevated)
                        .frame(width: 36, height: 36)
                    Image(systemName: ACTION_ICONS[item.action] ?? "clock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(VitaColors.textSecondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(ACTION_LABELS[item.action] ?? item.action)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text(formatTimeAgo(item.createdAt))
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer()

                if item.xpAwarded > 0 {
                    Text("+\(item.xpAwarded) XP")
                        .font(VitaTypography.labelMedium)
                        .bold()
                        .foregroundStyle(VitaColors.accent)
                }
            }
            .padding(12)
        }
    }
}

private func formatTimeAgo(_ dateStr: String) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr) else {
        return dateStr
    }
    let diff = Date().timeIntervalSince(date)
    let mins = Int(diff / 60)
    switch mins {
    case ..<1: return "agora"
    case ..<60: return "\(mins)min"
    case ..<1440: return "\(mins / 60)h"
    default: return "\(mins / 1440)d"
    }
}
