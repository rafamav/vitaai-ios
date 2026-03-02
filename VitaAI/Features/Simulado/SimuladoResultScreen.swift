import SwiftUI

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
                resultContent(vm: vm)
            } else {
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    ProgressView().tint(VitaColors.accent)
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
    private func resultContent(vm: SimuladoViewModel) -> some View {
        let totalQ = vm.state.result?.totalQ ?? vm.state.questions.count
        let correctQ: Int = vm.state.result?.correctQ ?? vm.state.answers.reduce(0) { acc, pair in
            let (qId, chosen) = pair
            let isCorrect = vm.state.questions.first { $0.id == qId }?.correctIdx == chosen
            return acc + (isCorrect ? 1 : 0)
        }
        let wrongQ = vm.state.answers.count - correctQ
        let blankQ = totalQ - vm.state.answers.count
        let scorePercent = totalQ > 0 ? Int(Double(correctQ) / Double(totalQ) * 100) : 0
        let scoreColor: Color = scorePercent >= 70 ? VitaColors.dataGreen : scorePercent >= 50 ? VitaColors.dataAmber : VitaColors.dataRed

        ScrollView {
            VStack(spacing: 0) {
                // Back button
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(VitaColors.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    Spacer()
                }
                .padding(.horizontal, 8)

                Spacer().frame(height: 32)

                // Circular score arc
                ZStack {
                    Circle()
                        .stroke(VitaColors.glassBorder, lineWidth: 10)
                        .frame(width: 160, height: 160)

                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))

                    Text("\(scorePercent)%")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(scoreColor)
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 1.0)) {
                        animatedProgress = Double(scorePercent) / 100.0
                    }
                }

                Spacer().frame(height: 24)

                // Stats row
                HStack {
                    Spacer()
                    ResultStatItem(icon: "checkmark", count: correctQ, label: "Corretas", color: VitaColors.dataGreen)
                    Spacer()
                    ResultStatItem(icon: "xmark", count: wrongQ, label: "Erradas", color: VitaColors.dataRed)
                    Spacer()
                    ResultStatItem(icon: "minus", count: blankQ, label: "Em branco", color: VitaColors.textTertiary)
                    Spacer()
                }

                Spacer().frame(height: 8)

                // Subject breakdown
                let subjectGroups = Dictionary(
                    grouping: vm.state.questions.filter { !($0.subject ?? "").isEmpty }
                ) { $0.subject! }

                if subjectGroups.count > 1 {
                    Spacer().frame(height: 20)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Por Matéria")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)

                        ForEach(subjectGroups.keys.sorted(), id: \.self) { subject in
                            let qs = subjectGroups[subject] ?? []
                            let subCorrect = qs.filter { q in
                                let chosen = vm.state.answers[q.id]
                                return chosen != nil && chosen == q.correctIdx
                            }.count
                            let rate = qs.isEmpty ? 0.0 : Double(subCorrect) / Double(qs.count)
                            let barColor: Color = rate >= 0.7 ? VitaColors.dataGreen : rate >= 0.5 ? VitaColors.dataAmber : VitaColors.dataRed

                            HStack(spacing: 10) {
                                Text(subject)
                                    .font(.system(size: 12))
                                    .foregroundStyle(VitaColors.textPrimary)
                                    .frame(width: 100, alignment: .leading)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3).fill(VitaColors.glassBorder)
                                        RoundedRectangle(cornerRadius: 3).fill(barColor)
                                            .frame(width: geo.size.width * rate)
                                    }
                                }
                                .frame(height: 6)

                                Text("\(Int(rate * 100))%")
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
                    .padding(.horizontal, 24)
                }

                Spacer().frame(height: 32)

                VStack(spacing: 10) {
                    VitaButton(label: "Revisar Questões", variant: .secondary, action: onReview)
                    VitaButton(label: "Novo Simulado", action: onNewSimulado)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 24)
            }
        }
    }
}

// MARK: - Sub-components

private struct ResultStatItem: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
            Text("\(count)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(VitaColors.textTertiary)
        }
    }
}
