import SwiftUI

// MARK: - CourseDetailScreen
// Mirrors Android: ui/screens/coursedetail/CourseDetailScreen.kt

struct CourseDetailScreen: View {
    @Environment(\.appContainer) private var container

    let courseId: String
    let folderColor: Color
    var onBack: () -> Void
    var onNavigateToPdfViewer: ((URL) -> Void)?
    var onNavigateToCanvasConnect: (() -> Void)?

    @State private var viewModel: CourseDetailViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                CourseDetailContent(
                    vm: vm,
                    folderColor: folderColor,
                    onBack: onBack,
                    onNavigateToPdfViewer: onNavigateToPdfViewer,
                    onNavigateToCanvasConnect: onNavigateToCanvasConnect
                )
            } else {
                ZStack {
                    VitaScreenBg()
                    ProgressView().tint(folderColor)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = CourseDetailViewModel(api: container.api, courseId: courseId)
                viewModel = vm
                Task { await vm.load() }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - CourseDetailContent

private struct CourseDetailContent: View {
    @Bindable var vm: CourseDetailViewModel
    let folderColor: Color
    let onBack: () -> Void
    let onNavigateToPdfViewer: ((URL) -> Void)?
    let onNavigateToCanvasConnect: (() -> Void)?

    var body: some View {
        ZStack {
            VitaScreenBg()

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
                    .accessibilityIdentifier("backButton")
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                if vm.isLoading {
                    Spacer()
                    ProgressView().tint(folderColor)
                    Spacer()
                } else {
                    // Course header
                    if let course = vm.course {
                        CourseHeader(
                            course: course,
                            filesCount: vm.files.count,
                            assignmentsCount: vm.assignments.count,
                            folderColor: folderColor
                        )
                        .padding(.horizontal, 16)
                    }

                    Spacer().frame(height: 12)

                    // Tab bar
                    let tabTitles = [
                        "Arquivos (\(vm.files.count))",
                        "Tarefas (\(vm.assignments.count))",
                    ]
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(tabTitles.indices, id: \.self) { index in
                                CourseTabItem(
                                    title: tabTitles[index],
                                    isSelected: vm.selectedTab == index,
                                    accentColor: folderColor,
                                    onTap: { vm.selectTab(index) }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }

                    // Tab content
                    if vm.selectedTab == 0 {
                        FilesTab(
                            vm: vm,
                            folderColor: folderColor,
                            onNavigateToPdfViewer: onNavigateToPdfViewer,
                            onNavigateToCanvasConnect: onNavigateToCanvasConnect
                        )
                    } else {
                        AssignmentsTab(
                            assignments: vm.assignments,
                            onNavigateToCanvasConnect: onNavigateToCanvasConnect
                        )
                    }
                }
            }
        }
    }
}

// MARK: - CourseHeader

private struct CourseHeader: View {
    let course: Course
    let filesCount: Int
    let assignmentsCount: Int
    let folderColor: Color

    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text(course.name)
                    .font(VitaTypography.titleLarge)
                    .foregroundColor(VitaColors.textPrimary)
                    .lineLimit(3)

                // Subtitle
                let subtitle = formatCourseSubtitle(code: course.code, term: course.term)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(VitaTypography.bodySmall)
                        .foregroundColor(VitaColors.textSecondary)
                }

                // Stats row
                HStack(spacing: 12) {
                    StatPill(
                        systemImage: "doc.text",
                        count: filesCount,
                        label: "arquivos",
                        color: folderColor
                    )
                    StatPill(
                        systemImage: "calendar",
                        count: assignmentsCount,
                        label: "tarefas",
                        color: VitaColors.textSecondary
                    )
                    Spacer()
                }
            }
            .padding(20)
        }
    }

    private func formatCourseSubtitle(code: String, term: String) -> String {
        var parts: [String] = []
        if !term.isEmpty { parts.append(term) }
        if !code.isEmpty {
            // Extract "Turma XXXXX" if present (mirrors Android regex)
            if let range = code.range(of: #"Turma\s*(\d+)"#, options: .regularExpression) {
                let turma = code[range]
                    .replacingOccurrences(of: " ", with: " ")
                parts.append(turma.description)
            }
            // Extract day of week abbreviation
            if let dayRange = code.range(of: #"(Seg|Ter|Qua|Qui|Sex|Sáb|Sab)"#, options: .regularExpression) {
                parts.append(code[dayRange].description)
            }
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - StatPill

private struct StatPill: View {
    let systemImage: String
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12))
                .foregroundColor(color.opacity(0.7))
            Text("\(count)")
                .font(VitaTypography.titleSmall)
                .foregroundColor(VitaColors.textPrimary)
            Text(label)
                .font(VitaTypography.labelSmall)
                .foregroundColor(VitaColors.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - CourseTabItem

private struct CourseTabItem: View {
    let title: String
    let isSelected: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(title)
                    .font(VitaTypography.labelLarge)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? VitaColors.textPrimary : VitaColors.textSecondary)
                    .padding(.horizontal, 4)

                Rectangle()
                    .fill(isSelected ? accentColor : Color.clear)
                    .frame(height: 2)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
            }
        }
        .padding(.trailing, 24)
    }
}

