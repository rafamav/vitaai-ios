import SwiftUI

// MARK: - Explanation Sheet

struct QBankExplanationSheet: View {
    let question: QBankQuestionDetail

    private static let letters = ["A", "B", "C", "D", "E"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Gabarito e Comentário")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .padding(.top, 20)

                let sortedAlts = question.alternatives.sorted { $0.sortOrder < $1.sortOrder }

                // Correct alternative
                ForEach(Array(sortedAlts.enumerated()), id: \.element.id) { idx, alt in
                    if alt.isCorrect {
                        HStack(spacing: 8) {
                            Text(Self.letters.indices.contains(idx) ? Self.letters[idx] : "\(idx+1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(VitaColors.dataGreen)
                                .frame(width: 22, height: 22)
                                .background(VitaColors.dataGreen.opacity(0.15))
                                .clipShape(Circle())
                            Text(alt.text)
                                .font(.system(size: 13))
                                .foregroundStyle(VitaColors.textPrimary)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(VitaColors.dataGreen)
                        }
                        .padding(10)
                        .background(VitaColors.dataGreen.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VitaColors.dataGreen.opacity(0.3), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Statistics
                if !question.statistics.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Distribuição das Respostas")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                        ForEach(Array(sortedAlts.enumerated()), id: \.element.id) { idx, alt in
                            if let stat = question.statistics.first(where: { $0.alternativeId == alt.id }) {
                                HStack(spacing: 8) {
                                    Text(Self.letters.indices.contains(idx) ? Self.letters[idx] : "\(idx+1)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(alt.isCorrect ? VitaColors.dataGreen : VitaColors.textTertiary)
                                        .frame(width: 18)
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3).fill(VitaColors.glassBorder)
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(alt.isCorrect ? VitaColors.dataGreen : VitaColors.accent.opacity(0.4))
                                                .frame(width: geo.size.width * CGFloat(stat.percentage / 100).clamped(to: 0...1))
                                        }
                                    }
                                    .frame(height: 8)
                                    Text("\(Int(stat.percentage))%")
                                        .font(.system(size: 10))
                                        .foregroundStyle(alt.isCorrect ? VitaColors.dataGreen : VitaColors.textTertiary)
                                        .frame(width: 32, alignment: .trailing)
                                }
                            }
                        }
                    }
                }

                // Explanation
                if let explanation = question.explanation, !explanation.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Comentário")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                        if explanation.contains("<") {
                            QBankHTMLText(html: explanation, textColor: "#AAAAAA", bgColor: "transparent")
                                .frame(minHeight: 80)
                        } else {
                            Text(explanation)
                                .font(.system(size: 13))
                                .foregroundStyle(VitaColors.textSecondary)
                                .lineSpacing(3)
                        }
                    }
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
        }
        .background(VitaColors.surface)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
