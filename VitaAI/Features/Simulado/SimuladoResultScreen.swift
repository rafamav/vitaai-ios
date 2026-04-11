import SwiftUI

// MARK: - SimuladoResultScreen

struct SimuladoResultScreen: View {
    let attemptId: String
    @Environment(\.appContainer) private var container
    @State private var vm: SimuladoViewModel?
    let onBack: () -> Void
    let onReview: () -> Void
    let onNewSimulado: () -> Void

    @State private var animatedProgress: Double = 0

    var body: some View {
        Group {
            if let vm {
                if vm.state.isLoading {
                    loadingView
                } else {
                    resultContent(vm: vm)
                }
            } else {
                loadingView
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if vm == nil { vm = SimuladoViewModel(api: container.api, gamificationEvents: container.gamificationEvents) }
            guard let vm else { return }
            if vm.state.currentAttemptId != attemptId {
                vm.loadSession(attemptId)
            }
        }
    }

    private var loadingView: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            ProgressView()
                .tint(Color(red: 200/255, green: 155/255, blue: 70/255))
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func resultContent(vm: SimuladoViewModel) -> some View {
        let totalQ = vm.state.result?.totalQ ?? vm.state.questions.count
        let correctQ: Int = {
            if let r = vm.state.result { return r.correctQ }
            return vm.state.questions.filter { q in
                vm.state.answers[q.id] == q.correctIdx
            }.count
        }()
        let erradas: Int = {
            let answered = vm.state.questions.filter { vm.state.answers[$0.id] != nil }
            return answered.filter { q in vm.state.answers[q.id] != q.correctIdx }.count
        }()
        let elapsed = Date().timeIntervalSince(vm.state.sessionStartDate)
        let wrongQs = vm.state.questions.filter { q in
            guard let chosen = vm.state.answers[q.id] else { return false }
            return chosen != q.correctIdx
        }

        ResultBodyView(
            totalQ: totalQ,
            correctQ: correctQ,
            erradas: erradas,
            elapsedSeconds: elapsed,
            wrongQs: wrongQs,
            animatedProgress: $animatedProgress,
            onBack: onBack,
            onNewSimulado: onNewSimulado
        )
    }
}

// MARK: - Background

private var resultBackground: some View {
    ZStack {
        Color(red: 8/255, green: 6/255, blue: 10/255)
            .ignoresSafeArea()
        // Blue radial gradient 1 — top-center
        RadialGradient(
            colors: [
                Color(red: 60/255, green: 120/255, blue: 200/255).opacity(0.07),
                Color.clear
            ],
            center: .init(x: 0.5, y: 0.25),
            startRadius: 0,
            endRadius: 300
        )
        .ignoresSafeArea()
        // Blue radial gradient 2 — top-right
        RadialGradient(
            colors: [
                Color(red: 40/255, green: 100/255, blue: 180/255).opacity(0.05),
                Color.clear
            ],
            center: .init(x: 0.85, y: 0.15),
            startRadius: 0,
            endRadius: 200
        )
        .ignoresSafeArea()
    }
}

// MARK: - ResultBodyView

private struct ResultBodyView: View {
    let totalQ: Int
    let correctQ: Int
    let erradas: Int
    let elapsedSeconds: TimeInterval
    @Binding var animatedProgress: Double
    let wrongQs: [SimuladoQuestionEntry]
    let onBack: () -> Void
    let onNewSimulado: () -> Void

    init(
        totalQ: Int,
        correctQ: Int,
        erradas: Int,
        elapsedSeconds: TimeInterval,
        wrongQs: [SimuladoQuestionEntry],
        animatedProgress: Binding<Double>,
        onBack: @escaping () -> Void,
        onNewSimulado: @escaping () -> Void
    ) {
        self.totalQ = totalQ
        self.correctQ = correctQ
        self.erradas = erradas
        self.elapsedSeconds = elapsedSeconds
        self.wrongQs = wrongQs
        self._animatedProgress = animatedProgress
        self.onBack = onBack
        self.onNewSimulado = onNewSimulado
    }

    private var pct: Int { totalQ > 0 ? Int(Double(correctQ) / Double(totalQ) * 100) : 0 }

    private var ringColor: Color {
        if pct >= 70 { return Color(red: 34/255, green: 197/255, blue: 94/255).opacity(0.80) }
        if pct >= 50 { return Color(red: 200/255, green: 155/255, blue: 70/255).opacity(0.80) }
        return Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.75)
    }

