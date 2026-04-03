import SwiftUI

// MARK: - Result content

struct QBankResultContent: View {
    @Bindable var vm: QBankViewModel
    let onBack: () -> Void
    let onNewSession: () -> Void

    @State private var animatedProgress: Double = 0

    private static let letters = ["A", "B", "C", "D", "E"]

    var body: some View {
        let answered = vm.state.sessionAnswers.count
        let correct = vm.state.correctCount
        let wrong = answered - correct
        let total = vm.state.totalInSession
        let unanswered = total - answered
        let accuracy = vm.state.accuracy
        let scoreColor: Color = accuracy >= 0.7 ? VitaColors.dataGreen : accuracy >= 0.5 ? VitaColors.dataAmber : VitaColors.dataRed

        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(VitaColors.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    Text("Resultado")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 8)

                Spacer().frame(height: 32)

                // Score hero (mockup: score-ring 100x100, r=42, stroke 5)
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 5)
                            .frame(width: 100, height: 100)
                        Circle()
                            .trim(from: 0, to: animatedProgress)
                            .stroke(scoreColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(accuracy * 100))%")
                            .font(.system(size: 22, weight: .heavy))
                            .tracking(-0.04 * 22)
                            .foregroundStyle(scoreColor)
                    }

                    Text(Int(accuracy * 100) >= 70 ? "Excelente desempenho!" :
                         Int(accuracy * 100) >= 50 ? "Bom resultado!" : "Continue praticando")
                        .font(.system(size: 22, weight: .heavy))
                        .tracking(-0.04 * 22)
                        .foregroundStyle(scoreColor)

                    Text("\(correct) de \(total) questões corretas")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textSecondary)
                }
                .padding(.vertical, 26)
                .frame(maxWidth: .infinity)
                .background(VitaColors.glassBg)
                .overlay(RoundedRectangle(cornerRadius: 18).stroke(VitaColors.glassBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 16)
                .onAppear {
                    withAnimation(.easeOut(duration: 1.0).delay(0.2)) { animatedProgress = accuracy }
                }

                Spacer().frame(height: 10)

                // Stats (mockup: stats-3 glass cards)
                HStack(spacing: 8) {
                    QBankStatCard(value: "\(correct)", label: "Acertos", color: VitaColors.dataGreen)
                    QBankStatCard(value: "\(wrong)", label: "Erros", color: VitaColors.dataRed)
                    let s = vm.state.elapsedSeconds
                    let timeStr = s >= 3600 ? "\(s/3600)h\((s%3600)/60)m" : "\(s/60)m"
                    QBankStatCard(value: timeStr, label: "Tempo", color: VitaColors.accent)
                }
                .padding(.horizontal, 16)

                // Difficulty breakdown
                let diffBreakdown = buildDiffBreakdown()
                if !diffBreakdown.isEmpty {
                    Spacer().frame(height: 20)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Por Dificuldade")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                        ForEach(diffBreakdown, id: \.0) { (diff, t, c) in
                            let rate = t > 0 ? Double(c) / Double(t) : 0
                            let col: Color = rate >= 0.7 ? VitaColors.dataGreen : rate >= 0.5 ? VitaColors.dataAmber : VitaColors.dataRed
                            HStack(spacing: 10) {
                                Text(diff.difficultyLabel)
                                    .font(.system(size: 12))
                                    .foregroundStyle(VitaColors.textPrimary)
                                    .frame(width: 50, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3).fill(VitaColors.glassBorder)
                                        RoundedRectangle(cornerRadius: 3).fill(col)
                                            .frame(width: geo.size.width * CGFloat(rate))
                                    }
                                }
                                .frame(height: 6)
                                Text("\(c)/\(t)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(col)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                    .padding(16)
                    .background(VitaColors.glassBg)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(VitaColors.glassBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 24)
                }

                // Question review
                let allIds = vm.state.session?.questionIds ?? []
                if !allIds.isEmpty {
                    Spacer().frame(height: 20)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Revisão das Questões")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                        ForEach(Array(allIds.enumerated()), id: \.element) { idx, qId in
                            let answer = vm.state.sessionAnswers[qId]
                            let detail = vm.state.sessionDetails[qId]
                            QBankResultReviewRow(index: idx + 1, questionId: qId, detail: detail, answer: answer)
                                .padding(.horizontal, 24)
                        }
                    }
                }

                Spacer().frame(height: 24)

                VStack(spacing: 10) {
                    VitaButton(text: "Nova Sessão", action: onNewSession)
                    VitaButton(text: "Voltar ao Início", action: onBack, variant: .secondary)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 80)
            }
        }

    }

    private func buildDiffBreakdown() -> [(String, Int, Int)] {
        var map: [String: (Int, Int)] = [:]
        for (qId, ans) in vm.state.sessionAnswers {
            guard let detail = vm.state.sessionDetails[qId] else { continue }
            var entry = map[detail.difficulty] ?? (0, 0)
            entry.0 += 1
            if ans.isCorrect { entry.1 += 1 }
            map[detail.difficulty] = entry
        }
        return ["easy", "medium", "hard"].compactMap { k in
            map[k].map { (k, $0.0, $0.1) }
        }
    }
}

/// Mockup stat-card: glass bg, number + uppercase label
struct QBankStatCard: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .tracking(-0.03 * 20)
                .foregroundStyle(color)
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(VitaColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(VitaColors.glassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct QBankResultReviewRow: View {
    let index: Int
    let questionId: Int
    let detail: QBankQuestionDetail?
    let answer: QBankAnswerResponse?

    private var statusColor: Color { answer.map { $0.isCorrect ? VitaColors.dataGreen : VitaColors.dataRed } ?? VitaColors.textTertiary }
    private var statusIcon: String  { answer.map { $0.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill" } ?? "minus.circle" }
    private var statement: String {
        guard let d = detail else { return "Questão \(questionId)" }
        let s = d.statement.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "Questão \(questionId)" : s
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index)").font(.system(size: 11, weight: .semibold)).foregroundStyle(VitaColors.textTertiary).frame(width: 24)
            Text(statement).font(.system(size: 12)).foregroundStyle(VitaColors.textSecondary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: statusIcon).font(.system(size: 16)).foregroundStyle(statusColor)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(VitaColors.glassBorder).frame(height: 0.5) }
    }
}
