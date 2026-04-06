import SwiftUI

// MARK: - FaculdadeScreen (matches faculdade-mobile-v1.html mockup)
// Data-driven: uses FaculdadeViewModel backed by WebAluno API endpoints.

struct FaculdadeScreen: View {
    @Environment(\.appContainer) private var container

    // Gold palette from mockup
    private let goldPrimary = VitaColors.accentHover   // #FFC878 → use VitaColors
    private let goldAccent  = VitaColors.accent           // #E0BA75 → VitaColors.accent
    private let goldMuted   = VitaColors.accentLight      // rgba(255,220,160) → VitaColors.accentLight
    private let textPrimary = VitaColors.textPrimary
    private let textSec     = VitaColors.textWarm.opacity(0.45)
    private let textDim     = VitaColors.textWarm.opacity(0.28)
    private let greenStat   = VitaColors.dataGreen
    private let glassBg     = VitaColors.glassBg
    private let glassBorder = VitaColors.textWarm.opacity(0.06)
    private let cardBg      = VitaColors.surfaceCard.opacity(0.85)

    @State private var vm: FaculdadeViewModel?
    @State private var selectedDayIndex: Int = currentWeekdayIndex()
    @State private var showApproved = false

    var body: some View {
        Group {
            if let vm {
                if vm.isLoading {
                    loadingState
                } else if !vm.isConnected {
                    notConnectedState
                } else if let error = vm.error {
                    errorState(error)
                } else {
                    contentView(vm)
                }
            } else {
                loadingState
            }
        }
        .task {
            if vm == nil {
                let viewModel = FaculdadeViewModel(api: container.api, tokenStore: container.tokenStore)
                vm = viewModel
                await viewModel.load()
            }
        }
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .tint(goldPrimary)
            Text("Carregando dados...")
                .font(.system(size: 13))
                .foregroundStyle(textSec)
            Spacer()
        }
    }

    // MARK: - Not Connected State

    private var notConnectedState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "link.badge.plus")
                .font(.system(size: 40))
                .foregroundStyle(goldPrimary.opacity(0.6))

            Text("WebAluno nao conectado")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(textPrimary)

            Text("Conecte seu WebAluno para ver suas disciplinas, notas e agenda.")
                .font(.system(size: 13))
                .foregroundStyle(textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            NavigationLink(value: Route.portalConnect(type: "webaluno")) {
                Text("Conectar WebAluno")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VitaColors.surface)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(goldPrimary)
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Error State

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(goldPrimary.opacity(0.6))

            Text("Erro ao carregar")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(textPrimary)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                if let vm {
                    Task { await vm.load() }
                }
            } label: {
                Text("Tentar novamente")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(goldPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .overlay(
                        Capsule()
                            .stroke(goldPrimary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Content

    private func contentView(_ vm: FaculdadeViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroCard(vm)
                semesterTabs(vm)
                agendaSection(vm)
                disciplinesSection(vm)
                approvedSection(vm)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 120)
        }
        .refreshable {
            await vm.load()
        }
    }

    // MARK: - Hero Card

    private func heroCard(_ vm: FaculdadeViewModel) -> some View {
        let totalDisc = vm.summary?.total ?? vm.grades.count
        let avgGrade = vm.summary?.averageGrade
        let avgFreq = vm.averageAttendance
        let inProgress = vm.summary?.inProgress ?? vm.filteredGrades.filter { $0.status != "approved" && $0.status != "completed" }.count
        let period = vm.currentPeriod.map { "\($0)o periodo" } ?? ""
        let university = vm.universityName ?? ""
        let semesterLabel = vm.selectedSemester ?? ""

        return ZStack(alignment: .bottomLeading) {
            // Layer 1 — background image
            Image("hero-anatomia")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 160)

            // Layer 2 — dark gradient overlay (bottom heavy)
            LinearGradient(
                colors: [
                    VitaColors.surface.opacity(0.80),
                    VitaColors.surface.opacity(0.40),
                    VitaColors.surface.opacity(0.20)
                ],
                startPoint: .bottom,
                endPoint: .top
            )

            // Layer 3 — inner glow radial corners
            ZStack {
                RadialGradient(
                    colors: [VitaColors.glassInnerLight.opacity(0.18), .clear],
                    center: .bottomLeading,
                    startRadius: 0, endRadius: 120
                )
                RadialGradient(
                    colors: [VitaColors.glassInnerLight.opacity(0.12), .clear],
                    center: .bottomTrailing,
                    startRadius: 0, endRadius: 110
                )
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(vm.courseName)\(period.isEmpty ? "" : " — \(period)")")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(textPrimary)
                    .tracking(-0.6)

                Text("\(university)\(semesterLabel.isEmpty ? "" : " · Semestre \(semesterLabel)")")
                    .font(.system(size: 12))
                    .foregroundStyle(textSec)

                // Stats row
                HStack(spacing: 0) {
                    heroStat(value: "\(totalDisc)", label: "Disciplinas", color: goldMuted)
                    heroDivider
                    heroStat(
                        value: avgGrade.map { String(format: "%.1f", $0) } ?? "--",
                        label: "Media",
                        color: greenStat
                    )
                    heroDivider
                    heroStat(
                        value: avgFreq.map { "\(Int($0))%" } ?? "--",
                        label: "Frequencia",
                        color: greenStat
                    )
                    heroDivider
                    heroStat(value: "\(inProgress)", label: "Cursando", color: goldMuted)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(VitaColors.surfaceCard.opacity(0.75))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(goldPrimary.opacity(0.08), lineWidth: 1)
                )
                .padding(.top, 16)
            }
            .padding(18)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    AngularGradient(
                        colors: [
                            goldPrimary.opacity(0.44),
                            goldPrimary.opacity(0.28),
                            goldPrimary.opacity(0.14),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.03),
                            Color.white.opacity(0.05),
                            goldPrimary.opacity(0.14),
                            goldPrimary.opacity(0.26),
                            goldPrimary.opacity(0.44)
                        ],
                        center: .bottomLeading
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.50), radius: 25, y: 10)
        .shadow(color: VitaColors.glassInnerLight.opacity(0.07), radius: 14)
        .padding(.bottom, 4)
    }

    private func heroStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(color.opacity(0.90))
                .tracking(-0.3)
            Text(label)
                .font(.system(size: 8.5, weight: .regular))
                .foregroundStyle(textDim.opacity(0.8))
                .textCase(.uppercase)
                .tracking(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var heroDivider: some View {
        Rectangle()
            .fill(goldPrimary.opacity(0.06))
            .frame(width: 1, height: 28)
    }

    // MARK: - Semester Tabs

    private func semesterTabs(_ vm: FaculdadeViewModel) -> some View {
        HStack(spacing: 6) {
            ForEach(vm.semesters, id: \.self) { sem in
                Button {
                    vm.selectSemester(sem)
                } label: {
                    semesterPill(sem, isActive: sem == vm.selectedSemester)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.vertical, 16)
    }

    private func semesterPill(_ text: String, isActive: Bool) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(
                isActive
                    ? goldMuted.opacity(0.85)
                    : VitaColors.textWarm.opacity(0.35)
            )
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(
                        isActive
                            ? VitaColors.glassInnerLight.opacity(0.12)
                            : Color.white.opacity(0.06)
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        isActive
                            ? goldPrimary.opacity(0.18)
                            : glassBorder,
                        lineWidth: 1
                    )
            )
    }

    // MARK: - Agenda

    private func agendaSection(_ vm: FaculdadeViewModel) -> some View {
        let weekDates = currentWeekDates()
        let todayIdx = Self.currentWeekdayIndex()

        return VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Agenda da semana")

            VStack(spacing: 12) {
                // Week strip
                HStack(spacing: 2) {
                    ForEach(Array(weekDates.enumerated()), id: \.offset) { idx, info in
                        Button {
                            selectedDayIndex = idx
                        } label: {
                            weekDay(
                                info.label,
                                num: info.dayNum,
                                isToday: idx == todayIdx,
                                isActive: idx == selectedDayIndex
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Schedule items for selected day (dayOfWeek: 1=Mon, 2=Tue, ...)
                let dayBlocks = vm.schedule
                    .filter { $0.dayOfWeek == selectedDayIndex + 1 }
                    .sorted { $0.startTime < $1.startTime }

                if dayBlocks.isEmpty {
                    Text("Sem aulas")
                        .font(.system(size: 12))
                        .foregroundStyle(textDim)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(dayBlocks.enumerated()), id: \.offset) { idx, block in
                            let timeStr = String(block.startTime.prefix(5))
                            let period = block.startTime < "12:00" ? "Manha" : "Tarde"
                            let roomStr = block.room.map { " · \($0)" } ?? ""
                            let detail = "\(period) · \(String(block.startTime.prefix(5)))-\(String(block.endTime.prefix(5)))\(roomStr)"
                            scheduleItem(
                                time: timeStr,
                                subject: block.subjectName ?? "",
                                room: detail,
                                isNow: idx == 0 && selectedDayIndex == todayIdx
                            )
                            if idx < dayBlocks.count - 1 {
                                Divider()
                                    .background(VitaColors.textWarm.opacity(0.03))
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(glassBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
            .padding(.bottom, 4)
        }
    }

    private func weekDay(_ label: String, num: String, isToday: Bool, isActive: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
            Text(num)
                .font(.system(size: 13, weight: .bold))
        }
        .foregroundStyle(
            isActive
                ? goldMuted.opacity(0.90)
                : VitaColors.textWarm.opacity(0.28)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isActive
                        ? VitaColors.glassInnerLight.opacity(0.12)
                        : Color.clear
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isActive
                        ? goldPrimary.opacity(0.16)
                        : Color.clear,
                    lineWidth: 1
                )
        )
        .overlay(alignment: .bottom) {
            if isToday {
                Circle()
                    .fill(goldPrimary.opacity(0.60))
                    .frame(width: 4, height: 4)
                    .offset(y: -3)
            }
        }
    }

    private func scheduleItem(time: String, subject: String, room: String, isNow: Bool) -> some View {
        HStack(spacing: 10) {
            Text(time)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(goldMuted.opacity(0.55))
                .frame(width: 44, alignment: .trailing)

            RoundedRectangle(cornerRadius: 1)
                .fill(
                    isNow
                        ? LinearGradient(colors: [goldPrimary.opacity(0.70)], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(
                            colors: [
                                VitaColors.glassInnerLight.opacity(0.40),
                                VitaColors.glassInnerLight.opacity(0.10)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                          )
                )
                .frame(width: 2, height: 32)
                .shadow(color: isNow ? goldPrimary.opacity(0.30) : .clear, radius: 4)

            VStack(alignment: .leading, spacing: 1) {
                Text(subject)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
                Text(room)
                    .font(.system(size: 9.5))
                    .foregroundStyle(textDim)
            }

            Spacer()
        }
    }

    // MARK: - Disciplines Table

    private func disciplinesSection(_ vm: FaculdadeViewModel) -> some View {
        let cursando = vm.filteredGrades.filter { $0.status != "approved" && $0.status != "completed" }

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                sectionLabel("Cursando")
                Spacer()
                HStack(spacing: 2) {
                    Text("Score Vita")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(VitaColors.accentHover.opacity(0.45))
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(VitaColors.accentHover.opacity(0.35))
                }
            }
            .padding(.top, 20)

            if cursando.isEmpty {
                Text("Nenhuma disciplina em andamento")
                    .font(.system(size: 12))
                    .foregroundStyle(textDim)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 4) {
                    ForEach(cursando) { grade in
                        let freq = Int(grade.attendance ?? 0)
                        let freqLvl: FreqLevel = freq >= 90 ? .good : (freq >= 80 ? .warn : .bad)
                        let finalGrade = grade.finalGrade
                        let diff = difficultyForSubject(grade.subjectName ?? "")
                        discRow(
                            icon: iconForSubject(grade.subjectName ?? ""),
                            name: grade.subjectName ?? "",
                            difficulty: diff,
                            freq: freq,
                            freqLevel: freqLvl,
                            grade: finalGrade,
                            score: scoreForDifficulty(diff),
                            scoreLevel: scoreLevelForDifficulty(diff)
                        )
                    }
                }
            }
        }
    }

    // MARK: - Approved Section

    private func approvedSection(_ vm: FaculdadeViewModel) -> some View {
        let approved = vm.filteredGrades.filter { $0.status == "approved" || $0.status == "completed" }
        let avgApproved: Double? = {
            let grades = approved.compactMap(\.finalGrade)
            guard !grades.isEmpty else { return nil }
            return grades.reduce(0, +) / Double(grades.count)
        }()

        return VStack(alignment: .leading, spacing: 6) {
            sectionLabel("Aprovadas")
                .padding(.top, 20)

            if approved.isEmpty {
                Text("Nenhuma disciplina aprovada neste semestre")
                    .font(.system(size: 12))
                    .foregroundStyle(textDim)
                    .padding(.vertical, 8)
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showApproved.toggle()
                    }
                } label: {
                    HStack {
                        Text("\(approved.count) disciplinas aprovadas")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        Spacer()
                        if let avg = avgApproved {
                            Text("Média \(String(format: "%.1f", avg))")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(greenStat.opacity(0.50))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 999)
                                        .fill(greenStat.opacity(0.06))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 999)
                                        .stroke(greenStat.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.015))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.textWarm.opacity(0.03), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if showApproved {
                    VStack(spacing: 4) {
                        ForEach(approved.sorted(by: { ($0.finalGrade ?? 0) > ($1.finalGrade ?? 0) })) { grade in
                            let freq = Int(grade.attendance ?? 0)
                            let finalGrade = grade.finalGrade ?? 0
                            let gLevel: GradeLevel = finalGrade >= 7.5 ? .good : (finalGrade >= 6.0 ? .ok : .bad)
                            approvedRow(
                                name: grade.subjectName ?? "",
                                freq: freq,
                                grade: finalGrade,
                                gradeLevel: gLevel
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
            .textCase(.uppercase)
            .tracking(0.8)
    }

    /// Map subject name to a gold icon asset. Falls back to interprofissional.
    private func iconForSubject(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("farmacologia") { return "disc-gold-farmacologia" }
        if lower.contains("patologia") { return "disc-gold-patologia-geral" }
        if lower.contains("anatomia") { return "disc-gold-anatomia" }
        if lower.contains("histologia") || lower.contains("histologia") { return "disc-gold-biologia-celular" }
        if lower.contains("bioquimica") || lower.contains("bioquímica") { return "disc-gold-bioquimica" }
        if lower.contains("fisiologia") { return "disc-gold-fisiologia-1" }
        if lower.contains("medicina legal") || lower.contains("deontologia") || lower.contains("ética") || lower.contains("etica") || lower.contains("ética médica") { return "disc-gold-etica-medica" }
        if lower.contains("interprofission") || lower.contains("práticas interpro") { return "disc-gold-interprofissional" }
        if lower.contains("familia") || lower.contains("família") || lower.contains("comunidade") || lower.contains("mfc") { return "disc-gold-mfc-1" }
        if lower.contains("sociedade") || lower.contains("humanidades") || lower.contains("cultura") { return "disc-gold-humanidades" }
        if lower.contains("estatistica") || lower.contains("estatística") { return "disc-gold-estatistica" }
        if lower.contains("comunicacao") || lower.contains("comunicação") { return "disc-gold-comunicacao" }
        return "disc-gold-interprofissional"
    }

    /// Heuristic difficulty based on subject name keywords.
    private func difficultyForSubject(_ name: String) -> Difficulty {
        let lower = name.lowercased()
        if lower.contains("farmacologia") || lower.contains("patologia") { return .hard }
        if lower.contains("anatomia") || lower.contains("fisiologia") || lower.contains("bioquimica") || lower.contains("bioquímica") || lower.contains("histologia") || lower.contains("medicina legal") || lower.contains("deontologia") || lower.contains("ética") || lower.contains("etica") {
            return .medium
        }
        return .easy
    }

    private func scoreForDifficulty(_ diff: Difficulty) -> Int {
        switch diff {
        case .hard:   return 60
        case .medium: return 35
        case .easy:   return 14
        }
    }

    private func scoreLevelForDifficulty(_ diff: Difficulty) -> ScoreLevel {
        switch diff {
        case .hard:   return .high
        case .medium: return .medium
        case .easy:   return .low
        }
    }

    // MARK: - Discipline Row

    private enum Difficulty {
        case easy, medium, hard

        var label: String {
            switch self {
            case .easy: return "Fácil"
            case .medium: return "Médio"
            case .hard: return "Difícil"
            }
        }

        var color: Color {
            switch self {
            case .easy: return VitaColors.dataGreen
            case .medium: return VitaColors.accentHover
            case .hard: return VitaColors.dataRed
            }
        }
    }

    private enum FreqLevel { case good, warn, bad }
    private enum GradeLevel { case good, ok, bad }

    private enum ScoreLevel {
        case high, medium, low

        var color: Color {
            switch self {
            case .high: return VitaColors.dataRed
            case .medium: return VitaColors.accentHover
            case .low: return VitaColors.dataGreen
            }
        }
    }

    private func discRow(
        icon: String,
        name: String,
        difficulty: Difficulty,
        freq: Int,
        freqLevel: FreqLevel,
        grade: Double?,
        score: Int,
        scoreLevel: ScoreLevel
    ) -> some View {
        HStack(spacing: 10) {
            // Discipline icon (glass icon with inner padding)
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(4)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VitaColors.glassInnerLight.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(VitaColors.glassInnerLight.opacity(0.08), lineWidth: 1)
                )

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(2)

                HStack(spacing: 6) {
                    diffBadge(difficulty)
                    if freq > 0 {
                        freqPill(freq, level: freqLevel)
                    }
                }
            }

            Spacer(minLength: 4)

            // Grade
            if let grade {
                Text(String(format: "%.1f", grade))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(gradeColor(grade))
                    .frame(minWidth: 28)
            } else {
                Text("\u{2014}")
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.15))
                    .frame(minWidth: 28)
            }

            // Score badge always visible
            scoreBadge(score: score, level: scoreLevel)

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(VitaColors.textWarm.opacity(0.18))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(glassBorder, lineWidth: 1)
        )
    }

    private func diffBadge(_ diff: Difficulty) -> some View {
        Text(diff.label)
            .font(.system(size: 8, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(diff.color.opacity(0.65))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(diff.color.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(diff.color.opacity(0.15), lineWidth: 1)
            )
    }

    private func freqPill(_ freq: Int, level: FreqLevel) -> some View {
        let color: Color = {
            switch level {
            case .good: return greenStat
            case .warn: return VitaColors.dataAmber
            case .bad: return VitaColors.dataRed
            }
        }()

        return Text("\(freq)%")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color.opacity(0.60))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.06))
            )
    }

    private func gradeColor(_ grade: Double) -> Color {
        if grade >= 7.5 { return greenStat.opacity(0.85) }
        if grade >= 6.0 { return goldMuted.opacity(0.75) }
        return VitaColors.dataRed.opacity(0.80)
    }

    private func scoreBadge(score: Int, level: ScoreLevel) -> some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.04), lineWidth: 3)
                .frame(width: 36, height: 36)

            Circle()
                .trim(from: 0, to: CGFloat(score) / 100.0)
                .stroke(level.color.opacity(0.50), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(-90))
                .shadow(color: level.color.opacity(0.25), radius: 4)

            Text("\(score)")
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(level.color.opacity(0.85))
                .tracking(-0.3)
        }
    }

    private func approvedRow(name: String, freq: Int, grade: Double, gradeLevel: GradeLevel) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 10)
                .fill(VitaColors.glassInnerLight.opacity(0.06))
                .frame(width: 38, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(VitaColors.glassInnerLight.opacity(0.08), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(1)
                if freq > 0 {
                    freqPill(freq, level: freq >= 90 ? .good : .warn)
                }
            }

            Spacer()

            Text(String(format: "%.1f", grade))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(gradeColor(grade))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(glassBorder, lineWidth: 1)
        )
        .opacity(0.5)
    }

    // MARK: - Week Date Helpers

    private struct WeekDayInfo {
        let label: String
        let dayNum: String
    }

    private static func currentWeekdayIndex() -> Int {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: Date())
        // Convert from Sunday=1..Saturday=7 to Mon=0..Fri=4
        switch weekday {
        case 2: return 0 // Mon
        case 3: return 1 // Tue
        case 4: return 2 // Wed
        case 5: return 3 // Thu
        case 6: return 4 // Fri
        default: return 0 // Weekend defaults to Mon
        }
    }

    private func currentWeekDates() -> [WeekDayInfo] {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        // Monday of current week
        let daysFromMonday = (weekday + 5) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!

        let labels = ["Seg", "Ter", "Qua", "Qui", "Sex"]
        return (0..<5).map { offset in
            let date = cal.date(byAdding: .day, value: offset, to: monday)!
            let dayNum = String(cal.component(.day, from: date))
            return WeekDayInfo(label: labels[offset], dayNum: dayNum)
        }
    }
}
