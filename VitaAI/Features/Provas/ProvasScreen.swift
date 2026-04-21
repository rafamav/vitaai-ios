import SwiftUI
import PhotosUI
import Sentry

// MARK: - ProvasScreen
// Mirrors Android: ui/screens/provas/ProvasScreen.kt

struct ProvasScreen: View {
    @Environment(\.appContainer) private var container
    var onBack: () -> Void

    @State private var viewModel: ProvasViewModel?
    @State private var selectedPhotos: [PhotosPickerItem] = []

    var body: some View {
        Group {
            if let vm = viewModel {
                ProvasContent(
                    vm: vm,
                    selectedPhotos: $selectedPhotos,
                    onBack: onBack
                )
                .onChange(of: selectedPhotos) { newItems in
                    Task { @MainActor in
                        await loadSelectedPhotos(newItems, vm: vm)
                    }
                }
            } else {
                ProgressView().tint(VitaColors.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = ProvasViewModel(api: container.api)
                viewModel = vm
                Task {
                    await vm.loadAll()
                    SentrySDK.reportFullyDisplayed()
                }
            }
        }
        .navigationBarHidden(true)
        .trackScreen("Provas")
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem], vm: ProvasViewModel) async {
        var results: [(Data, String, String)] = []
        for (index, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let filename = "exam_\(index + 1).jpg"
                results.append((data, filename, "image/jpeg"))
            }
        }
        if !results.isEmpty {
            vm.setPendingImages(results)
        }
        selectedPhotos = []
    }
}

// MARK: - ProvasContent

private struct ProvasContent: View {
    @Bindable var vm: ProvasViewModel
    @Binding var selectedPhotos: [PhotosPickerItem]
    let onBack: () -> Void

    private let tabLabels = ["Upload", "Professores", "Provas"]

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Back bar
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Voltar")
                                .font(VitaTypography.labelLarge)
                        }
                        .foregroundColor(VitaColors.textPrimary)
                    }
                    Spacer()
                    Text("Provas")
                        .font(VitaTypography.titleMedium)
                        .foregroundColor(VitaColors.textPrimary)
                    Spacer()
                    // Balance the back button
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Voltar")
                    }
                    .opacity(0)
                    .font(VitaTypography.labelLarge)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                // Tab bar
                HStack(spacing: 0) {
                    ForEach(tabLabels.indices, id: \.self) { index in
                        Button {
                            vm.selectTab(index)
                        } label: {
                            VStack(spacing: 8) {
                                Text(tabLabels[index])
                                    .font(VitaTypography.bodyMedium)
                                    .fontWeight(vm.selectedTab == index ? .semibold : .regular)
                                    .foregroundColor(
                                        vm.selectedTab == index
                                        ? VitaColors.textPrimary
                                        : VitaColors.textSecondary
                                    )
                                Rectangle()
                                    .fill(vm.selectedTab == index ? VitaColors.accent : Color.clear)
                                    .frame(height: 2)
                                    .animation(.easeInOut(duration: 0.2), value: vm.selectedTab)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)

                Spacer().frame(height: 8)

                // Tab content
                switch vm.selectedTab {
                case 0:
                    UploadTab(vm: vm, selectedPhotos: $selectedPhotos)
                case 1:
                    ProfessoresTab(vm: vm)
                default:
                    ProvasTab(vm: vm)
                }
            }
        }
    }
}

// MARK: - UploadTab