// MARK: - FilesTab

private struct FilesTab: View {
    @Bindable var vm: CourseDetailViewModel
    let folderColor: Color
    let onNavigateToPdfViewer: ((URL) -> Void)?
    let onNavigateToCanvasConnect: (() -> Void)?

    var body: some View {
        if vm.files.isEmpty {
            VitaEmptyState(
                title: "Nenhum arquivo encontrado",
                message: "Conecte o Canvas para importar os materiais desta disciplina.",
                actionText: onNavigateToCanvasConnect != nil ? "Conectar Canvas" : nil,
                onAction: onNavigateToCanvasConnect
            ) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundColor(folderColor)
            }
        } else {
            let grouped = vm.groupedFiles()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    // Grouped by module
                    ForEach(grouped.modules) { module in
                        ModuleHeader(name: module.name, count: module.files.count, color: folderColor)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        ForEach(module.files) { file in
                            FileRow(
                                file: file,
                                isDownloading: vm.downloadingFileId == file.id,
                                folderColor: folderColor,
                                onTap: {
                                    Task {
                                        if let url = await vm.downloadFile(
                                            fileId: file.id,
                                            fileName: file.displayName
                                        ) {
                                            onNavigateToPdfViewer?(url)
                                        }
                                    }
                                }
                            )
                            .padding(.horizontal, 16)
                        }
                    }

                    // Unorganized files
                    if !grouped.unorganized.isEmpty {
                        if !grouped.modules.isEmpty {
                            ModuleHeader(
                                name: "Outros arquivos",
                                count: grouped.unorganized.count,
                                color: folderColor
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }
                        ForEach(grouped.unorganized) { file in
                            FileRow(
                                file: file,
                                isDownloading: vm.downloadingFileId == file.id,
                                folderColor: folderColor,
                                onTap: {
                                    Task {
                                        if let url = await vm.downloadFile(
                                            fileId: file.id,
                                            fileName: file.displayName
                                        ) {
                                            onNavigateToPdfViewer?(url)
                                        }
                                    }
                                }
                            )
                            .padding(.horizontal, 16)
                        }
                    }

                    Spacer().frame(height: 100)
                }
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - ModuleHeader

private struct ModuleHeader: View {
    let name: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.open")
                .font(.system(size: 14))
                .foregroundColor(color.opacity(0.7))
            Text(name)
                .font(VitaTypography.labelLarge)
                .fontWeight(.semibold)
                .foregroundColor(VitaColors.textPrimary.opacity(0.85))
            Text("(\(count))")
                .font(VitaTypography.labelSmall)
                .foregroundColor(VitaColors.textSecondary.opacity(0.5))
        }
        .padding(.bottom, 4)
    }
}

// MARK: - FileRow

private struct FileRow: View {
    let file: CanvasFile
    let isDownloading: Bool
    let folderColor: Color
    let onTap: () -> Void

