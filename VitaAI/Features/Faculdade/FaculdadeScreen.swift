import SwiftUI

// MARK: - FaculdadeScreen
// Dedicated university screen: Canvas courses, schedule, grades, attendance, documents.

struct FaculdadeScreen: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: FaculdadeViewModel?

    var onNavigateToCanvasConnect: (() -> Void)?
    var onNavigateToWebAluno: (() -> Void)?
    var onNavigateToCourseDetail: ((String, Int) -> Void)?
    var onNavigateToPdfViewer: ((URL) -> Void)?

    var body: some View {
        Group {
            if let vm = viewModel {
                FaculdadeContent(
                    vm: vm,
                    onNavigateToCanvasConnect: onNavigateToCanvasConnect,
                    onNavigateToWebAluno: onNavigateToWebAluno,
                    onNavigateToCourseDetail: onNavigateToCourseDetail,
                    onNavigateToPdfViewer: onNavigateToPdfViewer
                )
            } else {
                ProgressView().tint(VitaColors.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = FaculdadeViewModel(api: container.api)
                Task { await viewModel?.load() }
            }
        }
    }
}

// MARK: - Content

private struct FaculdadeContent: View {
    @Bindable var vm: FaculdadeViewModel

    let onNavigateToCanvasConnect: (() -> Void)?
    let onNavigateToWebAluno: (() -> Void)?
    let onNavigateToCourseDetail: ((String, Int) -> Void)?
    let onNavigateToPdfViewer: ((URL) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            FaculdadeTabBar(selectedTab: $vm.selectedTab)

            if vm.isLoading && vm.courses.isEmpty && vm.grades.isEmpty {
                FaculdadeSkeleton()
            } else {
                tabContent
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch vm.selectedTab {
        case .cursos:
            CursosTab(
                vm: vm,
                onNavigateToCanvasConnect: onNavigateToCanvasConnect,
                onNavigateToCourseDetail: onNavigateToCourseDetail
            )
        case .horario:
            HorarioTab(schedule: vm.schedule)
        case .notas:
            NotasTab(
                grades: vm.grades,
                onNavigateToWebAluno: onNavigateToWebAluno
            )
        case .documentos:
            DocumentosTab(
                files: vm.files,
                isLoading: vm.isLoading,
                downloadingFileId: vm.downloadingFileId,
                onFileClick: { file in
                    Task {
                        if let url = await vm.downloadFile(fileId: file.id, fileName: file.displayName) {
                            onNavigateToPdfViewer?(url)
                        }
                    }
                }
            )
        }
    }
}

// MARK: - Tab enum

enum FaculdadeTab: Int, CaseIterable {
    case cursos     = 0
    case horario    = 1
    case notas      = 2
    case documentos = 3

    var title: String {
        switch self {
        case .cursos:     return "Cursos"
        case .horario:    return "Horário"
        case .notas:      return "Notas"
        case .documentos: return "Docs"
        }
    }
}

// MARK: - Tab Bar

private struct FaculdadeTabBar: View {
    @Binding var selectedTab: FaculdadeTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FaculdadeTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.title)
                            .font(VitaTypography.labelMedium)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundStyle(
                                selectedTab == tab
                                    ? VitaColors.accent
                                    : VitaColors.textSecondary
                            )
                        Rectangle()
                            .fill(selectedTab == tab ? VitaColors.accent : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VitaColors.glassBorder)
                .frame(height: 1)
        }
    }
}

// MARK: - Cursos Tab

private struct CursosTab: View {
    let vm: FaculdadeViewModel
    let onNavigateToCanvasConnect: (() -> Void)?
    let onNavigateToCourseDetail: ((String, Int) -> Void)?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                if !vm.canvasConnected {
                    ConnectBanner(
                        icon: "building.columns",
                        title: "Conecte o Canvas LMS",
                        subtitle: "Sincronize disciplinas, PDFs e tarefas",
                        buttonLabel: "Conectar",
                        action: onNavigateToCanvasConnect
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                if vm.courses.isEmpty && !vm.isLoading {
                    VitaEmptyState(
                        title: "Nenhuma disciplina",
                        message: "Conecte o Canvas para ver suas disciplinas"
                    ) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 40))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(Array(vm.courses.enumerated()), id: \.element.id) { index, course in
                        Button {
                            onNavigateToCourseDetail?(course.id, index % 6)
                        } label: {
                            FaculdadeCourseRow(course: course, colorIndex: index)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                    }
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, 8)
        }
        .refreshable { await vm.load() }
    }
}

