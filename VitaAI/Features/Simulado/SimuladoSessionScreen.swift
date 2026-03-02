import SwiftUI

private let optionLetters = ["A", "B", "C", "D", "E"]

struct SimuladoSessionScreen: View {
    let attemptId: String
    @Environment(\.appContainer) private var container
    @State private var vm: SimuladoViewModel?
    let onBack: () -> Void
    let onFinished: (String) -> Void

    @State private var showGrid = false
    @State private var showFinishDialog = false
    @State private var showExplanationSheet = false
    @State private var elapsedSeconds = 0
    @State private var timerTask: Task<Void, Never>? = nil

    var timerStr: String {
        "\(elapsedSeconds / 60):\(String(format: "%02d", elapsedSeconds % 60))"
    }

    var body: some View {
        Group {
            if let vm {
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    if vm.state.isLoading || vm.state.currentQuestion == nil {
                        ProgressView().tint(VitaColors.accent)
                    } else {
                        sessionContent(vm: vm)
                    }
                }
                .onChange(of: vm.state.result) { _, result in
                    if result != nil {
                        onFinished(vm.state.currentAttemptId ?? attemptId)
                    }
                }
                .sheet(isPresented: $showGrid) { gridSheet(vm: vm) }
                .sheet(isPresented: $showExplanationSheet) { explanationSheet(vm: vm) }
                .alert("Finalizar?", isPresented: $showFinishDialog) {
                    let unanswered = vm.state.questions.count - vm.state.answers.count
                    Button("Finalizar", role: .destructive) { vm.finishSimulado() }
                    Button("Continuar", role: .cancel) {}
                } message: {
                    let unanswered = vm.state.questions.count - vm.state.answers.count
                    if unanswered > 0 {
                        Text("Você ainda tem \(unanswered) questão(ões) sem resposta. Deseja finalizar mesmo assim?")
                    } else {
                        Text("Tem certeza que deseja finalizar a prova?")
                    }
                }
            } else {
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    ProgressView().tint(VitaColors.accent)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if vm == nil { vm = SimuladoViewModel(api: container.api) }
            guard let vm else { return }
            if vm.state.currentAttemptId != attemptId || vm.state.questions.isEmpty {
                vm.loadSession(attemptId)
            }
            startTimer()
        }
        .onDisappear { timerTask?.cancel() }
    }

