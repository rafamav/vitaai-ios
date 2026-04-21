import SwiftUI
import Sentry

// MARK: - TrabalhoScreen

struct TrabalhoScreen: View {
    @Environment(\.appContainer) private var container
    var onOpenDetail: ((String) -> Void)? = nil
    @State private var viewModel: TrabalhoViewModel?

    // Editor navigation state
    @State private var showEditor: Bool = false
    @State private var editorAssignmentId: String? = nil

    private let segments = ["Tarefas", "Notas por Disciplina"]

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
                viewModel = TrabalhoViewModel(api: container.api, dataManager: container.dataManager)
                Task {
                    await viewModel?.load()
                    SentrySDK.reportFullyDisplayed()
                }
            }
        }
        .fullScreenCover(isPresented: $showEditor) {
            if #available(iOS 17, *) {
                TrabalhoEditorView(
                    assignmentId: editorAssignmentId,
                    templateId: nil,
                    onDismiss: {
                        showEditor = false
                        editorAssignmentId = nil
                    }
                )
            } else {
                VStack(spacing: 16) {
                    Text("Recurso indisponível no iOS 16")
                        .foregroundColor(.white)
                    Button("Fechar") { showEditor = false }
                        .foregroundColor(VitaColors.accent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VitaColors.surface)
            }
        }
        .trackScreen("Trabalho")
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
        let allEmpty = vm.pending.isEmpty && vm.overdue.isEmpty && vm.completed.isEmpty

        if vm.isLoading {
            ProgressView()
                .tint(VitaColors.accent)
                .padding(.top, 40)
        } else if allEmpty {
            TrabalhoEmptyState(
                icon: "checkmark.circle",
                message: "Nenhuma tarefa encontrada.\nConecte seu portal para sincronizar."
            )
        } else {
            VStack(spacing: 16) {
                // Overdue section
                if !vm.overdue.isEmpty {
                    trabalhoSection(
                        vm: vm,
                        title: "Atrasados",
                        subtitle: "\(vm.overdue.count)",
                        icon: "exclamationmark.triangle.fill",
                        iconColor: VitaColors.dataRed,
                        items: vm.overdue
                    )
                }

                // Pending section
                if !vm.pending.isEmpty {
                    trabalhoSection(
                        vm: vm,
                        title: "Pendentes",
                        subtitle: "\(vm.pending.count)",
                        icon: "clock.fill",
                        iconColor: VitaColors.accent,
                        items: vm.pending
                    )
                }

                // Completed section
                if !vm.completed.isEmpty {
                    trabalhoSection(
                        vm: vm,
                        title: "Entregues",
                        subtitle: "\(vm.completed.count)",
                        icon: "checkmark.circle.fill",
                        iconColor: VitaColors.dataGreen,
                        items: vm.completed
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func trabalhoSection(
        vm: TrabalhoViewModel,
        title: String,
        subtitle: String,
        icon: String,
        iconColor: Color,
        items: [TrabalhoItem]
    ) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                Text(subtitle)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
                Spacer()
            }

            ForEach(items) { item in
                SwipeToArchive(onArchive: { vm.dismiss(item) }) {
                    Button {
                        if let onOpenDetail {
                            onOpenDetail(item.id)
                        } else {
                            editorAssignmentId = item.id
                            showEditor = true
                        }
                    } label: {
                        TrabalhoRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Grades Tab (grouped by discipline)

    @ViewBuilder
    private func gradesContent(vm: TrabalhoViewModel) -> some View {
        VStack(spacing: 16) {
            if vm.grades.isEmpty {
                TrabalhoEmptyState(
                    icon: "chart.bar",
                    message: "Nenhuma nota registrada"
                )
            } else {
                let grouped = Dictionary(grouping: vm.sortedGrades, by: { $0.label.isEmpty ? "Sem disciplina" : $0.label })
                let sortedKeys = grouped.keys.sorted()

                ForEach(sortedKeys, id: \.self) { subject in
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "book.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.accent)
                            Text(subject)
                                .font(VitaTypography.labelMedium)
                                .foregroundStyle(VitaColors.textPrimary)
                            Text("\(grouped[subject]?.count ?? 0)")
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textTertiary)
                            Spacer()
                        }

                        ForEach(grouped[subject] ?? []) { grade in
                            GradeRow(grade: grade)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Trabalho Row

private struct TrabalhoRow: View {
    let item: TrabalhoItem

    private var urgencyColor: Color {
        guard let days = item.daysUntil else { return VitaColors.textTertiary }
        if days < 0 { return VitaColors.dataRed }
        if days <= 1 { return VitaColors.dataRed }
        if days <= 3 { return VitaColors.dataAmber }
        if days <= 7 { return VitaColors.accent }
        return VitaColors.dataGreen
    }

    private var isCompleted: Bool { item.submitted }

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                // Urgency bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(isCompleted ? VitaColors.textTertiary.opacity(0.4) : urgencyColor)
                    .frame(width: 3, height: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(isCompleted ? VitaColors.textTertiary : VitaColors.textPrimary)
                        .strikethrough(isCompleted)
                        .lineLimit(2)

                    Text(item.subjectName)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)

                    HStack(spacing: 8) {
                        if let days = item.daysUntil {
                            Text(daysLabel(days))
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(isCompleted ? VitaColors.textTertiary : urgencyColor.opacity(0.8))
                        }

                        // Submission type pill
                        Text(item.submissionTypeLabel)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(VitaColors.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VitaColors.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(VitaColors.dataGreen)
                            .font(.system(size: 16))
                    } else if item.canGenerate {
                        Image("vita_btn")
                            .resizable()
                            .frame(width: 22, height: 22)
                            .opacity(0.9)
                    }

                    if let pts = item.pointsPossible, pts > 0 {
                        Text("\(Int(pts))pts")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .opacity(isCompleted ? 0.7 : 1.0)
        }
    }

    private func daysLabel(_ days: Int) -> String {
        if days < 0 { return "\(abs(days))d atrasado" }
        if days == 0 { return "Hoje" }
        if days == 1 { return "Amanha" }
        return "Em \(days) dias"
    }
}

// MARK: - Grade Row

private struct GradeRow: View {
    let grade: GradeEntry

    private var gradeColor: Color {
        let pct = grade.maxValue > 0 ? grade.value / grade.maxValue : 0
        if pct >= 0.7 { return VitaColors.dataGreen }
        if pct >= 0.5 { return VitaColors.dataAmber }
        return VitaColors.dataRed
    }

    private var fillFraction: Double {
        guard grade.maxValue > 0 else { return 0 }
        return min(grade.value / grade.maxValue, 1.0)
    }

    var body: some View {
        VitaGlassCard {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
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

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(VitaColors.surfaceElevated)
                            .frame(height: 3)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(gradeColor.opacity(0.75))
                            .frame(width: geo.size.width * fillFraction, height: 3)
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

// MARK: - Swipe to Archive

private struct SwipeToArchive<Content: View>: View {
    let onArchive: () -> Void
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    @State private var showingAction = false
    private let threshold: CGFloat = -80

    var body: some View {
        ZStack(alignment: .trailing) {
            // Background action
            HStack {
                Spacer()
                VStack(spacing: 2) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 16))
                    Text("Arquivar")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(width: 72)
            }
            .background(VitaColors.dataRed.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(offset < -20 ? 1 : 0)

            // Content
            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let translation = value.translation.width
                            if translation < 0 {
                                offset = translation * 0.7
                            }
                        }
                        .onEnded { value in
                            if offset < threshold {
                                // Full swipe — archive
                                withAnimation(.easeOut(duration: 0.25)) {
                                    offset = -400
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    onArchive()
                                }
                            } else {
                                withAnimation(.spring(duration: 0.3)) {
                                    offset = 0
                                }
                            }
                        }
                )
        }
    }
}
