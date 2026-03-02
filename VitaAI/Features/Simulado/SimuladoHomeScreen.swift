import SwiftUI

struct SimuladoHomeScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: SimuladoViewModel?
    let onBack: () -> Void
    let onNewSimulado: () -> Void
    let onOpenSession: (String) -> Void
    let onOpenResult: (String) -> Void
    let onOpenDiagnostics: () -> Void

    var body: some View {
        Group {
            if let vm {
                homeContent(vm: vm)
            } else {
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    ProgressView().tint(VitaColors.accent)
                }
            }
        }
        .onAppear {
            if vm == nil { vm = SimuladoViewModel(api: container.api) }
            vm?.loadAttempts()
        }
    }

    @ViewBuilder
    private func homeContent(vm: SimuladoViewModel) -> some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(width: 44, height: 44)
                }
                Text("Simulados")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            if vm.state.isLoading {
                Spacer()
                ProgressView().tint(VitaColors.accent)
                Spacer()
            } else if vm.state.attempts.isEmpty {
                Spacer()
                VitaEmptyState(
                    title: "Nenhum simulado ainda",
                    message: "Comece seu primeiro simulado para testar seus conhecimentos e acompanhar sua evolução.",
                    actionText: "Começar primeiro simulado",
                    onAction: onNewSimulado
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        StatsCard(stats: vm.state.stats)
                            .padding(.top, 8)

                        VitaButton(label: "Novo Simulado", action: onNewSimulado)
                            .padding(.horizontal, 16)

                        if !vm.state.bySubject.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Por Matéria")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(VitaColors.textPrimary)
                                    .padding(.horizontal, 16)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(vm.state.bySubject) { subj in SubjectCard(subj: subj) }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        if !vm.state.bySemester.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Semestres")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(VitaColors.textPrimary)
                                    .padding(.horizontal, 16)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        SemesterChip(label: "Todos", isSelected: vm.state.selectedSemester == nil) {
                                            vm.selectSemester(nil)
                                        }
                                        ForEach(vm.state.bySemester) { sem in
                                            SemesterChip(label: sem.label, isSelected: vm.state.selectedSemester == sem.label) {
                                                vm.selectSemester(sem.label)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        HStack {
                            Text(vm.state.selectedSemester.map { "Histórico — \($0)" } ?? "Histórico")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VitaColors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)

                        if vm.state.filteredAttempts.isEmpty {
                            Text("Nenhum simulado neste período.")
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.textTertiary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        } else {
                            ForEach(vm.state.filteredAttempts) { attempt in
                                AttemptCard(attempt: attempt) {
                                    if attempt.status == "finished" { onOpenResult(attempt.id) }
                                    else { onOpenSession(attempt.id) }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) { vm.deleteAttempt(attempt.id) } label: {
                                        Label("Apagar", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button { vm.archiveAttempt(attempt.id) } label: {
                                        Label("Arquivar", systemImage: "archivebox")
                                    }
                                    .tint(VitaColors.accent)
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        VitaButton(label: "Ver Diagnóstico Completo", variant: .secondary, action: onOpenDiagnostics)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                    }
                }
            }
        }
        .background(VitaColors.surface.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}

// MARK: - Sub-components

private struct StatsCard: View {
    let stats: SimuladoStats
    var body: some View {
        HStack {
            Spacer()
            MiniStat(label: "Simulados", value: "\(stats.completedAttempts)")
            Spacer()
            MiniStat(label: "Média", value: "\(Int(stats.avgScore * 100))%",
                     valueColor: VitaColors.dataGreen)
            Spacer()
            MiniStat(label: "Questões", value: "\(stats.totalQuestions)")
            Spacer()
        }
        .padding(16)
        .background(VitaColors.glassBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VitaColors.glassBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
    }
}

private struct MiniStat: View {
    let label: String
    let value: String
    var valueColor: Color = .white.opacity(0.85)
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(valueColor)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(VitaColors.textTertiary)
        }
    }
}

private struct SubjectCard: View {
    let subj: SubjectSummary
    private var rate: Int { Int(subj.correctRate) }
    private var barColor: Color {
        rate >= 70 ? VitaColors.dataGreen : rate >= 50 ? VitaColors.dataAmber : VitaColors.dataRed
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(subj.subject)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1)
            Text("\(subj.totalAttempts) simulado\(subj.totalAttempts != 1 ? "s" : "")")
                .font(.system(size: 10))
                .foregroundStyle(VitaColors.textTertiary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(VitaColors.glassBorder)
                    RoundedRectangle(cornerRadius: 2).fill(barColor)
                        .frame(width: geo.size.width * CGFloat(subj.correctRate / 100).clamped(to: 0...1))
                }
            }
            .frame(height: 4)
            Text("\(rate)% acerto")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(barColor)
        }
        .padding(12)
        .frame(width: 140)
        .background(VitaColors.glassBg)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VitaColors.glassBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct SemesterChip: View {
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    var body: some View {
        Text(label)
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
            .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(isSelected ? VitaColors.accent.opacity(0.15) : VitaColors.glassBg)
            .overlay(
                Capsule().stroke(isSelected ? VitaColors.accent : VitaColors.glassBorder, lineWidth: 1)
            )
            .clipShape(Capsule())
            .onTapGesture(perform: onTap)
    }
}

private struct AttemptCard: View {
    let attempt: SimuladoAttemptEntry
    let onTap: () -> Void
    private var scorePercent: Int { Int(attempt.score * 100) }
    private var isFinished: Bool { attempt.status == "finished" }
    private var scoreColor: Color {
        scorePercent >= 70 ? VitaColors.dataGreen : scorePercent >= 50 ? VitaColors.dataAmber : VitaColors.dataRed
    }
    private var dateDisplay: String {
        guard let raw = attempt.startedAt, raw.count >= 10 else { return "" }
        let parts = String(raw.prefix(10)).split(separator: "-")
        guard parts.count == 3 else { return "" }
        return "\(parts[2])/\(parts[1])"
    }
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(attempt.title.isEmpty ? "Simulado" : attempt.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textPrimary)
                HStack(spacing: 6) {
                    if let subj = attempt.subject, !subj.isEmpty {
                        Text(subj)
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.accent)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(VitaColors.accent.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Text(attempt.mode == "exam" ? "Prova" : "Imediato")
                        .font(.system(size: 10))
                        .foregroundStyle(VitaColors.textSecondary)
                    if !dateDisplay.isEmpty {
                        Text(dateDisplay)
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if isFinished {
                    Text("\(scorePercent)%")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(scoreColor)
                }
                Text(isFinished ? "Finalizado" : "Em andamento")
                    .font(.system(size: 10))
                    .foregroundStyle(isFinished ? VitaColors.dataGreen : VitaColors.dataAmber)
            }
        }
        .padding(14)
        .background(VitaColors.glassBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VitaColors.glassBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Extensions

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        max(range.lowerBound, min(self, range.upperBound))
    }
}
