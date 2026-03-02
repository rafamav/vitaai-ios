import SwiftUI

private let difficulties: [(String, String)] = [
    ("easy", "Fácil"),
    ("medium", "Médio"),
    ("hard", "Difícil"),
]
private let questionCounts = [10, 20, 30, 50]

struct SimuladoConfigScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: SimuladoViewModel?
    let onBack: () -> Void
    let onStartSession: (String) -> Void

    var body: some View {
        Group {
            if let vm {
                configContent(vm: vm)
            } else {
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    ProgressView().tint(VitaColors.accent)
                }
            }
        }
        .onAppear {
            if vm == nil { vm = SimuladoViewModel(api: container.api) }
            vm?.loadCourses()
        }
    }

    @ViewBuilder
    private func configContent(vm: SimuladoViewModel) -> some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(width: 44, height: 44)
                }
                Text("Novo Simulado")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // ── 1. Course selector ──
                    ConfigSectionTitle("Matéria (Curso)")

                    if vm.state.coursesLoading {
                        HStack {
                            Spacer()
                            ProgressView().tint(VitaColors.accent)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    } else {
                        FlowLayout(spacing: 8) {
                            // "Geral" option
                            ChipButton(
                                label: "Geral",
                                isSelected: vm.state.selectedCourse == nil && !vm.state.selectedSubject.isEmpty
                            ) {
                                vm.selectCourse(nil)
                                vm.setSubject("Geral")
                            }
                            ForEach(vm.state.courses) { course in
                                ChipButton(
                                    label: cleanCourseName(course.name),
                                    isSelected: vm.state.selectedCourse?.id == course.id
                                ) {
                                    vm.selectCourse(course)
                                }
                            }
                        }
                        if vm.state.courses.isEmpty {
                            Text("Nenhum curso encontrado. Conecte o Canvas primeiro.")
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                    }

                    // ── 2. PDF selector (visible after selecting a course) ──
                    if vm.state.selectedCourse != nil {
                        ConfigSectionTitle("Slides / PDFs")

                        if vm.state.filesLoading {
                            HStack {
                                Spacer()
                                ProgressView().tint(VitaColors.accent)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        } else if vm.state.files.isEmpty {
                            Text("Nenhum PDF com texto extraído neste curso.")
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.textTertiary)
                        } else {
                            let grouped = Dictionary(grouping: vm.state.files) { $0.moduleName ?? "Sem módulo" }
                            let sortedKeys = grouped.keys.sorted()
                            ForEach(sortedKeys, id: \.self) { moduleName in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(moduleName)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(VitaColors.textTertiary)

                                    FlowLayout(spacing: 8) {
                                        ForEach(grouped[moduleName] ?? []) { file in
                                            let displayName = file.displayName
                                                .replacingOccurrences(of: ".pdf", with: "", options: .caseInsensitive)
                                            ChipButton(
                                                label: displayName,
                                                isSelected: vm.state.selectedFileIds.contains(file.id)
                                            ) {
                                                vm.toggleFile(file.id)
                                            }
                                        }
                                    }
                                }
                            }
                            if vm.state.selectedFileIds.isEmpty {
                                Text("Nenhum selecionado = usa todos os PDFs do curso")
                                    .font(.system(size: 11))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                        }
                    }

                    // ── 3. Difficulty ──
                    ConfigSectionTitle("Dificuldade")
                    HStack(spacing: 8) {
                        ForEach(difficulties, id: \.0) { (key, label) in
                            ChipButton(
                                label: label,
                                isSelected: vm.state.selectedDifficulty == key
                            ) {
                                vm.setDifficulty(key)
                            }
                        }
                    }

                    // ── 4. Question count ──
                    ConfigSectionTitle("Número de Questões")
                    HStack(spacing: 8) {
                        ForEach(questionCounts, id: \.self) { count in
                            ChipButton(
                                label: "\(count)",
                                isSelected: vm.state.selectedQuestionCount == count
                            ) {
                                vm.setQuestionCount(count)
                            }
                        }
                    }

                    // ── 5. Mode ──
                    ConfigSectionTitle("Modo")
                    ModeCard(
                        icon: "checkmark.circle",
                        title: "Feedback Imediato",
                        description: "Veja se acertou a cada questão",
                        isSelected: vm.state.selectedMode == "immediate"
                    ) {
                        vm.setMode("immediate")
                    }
                    ModeCard(
                        icon: "timer",
                        title: "Prova Real",
                        description: "Resultado só no final, como uma prova de verdade",
                        isSelected: vm.state.selectedMode == "exam"
                    ) {
                        vm.setMode("exam")
                    }

                    // Error
                    if let error = vm.state.error {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(VitaColors.dataRed)
                    }
                }
                .padding(16)
            }

            // Generate button
            VStack(spacing: 8) {
                if vm.state.isGenerating {
                    VStack(spacing: 10) {
                        ProgressView().tint(VitaColors.accent)
                        Text("Analisando PDFs e gerando questões...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(VitaColors.accent)
                        Text("Isso pode levar alguns segundos")
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    .padding(.vertical, 12)
                } else {
                    VitaButton(
                        label: "Gerar Simulado",
                        isDisabled: vm.state.selectedSubject.isEmpty,
                        action: { vm.generateSimulado() }
                    )
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
        .background(VitaColors.surface.ignoresSafeArea())
        .navigationBarHidden(true)
        .onChange(of: vm.state.currentAttemptId) { _, newId in
            if let id = newId, !vm.state.isGenerating, !vm.state.questions.isEmpty {
                onStartSession(id)
            }
        }
    }
}

// MARK: - Sub-components

private struct ConfigSectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(VitaColors.textPrimary)
    }
}

private struct ChipButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textPrimary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? VitaColors.accent.opacity(0.15) : VitaColors.glassBg)
                .overlay(
                    Capsule().stroke(isSelected ? VitaColors.accent : VitaColors.glassBorder, lineWidth: 1)
                )
                .clipShape(Capsule())
        }
    }
}

private struct ModeCard: View {
    let icon: String
    let title: String
    let description: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textTertiary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textPrimary)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textSecondary)
                }
                Spacer()
            }
            .padding(16)
            .background(isSelected ? VitaColors.accent.opacity(0.05) : VitaColors.glassBg)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? VitaColors.accent : VitaColors.glassBorder,
                            lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: currentY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Helpers

private func cleanCourseName(_ raw: String) -> String {
    let stripped = raw.replacingOccurrences(of: #"^\d+\s*-\s*"#, with: "", options: .regularExpression)
    let roman = Set(["I","II","III","IV","V","VI","VII","VIII","IX","X"])
    let lowercase = Set(["DE","DA","DO","DAS","DOS","E","EM","COM"])
    return stripped.split(separator: " ").map { word in
        let upper = word.uppercased()
        if roman.contains(upper) { return upper }
        if lowercase.contains(upper) { return upper.lowercased() }
        return upper.prefix(1) + word.dropFirst().lowercased()
    }.joined(separator: " ")
}
