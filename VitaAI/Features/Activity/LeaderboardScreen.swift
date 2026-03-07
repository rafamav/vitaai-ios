import SwiftUI

private let PERIODS: [(key: String, label: String)] = [
    ("daily", "Hoje"),
    ("weekly", "Semana"),
    ("monthly", "Mes"),
    ("alltime", "Geral"),
]

struct LeaderboardScreen: View {
    let onBack: () -> Void

    @Environment(\.appContainer) private var container
    @State private var vm: LeaderboardViewModel?
    @State private var selectedPeriod = "weekly"

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                }
                Text("Ranking")
                    .font(VitaTypography.titleLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Period chips
            HStack(spacing: 8) {
                ForEach(PERIODS, id: \.key) { period in
                    Button(action: { selectedPeriod = period.key }) {
                        Text(period.label)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(
                                selectedPeriod == period.key
                                    ? VitaColors.black
                                    : VitaColors.textSecondary
                            )
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                selectedPeriod == period.key
                                    ? VitaColors.accent
                                    : VitaColors.glassBg
                            )
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(
                                    selectedPeriod == period.key
                                        ? Color.clear
                                        : VitaColors.glassBorder,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            if let vm, !vm.isLoading {
                if vm.entries.isEmpty {
                    Spacer()
                    Text("Nenhum dado para este periodo")
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textTertiary)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            ForEach(vm.entries) { entry in
                                LeaderboardRow(entry: entry)
                            }
                            Spacer().frame(height: 100)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            } else {
                Spacer()
                ProgressView()
                    .tint(VitaColors.accent)
                Spacer()
            }
        }
        .navigationBarHidden(true)
        .task(id: selectedPeriod) {
            if vm == nil {
                vm = LeaderboardViewModel(api: container.api)
            }
            await vm?.load(period: selectedPeriod)
        }
    }
}

// MARK: - Row

private struct LeaderboardRow: View {
    let entry: LeaderboardEntry

    private var rankColor: Color {
        switch entry.rank {
        case 1: return Color(red: 1, green: 0.84, blue: 0)       // gold
        case 2: return Color(red: 0.75, green: 0.75, blue: 0.75) // silver
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)    // bronze
        default: return VitaColors.textTertiary
        }
    }

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                // Rank badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(entry.rank <= 3 ? rankColor.opacity(0.15) : VitaColors.surfaceElevated)
                        .frame(width: 36, height: 36)
                    if entry.rank <= 3 {
                        Image(systemName: "medal.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(rankColor)
                    } else {
                        Text("\(entry.rank)")
                            .font(VitaTypography.labelMedium)
                            .bold()
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.displayName)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                    if let level = entry.level {
                        Text("Nivel \(level)")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(entry.xp)")
                        .font(VitaTypography.titleSmall)
                        .bold()
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("XP")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            .padding(12)
        }
    }
}