    private var numberColor: Color {
        if pct >= 70 { return Color(red: 34/255, green: 197/255, blue: 94/255).opacity(0.92) }
        if pct >= 50 { return Color(red: 200/255, green: 155/255, blue: 70/255).opacity(0.92) }
        return Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.88)
    }

    private var titleColor: Color {
        if pct >= 70 { return Color(red: 130/255, green: 220/255, blue: 140/255).opacity(0.95) }
        if pct >= 50 { return Color(red: 255/255, green: 210/255, blue: 130/255).opacity(0.95) }
        return Color(red: 255/255, green: 120/255, blue: 100/255).opacity(0.92)
    }

    private var scoreTitle: String {
        if pct >= 70 { return "Excelente desempenho!" }
        if pct >= 50 { return "Bom resultado!" }
        return "Continue praticando"
    }

    private var formattedTime: String {
        let secs = Int(elapsedSeconds)
        let minutes = secs / 60
        let seconds = secs % 60
        return "\(minutes)min \(String(format: "%02d", seconds))s"
    }

    var body: some View {
        ZStack {
            Color.clear.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    resultHeader
                    // Hero Score
                    heroScore
                        .padding(.top, 26)
                    // Stats 3-column grid
                    statsGrid
                        .padding(.top, 20)
                        .padding(.horizontal, 16)
                    // Wrong questions
                    wrongQuestionsSection
                        .padding(.top, 16)
                        .padding(.horizontal, 16)
                    // Buttons
                    actionButtons
                        .padding(.top, 14)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 40)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: Header

    private var resultHeader: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        VitaColors.textWarm.opacity(0.50)
                    )
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Resultado")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VitaColors.white.opacity(0.96))
                Text("\(totalQ) questões · \(pct)% de acerto")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.45))
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 56)
        .padding(.bottom, 8)
    }

    // MARK: Hero Score Ring

    private var heroScore: some View {
        VStack(spacing: 8) {
            // Score ring
            ZStack {
                // Track
                Circle()
                    .stroke(
                        Color(red: 1, green: 1, blue: 1).opacity(0.05),
                        lineWidth: 5
                    )
                    .frame(width: 100, height: 100)
                // Progress
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                // Score number
                Text("\(pct)%")
                    .font(.system(size: 22, weight: .heavy))
                    .kerning(-0.04 * 22)
                    .foregroundStyle(numberColor)
            }
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) {
                    animatedProgress = Double(pct) / 100.0
                }
            }
            // Score title
            Text(scoreTitle)
                .font(.system(size: 22, weight: .heavy))
                .kerning(-0.04 * 22)
                .foregroundStyle(titleColor)
            // Subtitle
            Text("\(correctQ) de \(totalQ) questões corretas")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                .padding(.top, 6)
        }
    }

    // MARK: Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 8) {
            StatCard(
                number: "\(correctQ)",
                label: "ACERTOS",
                numberColor: Color(red: 130/255, green: 220/255, blue: 140/255).opacity(0.90)
            )
            StatCard(
                number: "\(erradas)",
                label: "ERROS",
                numberColor: Color(red: 255/255, green: 120/255, blue: 100/255).opacity(0.85)
            )
            StatCard(
                number: formattedTime,
                label: "TEMPO",
                numberColor: Color(red: 255/255, green: 210/255, blue: 130/255).opacity(0.88)
            )
        }
    }

    // MARK: Wrong Questions Section

    @ViewBuilder
    private var wrongQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if wrongQs.isEmpty {
                // All correct card
                HStack {
                    Text("Parabens! Você acertou todas as questões.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(red: 130/255, green: 220/255, blue: 140/255).opacity(0.90))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color(red: 12/255, green: 9/255, blue: 7/255).opacity(0.90), location: 0),
                                    .init(color: Color(red: 10/255, green: 8/255, blue: 6/255).opacity(0.86), location: 1)
                                ],
                                startPoint: .init(x: 0.5, y: 0),
                                endPoint: .init(x: 0.5, y: 1)
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(VitaColors.accentHover.opacity(0.08), lineWidth: 1)
                )
            } else {
                // Section label
                Text("Questões para revisar")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(0.5)
                    .textCase(.uppercase)
                    .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                    .padding(.bottom, 4)

                ForEach(wrongQs) { q in
                    WrongQuestionCard(question: q)
                }
            }
        }
    }

    // MARK: Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 8) {
            // Gold primary button
            Button(action: onNewSimulado) {
                Text("Novo Simulado")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color(red: 255/255, green: 255/255, blue: 255/255).opacity(0.96))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    stops: [
                                        .init(color: Color(red: 200/255, green: 155/255, blue: 70/255).opacity(0.80), location: 0),
                                        .init(color: Color(red: 160/255, green: 110/255, blue: 40/255).opacity(0.65), location: 1)
                                    ],
                                    startPoint: .init(x: 0, y: 0),
                                    endPoint: .init(x: 1, y: 1)
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                Color(red: 255/255, green: 235/255, blue: 180/255).opacity(0.22),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: Color(red: 200/255, green: 155/255, blue: 70/255).opacity(0.25),
                        radius: 12,
                        x: 0,
                        y: 8
                    )
            }
            .buttonStyle(.plain)

            // Ghost secondary button
            Button(action: onBack) {
                Text("Voltar para Simulados")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color(red: 1, green: 1, blue: 1).opacity(0.03))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                VitaColors.accentHover.opacity(0.14),
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - StatCard

