import SwiftUI

// MARK: - DisciplineDetailScreen
// Follows FaculdadeHomeScreen/FaculdadeMateriasScreen pattern:
// - No custom background (VitaAmbientBackground handles it globally)
// - VitaGlassCard for sections
// - VitaColors tokens only
// - All data from API, sections show useful state even when empty

struct DisciplineDetailScreen: View {
    let disciplineId: String
    let disciplineName: String

    var onBack: (() -> Void)?
    var onNavigateToFlashcards: ((String) -> Void)?
    var onNavigateToQBank: (() -> Void)?
    var onNavigateToSimulado: (() -> Void)?

    @State private var vm: DisciplineDetailViewModel?
    @State private var showProfessorSheet = false
    @State private var showColorPicker = false
    @State private var colorRefreshTrigger: UUID = UUID()
    @Environment(\.appContainer) private var container

    // Tokens — same as FaculdadeHomeScreen
    private var goldPrimary: Color { VitaColors.accentHover }
    private var goldMuted: Color { VitaColors.accentLight }
    private var textPrimary: Color { VitaColors.textPrimary }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }
    private var cardBg: Color { VitaColors.surfaceCard.opacity(0.55) }
    private var glassBorder: Color { VitaColors.textWarm.opacity(0.06) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            if let vm {
                if vm.isLoading {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .padding(.top, 100)
                } else if let error = vm.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(VitaColors.dataAmber)
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundStyle(textWarm)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 80)
                    .padding(.horizontal, 32)
                } else {
                    VStack(spacing: 14) {
                        heroCard(vm: vm)
                        gradesCard(vm: vm)
                        scheduleCard(vm: vm)
                        nextExamCard(vm: vm)
                        allExamsCard(vm: vm)
                        trabalhosCard(vm: vm)
                        studyCard(vm: vm)
                        documentsCard(vm: vm)
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
                    .padding(.top, 100)
            }
        }
        .onAppear {
            if vm == nil {
                vm = DisciplineDetailViewModel(
                    api: container.api,
                    disciplineId: disciplineId,
                    disciplineName: disciplineName
                )
            }
        }
        .refreshable { await vm?.load() }
        .task { await vm?.load() }
        .sheet(isPresented: $showProfessorSheet) {
            ProfessorProfileSheet(subjectId: disciplineId)
        }
        .sheet(isPresented: $showColorPicker) {
            SubjectColorPicker(subjectName: disciplineName) { _ in
                colorRefreshTrigger = UUID()
            }
            .presentationDetents([.height(320)])
            .presentationBackground(VitaColors.surfaceCard)
            .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - Hero Card

    private func heroCard(vm: DisciplineDetailViewModel) -> some View {
        let color = vm.subjectColor
        return ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.07, blue: 0.045),
                    Color(red: 0.05, green: 0.035, blue: 0.022)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [color.opacity(0.22), Color.clear],
                center: UnitPoint(x: 1.0, y: 0.0),
                startRadius: 0,
                endRadius: 140
            )

            Image(systemName: "book.fill")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(color.opacity(0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 14)
                .padding(.trailing, 16)

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 0) {
                    // Status badge
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor(vm.subjectStatus))
                            .frame(width: 5, height: 5)
                        Text(statusLabel(vm.subjectStatus))
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(statusColor(vm.subjectStatus))
                    }
                    .padding(.bottom, 6)

                    Text(disciplineName)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                        .kerning(-0.4)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)

                    // Workload + absences info
                    HStack(spacing: 12) {
                        if let wl = vm.workload, wl > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 9))
                                Text(String(format: "%.0fh", wl))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(goldMuted.opacity(0.65))
                        }
                        if let freq = vm.attendance {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 9))
                                Text(String(format: "%.0f%% freq", freq))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(freq >= 90 ? VitaColors.dataGreen.opacity(0.85) : freq >= 75 ? goldMuted.opacity(0.75) : VitaColors.dataRed.opacity(0.85))
                        }
                        if let abs = vm.absences {
                            HStack(spacing: 4) {
                                Image(systemName: "person.badge.minus")
                                    .font(.system(size: 9))
                                Text(String(format: "%.0f faltas", abs))
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(abs > 10 ? VitaColors.dataRed.opacity(0.85) : goldMuted.opacity(0.65))
                        }
                    }
                    .padding(.top, 4)

                    // Professor + room
                    HStack(spacing: 12) {
                        if let prof = vm.professorName {
                            Button {
                                showProfessorSheet = true
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 9))
                                    Text(prof)
                                        .font(.system(size: 11, weight: .medium))
                                        .lineLimit(1)
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 9))
                                }
                                .foregroundStyle(goldMuted.opacity(0.80))
                            }
                            .buttonStyle(.plain)
                        }
                        if let room = vm.room {
                            HStack(spacing: 4) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 9))
                                Text(room)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(goldMuted.opacity(0.65))
                        }
                    }
                    .padding(.top, 2)

                    // Average
                    if let avg = vm.currentAverage {
                        let allGraded = vm.gradeSlots.allSatisfy { $0.value != nil }
                        HStack(spacing: 4) {
                            Text(allGraded ? "Média:" : "Média parcial:")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(goldMuted.opacity(0.55))
                            Text(String(format: "%.1f", avg))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(gradeColor(normalized: avg))
                        }
                        .padding(.top, 4)
                    }

                    Spacer(minLength: 0)
                }

                Spacer()

                if vm.vitaScore > 0 {
                    vitaScoreBadge(score: vm.vitaScore)
                        .padding(.top, 2)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            // Color picker trigger — bottom trailing
            Button {
                showColorPicker = true
            } label: {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 20, height: 20)
                    Circle()
                        .stroke(Color.white.opacity(0.30), lineWidth: 1)
                        .frame(width: 20, height: 20)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 14)
            .padding(.bottom, 12)
        }
        .frame(height: 162)
        .id(colorRefreshTrigger)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            goldPrimary.opacity(0.40),
                            goldPrimary.opacity(0.10),
                            goldPrimary.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.30), radius: 14, y: 6)
    }

    private func vitaScoreBadge(score: Int) -> some View {
        let tierColor: Color = {
            if score >= 80 { return VitaColors.dataAmber }
            if score >= 60 { return VitaColors.dataGreen }
            if score >= 40 { return VitaColors.accent }
            return VitaColors.dataRed
        }()
        return ZStack {
            Circle()
                .fill(tierColor.opacity(0.15))
                .frame(width: 52, height: 52)
            Circle()
                .stroke(tierColor.opacity(0.50), lineWidth: 1.5)
                .frame(width: 52, height: 52)
            VStack(spacing: 1) {
                Text("\(score)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tierColor)
                Text("VITA")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(tierColor.opacity(0.80))
            }
        }
    }

    // MARK: - Grades Card (P1/P2/P3/Final/Freq)

    @ViewBuilder
    private func gradesCard(vm: DisciplineDetailViewModel) -> some View {
        VitaGlassCard {
            VStack(spacing: 12) {
                HStack {
                    Text("Notas")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textPrimary)
                    if vm.hasGradeRisk {
                        Text("RISCO")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(VitaColors.dataRed)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(VitaColors.dataRed.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    Spacer()
                    if let att = vm.attendance {
                        HStack(spacing: 3) {
                            Image(systemName: "person.fill.checkmark")
                                .font(.system(size: 9))
                            Text(String(format: "%.0f%%", att))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(att >= 75 ? VitaColors.dataGreen : VitaColors.dataRed)
                    }
                }

                // Headers
                HStack(spacing: 0) {
                    ForEach(vm.gradeSlots, id: \.label) { slot in
                        Text(slot.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(textDim)
                            .frame(maxWidth: .infinity)
                    }
                    Text("Final")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(textDim)
                        .frame(maxWidth: .infinity)
                }

                Rectangle()
                    .fill(VitaColors.accent.opacity(0.15))
                    .frame(height: 0.5)

                // Values: "1.3/2 (6.5)" format with color based on normalized value
                HStack(spacing: 0) {
                    ForEach(vm.gradeSlots, id: \.label) { slot in
                        gradeSlotCell(value: slot.value, weight: slot.weight)
                    }
                    gradeCell(vm.finalGrade, maxValue: 10)
                }

                if !vm.hasAnyGrade {
                    Text("Nenhuma nota registrada ainda")
                        .font(.system(size: 11))
                        .foregroundStyle(textDim)
                        .padding(.top, 4)
                }
            }
            .padding(16)
        }
    }

    /// Grade slot cell showing "value/weight (normalized)" e.g. "1.3/2 (6.5)"
    private func gradeSlotCell(value: Double?, weight: Double) -> some View {
        VStack(spacing: 2) {
            if let v = value {
                let norm = DisciplineDetailViewModel.normalized(v, weight: weight)
                Text(String(format: "%.1f/%.0f", v, weight))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(gradeColor(normalized: norm))
                Text("(\(String(format: "%.1f", norm)))")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(gradeColor(normalized: norm).opacity(0.7))
            } else {
                Text("—")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(textDim)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Simple grade cell for finalGrade (already on 0-10 scale)
    private func gradeCell(_ val: Double?, maxValue: Double) -> some View {
        VStack(spacing: 2) {
            Text(val.map { String(format: "%.1f", $0) } ?? "—")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(val.map { gradeColor(normalized: ($0 / maxValue) * 10.0) } ?? textDim)
        }
        .frame(maxWidth: .infinity)
    }

    private func gradeColor(normalized: Double) -> Color {
        if normalized >= 7.0 { return VitaColors.dataGreen }
        if normalized >= 5.0 { return VitaColors.dataAmber }
        return VitaColors.dataRed
    }

    // MARK: - Schedule Card (horários da disciplina)

    // 0=Dom 1=Seg 2=Ter 3=Qua 4=Qui 5=Sex 6=Sab (matches portal_schedule.dayOfWeek)
    private static let dayNames = ["Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"]

    @ViewBuilder
    private func scheduleCard(vm: DisciplineDetailViewModel) -> some View {
        let blocks = vm.subjectSchedule
        if !blocks.isEmpty {
            VitaGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 12))
                            .foregroundStyle(goldPrimary)
                        Text("Horários")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(textPrimary)
                    }

                    ForEach(blocks) { block in
                        HStack(spacing: 10) {
                            let dayIdx = max(0, min(6, block.dayOfWeek))
                            Text(Self.dayNames[dayIdx])
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(goldPrimary)
                                .frame(width: 30, alignment: .leading)

                            Text("\(block.startTime) – \(block.endTime)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(textWarm)

                            Spacer()

                            if let room = block.room, !room.isEmpty {
                                HStack(spacing: 3) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 9))
                                    Text(room)
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(goldMuted.opacity(0.6))
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .padding(16)
            }
        }
    }

    // MARK: - Next Exam (highlighted)

    @ViewBuilder
    private func nextExamCard(vm: DisciplineDetailViewModel) -> some View {
        if let exam = vm.nextExam {
            let urgencyColor: Color = {
                if exam.daysUntil <= 0 { return VitaColors.dataRed }
                if exam.daysUntil <= 3 { return VitaColors.dataAmber }
                if exam.daysUntil <= 7 { return VitaColors.accent }
                return VitaColors.dataGreen
            }()

            VitaGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center) {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(urgencyColor)
                            Text("Próxima Prova")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(textPrimary)
                        }
                        Spacer()
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text("\(max(0, exam.daysUntil))")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(urgencyColor)
                            Text(exam.daysUntil == 1 ? "dia" : "dias")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(urgencyColor.opacity(0.75))
                        }
                    }

                    Text(exam.displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(textPrimary)

                    if !exam.date.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                                .foregroundStyle(urgencyColor.opacity(0.80))
                            Text(formatDate(exam.date, format: "dd 'de' MMMM · HH:mm"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(textWarm.opacity(0.60))
                        }
                    }

                    if let notes = exam.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.system(size: 12))
                            .foregroundStyle(textWarm.opacity(0.55))
                            .lineLimit(3)
                    }
                }
                .padding(16)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(urgencyColor.opacity(0.25), lineWidth: 1)
            )
        }
    }

    // MARK: - All Exams (history + upcoming)

    @ViewBuilder
    private func allExamsCard(vm: DisciplineDetailViewModel) -> some View {
        let allExams = vm.subjectExams
        if !allExams.isEmpty {
            VitaGlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Avaliações")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(textPrimary)
                        Spacer()
                        Text("\(allExams.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(goldMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    ForEach(Array(allExams.enumerated()), id: \.element.id) { idx, exam in
                        if idx > 0 {
                            Rectangle().fill(glassBorder).frame(height: 0.5)
                                .padding(.horizontal, 16)
                        }
                        examRow(exam)
                    }
                }
                .padding(.bottom, 14)
            }
        }
    }

    private func examRow(_ exam: ExamEntry) -> some View {
        let isPast = exam.daysUntil < 0
        return HStack(spacing: 10) {
            Circle()
                .fill(isPast ? textDim : VitaColors.accent)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(exam.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                if !exam.date.isEmpty {
                    Text(formatDate(exam.date, format: "dd/MM/yyyy"))
                        .font(.system(size: 10))
                        .foregroundStyle(textDim)
                }
            }

            Spacer()

            if let result = exam.result {
                Text(String(format: "%.1f", result))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(gradeColor(normalized: result))
            } else if !isPast {
                Text("\(exam.daysUntil)d")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(exam.daysUntil <= 7 ? VitaColors.dataAmber : textDim)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Trabalhos Card

    @ViewBuilder
    private func trabalhosCard(vm: DisciplineDetailViewModel) -> some View {
        let items = vm.subjectTrabalhos
        if !items.isEmpty {
            VitaGlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.badge.clock")
                                .font(.system(size: 12))
                                .foregroundStyle(goldPrimary)
                            Text("Trabalhos")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(textPrimary)
                        }
                        Spacer()
                        if !vm.trabalhosPending.isEmpty {
                            Text("\(vm.trabalhosPending.count) pendente\(vm.trabalhosPending.count > 1 ? "s" : "")")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(VitaColors.dataAmber)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(VitaColors.dataAmber.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        if idx > 0 {
                            Rectangle().fill(glassBorder).frame(height: 0.5)
                                .padding(.horizontal, 16)
                        }
                        Button {
                            router.navigate(to: .trabalhoDetail(id: item.id))
                        } label: {
                            trabalhoRow(item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 14)
            }
        }
    }

    private func trabalhoRow(_ item: TrabalhoItem) -> some View {
        let statusColor: Color = {
            if item.submitted { return VitaColors.dataGreen }
            if let d = item.daysUntil, d < 0 { return VitaColors.dataRed }
            if item.status == "graded" { return VitaColors.accent }
            if let d = item.daysUntil, d <= 3 { return VitaColors.dataAmber }
            return goldMuted
        }()
        let statusText: String = {
            if item.submitted { return "ENTREGUE" }
            if let d = item.daysUntil, d < 0 { return "ATRASADO" }
            if item.status == "graded" { return "CORRIGIDO" }
            return "PENDENTE"
        }()

        return HStack(spacing: 10) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                if let date = item.dueDate {
                    let fmt = DateFormatter()
                    let _ = { fmt.locale = Locale(identifier: "pt_BR"); fmt.dateFormat = "dd/MM" }()
                    Text(fmt.string(from: date))
                        .font(.system(size: 10))
                        .foregroundStyle(textDim)
                }
            }

            Spacer()

            Text(statusText)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(statusColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(statusColor.opacity(0.12))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(textDim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Study Section (always visible)

    private func studyCard(vm: DisciplineDetailViewModel) -> some View {
        let progress = vm.subjectProgress
        return VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Estudar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textPrimary)
                    Spacer()
                    if let p = progress, p.hoursSpent > 0 {
                        Text(String(format: "%.1fh estudadas", p.hoursSpent))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(textDim)
                    }
                }

                studyRow(
                    icon: "rectangle.on.rectangle.angled",
                    title: "Flashcards",
                    detail: flashcardDetail(vm),
                    badge: vm.flashcardsDue > 0 ? "\(vm.flashcardsDue)" : nil,
                    badgeColor: VitaColors.dataAmber
                ) {
                    onNavigateToFlashcards?(vm.subjectDecks.first?.id ?? "")
                }

                Rectangle().fill(glassBorder).frame(height: 0.5)

                studyRow(
                    icon: "list.bullet.clipboard",
                    title: "Questões",
                    detail: questoesDetail(vm),
                    badge: nil,
                    badgeColor: .clear
                ) {
                    onNavigateToQBank?()
                }

                Rectangle().fill(glassBorder).frame(height: 0.5)

                studyRow(
                    icon: "clock.badge.checkmark",
                    title: "Simulados",
                    detail: simuladoDetail(vm),
                    badge: nil,
                    badgeColor: .clear
                ) {
                    onNavigateToSimulado?()
                }
            }
            .padding(16)
        }
    }

    private func flashcardDetail(_ vm: DisciplineDetailViewModel) -> String {
        if vm.flashcardsDue > 0 {
            return "\(vm.flashcardsDue) para revisar · \(vm.flashcardsTotal) total"
        } else if vm.flashcardsTotal > 0 {
            return "\(vm.flashcardsTotal) cards"
        }
        return "Iniciar flashcards"
    }

    private func questoesDetail(_ vm: DisciplineDetailViewModel) -> String {
        if let p = vm.subjectProgress, p.questionCount > 0 {
            let pct = Int(p.accuracy * 100)
            return "\(p.questionCount) respondidas · \(pct)% acerto"
        }
        return "Iniciar questões"
    }

    private func simuladoDetail(_ vm: DisciplineDetailViewModel) -> String {
        if let p = vm.subjectProgress, p.questionCount > 0 {
            return "Treinar com prova cronometrada"
        }
        return "Iniciar simulado"
    }

    private func studyRow(icon: String, title: String, detail: String, badge: String?, badgeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VitaColors.accent.opacity(0.80))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(VitaColors.accent.opacity(0.10))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textPrimary)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(textDim)
                }

                Spacer()

                if let badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(badgeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(badgeColor.opacity(0.15))
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(textDim)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Documents (grouped by type)

    private struct DocCategory: Identifiable {
        var id: String { label }
        let label: String
        let icon: String
        let color: Color
        let docs: [VitaDocument]
    }

    private func categorizedDocs(_ docs: [VitaDocument]) -> [DocCategory] {
        var planos: [VitaDocument] = []
        var slides: [VitaDocument] = []
        var provas: [VitaDocument] = []
        var outros: [VitaDocument] = []

        for doc in docs {
            let t = doc.title.lowercased()
            if t.contains("plano") || t.contains("cronograma") || t.contains("ementa") || t.contains("syllabus") {
                planos.append(doc)
            } else if t.contains("apresenta") || t.contains("aula") || t.contains("slide") || t.contains("pptx") || doc.fileName.lowercased().hasSuffix(".pptx") {
                slides.append(doc)
            } else if t.contains("prova") || t.contains("ade") || t.contains("avaliação") || t.contains("simulado") || t.contains("gabarito") {
                provas.append(doc)
            } else {
                outros.append(doc)
            }
        }

        var result: [DocCategory] = []
        if !planos.isEmpty { result.append(DocCategory(label: "Planos de Ensino", icon: "list.clipboard", color: VitaColors.accent, docs: planos)) }
        if !slides.isEmpty { result.append(DocCategory(label: "Aulas & Slides", icon: "doc.richtext", color: VitaColors.dataAmber, docs: slides)) }
        if !provas.isEmpty { result.append(DocCategory(label: "Provas & Avaliações", icon: "checkmark.seal", color: VitaColors.dataRed, docs: provas)) }
        if !outros.isEmpty { result.append(DocCategory(label: "Outros Materiais", icon: "doc.text", color: goldPrimary, docs: outros)) }
        return result
    }

    @ViewBuilder
    private func documentsCard(vm: DisciplineDetailViewModel) -> some View {
        let allDocs = vm.subjectDocuments
        if !allDocs.isEmpty {
            let categories = categorizedDocs(allDocs)
            VitaGlassCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Materiais")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(textPrimary)
                        Spacer()
                        Text("\(allDocs.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(goldMuted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    ForEach(categories) { cat in
                        docCategorySection(cat)
                    }
                }
                .padding(.bottom, 14)
            }
        }
    }

    @Environment(Router.self) private var router

    private func docCategorySection(_ cat: DocCategory) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: cat.icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(cat.color.opacity(0.80))
                Text(cat.label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.6)
                    .foregroundStyle(cat.color.opacity(0.65))
                Spacer()
                Text("\(cat.docs.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(textDim)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ForEach(Array(cat.docs.enumerated()), id: \.element.id) { idx, doc in
                if idx > 0 {
                    Rectangle().fill(glassBorder).frame(height: 0.5)
                        .padding(.horizontal, 16)
                }
                Button {
                    router.navigate(to: .pdfViewer(url: "\(AppConfig.apiBaseURL)/documents/\(doc.id)/file"))
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: docIcon(doc.fileName))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(cat.color.opacity(0.80))
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(cat.color.opacity(0.10))
                            )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(doc.title.isEmpty ? doc.fileName : doc.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(textPrimary)
                                .lineLimit(1)
                            if let date = doc.createdAt {
                                Text(formatDate(date, format: "dd/MM/yyyy"))
                                    .font(.system(size: 10))
                                    .foregroundStyle(textDim)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(textDim)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ dateStr: String, format: String) -> String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: dateStr) ?? ISO8601DateFormatter().date(from: dateStr)
        guard let d = date else { return dateStr }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "pt_BR")
        fmt.dateFormat = format
        return fmt.string(from: d)
    }

    private func statusColor(_ status: String?) -> Color {
        switch status?.lowercased() {
        case "aprovado": return VitaColors.dataGreen
        case "reprovado": return VitaColors.dataRed
        default: return goldPrimary
        }
    }

    private func statusLabel(_ status: String?) -> String {
        switch status?.lowercased() {
        case "aprovado": return "APROVADO"
        case "reprovado": return "REPROVADO"
        case "cursando": return "CURSANDO"
        default: return "DISCIPLINA"
        }
    }

    private func docIcon(_ fileName: String) -> String {
        let ext = fileName.components(separatedBy: ".").last?.lowercased() ?? ""
        switch ext {
        case "pdf": return "doc.text"
        case "ppt", "pptx": return "doc.richtext"
        case "doc", "docx": return "doc.text.fill"
        case "xls", "xlsx": return "tablecells"
        case "jpg", "jpeg", "png": return "photo"
        default: return "doc"
        }
    }
}