    var body: some View {
        let typeInfo = fileTypeInfo(contentType: file.contentType, name: file.displayName)

        Button(action: onTap) {
            HStack(spacing: 14) {
                // File icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(typeInfo.color.opacity(0.10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(typeInfo.color.opacity(0.15), lineWidth: 1)
                        )
                        .frame(width: 42, height: 42)

                    if isDownloading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(typeInfo.color)
                    } else {
                        Image(systemName: typeInfo.systemImage)
                            .font(.system(size: 18))
                            .foregroundColor(typeInfo.color)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(file.displayName)
                        .font(VitaTypography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(VitaColors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Text(typeInfo.label)
                            .font(VitaTypography.labelSmall)
                            .foregroundColor(typeInfo.color.opacity(0.8))
                            .fontWeight(.semibold)

                        Text(formatFileSize(file.size))
                            .font(VitaTypography.labelSmall)
                            .foregroundColor(VitaColors.textSecondary.opacity(0.5))

                        if let pages = file.totalPages, pages > 0 {
                            Text("\(pages) pág")
                                .font(VitaTypography.labelSmall)
                                .foregroundColor(VitaColors.textSecondary.opacity(0.5))
                        }

                        if file.hasText {
                            HStack(spacing: 2) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(VitaColors.dataGreen)
                                Text("Extraído")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(VitaColors.dataGreen)
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(14)
            .background(VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AssignmentsTab

private struct AssignmentsTab: View {
    let assignments: [Assignment]
    let onNavigateToCanvasConnect: (() -> Void)?

    var body: some View {
        if assignments.isEmpty {
            VitaEmptyState(
                title: "Nenhuma tarefa",
                message: "Quando o professor publicar tarefas no Canvas, elas aparecerão aqui."
            ) {
                Image(systemName: "calendar")
                    .font(.system(size: 48))
                    .foregroundColor(VitaColors.textSecondary.opacity(0.4))
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(assignments) { assignment in
                        AssignmentRow(assignment: assignment)
                            .padding(.horizontal, 16)
                    }
                    Spacer().frame(height: 100)
                }
                .padding(.top, 8)
            }
        }
    }
}

// MARK: - AssignmentRow

private struct AssignmentRow: View {
    let assignment: Assignment

    var body: some View {
        let urgency = computeUrgency(dueAt: assignment.dueAt)

        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(urgency.color.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(urgency.color.opacity(0.15), lineWidth: 1)
                    )
                    .frame(width: 42, height: 42)
                Image(systemName: urgency.systemImage)
                    .font(.system(size: 18))
                    .foregroundColor(urgency.color)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(assignment.name)
                    .font(VitaTypography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(VitaColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(urgency.label)
                        .font(VitaTypography.labelSmall)
                        .foregroundColor(urgency.color)
                        .fontWeight(.semibold)

                    if let pts = assignment.pointsPossible {
                        Text("\(Int(pts)) pts")
                            .font(VitaTypography.labelSmall)
                            .foregroundColor(VitaColors.textSecondary.opacity(0.5))
                    }
                }
            }

            Spacer()
        }
        .padding(14)
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Helpers

private struct FileTypeInfo {
    let systemImage: String
    let label: String
    let color: Color
}

private func fileTypeInfo(contentType: String?, name: String) -> FileTypeInfo {
    let ct   = (contentType ?? "").lowercased()
    let ext  = name.lowercased()
    switch true {
    case ct.contains("pdf") || ext.hasSuffix(".pdf"):
        return FileTypeInfo(systemImage: "doc.richtext", label: "PDF", color: Color(red: 0.61, green: 0.64, blue: 0.69))
    case ct.contains("presentation") || ct.contains("powerpoint") || ext.hasSuffix(".pptx") || ext.hasSuffix(".ppt"):
        return FileTypeInfo(systemImage: "play.rectangle", label: "Slides", color: Color(red: 0.83, green: 0.65, blue: 0.39))
    case ct.contains("document") || ct.contains("word") || ct.contains("text") || ext.hasSuffix(".docx") || ext.hasSuffix(".doc") || ext.hasSuffix(".txt"):
        return FileTypeInfo(systemImage: "doc.text", label: "Doc", color: Color(red: 0.49, green: 0.66, blue: 0.91))
    case ct.contains("image") || ext.hasSuffix(".png") || ext.hasSuffix(".jpg") || ext.hasSuffix(".jpeg"):
        return FileTypeInfo(systemImage: "photo", label: "Imagem", color: Color(red: 0.43, green: 0.77, blue: 0.65))
    default:
        return FileTypeInfo(systemImage: "doc", label: "Arquivo", color: VitaColors.textSecondary)
    }
}

private func formatFileSize(_ bytes: Int64) -> String {
    if bytes < 1024 { return "\(bytes) B" }
    if bytes < 1024 * 1024 { return "\(bytes / 1024) KB" }
    return String(format: "%.1f MB", Double(bytes) / (1024.0 * 1024.0))
}

private struct UrgencyInfo {
    let label: String
    let color: Color
    let systemImage: String
}

private func computeUrgency(dueAt: String?) -> UrgencyInfo {
    guard let dueAt else {
        return UrgencyInfo(label: "Sem prazo", color: VitaColors.textSecondary, systemImage: "calendar")
    }
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let formatter2 = ISO8601DateFormatter()
    formatter2.formatOptions = [.withInternetDateTime]

    guard let dueDate = formatter.date(from: dueAt) ?? formatter2.date(from: dueAt) else {
        return UrgencyInfo(label: "Sem prazo", color: VitaColors.textSecondary, systemImage: "calendar")
    }

    let now      = Date()
    let diffDays = Calendar.current.dateComponents([.day], from: now, to: dueDate).day ?? 0

    let display: String = {
        let df = DateFormatter()
        df.dateFormat = "dd MMM HH:mm"
        df.locale = Locale(identifier: "pt_BR")
        return df.string(from: dueDate)
    }()

    if diffDays < 0 {
        return UrgencyInfo(label: "Atrasado (\(display))", color: VitaColors.dataRed, systemImage: "exclamationmark.circle")
    } else if diffDays <= 3 {
        return UrgencyInfo(label: display, color: VitaColors.dataAmber, systemImage: "clock")
    } else {
        return UrgencyInfo(label: display, color: VitaColors.textSecondary, systemImage: "calendar")
    }
}
