import SwiftUI
import Sentry

// MARK: - FaculdadeDisciplinasScreen
//
// Full list of user's disciplines with navigation to detail.
// Route: Faculdade → Disciplinas → [tap] → DisciplineDetailScreen

struct FaculdadeDisciplinasScreen: View {
    @Environment(\.appData) private var appData
    @Environment(Router.self) private var router

    // Rename sheet state
    @State private var renameTarget: RenameTarget?

    private var goldPrimary: Color { VitaColors.accentHover }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }

    private struct RenameTarget: Identifiable {
        let id: String      // academic_subjects.id
        let currentName: String
    }

    var body: some View {
        // Read enrolledDisciplines at the top level so SwiftUI subscribes
        // to changes. Without this, `displayText(for:)` reads it inside a
        // sub-helper and @Observable may not propagate the mutation back
        // to this view's render, leaving renamed cards stuck on old name.
        let _ = appData.enrolledDisciplines.count

        return ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                let current = appData.gradesResponse?.current ?? []
                let completed = appData.gradesResponse?.completed ?? []

                if current.isEmpty && completed.isEmpty {
                    emptyState
                } else {
                    if !current.isEmpty {
                        sectionHeader("Cursando", count: current.count)
                        disciplinesList(current)
                    }

                    if !completed.isEmpty {
                        sectionHeader("Aprovadas", count: completed.count)
                            .padding(.top, current.isEmpty ? 0 : 8)
                        disciplinesList(completed)
                    }
                }

                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .refreshable { await appData.forceRefresh() }
        .onAppear { SentrySDK.reportFullyDisplayed() }
        .trackScreen("FaculdadeDisciplinas")
        .sheet(item: $renameTarget) { target in
            RenameSubjectSheet(
                subjectId: target.id,
                currentName: target.currentName,
                initialDisplayName: appData.enrolledDisciplines
                    .first(where: { $0.id == target.id })?.displayName
            )
            .presentationDetents([.height(260)])
            .presentationBackground(.ultraThinMaterial)
            .presentationCornerRadius(28)
        }
    }

    // Resolve the best name for a subject row: user edit > catalog > portal.
    private func displayText(for subject: GradeSubject) -> String {
        guard let sid = subject.subjectId,
              let match = appData.enrolledDisciplines.first(where: { $0.id == sid })
        else { return subject.subjectName }
        return match.preferredName
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "graduationcap")
                .font(.system(size: 44))
                .foregroundStyle(goldPrimary.opacity(0.40))
            Text("Sem disciplinas sincronizadas")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
            Text("Conecte seu portal acadêmico para ver suas disciplinas.")
                .font(.system(size: 12))
                .foregroundStyle(textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.8)
                .foregroundStyle(VitaColors.sectionLabel)
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(textDim)
            Spacer()
        }
    }

    // MARK: - List

    private func disciplinesList(_ subjects: [GradeSubject]) -> some View {
        VStack(spacing: 8) {
            ForEach(subjects) { subject in
                ZStack(alignment: .topTrailing) {
                    Button {
                        router.navigate(to: .disciplineDetail(
                            disciplineId: subject.id,
                            disciplineName: displayText(for: subject)
                        ))
                    } label: {
                        disciplineCard(subject)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if let sid = subject.subjectId {
                            Button {
                                renameTarget = RenameTarget(
                                    id: sid,
                                    currentName: displayText(for: subject)
                                )
                            } label: {
                                Label("Renomear", systemImage: "pencil")
                            }
                        }
                    }

                    // Explicit affordance — long-press isn't discoverable enough, especially
                    // in the Simulator where it needs a held mouse click. Matches Notion /
                    // Linear / Apple Files-style "more actions" dot button.
                    if let sid = subject.subjectId {
                        Menu {
                            Button {
                                renameTarget = RenameTarget(
                                    id: sid,
                                    currentName: displayText(for: subject)
                                )
                            } label: {
                                Label("Renomear", systemImage: "pencil")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                                .frame(width: 32, height: 32)
                                .contentShape(Rectangle())
                        }
                        .offset(x: -4, y: 4)
                        .accessibilityLabel("Mais ações da disciplina")
                    }
                }
            }
        }
    }

    // MARK: - Card

    private func disciplineCard(_ subject: GradeSubject) -> some View {
        let color = SubjectColors.colorFor(subject: subject.subjectName)
        let rendered = displayText(for: subject)
        let shortName = rendered
            .replacingOccurrences(of: "(?i),.*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return HStack(spacing: 12) {
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 2) {
                Text(shortName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textWarm.opacity(0.90))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    if let grade = subject.finalGrade {
                        miniStat("Nota", value: String(format: "%.1f", grade))
                    }
                    if let freq = subject.attendance {
                        miniStat("Freq", value: String(format: "%.0f%%", freq))
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textWarm.opacity(0.20))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(VitaColors.surfaceCard.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.textWarm.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func miniStat(_ label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(textDim)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textWarm.opacity(0.70))
        }
    }
}
