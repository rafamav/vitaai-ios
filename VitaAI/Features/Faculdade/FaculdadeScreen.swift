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

// MARK: - Cursos Tab (with CR ring, semester swiper, frequência, eventos, docs pills)

private struct CursosTab: View {
    let vm: FaculdadeViewModel
    let onNavigateToCanvasConnect: (() -> Void)?
    let onNavigateToCourseDetail: ((String, Int) -> Void)?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // ── Semester swiper ──────────────────────────────────────────────
                SemesterSwiperView()
                    .padding(.top, 12)
                    .padding(.bottom, 12)

                // ── CR ring + academic summary ───────────────────────────────────
                AcademicSummaryCard()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                // ── Frequência colorida ──────────────────────────────────────────
                FrequenciaSection()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                // ── Próximos eventos (horizontal scroll) ─────────────────────────
                ProximosEventosSection()
                    .padding(.bottom, 14)

                // ── Documentos pills ─────────────────────────────────────────────
                DocumentosPillsSection()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)

                // ── Canvas connect banner ────────────────────────────────────────
                if !vm.canvasConnected {
                    ConnectBanner(
                        icon: "building.columns",
                        title: "Conecte o Canvas LMS",
                        subtitle: "Sincronize disciplinas, PDFs e tarefas",
                        buttonLabel: "Conectar",
                        action: onNavigateToCanvasConnect
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }

                // ── Canvas courses ───────────────────────────────────────────────
                if !vm.courses.isEmpty {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Disciplinas Canvas")
                                .font(VitaTypography.labelSmall)
                                .textCase(.uppercase)
                                .tracking(0.6)
                                .foregroundStyle(VitaColors.textTertiary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)

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
                }

                Spacer().frame(height: 100)
            }
        }
        .refreshable { await vm.load() }
    }
}

// MARK: - Semester Swiper

private struct SemesterSwiperView: View {
    private let totalSemesters = 12
    private let currentSemester = 5

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(1...totalSemesters, id: \.self) { sem in
                    let state: SemChipState = sem < currentSemester ? .done
                                           : sem == currentSemester ? .active
                                           : .locked
                    SemesterChip(semester: sem, state: state)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private enum SemChipState { case done, active, locked }

private struct SemesterChip: View {
    let semester: Int
    let state: SemChipState

    private var bgColor: Color {
        switch state {
        case .done:   return VitaColors.accent
        case .active: return Color.clear
        case .locked: return Color.white.opacity(0.03)
        }
    }
    private var borderColor: Color {
        switch state {
        case .done:   return VitaColors.accent
        case .active: return VitaColors.accent
        case .locked: return Color.white.opacity(0.07)
        }
    }
    private var textColor: Color {
        switch state {
        case .done:   return Color(red: 20/255, green: 16/255, blue: 10/255)
        case .active: return VitaColors.accent
        case .locked: return VitaColors.textTertiary
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(bgColor)
                    .frame(width: 36, height: 28)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: 1)
                    )
                Text("\(semester)°")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(textColor)
            }
            .opacity(state == .locked ? 0.25 : 1.0)

            if state == .active {
                Text("atual")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(VitaColors.accent.opacity(0.7))
            } else {
                // Reserve space so chips are same height
                Text(" ")
                    .font(.system(size: 7))
            }
        }
    }
}

// MARK: - Academic Summary Card (CR donut ring + expandable grades)

private struct AcademicSummaryCard: View {
    private let crValue: Double = 7.66
    private let university = "ULBRA — Medicina"
    private let semesterLabel = "5° Semestre • 2026.1"
    private let disciplines = 6
    private let creditsCompleted = 120
    private let creditsTotal = 240
    private let compHoursCompleted = 45
    private let compHoursTotal = 120

    @State private var expanded = false

    private var ringProgress: Double { crValue / 10.0 }

    var body: some View {
        VStack(spacing: 0) {
            // ── Closed row ──
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    expanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    // CR donut
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 4)
                            .frame(width: 68, height: 68)

                        Circle()
                            .trim(from: 0, to: CGFloat(ringProgress))
                            .stroke(
                                VitaColors.accent.opacity(0.75),
                                style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                            )
                            .frame(width: 68, height: 68)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: VitaColors.accent.opacity(0.25), radius: 4)

