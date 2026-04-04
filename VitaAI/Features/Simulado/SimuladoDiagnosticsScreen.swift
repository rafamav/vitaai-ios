import SwiftUI

private let periodOptions: [(String, String)] = [
    ("7 dias", "7d"),
    ("14 dias", "14d"),
    ("30 dias", "30d"),
    ("90 dias", "90d"),
]

private let difficultyLabels = ["easy": "Fácil", "medium": "Médio", "hard": "Difícil"]

struct SimuladoDiagnosticsScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: SimuladoViewModel?
    let onBack: () -> Void
    @State private var selectedPeriod = "30d"

    var body: some View {
        Group {
            if let vm {
                diagnosticsContent(vm: vm)
            } else {
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    ProgressView().tint(VitaColors.tealAccent)
                }
            }
        }
        .background(VitaColors.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            if vm == nil { vm = SimuladoViewModel(api: container.api) }
            vm?.loadDiagnostics(period: selectedPeriod)
        }
    }

    @ViewBuilder
    private func diagnosticsContent(vm: SimuladoViewModel) -> some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(width: 44, height: 44)
                }
                Text("Diagnóstico")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // Period chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(periodOptions, id: \.0) { (label, value) in
                        Button {
                            selectedPeriod = value
                            vm.loadDiagnostics(period: value)
                        } label: {
                            Text(label)
                                .font(.system(size: 12, weight: selectedPeriod == value ? .semibold : .regular))
                                .foregroundStyle(selectedPeriod == value ? VitaColors.tealAccent : VitaColors.textPrimary)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(selectedPeriod == value ? VitaColors.tealAccent.opacity(0.15) : VitaColors.glassBg)
                                .overlay(Capsule().stroke(selectedPeriod == value ? VitaColors.tealAccent : VitaColors.glassBorder, lineWidth: 1))
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 6)

            if vm.state.isLoading {
                Spacer()
                ProgressView().tint(VitaColors.tealAccent)
                Spacer()
            } else if let diag = vm.state.diagnostics {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // Overall stats card
                        OverallStatsCard(overall: diag.overall)
                            .padding(.top, 4)

                        // By subject
                        if !diag.bySubject.isEmpty {
                            diagSectionHeader("Por Matéria")
                            ForEach(diag.bySubject) { stat in
                                SubjectStatCard(stat: stat)
                            }
                        }

                        // Weak topics
                        if !diag.weakTopics.isEmpty {
                            diagSectionHeader("Temas que precisam de atenção")
                            ForEach(diag.weakTopics) { topic in
                                WeakTopicCard(topic: topic)
                            }
                        }

                        // By difficulty
                        if !diag.byDifficulty.isEmpty {
                            DifficultyCard(difficulties: diag.byDifficulty)
                        }

                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                Spacer()
                VitaEmptyState(
                    title: "Sem dados ainda",
                    message: "Complete alguns simulados para ver seu diagnóstico de desempenho.",
                    actionText: nil,
                    onAction: nil
                )
                Spacer()
            }
        }
    }

    private func diagSectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
            Spacer()
        }
        .padding(.top, 4)
    }
}

// MARK: - Overall Stats Card

private struct OverallStatsCard: View {
    let overall: OverallStats
    private var avgPercent: Int { Int(overall.avgScore * 100) }
    private var bestPercent: Int { Int(overall.bestScore * 100) }
    private var correctPercent: Int { Int(overall.correctRate * 100) }
    private var correctColor: Color {
        correctPercent >= 70 ? VitaColors.dataGreen : correctPercent >= 50 ? VitaColors.dataAmber : VitaColors.dataRed
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Visão Geral")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
            }
            HStack {
                Spacer()
                DiagMiniStat(label: "Simulados", value: "\(overall.totalAttempts)")
                Spacer()
                DiagMiniStat(label: "Média", value: "\(avgPercent)%", valueColor: VitaColors.dataGreen)
                Spacer()
                DiagMiniStat(label: "Melhor", value: "\(bestPercent)%", valueColor: VitaColors.tealAccent)
                Spacer()
            }
            HStack {
                Spacer()
                DiagMiniStat(label: "Questões", value: "\(overall.totalQuestions)")
                Spacer()
                DiagMiniStat(label: "Acerto", value: "\(correctPercent)%", valueColor: correctColor)
                Spacer()
            }
        }
        .padding(16)
        .background(VitaColors.glassBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VitaColors.glassBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct DiagMiniStat: View {
    let label: String
    let value: String
    var valueColor: Color = .white.opacity(0.85)
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(VitaColors.textTertiary)
        }
    }
}

// MARK: - Subject Stat Card

private struct SubjectStatCard: View {
    let stat: SubjectStat
    private var ratePercent: Int { Int(stat.correctRate * 100) }
    private var barColor: Color {
        ratePercent >= 70 ? VitaColors.dataGreen : ratePercent >= 50 ? VitaColors.dataAmber : VitaColors.dataRed
    }
    private var trendIcon: String {
        switch stat.trend {
        case "up": return "arrow.up.right"
        case "down": return "arrow.down.right"
        default: return "minus"
        }
    }
    private var trendColor: Color {
        switch stat.trend {
        case "up": return VitaColors.dataGreen
        case "down": return VitaColors.dataRed
        default: return VitaColors.textTertiary
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(stat.subject)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                    Image(systemName: trendIcon)
                        .font(.system(size: 12))
                        .foregroundStyle(trendColor)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(VitaColors.glassBorder)
                        RoundedRectangle(cornerRadius: 3).fill(barColor)
                            .frame(width: geo.size.width * CGFloat(stat.correctRate).clamped(to: 0...1))
                    }
                }
                .frame(height: 6)
                Text("\(stat.attempts) tentativa\(stat.attempts != 1 ? "s" : "")")
                    .font(.system(size: 10))
                    .foregroundStyle(VitaColors.textTertiary)
            }

            Text("\(ratePercent)%")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(barColor)
        }
        .padding(14)
        .background(VitaColors.glassBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VitaColors.glassBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Weak Topic Card

private struct WeakTopicCard: View {
    let topic: WeakTopic
    private var ratePercent: Int { Int(topic.correctRate * 100) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundStyle(VitaColors.dataAmber)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(topic.subject)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("\(ratePercent)%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VitaColors.dataRed)
                }
                if !topic.suggestion.isEmpty {
                    Text(topic.suggestion)
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textSecondary)
                        .lineSpacing(2)
                }
            }
        }
        .padding(14)
        .background(VitaColors.dataAmber.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VitaColors.dataAmber.opacity(0.2), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Difficulty Card

private struct DifficultyCard: View {
    let difficulties: [DifficultyStat]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Por Dificuldade")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)

            ForEach(difficulties) { diff in
                let label = difficultyLabels[diff.difficulty] ?? diff.difficulty
                let ratePercent = Int(diff.correctRate * 100)
                let barColor: Color = ratePercent >= 70 ? VitaColors.dataGreen : ratePercent >= 50 ? VitaColors.dataAmber : VitaColors.dataRed

                HStack(spacing: 10) {
                    Text(label)
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(width: 50, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(VitaColors.glassBorder)
                            RoundedRectangle(cornerRadius: 3).fill(barColor)
                                .frame(width: geo.size.width * CGFloat(diff.correctRate).clamped(to: 0...1))
                        }
                    }
                    .frame(height: 6)

                    Text("\(ratePercent)%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(barColor)
                        .frame(width: 34, alignment: .trailing)
                }
            }
        }
        .padding(16)
        .background(VitaColors.glassBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VitaColors.glassBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Extensions

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(self, range.upperBound))
    }
}