    @ViewBuilder
    private func sessionContent(vm: SimuladoViewModel) -> some View {
        guard let question = vm.state.currentQuestion else {
            EmptyView()
            return
        }
        let options = question.parsedOptions
        let selectedIdx = vm.state.answers[question.id]
        let isExam = vm.state.isExamMode

        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textSecondary)
                        .frame(width: 40, height: 40)
                }

                Text("Questão \(vm.state.currentQuestionIndex + 1)/\(vm.state.questions.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)

                Spacer()

                Text(timerStr)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)

                if let subj = question.subject, !subj.isEmpty {
                    Text(subj)
                        .font(.system(size: 10))
                        .foregroundStyle(VitaColors.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(VitaColors.accent.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Statement + options
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(question.statement)
                        .font(.system(size: 15))
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineSpacing(4)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)

                    ForEach(Array(options.enumerated()), id: \.offset) { idx, optionText in
                        OptionRow(
                            idx: idx,
                            text: optionText,
                            selectedIdx: selectedIdx,
                            correctIdx: question.correctIdx,
                            showFeedback: vm.state.showFeedback && !isExam
                        ) {
                            vm.selectAnswer(questionId: question.id, chosenIdx: idx)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, idx < options.count - 1 ? 8 : 0)
                    }
                }
                .padding(.bottom, 16)
            }

            // Bottom actions
            VStack(spacing: 8) {
                if vm.state.showFeedback && !isExam {
                    // Immediate mode after confirm
                    HStack(spacing: 10) {
                        Button {
                            vm.loadExplanation(questionId: question.id)
                            showExplanationSheet = true
                        } label: {
                            Text("Ver Explicação")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(VitaColors.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(VitaColors.accent, lineWidth: 1))
                        }

                        Button {
                            if vm.state.currentQuestionIndex < vm.state.questions.count - 1 {
                                vm.nextQuestion()
                            } else {
                                vm.finishSimulado()
                            }
                        } label: {
                            Text(vm.state.currentQuestionIndex < vm.state.questions.count - 1 ? "Próxima" : "Finalizar")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(VitaColors.surface)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(VitaColors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                } else {
                    // Confirm row + exam controls
                    HStack(spacing: 8) {
                        if isExam {
                            Button {
                                vm.toggleMark(question.questionNo)
                            } label: {
                                Image(systemName: vm.state.markedQuestions.contains(question.questionNo) ? "bookmark.fill" : "bookmark")
                                    .font(.system(size: 18))
                                    .foregroundStyle(vm.state.markedQuestions.contains(question.questionNo) ? VitaColors.dataAmber : VitaColors.textTertiary)
                                    .frame(width: 40, height: 40)
                            }

                            Button {
                                showGrid = true
                            } label: {
                                Image(systemName: "square.grid.3x3")
                                    .font(.system(size: 18))
                                    .foregroundStyle(VitaColors.textTertiary)
                                    .frame(width: 40, height: 40)
                            }
                        }

                        Spacer()

                        Button {
                            vm.confirmAnswer()
                        } label: {
                            Text("Confirmar")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(VitaColors.surface)
                                .padding(.horizontal, 32)
                                .frame(height: 46)
                                .background(selectedIdx != nil ? VitaColors.accent : VitaColors.accent.opacity(0.4))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .disabled(selectedIdx == nil)
                    }
                }

                Button {
                    showFinishDialog = true
                } label: {
                    Text(isExam ? "Finalizar Prova" : "Encerrar Simulado")
                        .font(.system(size: 13))
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Grid Sheet

    @ViewBuilder
    private func gridSheet(vm: SimuladoViewModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Questões")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
                .padding(.top, 20)

            LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 10), count: 6), spacing: 10) {
                ForEach(Array(vm.state.questions.enumerated()), id: \.offset) { idx, q in
                    let isAnswered = vm.state.answers[q.id] != nil
                    let isMarked = vm.state.markedQuestions.contains(q.questionNo)
                    let isCurrent = idx == vm.state.currentQuestionIndex

                    let bg: Color = isMarked ? VitaColors.dataAmber : isAnswered ? VitaColors.accent : VitaColors.glassBorder

                    Button {
                        vm.goToQuestion(idx)
                        showGrid = false
                    } label: {
                        Text("\(idx + 1)")
                            .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                            .foregroundStyle(isAnswered || isMarked ? VitaColors.surface : VitaColors.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(bg.opacity(isCurrent ? 1 : 0.65))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            VitaButton(label: "Finalizar Prova", variant: .secondary) {
                showGrid = false
                showFinishDialog = true
            }
        }
        .padding(20)
        .background(VitaColors.surface)
        .presentationDetents([.medium, .large])
    }

    // MARK: - Explanation Sheet

    @ViewBuilder
    private func explanationSheet(vm: SimuladoViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Explicação")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .padding(.top, 20)

                if vm.state.isLoadingExplanation {
                    HStack { Spacer(); ProgressView().tint(VitaColors.accent); Spacer() }
                        .frame(height: 80)
                } else if let explanation = vm.state.currentExplanation {
                    Text(explanation.general)
                        .font(.system(size: 14))
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineSpacing(3)

                    if !explanation.perOption.isEmpty {
                        Text("Por alternativa")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                            .padding(.top, 8)

                        ForEach(explanation.perOption) { opt in
                            let letter = optionLetters.indices.contains(opt.index) ? optionLetters[opt.index] : "\(opt.index + 1)"
                            let isCorrect = opt.index == vm.state.currentQuestion?.correctIdx
                            HStack(alignment: .top, spacing: 4) {
                                Text("\(letter))")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(isCorrect ? VitaColors.dataGreen : VitaColors.textTertiary)
                                Text(opt.text)
                                    .font(.system(size: 12))
                                    .foregroundStyle(VitaColors.textPrimary)
                            }
                        }
                    }
                } else {
                    Text("Explicação não disponível")
                        .font(.system(size: 14))
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 20)
        }
        .background(VitaColors.surface)
        .onDisappear { vm.dismissExplanation() }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Timer

    private func startTimer() {
        timerTask?.cancel()
        let start = vm?.state.sessionStartDate ?? Date()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                elapsedSeconds = Int(Date().timeIntervalSince(start))
            }
        }
    }
}

// MARK: - Option Row

private struct OptionRow: View {
    let idx: Int
    let text: String
    let selectedIdx: Int?
    let correctIdx: Int
    let showFeedback: Bool
    let onSelect: () -> Void

    private var isSelected: Bool { selectedIdx == idx }
    private var isCorrect: Bool { idx == correctIdx }
    private var isWrongChoice: Bool { showFeedback && isSelected && !isCorrect }

    private var borderColor: Color {
        if showFeedback && isCorrect { return VitaColors.dataGreen }
        if isWrongChoice { return VitaColors.dataRed }
        if isSelected { return VitaColors.accent }
        return VitaColors.glassBorder
    }

    private var bgColor: Color {
        if showFeedback && isCorrect { return VitaColors.dataGreen.opacity(0.12) }
        if isWrongChoice { return VitaColors.dataRed.opacity(0.12) }
        if isSelected { return VitaColors.accent.opacity(0.1) }
        return Color.clear
    }

    private var letterColor: Color {
        if showFeedback && isCorrect { return VitaColors.dataGreen }
        if isWrongChoice { return VitaColors.dataRed }
        if isSelected { return VitaColors.accent }
        return VitaColors.textTertiary
    }

    private var letter: String {
        optionLetters.indices.contains(idx) ? optionLetters[idx] : "\(idx + 1)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSelected || (showFeedback && isCorrect) ? borderColor.opacity(0.15) : VitaColors.glassBg)
                    .frame(width: 28, height: 28)
                Text(letter)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(letterColor)
            }

            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(VitaColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(bgColor)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            if !showFeedback { onSelect() }
        }
        .animation(.easeInOut(duration: 0.25), value: showFeedback)
        .animation(.easeInOut(duration: 0.25), value: isSelected)
    }
}