private struct UploadTab: View {
    @Bindable var vm: ProvasViewModel
    @Binding var selectedPhotos: [PhotosPickerItem]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Drop zone / picker
                PhotosPicker(
                    selection: $selectedPhotos,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    VitaGlassCard {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(VitaColors.surfaceElevated)
                                    .frame(width: 56, height: 56)
                                Image(systemName: "icloud.and.arrow.up")
                                    .font(.system(size: 26))
                                    .foregroundColor(VitaColors.accent)
                            }
                            Text("Selecionar imagens da prova")
                                .font(VitaTypography.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(VitaColors.textPrimary)
                            Text("Toque para escolher fotos da galeria")
                                .font(VitaTypography.bodySmall)
                                .foregroundColor(VitaColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                    }
                }
                .buttonStyle(.plain)

                // Pending images + upload button
                if vm.pendingImageCount > 0 {
                    VitaGlassCard {
                        VStack(spacing: 12) {
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .foregroundColor(VitaColors.accent)
                                    Text("\(vm.pendingImageCount) imagem(ns) selecionada(s)")
                                        .font(VitaTypography.bodyMedium)
                                        .fontWeight(.semibold)
                                        .foregroundColor(VitaColors.textPrimary)
                                }
                                Spacer()
                                Button {
                                    vm.clearPendingImages()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 14))
                                        .foregroundColor(VitaColors.textSecondary)
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .accessibilityLabel("Limpar imagens")
                            }

                            if let uploadErr = vm.uploadError {
                                Text(uploadErr)
                                    .font(VitaTypography.bodySmall)
                                    .foregroundColor(VitaColors.dataRed)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            VitaButton(
                                text: vm.isUploading ? "Enviando..." : "Enviar para processamento",
                                action: {
                                    Task { await vm.uploadImages() }
                                },
                                variant: .primary,
                                size: .lg,
                                isEnabled: !vm.isUploading,
                                isLoading: vm.isUploading,
                                leadingSystemImage: vm.isUploading ? nil : "paperplane"
                            )
                        }
                        .padding(16)
                    }
                }

                // Upload history
                if !vm.uploads.isEmpty {
                    Text("HISTÓRICO DE UPLOADS")
                        .font(VitaTypography.labelSmall)
                        .foregroundColor(VitaColors.textSecondary)
                        .tracking(1.2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    ForEach(vm.uploads) { upload in
                        UploadHistoryCard(upload: upload)
                    }
                }

                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .refreshable { await vm.loadAll() }
    }
}

// MARK: - UploadHistoryCard

private struct UploadHistoryCard: View {
    let upload: CrowdUploadRecord

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                let (icon, tint) = statusIconAndTint(upload.status)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(upload.id.prefix(12)) + "…")
                        .font(VitaTypography.bodySmall)
                        .fontWeight(.semibold)
                        .foregroundColor(VitaColors.textPrimary)
                        .lineLimit(1)
                    Text(statusLabel(upload.status, error: upload.errorMessage))
                        .font(VitaTypography.bodySmall)
                        .foregroundColor(VitaColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if pendingStatuses.contains(upload.status) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(VitaColors.accent)
                }
            }
            .padding(16)
        }
    }

    private let pendingStatuses: Set<String> = ["pending", "processing"]

    private func statusIconAndTint(_ status: String) -> (String, Color) {
        switch status {
        case "completed": return ("checkmark.circle.fill", VitaColors.accent)
        case "failed":    return ("exclamationmark.circle.fill", VitaColors.dataRed)
        case "processing": return ("hourglass", VitaColors.dataAmber)
        default:          return ("hourglass", VitaColors.textSecondary)
        }
    }

    private func statusLabel(_ status: String, error: String?) -> String {
        switch status {
        case "completed":  return "Concluído"
        case "failed":     return error ?? "Falha"
        case "processing": return "Processando…"
        case "pending":    return "Na fila…"
        default:           return status
        }
    }
}

// MARK: - ProfessoresTab

private struct ProfessoresTab: View {
    @Bindable var vm: ProvasViewModel