                        VStack(spacing: 1) {
                            Text(String(format: "%.2f", crValue))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(VitaColors.accent)
                            Text("CR")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(VitaColors.textTertiary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(university)
                            .font(VitaTypography.labelMedium)
                            .fontWeight(.semibold)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(1)

                        Text(semesterLabel)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)

                        HStack(spacing: 6) {
                            AcadPill("\(disciplines) disc")
                            AcadPill("\(creditsCompleted)/\(creditsTotal) cred")
                            AcadPill("\(compHoursCompleted)/\(compHoursTotal)h compl")
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VitaColors.textTertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // ── Expanded detail ──
            if expanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(VitaColors.glassBorder)
                        .frame(height: 1)
                        .padding(.horizontal, 14)

                    GradeTableView()
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .padding(.bottom, 6)

                    VStack(spacing: 8) {
                        AcadProgressBar(
                            label: "Creditos",
                            valueStr: "\(creditsCompleted)/\(creditsTotal) (50%)",
                            progress: Double(creditsCompleted) / Double(creditsTotal)
                        )
                        AcadProgressBar(
                            label: "Horas Compl.",
                            valueStr: "\(compHoursCompleted)/\(compHoursTotal)h",
                            progress: Double(compHoursCompleted) / Double(compHoursTotal)
                        )
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }
}

private struct AcadPill: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(VitaColors.textSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

private struct AcadProgressBar: View {
    let label: String
    let valueStr: String
    let progress: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 10))
                    .foregroundStyle(VitaColors.textSecondary)
                Spacer()
                Text(valueStr)
                    .font(.system(size: 10))
                    .foregroundStyle(VitaColors.textSecondary)
            }
            GeometryReader { geo in
                let pct = CGFloat(min(max(progress, 0), 1))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(VitaColors.goldBarGradient)
                        .frame(width: geo.size.width * pct, height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Grade Table (inside expanded summary card)

private struct GradeTableView: View {
    private struct GradeEntry {
        let subject: String
        let n1: String
        let n2: String
        let avg: String
        let avgState: AcadGradeState
        let needs: String
        let needsDanger: Bool
    }

    private enum AcadGradeState { case good, mid, bad }

    private let entries: [GradeEntry] = [
        .init(subject: "Anatomia",     n1: "8.5", n2: "7.9", avg: "8.2", avgState: .good, needs: "—",       needsDanger: false),
        .init(subject: "Fisiologia",   n1: "7.0", n2: "8.0", avg: "7.5", avgState: .good, needs: "—",       needsDanger: false),
        .init(subject: "Bioquimica",   n1: "5.8", n2: "7.0", avg: "6.4", avgState: .bad,  needs: "N3: 7.8", needsDanger: true),
        .init(subject: "Farmacologia", n1: "7.2", n2: "—",   avg: "7.2", avgState: .mid,  needs: "N2: 6.8", needsDanger: false),
        .init(subject: "Med Legal",    n1: "8.8", n2: "—",   avg: "8.8", avgState: .good, needs: "—",       needsDanger: false),
        .init(subject: "Prat Interp",  n1: "—",   n2: "—",   avg: "—",   avgState: .mid,  needs: "—",       needsDanger: false),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("Disciplina")
                    .font(.system(size: 9)).textCase(.uppercase).tracking(0.5)
                    .foregroundStyle(Color.white.opacity(0.18))
                Spacer()
                HStack(spacing: 8) {
                    Text("N1").frame(minWidth: 22, alignment: .trailing)
                    Text("N2").frame(minWidth: 22, alignment: .trailing)
                    Text("Med").frame(minWidth: 28, alignment: .trailing)
                    Text("Precisa").frame(minWidth: 50, alignment: .trailing)
                }
                .font(.system(size: 9)).foregroundStyle(Color.white.opacity(0.18))
            }
            .padding(.bottom, 6)

            ForEach(entries, id: \.subject) { entry in
                let avgColor: Color = {
                    switch entry.avgState {
                    case .good: return VitaColors.dataGreen
                    case .mid:  return VitaColors.dataAmber
                    case .bad:  return VitaColors.dataRed
                    }
                }()
                HStack {
                    Text(entry.subject)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(VitaColors.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    HStack(spacing: 8) {
                        Text(entry.n1).frame(minWidth: 22, alignment: .trailing)
                        Text(entry.n2).frame(minWidth: 22, alignment: .trailing)
                        Text(entry.avg)
                            .fontWeight(.semibold)
                            .foregroundStyle(avgColor)
                            .frame(minWidth: 28, alignment: .trailing)
                        Text(entry.needs)
                            .foregroundStyle(entry.needsDanger ? VitaColors.dataRed.opacity(0.8) : VitaColors.textTertiary)
                            .frame(minWidth: 50, alignment: .trailing)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textTertiary)
                }
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Frequência Section

private struct FreqItemData: Identifiable {
    let id = UUID()
    let subject: String
    let percent: Double
    let absences: Int
    let total: Int
}

private let mockFreqData: [FreqItemData] = [
    FreqItemData(subject: "Anatomia",     percent: 95,  absences: 2, total: 40),
    FreqItemData(subject: "Fisiologia",   percent: 88,  absences: 4, total: 34),
    FreqItemData(subject: "Bioquimica",   percent: 78,  absences: 8, total: 36),
    FreqItemData(subject: "Farmacologia", percent: 92,  absences: 3, total: 38),
    FreqItemData(subject: "Med Legal",    percent: 100, absences: 0, total: 30),
    FreqItemData(subject: "Prat Interp",  percent: 76,  absences: 9, total: 38),
]

private struct FrequenciaSection: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Frequência")
                    .font(VitaTypography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                Text("Min 75%")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(Array(mockFreqData.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Rectangle()
                            .fill(VitaColors.glassBorder)
                            .frame(height: 1)
                    }
                    FreqRowView(item: item)
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
        }
    }
}

private struct FreqRowView: View {
    let item: FreqItemData

    private var barColor: Color {
        if item.percent >= 85 { return VitaColors.dataGreen }
        if item.percent >= 75 { return VitaColors.dataAmber }
        return VitaColors.dataRed
    }

    private var isAtLimit: Bool { item.percent < 76 }

    private var remainingAbsences: Int {
        let maxAllowed = Int(Double(item.total) * 0.25)
        return max(0, maxAllowed - item.absences)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(item.subject)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VitaColors.textSecondary)
                .frame(width: 76, alignment: .leading)
                .lineLimit(1)

            GeometryReader { geo in
                let pct = CGFloat(min(max(item.percent / 100, 0), 1))
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor)
                        .frame(width: geo.size.width * pct, height: 5)
                }
            }
            .frame(height: 5)

            Text("\(Int(item.percent))%")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(barColor)
                .frame(width: 32, alignment: .trailing)

            if isAtLimit {
                Text("LIMITE!")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(VitaColors.dataRed)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(VitaColors.dataRed.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                Text("Restam \(remainingAbsences)")
                    .font(.system(size: 9))
                    .foregroundStyle(VitaColors.textTertiary)
                    .lineLimit(1)
                    .frame(minWidth: 52, alignment: .leading)
            }
        }
    }
}

// MARK: - Próximos Eventos

private struct EventoItem: Identifiable {
    let id = UUID()
    let date: String
    let title: String
    let tag: String
    let tagColor: Color
}

private let mockEventos: [EventoItem] = [
    EventoItem(date: "17-21 Mar", title: "Semana de Provas P2",   tag: "provas",   tagColor: VitaColors.dataRed),
    EventoItem(date: "28 Mar",    title: "Entrega TCC parcial",    tag: "entrega",  tagColor: VitaColors.dataAmber),
    EventoItem(date: "07-11 Abr", title: "Provas Finais",          tag: "provas",   tagColor: VitaColors.dataRed),
    EventoItem(date: "14 Abr",    title: "Matrícula 6° sem",       tag: "info",     tagColor: VitaColors.dataBlue),
    EventoItem(date: "21 Abr",    title: "Recesso Tiradentes",     tag: "feriado",  tagColor: VitaColors.dataGreen),
]

private struct ProximosEventosSection: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Próximos")
                    .font(VitaTypography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                Text("Calendário")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.accent)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(mockEventos) { event in
                        EventoCard(event: event)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct EventoCard: View {
    let event: EventoItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(event.date)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(VitaColors.textTertiary)

            Text(event.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(event.tag)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(event.tagColor)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(event.tagColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .padding(12)
        .frame(width: 130, alignment: .leading)
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }
}

// MARK: - Documentos Pills Section

private struct DocPillItem: Identifiable {
    let id = UUID()
    let label: String
    let icon: String
}

private let mockDocPills: [DocPillItem] = [
    DocPillItem(label: "Histórico",  icon: "doc.text.fill"),
    DocPillItem(label: "Matrícula",  icon: "checkmark.seal.fill"),
    DocPillItem(label: "Declaração", icon: "arrow.down.doc.fill"),
    DocPillItem(label: "Atestados",  icon: "calendar.badge.plus"),
]

private struct DocumentosPillsSection: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Documentos")
                    .font(VitaTypography.labelLarge)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(mockDocPills) { doc in
                        HStack(spacing: 6) {
                            Image(systemName: doc.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(VitaColors.textSecondary.opacity(0.7))
                            Text(doc.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(VitaColors.textSecondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(VitaColors.glassBg)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(VitaColors.glassBorder, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
}

// MARK: - FaculdadeCourseRow

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

    // Day indices: 1=Seg, 2=Ter, 3=Qua, 4=Qui, 5=Sex
    private let weekDayNames = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]
    private let weekDayShort = ["", "Seg", "Ter", "Qua", "Qui", "Sex"]

    // Start on today's weekday if it's Mon-Fri, else Seg
    @State private var selectedDay: Int = {
        let wd = Calendar.current.component(.weekday, from: Date())
        // weekday: 1=Sun, 2=Mon, ..., 6=Fri, 7=Sat
        let mapped = wd - 1  // 1=Mon...5=Fri
        return (mapped >= 1 && mapped <= 5) ? mapped : 1
    }()

    private var groupedByDay: [Int: [WebalunoScheduleBlock]] {
        Dictionary(grouping: schedule) { $0.dayOfWeek }
    }

    private var activeDays: [Int] {
        (1...5).filter { groupedByDay[$0] != nil }
    }

    private var selectedBlocks: [WebalunoScheduleBlock] {
        (groupedByDay[selectedDay] ?? []).sorted { $0.startTime < $1.startTime }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if schedule.isEmpty {
                    // Mock data for visual preview when no WebAluno connected
                    HorarioDayTabs(
                        selectedDay: $selectedDay,
                        activeDays: [1, 2, 3, 4, 5],
                        weekDayShort: weekDayShort
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    VStack(spacing: 0) {
                        mockSlotRow(time: "08:00", name: "Fisiologia", sub: "Prof. Martins", room: "Sala 302", color: VitaColors.dataBlue)
                        Divider().background(VitaColors.glassBorder).padding(.leading, 66)
                        mockSlotRow(time: "10:00", name: "Medicina Legal", sub: "Prof. Tavares", room: "Sala 105", color: VitaColors.dataAmber)
                        Divider().background(VitaColors.glassBorder).padding(.leading, 66)
                        mockFreeSlot(time: "14:00")
                        Divider().background(VitaColors.glassBorder).padding(.leading, 66)
                        mockSlotRow(time: "16:00", name: "Anatomia Lab", sub: "Prof. Silva", room: "Lab 2", color: VitaColors.accent)
                    }
                    .background(VitaColors.glassBg)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(VitaColors.glassBorder, lineWidth: 1))
                    .padding(.horizontal, 16)
                } else {
                    HorarioDayTabs(
                        selectedDay: $selectedDay,
                        activeDays: activeDays,
                        weekDayShort: weekDayShort
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    if selectedBlocks.isEmpty {
                        Text("Sem aulas")
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textTertiary)
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(selectedBlocks.enumerated()), id: \.offset) { index, block in
                                if index > 0 {
                                    Divider().background(VitaColors.glassBorder).padding(.leading, 66)
                                }
                                ScheduleBlockRow(block: block)
                            }
                        }
                        .background(VitaColors.glassBg)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(VitaColors.glassBorder, lineWidth: 1))
                        .padding(.horizontal, 16)
                    }
                }

                Spacer().frame(height: 100)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedDay)
    }

    private func mockSlotRow(time: String, name: String, sub: String, room: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(time)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.35))
                .frame(width: 40, alignment: .trailing)
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 36)
                .cornerRadius(2)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.70))
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.30))
            }
            Spacer()
            Text(room)
                .font(.system(size: 10))
                .foregroundStyle(Color.white.opacity(0.25))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func mockFreeSlot(time: String) -> some View {
        HStack(spacing: 10) {
            Text(time)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.35))
                .frame(width: 40, alignment: .trailing)
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 3, height: 28)
                .cornerRadius(2)
            Text("Livre")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.20))
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .opacity(0.5)
    }
}

private struct HorarioDayTabs: View {
    @Binding var selectedDay: Int
    let activeDays: [Int]
    let weekDayShort: [String]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...5, id: \.self) { day in
                let isActive = selectedDay == day
                let hasClasses = activeDays.contains(day)
                let label = day < weekDayShort.count ? weekDayShort[day] : "?"
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedDay = day }
                } label: {
                    Text(label)
                        .font(.system(size: 11, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(
                            isActive ? VitaColors.accent : (hasClasses ? Color.white.opacity(0.55) : Color.white.opacity(0.25))
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(isActive ? VitaColors.accent.opacity(0.12) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isActive ? VitaColors.accent.opacity(0.20) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
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
        HStack(spacing: 10) {
            Text(block.startTime)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.35))
                .frame(width: 40, alignment: .trailing)

            Rectangle()
                .fill(accentColor)
                .frame(width: 3, height: 36)
                .cornerRadius(2)

            VStack(alignment: .leading, spacing: 2) {
                Text(block.subjectName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.70))
                    .lineLimit(1)
                if let prof = block.professor, !prof.isEmpty {
                    Text(prof)
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.30))
                }
            }

            Spacer()

            if let room = block.room, !room.isEmpty {
                Text(room)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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

// MARK: - Connect Banner

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
