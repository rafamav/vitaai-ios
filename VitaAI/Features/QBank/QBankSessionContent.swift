import SwiftUI

// MARK: - Session content

struct QBankSessionContent: View {
    @Bindable var vm: QBankViewModel
    let onBack: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var showFinishAlert = false
    @State private var showExplanationSheet = false
    @State private var timerTask: Task<Void, Never>? = nil

    // Cap image height so it never overflows on iPad.
    // iPhone: 260pt max. iPad (regular width): 400pt max.
    private var maxImageHeight: CGFloat {
        horizontalSizeClass == .regular ? 400 : 260
    }

    var timerStr: String {
        let s = vm.state.elapsedSeconds
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            if vm.state.questionLoading || vm.state.currentQuestionDetail == nil {
                VStack(spacing: 12) {
                    ProgressView().tint(VitaColors.accent)
                    Text("Carregando questão...")
                        .font(.system(size: 13))
                        .foregroundStyle(VitaColors.textTertiary)
                }
            } else if let question = vm.state.currentQuestionDetail {
                sessionContent(question: question)
            }
        }
        .sheet(isPresented: $showExplanationSheet) {
            VitaSheet(title: "Explicação") {
                if let question = vm.state.currentQuestionDetail {
                    QBankExplanationSheet(question: question)
                }
            }
        }
        .vitaAlert(
            isPresented: $showFinishAlert,
            title: "Encerrar Sessão?",
            message: "Você respondeu \(vm.state.sessionAnswers.count) de \(vm.state.totalInSession) questões. Deseja encerrar?",
            destructiveLabel: "Encerrar",
            cancelLabel: "Continuar",
            onConfirm: { vm.finishSession() }
        )
        .onAppear { startTimer() }
        .onDisappear { timerTask?.cancel() }
    }

    @ViewBuilder
    private func sessionContent(question: QBankQuestionDetail) -> some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textSecondary)
                        .frame(width: 40, height: 40)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Questão \(vm.state.progress1Based)/\(vm.state.totalInSession)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                    if let year = question.year {
                        Text("\(year) · \(question.difficulty.difficultyLabel)")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
                Spacer()
                Text(timerStr)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)
                if let inst = question.institutionName, !inst.isEmpty {
                    Text(inst)
                        .font(.system(size: 10))
                        .foregroundStyle(VitaColors.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(VitaColors.accent.opacity(0.1))
                        .clipShape(Capsule())
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(VitaColors.glassBorder)
                    Rectangle()
                        .fill(VitaColors.accent)
                        .frame(width: geo.size.width * CGFloat(vm.state.sessionProgress))
                        .animation(.easeInOut(duration: 0.4), value: vm.state.sessionProgress)
                }
            }
            .frame(height: 2)

            // Topics tags
            if !question.topics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(question.topics) { topic in
                            Text(topic.title)
                                .font(.system(size: 10))
                                .foregroundStyle(VitaColors.textSecondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(VitaColors.glassBg)
                                .overlay(Capsule().stroke(VitaColors.glassBorder, lineWidth: 1))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Badges
                    let hasBadges = question.isResidence || question.isCancelled || question.isOutdated
                    if hasBadges {
                        HStack(spacing: 6) {
                            if question.isResidence { QBankBadge(text: "Residência", color: VitaColors.dataBlue) }
                            if question.isCancelled { QBankBadge(text: "Anulada",    color: VitaColors.dataAmber) }
                            if question.isOutdated  { QBankBadge(text: "Desatualizada", color: VitaColors.textTertiary) }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }

                    // Statement
                    if question.statement.contains("<") {
                        QBankHTMLText(html: question.statement, textColor: "#FFFFFF", bgColor: "transparent")
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                    } else {
                        Text(question.statement)
                            .font(.system(size: 15))
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineSpacing(4)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                    }

                    // Question images (if any)
                    if !question.images.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(question.images) { img in
                                AsyncImage(url: URL(string: img.imageUrl)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: .infinity, maxHeight: maxImageHeight)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    case .failure:
                                        HStack(spacing: 6) {
                                            Image(systemName: "photo.badge.exclamationmark")
                                                .font(.system(size: 14))
                                                .foregroundStyle(VitaColors.textTertiary)
                                            Text("Imagem indisponível")
                                                .font(.system(size: 12))
                                                .foregroundStyle(VitaColors.textTertiary)
                                        }
                                    default:
                                        ProgressView()
                                            .tint(VitaColors.accent)
                                            .frame(height: 100)
                                    }
                                }
                                if let caption = img.caption, !caption.isEmpty {
                                    Text(caption)
                                        .font(.system(size: 11))
                                        .foregroundStyle(VitaColors.textTertiary)
                                        .italic()
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }

                    // Alternatives
                    let sortedAlts = question.alternatives.sorted { $0.sortOrder < $1.sortOrder }
                    ForEach(Array(sortedAlts.enumerated()), id: \.element.id) { idx, alt in
                        QBankAlternativeCard(
                            idx: idx,
                            alternative: alt,
                            selectedId: vm.state.selectedAlternativeId,
                            showFeedback: vm.state.showFeedback
                        ) {
                            vm.selectAlternative(id: alt.id)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, idx < sortedAlts.count - 1 ? 8 : 0)
                    }

                    // Inline explanation after feedback
                    if vm.state.showFeedback, let explanation = question.explanation, !explanation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Comentário")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(VitaColors.textPrimary)
                            if explanation.contains("<") {
                                QBankHTMLText(html: explanation, textColor: "#AAAAAA", bgColor: "transparent")
                            } else {
                                Text(explanation)
                                    .font(.system(size: 13))
                                    .foregroundStyle(VitaColors.textSecondary)
                                    .lineSpacing(3)
                            }
                        }
                        .padding(14)
                        .glassCard(cornerRadius: 12)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            // Bottom actions
            VStack(spacing: 8) {
                if let answerError = vm.state.answerError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VitaColors.dataRed.opacity(0.9))
                        Text(answerError)
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.dataRed.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(VitaColors.dataRed.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                if vm.state.showFeedback {
                    HStack(spacing: 10) {
                        Button {
                            showExplanationSheet = true
                        } label: {
                            Text("Detalhes")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(VitaColors.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(VitaColors.accent, lineWidth: 1))
                        }
                        Button {
                            if vm.state.isLastQuestion { vm.finishSession() } else { vm.nextQuestion() }
                        } label: {
                            Text(vm.state.isLastQuestion ? "Ver Resultado" : "Próxima")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(VitaColors.surface)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(VitaColors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                } else {
                    Button { vm.confirmAnswer() } label: {
                        Text("Confirmar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VitaColors.surface)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(vm.state.selectedAlternativeId != nil ? VitaColors.accent : VitaColors.accent.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(vm.state.selectedAlternativeId == nil)
                }

                Button { showFinishAlert = true } label: {
                    Text("Encerrar Sessão")
                        .font(.system(size: 13))
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 80)
        }
        .animation(.easeInOut(duration: 0.3), value: vm.state.showFeedback)
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                vm.tickTimer()
            }
        }
    }
}

// MARK: - Alternative Card (standalone for coordinator use)

struct QBankAlternativeCard: View {
    let idx: Int
    let alternative: QBankAlternative
    let selectedId: Int?
    let showFeedback: Bool
    let onSelect: () -> Void

    private static let letters = ["A", "B", "C", "D", "E"]

    private var isSelected: Bool { selectedId == alternative.id }
    private var isCorrect: Bool { alternative.isCorrect }
    private var isWrongChoice: Bool { showFeedback && isSelected && !isCorrect }

    private var borderColor: Color {
        if showFeedback && isCorrect { return VitaColors.dataGreen }
        if isWrongChoice { return VitaColors.dataRed }
        if isSelected { return VitaColors.accent }
        return VitaColors.glassBorder
    }
    private var bgColor: Color {
        if showFeedback && isCorrect { return VitaColors.dataGreen.opacity(0.10) }
        if isWrongChoice { return VitaColors.dataRed.opacity(0.10) }
        if isSelected { return VitaColors.accent.opacity(0.08) }
        return Color.clear
    }
    private var letterColor: Color {
        if showFeedback && isCorrect { return VitaColors.dataGreen }
        if isWrongChoice { return VitaColors.dataRed }
        if isSelected { return VitaColors.accent }
        return VitaColors.textTertiary
    }
    private var letter: String {
        Self.letters.indices.contains(idx) ? Self.letters[idx] : "\(idx + 1)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // option-letter: 24x24 rounded 8px square matching mockup
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected || (showFeedback && isCorrect) ? borderColor.opacity(0.20) : Color.white.opacity(0.06))
                    .frame(width: 24, height: 24)
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor.opacity(showFeedback ? 0.35 : 0.12), lineWidth: 1)
                    .frame(width: 24, height: 24)
                if showFeedback && isCorrect {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VitaColors.dataGreen)
                } else if isWrongChoice {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(VitaColors.dataRed)
                } else {
                    Text(letter)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(letterColor)
                }
            }
            Text(alternative.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(VitaColors.textPrimary)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(13)
        .background(bgColor)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(borderColor, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { if !showFeedback { onSelect() } }
        .animation(.easeInOut(duration: 0.2), value: showFeedback)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