private struct FaculdadeCourseRow: View {
    let course: Course
    let colorIndex: Int

    private var folderColor: Color { FolderPalette.color(forIndex: colorIndex) }

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(folderColor.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "folder.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(folderColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(course.name)
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        if !course.code.isEmpty {
                            Text(course.code)
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                        Text("\(course.filesCount) arquivos")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Horário Tab

private struct HorarioTab: View {
    let schedule: [WebalunoScheduleBlock]

    private let weekDayNames = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]

    private var groupedByDay: [(dayIndex: Int, dayName: String, blocks: [WebalunoScheduleBlock])] {
        let grouped = Dictionary(grouping: schedule) { $0.dayOfWeek }
        return (1...6).compactMap { day -> (Int, String, [WebalunoScheduleBlock])? in
            guard let blocks = grouped[day], !blocks.isEmpty else { return nil }
            let name = day < weekDayNames.count ? weekDayNames[day] : "Dia \(day)"
            let sorted = blocks.sorted { $0.startTime < $1.startTime }
            return (day, name, sorted)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if schedule.isEmpty {
                    VitaEmptyState(
                        title: "Sem horário",
                        message: "Conecte o WebAluno para importar sua grade horária"
                    ) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 40))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(groupedByDay, id: \.dayIndex) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(entry.dayName)
                                .font(VitaTypography.labelLarge)
                                .fontWeight(.semibold)
                                .foregroundStyle(VitaColors.textSecondary)
                                .padding(.horizontal, 16)

                            ForEach(Array(entry.blocks.enumerated()), id: \.offset) { _, block in
                                ScheduleBlockRow(block: block)
                                    .padding(.horizontal, 16)
                            }
                        }
                    }
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, 12)
        }
    }
}

private struct ScheduleBlockRow: View {
    let block: WebalunoScheduleBlock

    private let subjectColors: [Color] = [
        VitaColors.dataBlue, VitaColors.dataGreen, VitaColors.dataAmber,
        VitaColors.dataIndigo, VitaColors.accent
    ]

    private var accentColor: Color {
        let hash = abs(block.subjectName.hashValue)
        return subjectColors[hash % subjectColors.count]
    }

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(accentColor)
                    .frame(width: 3)
                    .cornerRadius(2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(block.subjectName)
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Label("\(block.startTime)–\(block.endTime)", systemImage: "clock")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)

                        if let room = block.room, !room.isEmpty {
                            Label(room, systemImage: "mappin")
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                    }

                    if let prof = block.professor, !prof.isEmpty {
                        Text(prof)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Notas Tab

private struct NotasTab: View {
    let grades: [WebalunoGrade]
    let onNavigateToWebAluno: (() -> Void)?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                if grades.isEmpty {
                    VStack(spacing: 16) {
                        VitaEmptyState(
                            title: "Sem notas",
                            message: "Conecte o WebAluno para importar suas notas"
                        ) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 40))
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                        if let onNavigateToWebAluno {
                            Button("Conectar WebAluno") { onNavigateToWebAluno() }
                                .font(VitaTypography.labelMedium)
                                .fontWeight(.semibold)
                                .foregroundStyle(VitaColors.accent)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(VitaColors.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(grades) { grade in
                        FaculdadeGradeRow(grade: grade)
                            .padding(.horizontal, 16)
                    }
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, 8)
        }
    }
}

private struct FaculdadeGradeRow: View {
    let grade: WebalunoGrade

    private var displayGrade: Double {
        grade.finalGrade ?? grade.grade1 ?? 0
    }

