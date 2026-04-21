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

    // Institution info from user profile (via onboarding)
    private var institutionName: String { appData.profile?.university ?? "Minha Faculdade" }
    private var courseName: String { "Medicina" }
    private var currentSemester: Int { appData.profile?.semester ?? 0 }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                subTabRow
                heroCard
                disciplinesSection
                MateriasAgendaWidget(
                    subjects: appData.gradesResponse?.current ?? [],
                    schedule: appData.classSchedule,
                    evaluations: appData.academicEvaluations,
                    onNavigateToDiscipline: { id, name in
                        router.navigate(to: .faculdadeDisciplinas)
                        router.navigate(to: .disciplineDetail(disciplineId: id, disciplineName: name))
                    }
                )
                trabalhosMiniCard
                documentosMiniCard
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable { await appData.forceRefresh() }
        .onAppear {
            Task {
                await appData.silentRefresh()
                ScreenLoadContext.finish(for: "Faculdade")
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await appData.silentRefresh() }
            }
        }
        .trackScreen("Faculdade")
    }

    // MARK: - Subtab row (navigation shortcuts)

    private var subTabRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                subTabPill(title: "Disciplinas", icon: "graduationcap", route: .faculdadeDisciplinas)
                subTabPill(title: "Documentos", icon: "doc.text", route: .faculdadeDocumentos)
                subTabPill(title: "Trabalhos", icon: "doc.richtext", route: .trabalhos)
                subTabPill(title: "Professores", icon: "person.2", route: .faculdadeProfessores)
            }
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
            if currentSemester > 0 {
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
            }

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

    // MARK: - Disciplines section (folder grid)

    private var disciplinesSection: some View {
        let subjects = appData.gradesResponse?.current ?? []

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Minhas Disciplinas")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(VitaColors.sectionLabel)
                Spacer()
                if !subjects.isEmpty {
                    Button {
                        router.navigate(to: .faculdadeDisciplinas)
                    } label: {
                        HStack(spacing: 3) {
                            Text("Ver todas")
                                .font(.system(size: 10, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundStyle(goldPrimary.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                }
            }

            if subjects.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "graduationcap")
                        .font(.system(size: 16))
                        .foregroundStyle(goldPrimary.opacity(0.35))
                    Text("Conecte seu portal para ver disciplinas")
                        .font(.system(size: 12))
                        .foregroundStyle(textDim)
                }
                .padding(.vertical, 8)
            } else {
                let sorted = sortedByFavorite(subjects)
                let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(sorted) { subject in
                        Button {
                            router.navigate(to: .faculdadeDisciplinas)
                            router.navigate(to: .disciplineDetail(disciplineId: subject.id, disciplineName: subject.subjectName))
                        } label: {
                            DisciplineFolderCard(
                                subjectName: subject.subjectName,
                                vitaScore: Int(appData.vitaScore(for: subject.subjectName))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func sortedByFavorite(_ subjects: [GradeSubject]) -> [GradeSubject] {
        let favs = DisciplineFolderCard.favorites()
        return subjects.sorted { a, b in
            let aFav = favs.contains(a.subjectName)
            let bFav = favs.contains(b.subjectName)
            if aFav != bFav { return aFav }
            return a.subjectName < b.subjectName
        }
    }

    // MARK: - Mini card: Trabalhos

    private var trabalhosMiniCard: some View {
        // Pending list: any assignment not yet submitted — includes overdue,
        // because the student still needs to see them (and can submit late).
        // Canvas marks submitted rows with status='completed' or submitted=true.
        let assignments = appData.academicEvaluations.filter { $0.type == "assignment" }
        let upcoming = assignments.filter { eval in
            // Show anything not yet submitted — overdue included. Student
            // still needs to see (and can submit late) past-due work.
            let status = eval.status.lowercased()
            return status != "completed" && status != "graded" && status != "submitted"
        }.sorted { a, b in
            (a.date ?? "") < (b.date ?? "")
        }

        return Button {
            router.navigate(to: .trabalhos)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                miniCardHeader(
                    icon: "doc.richtext",
                    title: "Trabalhos",
                    trailing: upcoming.isEmpty ? "" : "\(upcoming.count) pendente\(upcoming.count == 1 ? "" : "s")"
                )

                if upcoming.isEmpty {
                    Text("Nenhum trabalho pendente")
                        .font(.system(size: 11))
                        .foregroundStyle(textDim)
                        .padding(.vertical, 6)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(upcoming.prefix(3).enumerated()), id: \.offset) { _, eval in
                            miniTrabalhoLine(eval)
                        }
                        if upcoming.count > 3 {
                            Text("+ \(upcoming.count - 3) mais")
                                .font(.system(size: 10))
                                .foregroundStyle(textDim)
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

    private func miniTrabalhoLine(_ eval: AgendaEvaluation) -> some View {
        let subject = eval.subjectName ?? "—"
        let color = SubjectColors.colorFor(subject: subject)
        return HStack(spacing: 8) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(eval.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(textWarm.opacity(0.80))
                .lineLimit(1)
            Spacer(minLength: 0)
            if let dateStr = eval.date {
                Text(shortDate(dateStr))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(textDim)
            }
        }
    }

    private func shortDate(_ iso: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fmt2 = ISO8601DateFormatter()
        fmt2.formatOptions = [.withInternetDateTime]
        guard let d = fmt.date(from: iso) ?? fmt2.date(from: iso) else { return "" }
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "d MMM"
        return df.string(from: d)
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