private struct StatCard: View {
    let number: String
    let label: String
    let numberColor: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.system(size: 20, weight: .heavy))
                .kerning(-0.03 * 20)
                .foregroundStyle(numberColor)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .kerning(0.5)
                .textCase(.uppercase)
                .foregroundStyle(VitaColors.textWarm.opacity(0.30))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 13)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 12/255, green: 9/255, blue: 7/255).opacity(0.90), location: 0),
                            .init(color: Color(red: 10/255, green: 8/255, blue: 6/255).opacity(0.86), location: 1)
                        ],
                        startPoint: .init(x: 0.5, y: 0),
                        endPoint: .init(x: 0.5, y: 1)
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VitaColors.accentHover.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 8)
    }
}

// MARK: - WrongQuestionCard

private struct WrongQuestionCard: View {
    let question: SimuladoQuestionEntry
    @State private var expanded = false

    private let letters = ["A", "B", "C", "D", "E"]

    private var chosenLetter: String {
        guard let idx = question.chosenIdx, letters.indices.contains(idx) else { return "?" }
        return letters[idx]
    }

    private var correctLetter: String {
        letters.indices.contains(question.correctIdx) ? letters[question.correctIdx] : "?"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top row
            Button(action: { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { expanded.toggle() } }) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center) {
                        // Topic label
                        Text((question.topic ?? question.subject ?? "Questão").uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .kerning(0.5)
                            .foregroundStyle(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.60))
                            .lineLimit(1)
                        Spacer()
                        // Question number + chevron
                        HStack(spacing: 6) {
                            Text("Q\(question.questionNo)")
                                .font(.system(size: 9, weight: .regular))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.30))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.25))
                                .rotationEffect(.degrees(expanded ? 180 : 0))
                                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: expanded)
                        }
                    }
                    // Statement
                    Text(question.statement)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(VitaColors.white.opacity(0.75))
                        .lineSpacing(12 * 0.45)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Answer tags
            HStack(spacing: 8) {
                // Wrong answer tag
                HStack(spacing: 4) {
                    Text("✗")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Sua resposta: \(chosenLetter)")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Color(red: 255/255, green: 120/255, blue: 100/255).opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.18), lineWidth: 1)
                )

                // Correct answer tag
                HStack(spacing: 4) {
                    Text("✓")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Correta: \(correctLetter)")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(Color(red: 130/255, green: 220/255, blue: 140/255).opacity(0.85))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(red: 34/255, green: 197/255, blue: 94/255).opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(red: 34/255, green: 197/255, blue: 94/255).opacity(0.18), lineWidth: 1)
                )

                Spacer()
            }
            .padding(.top, 8)

            // Expandable explanation
            if expanded, let explanation = question.explanation, !explanation.isEmpty {
                Divider()
                    .background(VitaColors.textWarm.opacity(0.05))
                    .padding(.top, 10)

                Text(explanation)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(VitaColors.white.opacity(0.55))
                    .lineSpacing(11.5 * 0.6)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 12/255, green: 9/255, blue: 7/255).opacity(0.90), location: 0),
                            .init(color: Color(red: 10/255, green: 8/255, blue: 6/255).opacity(0.86), location: 1)
                        ],
                        startPoint: .init(x: 0.5, y: 0),
                        endPoint: .init(x: 0.5, y: 1)
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(red: 239/255, green: 68/255, blue: 68/255).opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.30), radius: 6, x: 0, y: 4)
        .padding(.bottom, 8)
    }
}
