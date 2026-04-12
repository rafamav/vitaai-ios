import SwiftUI

// MARK: - FaculdadeHomeScreen
//
// Dashboard of the Faculdade tab. Structure:
//   1. Subtab pills (Agenda · Matérias · Documentos) at top — navigation shortcut
//   2. Hero card — institution branding (background image or fallback gradient)
//   3. Mini cards — compact previews of each subpage content (today, CR, recent docs)
//
// Every navigable element pushes to its respective full subpage via NavigationStack.

struct FaculdadeHomeScreen: View {
    @Environment(\.appData) private var appData
    @Environment(\.scenePhase) private var scenePhase
    @Environment(Router.self) private var router

    // Tokens
    private var goldPrimary: Color { VitaColors.accentHover }
    private var goldMuted: Color { VitaColors.accentLight }
    private var textPrimary: Color { VitaColors.textPrimary }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }
    private var cardBg: Color { VitaColors.surfaceCard.opacity(0.55) }
    private var glassBorder: Color { VitaColors.textWarm.opacity(0.06) }

    // Institution info — coming from user profile / appData.
    // Hardcoded por enquanto até termos getUserProfile() exposto no appData.
    private var institutionName: String { "ULBRA Porto Alegre" }
    private var courseName: String { "Medicina" }
    private var currentSemester: Int { 3 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                subTabRow
                heroCard
                agendaMiniCard
                materiasMiniCard
                documentosMiniCard
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable { await appData.forceRefresh() }
        .onAppear {
            Task { await appData.silentRefresh() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await appData.silentRefresh() }
            }
        }
    }

    // MARK: - Subtab row (navigation shortcuts)

    private var subTabRow: some View {
        HStack(spacing: 6) {
            subTabPill(title: "Agenda", icon: "calendar", route: .faculdadeAgenda)
            subTabPill(title: "Matérias", icon: "graduationcap", route: .faculdadeMaterias)
            subTabPill(title: "Documentos", icon: "doc.text", route: .faculdadeDocumentos)
            Spacer()
        }
    }

    private func subTabPill(title: String, icon: String, route: Route) -> some View {
        Button {
            router.navigate(to: route)
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(goldMuted.opacity(0.75))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(VitaColors.glassInnerLight.opacity(0.05))
            )
            .overlay(
                Capsule().stroke(goldPrimary.opacity(0.16), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Hero card (instituição)
    //
    // Card premium sem imagem — gradient vertical sólido + accent dourado na
    // borda + tipografia dominante. Zero variabilidade de fundo, zero ruído
    // atrás do texto, contraste garantido.

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            heroSolidBackground
            heroGoldAccent
            heroBuildingMotif
            heroContent
        }
        .frame(height: 162)
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

    // Motif generalizado: ícone de prédio discreto no canto superior direito,
    // fora da zona de texto, baixa opacidade.
    private var heroBuildingMotif: some View {
        Image(systemName: "building.columns.fill")
            .font(.system(size: 64, weight: .ultraLight))
            .foregroundStyle(goldPrimary.opacity(0.08))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 14)
            .padding(.trailing, 16)
    }

    // Gradient vertical escuro — previsível, uniforme, texto sempre sobre zona escura.
    private var heroSolidBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.07, blue: 0.045),
                Color(red: 0.05, green: 0.035, blue: 0.022)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // Accent dourado minúsculo no canto superior direito — só uma luz suave,
    // longe da zona do texto, dá sensação premium sem interferir na leitura.
    private var heroGoldAccent: some View {
        RadialGradient(
            colors: [goldPrimary.opacity(0.22), Color.clear],
            center: UnitPoint(x: 1.0, y: 0.0),
            startRadius: 0,
            endRadius: 140
        )
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Zona 1: eyebrow no topo
            HStack(spacing: 6) {
                Circle()
                    .fill(goldPrimary)
                    .frame(width: 5, height: 5)
                Text("\(currentSemester)º SEMESTRE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(goldPrimary)
            }
            .padding(.bottom, 6)

            // Zona 2: título agrupado (institution + curso)
            Text(institutionName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.white)
                .kerning(-0.4)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            HStack(spacing: 6) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(goldMuted.opacity(0.75))
                Text(courseName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .padding(.top, 3)

            Spacer(minLength: 0)

            // Zona 3: stats strip embaixo
            heroStatsStrip
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var heroStatsStrip: some View {
        HStack(spacing: 14) {
            heroStat(label: "CR", value: crValue)
            heroStatDivider
            heroStat(label: "Aprov.", value: "\(appData.gradesResponse?.completed.count ?? 0)")
            heroStatDivider
            heroStat(label: "Cursando", value: "\(appData.gradesResponse?.current.count ?? 0)")
            Spacer()
        }
    }

    private var heroStatDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 16)
    }

    private func heroStat(label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(goldPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.white.opacity(0.55))
        }
    }

    private var crValue: String {
        guard let avg = appData.gradesResponse?.summary.averageGrade else { return "—" }
        return String(format: "%.2f", avg)
    }

    // MARK: - Mini card: Agenda (preview só de hoje)

    private var agendaMiniCard: some View {
        Button {
            router.navigate(to: .faculdadeAgenda)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                miniCardHeader(icon: "calendar", title: "Hoje", trailing: todayShort)

                let aulas = appData.classSchedule.filter { $0.dayOfWeek == todayWeekdayAPI }
                    .sorted { $0.startTime < $1.startTime }
                let evals = todayEvaluations

                if aulas.isEmpty && evals.isEmpty {
                    Text("Nenhum compromisso hoje")
                        .font(.system(size: 12))
                        .foregroundStyle(textDim)
                        .padding(.vertical, 6)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(evals.prefix(2).enumerated()), id: \.offset) { _, eval in
                            miniEvalLine(eval)
                        }
                        ForEach(Array(aulas.prefix(3).enumerated()), id: \.offset) { _, aula in
                            miniAulaLine(aula)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(glassBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var todayShort: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEE, d MMM"
        return f.string(from: Date()).capitalized
    }

    private var todayWeekdayAPI: Int {
        let wd = Calendar.current.component(.weekday, from: Date())
        // Foundation: 1=Sun ... 7=Sat → API: 1=Mon ... 7=Sun
        return ((wd + 5) % 7) + 1
    }

    private var todayEvaluations: [AgendaEvaluation] {
        let today = Date()
        let cal = Calendar.current
        return appData.academicEvaluations.filter { eval in
            guard let s = eval.date else { return false }
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fmt2 = ISO8601DateFormatter()
            fmt2.formatOptions = [.withInternetDateTime]
            guard let d = fmt.date(from: s) ?? fmt2.date(from: s) else { return false }
            return cal.isDate(d, inSameDayAs: today)
        }
    }

    private func miniEvalLine(_ eval: AgendaEvaluation) -> some View {
        let subject = eval.subjectName ?? "—"
        let color = SubjectColors.colorFor(subject: subject)
        let prova = eval.type.uppercased().contains("EXAM") || eval.type.uppercased().contains("PROVA")
        return HStack(spacing: 8) {
            Group {
                if prova {
                    Circle().fill(color).frame(width: 7, height: 7)
                        .shadow(color: color.opacity(0.5), radius: 2)
                } else {
                    Circle().stroke(color, lineWidth: 1.3).frame(width: 7, height: 7)
                }
            }
            .frame(width: 10)
            Text(eval.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color.opacity(0.95))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    private func miniAulaLine(_ aula: AgendaClassBlock) -> some View {
        let color = SubjectColors.colorFor(subject: aula.subjectName)
        return HStack(spacing: 8) {
            Text(String(aula.startTime.prefix(5)))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textWarm.opacity(0.55))
                .frame(width: 36, alignment: .leading)
            Rectangle()
                .fill(color)
                .frame(width: 2, height: 12)
            Text(aula.subjectName)
                .font(.system(size: 11))
                .foregroundStyle(textWarm.opacity(0.75))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Mini card: Matérias

    @State private var hoveredSubject: String?

    private var materiasMiniCard: some View {
        Button {
            router.navigate(to: .faculdadeMaterias)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                miniCardHeader(icon: "graduationcap", title: "Matérias", trailing: cursandoShort)

                let subjects = appData.gradesResponse?.current ?? []
                if subjects.isEmpty {
                    Text("Nenhuma disciplina ativa")
                        .font(.system(size: 11))
                        .foregroundStyle(textDim)
                        .padding(.vertical, 6)
                } else {
                    // Column headers
                    HStack(spacing: 0) {
                        Text("DISCIPLINA")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("G1").frame(width: 36, alignment: .center)
                        Text("FREQ").frame(width: 42, alignment: .center)
                    }
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(textDim)
                    .padding(.horizontal, 4)

                    VStack(spacing: 0) {
                        ForEach(subjects) { subject in
                            materiaRow(subject)
                            if subject.id != subjects.last?.id {
                                Rectangle().fill(glassBorder).frame(height: 0.5)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(glassBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            if let name = hoveredSubject {
                Text(name)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VitaColors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(cardBg))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(glassBorder, lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
                    .offset(y: -30)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: hoveredSubject)
    }

    private var cursandoShort: String {
        let n = appData.gradesResponse?.current.count ?? 0
        return n == 0 ? "" : "\(n) ativas"
    }

    @ViewBuilder
    private func materiaRow(_ subject: GradeSubject) -> some View {
        let color = SubjectColors.colorFor(subject: subject.subjectName)
        let grade = subject.grade1
        let freq = subject.attendance
        HStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(width: 2, height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 1))
                .padding(.trailing, 6)
            Text(subject.subjectName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textWarm.opacity(0.82))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onLongPressGesture(minimumDuration: 0.3) {
                    hoveredSubject = subject.subjectName
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if hoveredSubject == subject.subjectName { hoveredSubject = nil }
                    }
                }
            Text(grade.map { String(format: "%.1f", $0) } ?? "--")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(grade.map { gradeColor($0) } ?? textDim)
                .frame(width: 36, alignment: .center)
            Text(freq.map { "\($0)%" } ?? "--")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(freq.map { freqColor(Double($0)) } ?? textDim)
                .frame(width: 42, alignment: .center)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 5)
    }

    private func miniStatPill(value: String, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(textDim)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule().fill(color.opacity(0.10))
        )
    }

    private func freqColor(_ freq: Double) -> Color {
        if freq >= 85 { return VitaColors.dataGreen }
        if freq >= 75 { return VitaColors.dataAmber }
        return VitaColors.dataRed
    }

    private func gradeColor(_ grade: Double) -> Color {
        if grade >= 7 { return VitaColors.dataGreen }
        if grade >= 5 { return VitaColors.dataAmber }
        return VitaColors.dataRed
    }

    // MARK: - Mini card: Documentos

    private var documentosMiniCard: some View {
        Button {
            router.navigate(to: .faculdadeDocumentos)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                miniCardHeader(icon: "doc.text", title: "Documentos", trailing: "")
                Text("Planos de ensino, slides e materiais do portal")
                    .font(.system(size: 11))
                    .foregroundStyle(textWarm.opacity(0.45))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(cardBg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14).stroke(glassBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Shared mini card header

    private func miniCardHeader(icon: String, title: String, trailing: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(goldPrimary.opacity(0.80))
                .frame(width: 20, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(goldPrimary.opacity(0.10))
                )
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(textPrimary)
            Spacer()
            if !trailing.isEmpty {
                Text(trailing)
                    .font(.system(size: 10))
                    .foregroundStyle(textDim)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(textDim)
        }
    }

}
