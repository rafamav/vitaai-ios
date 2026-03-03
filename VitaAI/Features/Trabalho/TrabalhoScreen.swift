import SwiftUI

// MARK: - TrabalhoScreen

struct TrabalhoScreen: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: TrabalhoViewModel?

    // Editor navigation state
    @State private var showEditor: Bool = false
    @State private var editorAssignmentId: String? = nil

    private let segments = ["Tarefas", "Notas"]

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm: vm)
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = TrabalhoViewModel(api: container.api)
                Task { await viewModel?.load() }
            }
        }
        .fullScreenCover(isPresented: $showEditor) {
            TrabalhoEditorView(
                assignmentId: editorAssignmentId,
                templateId: editorAssignmentId == nil ? nil : nil,
                onDismiss: {
                    showEditor = false
                    editorAssignmentId = nil
                }
            )
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(vm: TrabalhoViewModel) -> some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    segmentControl(vm: vm)

                    if vm.selectedSegment == 0 {
                        assignmentsContent(vm: vm)
                    } else {
                        gradesContent(vm: vm)
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .refreshable { await vm.load() }

            // FAB — Novo Trabalho (only on Tarefas tab)
            if vm.selectedSegment == 0 {
                Button {
                    editorAssignmentId = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(VitaColors.surface)
                        .frame(width: 52, height: 52)
                        .background(
                            LinearGradient(
                                colors: [VitaColors.accent, VitaColors.accentDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: VitaColors.accent.opacity(0.4), radius: 12, x: 0, y: 4)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 24)
                .sensoryFeedback(.selection, trigger: showEditor)
                .transition(.scale.combined(with: .opacity))
                .animation(.spring(duration: 0.3), value: vm.selectedSegment)
            }
        }
    }

    // MARK: - Segment Control

    @ViewBuilder
    private func segmentControl(vm: TrabalhoViewModel) -> some View {
        HStack(spacing: 0) {
            ForEach(segments.indices, id: \.self) { i in
                Button(segments[i]) {
                    withAnimation(.spring(duration: 0.2)) {
                        vm.selectedSegment = i
                    }
                }
                .font(VitaTypography.labelMedium)
                .foregroundStyle(
                    vm.selectedSegment == i ? VitaColors.surface : VitaColors.textSecondary
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(vm.selectedSegment == i ? VitaColors.accent : Color.clear)
            }
        }
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }

    // MARK: - Assignments Tab

    @ViewBuilder
    private func assignmentsContent(vm: TrabalhoViewModel) -> some View {
        VStack(spacing: 8) {
            // Summary header
            if vm.pendingCount > 0 {
                HStack {
                    SectionHeader(
                        title: "Tarefas",
                        subtitle: "\(vm.pendingCount) pendente\(vm.pendingCount == 1 ? "" : "s")"
                    )
                }
            } else {
                SectionHeader(title: "Tarefas")
            }

            if vm.assignments.isEmpty {
                TrabalhoEmptyState(
                    icon: "checkmark.circle",
                    message: "Nenhuma tarefa pendente"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(vm.sortedAssignments) { assignment in
                        Button {
                            editorAssignmentId = assignment.id
                            showEditor = true
                        } label: {
                            AssignmentRow(assignment: assignment)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Grades Tab

    @ViewBuilder
    private func gradesContent(vm: TrabalhoViewModel) -> some View {
        VStack(spacing: 8) {
            SectionHeader(title: "Notas")

            if vm.grades.isEmpty {
                TrabalhoEmptyState(
                    icon: "chart.bar",
                    message: "Nenhuma nota registrada"
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(vm.sortedGrades) { grade in
                        GradeRow(grade: grade)
                    }
                }
            }
        }
    }
}

// MARK: - Assignment Row

private struct AssignmentRow: View {
    let assignment: LocalAssignment

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                // Urgency indicator bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        assignment.isSubmitted
                            ? Color.gray.opacity(0.4)
                            : assignment.urgencyColor
                    )
                    .frame(width: 3, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(assignment.title)
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(
                            assignment.isSubmitted
                                ? VitaColors.textTertiary
                                : VitaColors.textPrimary
                        )
                        .strikethrough(assignment.isSubmitted)
                        .lineLimit(2)

                    Text(assignment.courseName)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)

                    if let due = assignment.dueAt {
                        Text("Entrega: \(formattedDate(due))")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(
                                assignment.isSubmitted
                                    ? VitaColors.textTertiary
                                    : assignment.urgencyColor.opacity(0.8)
                            )
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    if assignment.isSubmitted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                            .font(.system(size: 16))
                    }
                    if let pts = assignment.pointsPossible {
                        Text("\(Int(pts))pts")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .opacity(assignment.isSubmitted ? 0.7 : 1.0)
        }
    }
}

// MARK: - Grade Row

private struct GradeRow: View {
    let grade: GradeEntry

    private var gradeColor: Color {
        let pct = grade.maxValue > 0 ? grade.value / grade.maxValue : 0
        if pct >= 0.7 { return Color(hex: 0x22C55E) }
        if pct >= 0.5 { return Color.yellow }
        return Color.red
    }

    private var fillFraction: Double {
        guard grade.maxValue > 0 else { return 0 }
        return min(grade.value / grade.maxValue, 1.0)
    }

    var body: some View {
        VitaGlassCard {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    // Icon square
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(VitaColors.surfaceElevated)
                            .frame(width: 34, height: 34)
                        Image(systemName: "doc.badge.checkmark")
                            .font(.system(size: 13))
                            .foregroundStyle(VitaColors.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(grade.label)
                            .font(VitaTypography.labelMedium)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(2)

                        if let date = grade.date {
                            Text(date)
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "%.1f", grade.value))
                            .font(.system(size: 16, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(gradeColor)

                        Text("/ \(String(format: "%.0f", grade.maxValue))")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }

                // Grade bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(VitaColors.surfaceElevated)
                            .frame(height: 3)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(gradeColor.opacity(0.75))
                            .frame(
                                width: geo.size.width * fillFraction,
                                height: 3
                            )
                    }
                }
                .frame(height: 3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Empty State

private struct TrabalhoEmptyState: View {
    let icon: String
    let message: String

    var body: some View {
        VitaGlassCard {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(VitaColors.textTertiary)

                Text(message)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textTertiary)
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Helpers

private func formattedDate(_ date: Date) -> String {
    let df = DateFormatter()
    df.locale = Locale(identifier: "pt_BR")
    df.dateStyle = .short
    return df.string(from: date)
}
