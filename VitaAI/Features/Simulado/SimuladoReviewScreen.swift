import SwiftUI

private let optionLetters = ["A", "B", "C", "D", "E"]

struct SimuladoReviewScreen: View {
    let attemptId: String
    @Environment(\.appContainer) private var container
    @State private var vm: SimuladoViewModel?
    let onBack: () -> Void

    @State private var expandedId: String? = nil

    var body: some View {
        Group {
            if let vm {
                reviewContent(vm: vm)
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
            guard let vm else { return }
            if vm.state.currentAttemptId != attemptId {
                vm.loadSession(attemptId)
            }
        }
    }

    @ViewBuilder
    private func reviewContent(vm: SimuladoViewModel) -> some View {
        let filteredQuestions: [SimuladoQuestionEntry] = {
            switch vm.state.reviewFilter {
            case "wrong":
                return vm.state.questions.filter { q in
                    guard let chosen = vm.state.answers[q.id] else { return false }
                    return chosen != q.correctIdx
                }
            case "marked":
                return vm.state.questions.filter { q in vm.state.markedQuestions.contains(q.questionNo) }
            default:
                return vm.state.questions
            }
        }()

        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(width: 44, height: 44)
                }
                Text("Revisão")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // Filter chips
            HStack(spacing: 8) {
                ReviewFilterChip(label: "Todas", value: "all", current: vm.state.reviewFilter) {
                    vm.setReviewFilter("all")
                }
                ReviewFilterChip(label: "Só erradas", value: "wrong", current: vm.state.reviewFilter) {
                    vm.setReviewFilter("wrong")
                }
                ReviewFilterChip(label: "Marcadas", value: "marked", current: vm.state.reviewFilter) {
                    vm.setReviewFilter("marked")
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredQuestions) { question in
                        ReviewCard(
                            question: question,
                            chosenIdx: vm.state.answers[question.id],
                            isExpanded: expandedId == question.id,
                            explanation: expandedId == question.id ? vm.state.currentExplanation : nil,
                            isLoadingExplanation: vm.state.isLoadingExplanation && expandedId == question.id
                        ) {
                            if expandedId == question.id {
                                expandedId = nil
                                vm.dismissExplanation()
                            } else {
                                expandedId = question.id
                                vm.loadExplanation(questionId: question.id)
                            }
                        }
                    }
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - Review Filter Chip

private struct ReviewFilterChip: View {
    let label: String
    let value: String
    let current: String
    let action: () -> Void
    private var isSelected: Bool { value == current }
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? VitaColors.tealAccent : VitaColors.textPrimary)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? VitaColors.tealAccent.opacity(0.15) : VitaColors.glassBg)
                .overlay(Capsule().stroke(isSelected ? VitaColors.tealAccent : VitaColors.glassBorder, lineWidth: 1))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Review Card

private struct ReviewCard: View {
    let question: SimuladoQuestionEntry
    let chosenIdx: Int?
    let isExpanded: Bool
    let explanation: ExplainResponse?
    let isLoadingExplanation: Bool
    let onToggleExplanation: () -> Void

    private var options: [String] { question.parsedOptions }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Questão \(question.questionNo)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VitaColors.tealAccent)
                .padding(.bottom, 6)

            // Statement
            Text(question.statement)
                .font(.system(size: 14))
                .foregroundStyle(VitaColors.textPrimary)
                .lineSpacing(3)
                .padding(.bottom, 12)

            // Options
            ForEach(Array(options.enumerated()), id: \.offset) { idx, optionText in
                ReviewOptionRow(
                    idx: idx,
                    text: optionText,
                    chosenIdx: chosenIdx,
                    correctIdx: question.correctIdx
                )
                .padding(.vertical, 3)
            }

            // Toggle explanation
            Button(action: onToggleExplanation) {
                Text(isExpanded ? "Ocultar Explicação" : "Ver Explicação")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VitaColors.tealAccent)
                    .padding(.horizontal, 8).padding(.vertical, 6)
            }
            .padding(.top, 8)

            // Explanation section
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if isLoadingExplanation {
                        HStack { Spacer(); ProgressView().tint(VitaColors.tealAccent); Spacer() }
                            .frame(height: 40)
                    } else if let exp = explanation {
                        if !exp.general.isEmpty {
                            Text(exp.general)
                                .font(.system(size: 13))
                                .foregroundStyle(VitaColors.textPrimary)
                                .lineSpacing(2)
                        }
                        if !exp.perOption.isEmpty {
                            ForEach(exp.perOption) { opt in
                                let letter = optionLetters.indices.contains(opt.index) ? optionLetters[opt.index] : "\(opt.index + 1)"
                                let isCorrect = opt.index == question.correctIdx
                                HStack(alignment: .top, spacing: 4) {
                                    Text("\(letter):")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(isCorrect ? VitaColors.dataGreen : VitaColors.textTertiary)
                                    Text(opt.text)
                                        .font(.system(size: 12))
                                        .foregroundStyle(VitaColors.textPrimary)
                                        .lineSpacing(2)
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(VitaColors.tealAccent.opacity(0.05))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(VitaColors.tealAccent.opacity(0.15), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
            }
        }
        .padding(16)
        .background(VitaColors.glassBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VitaColors.glassBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct ReviewOptionRow: View {
    let idx: Int
    let text: String
    let chosenIdx: Int?
    let correctIdx: Int

    private var isCorrect: Bool { idx == correctIdx }
    private var isChosen: Bool { idx == chosenIdx }
    private var isWrong: Bool { isChosen && !isCorrect }

    private var borderColor: Color {
        isCorrect ? VitaColors.dataGreen : isWrong ? VitaColors.dataRed : VitaColors.glassBorder
    }
    private var bgColor: Color {
        isCorrect ? VitaColors.dataGreen.opacity(0.08) : isWrong ? VitaColors.dataRed.opacity(0.08) : Color.clear
    }
    private var label: String {
        optionLetters.indices.contains(idx) ? optionLetters[idx] : "\(idx + 1)"
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(label))")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(borderColor)

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isCorrect {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VitaColors.dataGreen)
            } else if isWrong {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VitaColors.dataRed)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(bgColor)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: isCorrect || isWrong ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
