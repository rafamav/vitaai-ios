import SwiftUI
import Sentry

// MARK: - FaculdadeMateriasScreen
//
// Full-screen subpage: Faculdade → Matérias.
// Shows the rich grades table migrated from the legacy AgendaScreen:
//   - CR badge with color by performance
//   - Cursando | Aprovadas filter pills
//   - Notas | Freq column toggle
//   - Per-subject rows with G1/G2/Final or Freq/Faltas/CH

struct FaculdadeMateriasScreen: View {
    let onBack: () -> Void
    var onNavigateToDiscipline: ((String, String) -> Void)?
    @Environment(\.appData) private var appData
    @State private var gradesFilter = 0 // 0 = Cursando, 1 = Aprovadas
    @State private var gradesTab = 0    // 0 = Notas, 1 = Freq

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if let grades = appData.gradesResponse,
                   (!grades.current.isEmpty || !grades.completed.isEmpty) {
                    gradesCard(grades)
                } else {
                    emptyState
                }
                Spacer().frame(height: 40)
            }
            .padding(.top, 8)
        }
        .refreshable { await appData.forceRefresh() }
        .onAppear { SentrySDK.reportFullyDisplayed() }
        .trackScreen("FaculdadeMateria")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "graduationcap")
                .font(.system(size: 44))
                .foregroundStyle(VitaColors.accentHover.opacity(0.40))
            Text("Sem matérias sincronizadas")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
            Text("Conecte seu portal acadêmico para ver notas, frequência e disciplinas.")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Grades card

    private func gradesCard(_ grades: GradesCurrentResponse) -> some View {
        let cr = computeCR(grades.completed)
        let subjects = gradesFilter == 0 ? grades.current : grades.completed

        return VitaGlassCard {
            VStack(spacing: 14) {
                // Title + CR badge
                HStack {
                    Text("Matérias")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)

                    if let cr {
                        Text("CR \(String(format: "%.2f", cr))")
                            .font(.system(size: 11, weight: .bold))
                            .monospacedDigit()
                            .foregroundStyle(crColor(cr))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(crColor(cr).opacity(0.10))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(crColor(cr).opacity(0.20), lineWidth: 1))
                    }
                    Spacer()
                }

                // Filter pills + column toggle
                HStack(spacing: 6) {
                    filterPill("Cursando", count: grades.current.count, index: 0)
                    filterPill("Aprovadas", count: grades.completed.count, index: 1)
                    Spacer()
                    HStack(spacing: 0) {
                        tabButton("Notas", index: 0)
                        tabButton("Freq", index: 1)
                    }
                    .background(VitaColors.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
                }

                if subjects.isEmpty {
                    Text(gradesFilter == 0 ? "Sem matérias cursando" : "Sem matérias aprovadas")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                        .padding(.vertical, 8)
                } else {
                    // Table header
                    if gradesTab == 0 {
                        if gradesFilter == 0 {
                            tableHeader([("Disciplina", .leading, 1.0), ("G1", .center, 0.2), ("G2", .center, 0.2), ("Final", .center, 0.25)])
                        } else {
                            tableHeader([("Disciplina", .leading, 1.0), ("Final", .center, 0.25)])
                        }
                    } else {
                        tableHeader([("Disciplina", .leading, 1.0), ("Freq", .center, 0.22), ("Faltas", .center, 0.22), ("CH", .center, 0.2)])
                    }

                    ForEach(subjects) { subject in
                        Button {
                            onNavigateToDiscipline?(subject.id, subject.subjectName)
                        } label: {
                            if gradesTab == 0 {
                                if gradesFilter == 0 {
                                    notasRow(subject)
                                } else {
                                    approvedRow(subject)
                                }
                            } else {
                                freqRow(subject)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Row builders

    private func filterPill(_ title: String, count: Int, index: Int) -> some View {
        let isActive = gradesFilter == index
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { gradesFilter = index }
        } label: {
            HStack(spacing: 4) {
                Text(title).font(.system(size: 11, weight: .medium))
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
            }
            .foregroundStyle(isActive ? VitaColors.surface : VitaColors.textWarm.opacity(0.60))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isActive ? VitaColors.accent : VitaColors.surfaceElevated)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(isActive ? VitaColors.accent.opacity(0.5) : VitaColors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func tabButton(_ title: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { gradesTab = index }
        } label: {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(gradesTab == index ? VitaColors.surface : VitaColors.textWarm.opacity(0.60))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(gradesTab == index ? VitaColors.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func tableHeader(_ columns: [(String, HorizontalAlignment, CGFloat)]) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, col in
                Text(col.0)
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(VitaColors.textWarm.opacity(0.65))
                    .frame(maxWidth: col.2 == 1.0 ? .infinity : nil, alignment: col.1 == .leading ? .leading : .center)
                    .frame(width: col.2 < 1.0 ? 48 : nil)
            }
        }
        .padding(.horizontal, 4)

        Rectangle()
            .fill(VitaColors.accent.opacity(0.15))
            .frame(height: 0.5)
    }

    private func notasRow(_ s: GradeSubject) -> some View {
        HStack(spacing: 4) {
            Text(shortName(s.subjectName))
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            gradeCell(s.grade1)
            gradeCell(s.grade2)
            gradeCell(s.finalGrade)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
    }

    private func approvedRow(_ s: GradeSubject) -> some View {
        HStack(spacing: 4) {
            Text(shortName(s.subjectName))
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            gradeCell(s.finalGrade)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
    }

    private func freqRow(_ s: GradeSubject) -> some View {
        HStack(spacing: 4) {
            Text(shortName(s.subjectName))
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(s.attendance.map { String(format: "%.0f%%", $0) } ?? "—")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(attendanceColor(s.attendance))
                .frame(width: 48, alignment: .center)

            Text(s.absences.map { String(format: "%.0f", $0) } ?? "—")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(VitaColors.textWarm.opacity(0.60))
                .frame(width: 48, alignment: .center)

            Text(s.workload.map { String(format: "%.0f", $0) } ?? "—")
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(VitaColors.textWarm.opacity(0.60))
                .frame(width: 48, alignment: .center)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
    }

    private func gradeCell(_ val: Double?) -> some View {
        Text(val.map { String(format: "%.1f", $0) } ?? "—")
            .font(.system(size: 12, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(val != nil ? VitaColors.textPrimary : VitaColors.textWarm.opacity(0.40))
            .frame(width: 48, alignment: .center)
    }

    // MARK: - Helpers

    private func shortName(_ name: String) -> String {
        let subs: [(String, String)] = [
            ("MEDICINA DE FAMÍLIA E COMUNIDADE", "MFC"),
            ("FARMACOLOGIA MÉDICA", "Farmacologia"),
            ("PATOLOGIA MÉDICA", "Patologia"),
            ("MEDICINA LEGAL, DEONTOLOGIA E ÉTICA MÉDICA", "Med Legal"),
            ("PRÁTICAS INTERPROFISSIONAIS DE EDUCAÇÃO EM SAÚDE", "PIES"),
            ("SOCIEDADE E CONTEMPORANEIDADE", "Soc. Contemp."),
        ]
        for (full, short) in subs {
            if name.uppercased().hasPrefix(full) { return short }
        }
        if name.count > 22 {
            return String(name.prefix(20)) + "…"
        }
        return name.capitalized(with: Locale(identifier: "pt_BR"))
    }

    private func computeCR(_ completed: [GradeSubject]) -> Double? {
        let grades = completed.compactMap(\.finalGrade)
        guard !grades.isEmpty else { return nil }
        let withWorkload = completed.filter { $0.finalGrade != nil && $0.workload != nil && $0.workload! > 0 }
        if withWorkload.count > grades.count / 2 {
            let totalWeight = withWorkload.reduce(0.0) { $0 + ($1.workload ?? 0) }
            let weightedSum = withWorkload.reduce(0.0) { $0 + ($1.finalGrade ?? 0) * ($1.workload ?? 0) }
            return totalWeight > 0 ? weightedSum / totalWeight : nil
        }
        return grades.reduce(0, +) / Double(grades.count)
    }

    private func crColor(_ cr: Double) -> Color {
        if cr >= 8.0 { return VitaColors.dataGreen }
        if cr >= 6.0 { return VitaColors.accent }
        return VitaColors.dataRed
    }

    private func attendanceColor(_ val: Double?) -> Color {
        guard let v = val else { return VitaColors.textWarm.opacity(0.40) }
        if v >= 90 { return VitaColors.dataGreen }
        if v >= 75 { return VitaColors.accent }
        return VitaColors.dataRed
    }
}