    private var gradeColor: Color {
        if displayGrade >= 8 { return VitaColors.dataGreen }
        if displayGrade >= 6 { return VitaColors.dataAmber }
        return VitaColors.dataRed
    }

    private var statusText: String { grade.status ?? "Cursando" }

    private var statusColor: Color {
        let s = statusText.lowercased()
        if s.contains("aprovado") { return VitaColors.dataGreen }
        if s.contains("reprovado") { return VitaColors.dataRed }
        return VitaColors.accent
    }

    private var gradeParts: String {
        var parts: [String] = []
        if let g1 = grade.grade1 { parts.append("N1 \(String(format: "%.1f", g1))") }
        if let g2 = grade.grade2 { parts.append("N2 \(String(format: "%.1f", g2))") }
        if let g3 = grade.grade3 { parts.append("N3 \(String(format: "%.1f", g3))") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(gradeColor.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Text(displayGrade > 0 ? String(format: "%.1f", displayGrade) : "—")
                        .font(VitaTypography.labelLarge)
                        .fontWeight(.bold)
                        .foregroundStyle(displayGrade > 0 ? gradeColor : VitaColors.textTertiary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(grade.subjectName)
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.medium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(2)

                    if !gradeParts.isEmpty {
                        Text(gradeParts)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }

                    if let att = grade.attendance {
                        HStack(spacing: 4) {
                            ProgressView(value: att / 100)
                                .tint(att >= 75 ? VitaColors.dataGreen : VitaColors.dataRed)
                                .frame(width: 60)
                            Text("\(Int(att))% freq.")
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(att >= 75 ? VitaColors.dataGreen : VitaColors.dataRed)
                        }
                    }
                }

                Spacer()

                Text(statusText)
                    .font(VitaTypography.labelSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }
            .padding(14)
        }
    }
}

// MARK: - Documentos Tab

private struct DocumentosTab: View {
    let files: [CanvasFile]
    let isLoading: Bool
    let downloadingFileId: String?
    let onFileClick: (CanvasFile) -> Void

    private var groupedByCourse: [(courseName: String, files: [CanvasFile])] {
        let grouped = Dictionary(grouping: files) { $0.courseName ?? "Sem disciplina" }
        return grouped
            .sorted { $0.key < $1.key }
            .map { (courseName: $0.key, files: $0.value) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if files.isEmpty && !isLoading {
                    VitaEmptyState(
                        title: "Nenhum documento",
                        message: "Conecte o Canvas para importar materiais"
                    ) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 40))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(groupedByCourse, id: \.courseName) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.courseName)
                                .font(VitaTypography.labelLarge)
                                .fontWeight(.semibold)
                                .foregroundStyle(VitaColors.textSecondary)
                                .padding(.horizontal, 16)

                            ForEach(group.files) { file in
                                DocumentRow(
                                    file: file,
                                    isDownloading: downloadingFileId == file.id,
                                    onTap: { onFileClick(file) }
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, 8)
        }
    }
}

private struct DocumentRow: View {
    let file: CanvasFile
    let isDownloading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VitaGlassCard {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(VitaColors.dataRed.opacity(0.12))
                            .frame(width: 36, height: 36)
                        if isDownloading {
                            ProgressView()
                                .tint(VitaColors.dataRed)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(VitaColors.dataRed)
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(file.displayName)
                            .font(VitaTypography.labelMedium)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(2)
                        if let mod = file.moduleName {
                            Text(mod)
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDownloading)
    }
}

// MARK: - Connect Banner (shared)

private struct ConnectBanner: View {
    let icon: String
    let title: String
    let subtitle: String
    let buttonLabel: String
    let action: (() -> Void)?

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundStyle(VitaColors.accent.opacity(0.8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text(subtitle)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer()

                if let action {
                    Button(buttonLabel, action: action)
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(VitaColors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Skeleton

private struct FaculdadeSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VitaColors.surfaceElevated)
                            .frame(width: 44, height: 44)
                            .shimmer()
                        VStack(alignment: .leading, spacing: 6) {
                            ShimmerText(width: 180, height: 16)
                            ShimmerText(width: 120, height: 12)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 16)
        }
    }
}