    var body: some View {
        if vm.isLoading && vm.professors.isEmpty {
            Spacer()
            ProgressView().tint(VitaColors.accent)
            Spacer()
        } else if vm.professors.isEmpty {
            ProvasEmptyState(
                message: "Nenhum professor encontrado.\nEnvie provas para construir o perfil.",
                onRefresh: { vm.loadProfessors() }
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Text("\(vm.professors.count) PROFESSOR(ES)")
                        .font(VitaTypography.labelSmall)
                        .foregroundColor(VitaColors.textSecondary)
                        .tracking(1.2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    ForEach(vm.professors) { professor in
                        ProfessorCard(professor: professor)
                    }
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .refreshable { await vm.loadAll() }
        }
    }
}

// MARK: - ProfessorCard

private struct ProfessorCard: View {
    let professor: CrowdProfessor

    var body: some View {
        VitaGlassCard {
            HStack(alignment: .top, spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(VitaColors.surfaceElevated)
                        .frame(width: 40, height: 40)
                    Image(systemName: "person")
                        .font(.system(size: 18))
                        .foregroundColor(VitaColors.accent)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(professor.nameDisplay.isEmpty ? "Professor desconhecido" : professor.nameDisplay)
                        .font(VitaTypography.bodyMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(VitaColors.textPrimary)
                        .lineLimit(1)

                    if !professor.institution.isEmpty {
                        Text(professor.institution)
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.textSecondary)
                            .lineLimit(1)
                    }

                    if !professor.disciplines.isEmpty {
                        Text(professor.disciplines.prefix(3).joined(separator: " · "))
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.accent)
                            .lineLimit(1)
                    }

                    HStack(spacing: 16) {
                        ProvasStatChip(value: "\(professor.examCount)", label: "provas")
                        ProvasStatChip(value: "\(professor.questionCount)", label: "questões")
                    }
                    .padding(.top, 2)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(VitaColors.textSecondary)
            }
            .padding(16)
        }
    }
}

// MARK: - ProvasTab

private struct ProvasTab: View {
    @Bindable var vm: ProvasViewModel

    var body: some View {
        // Exam detail overlay
        if let exam = vm.selectedExam {
            ExamDetailView(
                exam: exam,
                isLoading: vm.isLoading,
                onBack: { vm.clearSelectedExam() }
            )
        } else if vm.isLoading && vm.exams.isEmpty {
            Spacer()
            ProgressView().tint(VitaColors.accent)
            Spacer()
        } else if vm.exams.isEmpty {
            ProvasEmptyState(
                message: "Nenhuma prova encontrada.\nEnvie fotos de provas para começar.",
                onRefresh: { vm.loadExams() }
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    Text("\(vm.exams.count) PROVA(S)")
                        .font(VitaTypography.labelSmall)
                        .foregroundColor(VitaColors.textSecondary)
                        .tracking(1.2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)

                    ForEach(vm.exams) { exam in
                        ExamCard(exam: exam) {
                            vm.loadExamDetail(exam.id)
                        }
                    }
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
            }
            .refreshable { await vm.loadAll() }
        }
    }
}

// MARK: - ExamCard

private struct ExamCard: View {
    let exam: CrowdExamEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VitaGlassCard {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exam.discipline.isEmpty ? "Disciplina não identificada" : exam.discipline)
                            .font(VitaTypography.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(VitaColors.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Text(exam.professorName.isEmpty ? "Prof. desconhecido" : exam.professorName)
                                .font(VitaTypography.bodySmall)
                                .foregroundColor(VitaColors.textSecondary)
                                .lineLimit(1)

                            if !exam.institution.isEmpty {
                                Text("·")
                                    .font(VitaTypography.bodySmall)
                                    .foregroundColor(VitaColors.textSecondary)
                                Text(exam.institution)
                                    .font(VitaTypography.bodySmall)
                                    .foregroundColor(VitaColors.textSecondary)
                                    .lineLimit(1)
                            }
                        }

                        HStack(spacing: 12) {
                            if !(exam.examType ?? "").isEmpty {
                                ProvasTagChip(label: exam.examType ?? "")
                            }
                            if let semester = exam.semester {
                                ProvasTagChip(label: semester)
                            }
                            ProvasStatChip(value: "\(exam.questionCount)", label: "questões")
                        }
                        .padding(.top, 2)
                    }

                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(VitaColors.textSecondary)
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ExamDetailView

private struct ExamDetailView: View {
    let exam: CrowdExamDetail
    let isLoading: Bool
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exam.discipline.isEmpty ? "Prova" : exam.discipline)
                        .font(VitaTypography.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(VitaColors.textPrimary)
                        .lineLimit(1)

                    let subtitle = [exam.professorName, exam.institution]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.textSecondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button(action: onBack) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(VitaColors.textSecondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()
                .overlay(VitaColors.glassBorder)
                .padding(.vertical, 4)

            if isLoading {
                Spacer()
                ProgressView().tint(VitaColors.accent)
                Spacer()
            } else if exam.questions.isEmpty {
                Spacer()
                Text("Nenhuma questão extraída ainda.")
                    .font(VitaTypography.bodyMedium)
                    .foregroundColor(VitaColors.textSecondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Text("\(exam.questions.count) QUESTÃO(ÕES)")
                            .font(VitaTypography.labelSmall)
                            .foregroundColor(VitaColors.textSecondary)
                            .tracking(1.2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 8)

                        ForEach(exam.questions) { question in
                            QuestionCard(question: question)
                        }
                        Spacer().frame(height: 24)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

// MARK: - QuestionCard

private struct QuestionCard: View {
    let question: CrowdQuestion
    @State private var expanded = false

    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        expanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 8) {
                        // Question number badge
                        ZStack {
                            Circle()
                                .fill(VitaColors.accent.opacity(0.15))
                                .overlay(
                                    Circle().stroke(VitaColors.accent.opacity(0.4), lineWidth: 1)
                                )
                                .frame(width: 28, height: 28)
                            Text("\(question.questionIndex + 1)")
                                .font(VitaTypography.labelSmall)
                                .fontWeight(.bold)
                                .foregroundColor(VitaColors.accent)
                        }

                        let preview = expanded
                            ? question.statement
                            : String(question.statement.prefix(120)) + (question.statement.count > 120 ? "…" : "")

                        Text(preview)
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: expanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(VitaColors.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                if expanded {
                    VStack(alignment: .leading, spacing: 6) {
                        // Options
                        if let options = question.options, !options.isEmpty {
                            Divider().overlay(VitaColors.glassBorder)
                            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(Character(UnicodeScalar(65 + index)!)).")
                                        .font(VitaTypography.bodySmall)
                                        .fontWeight(.semibold)
                                        .foregroundColor(VitaColors.accent)
                                    Text(option)
                                        .font(VitaTypography.bodySmall)
                                        .foregroundColor(VitaColors.textPrimary)
                                }
                            }
                        }

                        // Answer
                        if let answer = question.answer {
                            Divider().overlay(VitaColors.glassBorder)
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11))
                                    .foregroundColor(VitaColors.accent)
                                Text("Resposta: \(answer)")
                                    .font(VitaTypography.bodySmall)
                                    .fontWeight(.semibold)
                                    .foregroundColor(VitaColors.accent)
                            }
                        }

                        // Tags
                        if question.topic != nil || question.difficulty != nil {
                            HStack(spacing: 8) {
                                if let topic = question.topic { ProvasTagChip(label: topic) }
                                if let diff  = question.difficulty { ProvasTagChip(label: diff) }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Shared Helper Views

private struct ProvasStatChip: View {
    let value: String
    let label: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            Text(value)
                .font(VitaTypography.labelSmall)
                .fontWeight(.bold)
                .foregroundColor(VitaColors.textPrimary)
            Text(label)
                .font(VitaTypography.labelSmall)
                .foregroundColor(VitaColors.textSecondary)
        }
    }
}

private struct ProvasTagChip: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(VitaColors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(VitaColors.glassBorder.opacity(2), lineWidth: 0.5)
            )
    }
}

private struct ProvasEmptyState: View {
    let message: String
    let onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "graduationcap")
                .font(.system(size: 48))
                .foregroundColor(VitaColors.textSecondary)
            Text(message)
                .font(VitaTypography.bodyMedium)
                .foregroundColor(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
            VitaButton(text: "Atualizar", action: onRefresh, variant: .secondary, size: .md)
            Spacer()
        }
        .padding(.horizontal, 32)
    }
}
