import SwiftUI
import Sentry

// MARK: - FaculdadeProfessoresScreen
//
// List of professors derived from grades/schedule data.
// Tap any row → ProfessorProfileSheet for that subject.

struct ProfessorEntry: Identifiable {
    let id: String          // professor name used as stable ID
    let name: String
    let subjects: [String]  // subject names they teach
    var subjectId: String?  // first subject ID for profile fetch
}

struct FaculdadeProfessoresScreen: View {
    @Environment(\.appData) private var appData
    @Environment(Router.self) private var router

    @State private var selectedSubjectId: String?
    @State private var selectedProfessorName: String?
    @State private var showProfessorSheet = false

    // Tokens
    private var goldPrimary: Color { VitaColors.accentHover }
    private var goldMuted: Color { VitaColors.accentLight }
    private var textPrimary: Color { VitaColors.textPrimary }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }
    private var cardBg: Color { VitaColors.surfaceCard.opacity(0.55) }
    private var glassBorder: Color { VitaColors.textWarm.opacity(0.06) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                // Back button row
                HStack {
                    Button {
                        router.goBack()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Faculdade")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundStyle(goldMuted.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Professores")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(textPrimary)
                        Text("Perfis dos professores deste semestre")
                            .font(.system(size: 12))
                            .foregroundStyle(textDim)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                // Professor list
                if professors.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    VitaGlassCard {
                        VStack(spacing: 0) {
                            ForEach(Array(professors.enumerated()), id: \.element.id) { idx, entry in
                                if idx > 0 {
                                    Rectangle()
                                        .fill(glassBorder)
                                        .frame(height: 0.5)
                                        .padding(.horizontal, 16)
                                }
                                professorRow(entry)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.horizontal, 16)
                }

                Spacer().frame(height: 100)
            }
        }
        .refreshable { await appData.forceRefresh() }
        .onAppear { SentrySDK.reportFullyDisplayed() }
        .sheet(isPresented: $showProfessorSheet) {
            if let subjectId = selectedSubjectId {
                ProfessorProfileSheet(subjectId: subjectId)
            }
        }
        .trackScreen("FaculdadeProfessores")
    }

    // MARK: - Professor Row

    private func professorRow(_ entry: ProfessorEntry) -> some View {
        Button {
            if let subjectId = entry.subjectId {
                selectedSubjectId = subjectId
                showProfessorSheet = true
            }
        } label: {
            HStack(spacing: 12) {
                // Avatar circle
                ZStack {
                    Circle()
                        .fill(goldPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Text(initials(entry.name))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(goldPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)

                    Text(entry.subjects.prefix(2).joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundStyle(textDim)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                if entry.subjectId != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(textDim)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .disabled(entry.subjectId == nil)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundStyle(goldPrimary.opacity(0.35))
            Text("Nenhum professor encontrado")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(textPrimary)
            Text("Conecte seu portal para ver os professores das suas disciplinas")
                .font(.system(size: 12))
                .foregroundStyle(textDim)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - Computed data

    /// Derive professor list from grades + schedule.
    private var professors: [ProfessorEntry] {
        var nameToSubjects: [String: [String]] = [:]
        var nameToSubjectId: [String: String] = [:]

        // From schedule (has professor field directly)
        for block in appData.classSchedule {
            guard let prof = block.professor, !prof.isEmpty else { continue }
            let subName = block.subjectName
            nameToSubjects[prof, default: []].append(subName)
            // Use subject name as subjectId (matches DisciplineDetail pattern)
            if nameToSubjectId[prof] == nil {
                nameToSubjectId[prof] = subName
            }
        }

        // From grades — infer professor name from subject when not in schedule
        for subject in (appData.gradesResponse?.current ?? []) {
            // If subject already covered via schedule, skip
            if nameToSubjects.values.flatMap({ $0 }).contains(subject.subjectName) { continue }
            // Add a "subject-only" entry (no professor name, use subject as placeholder)
        }

        // Deduplicate subjects per professor
        var entries: [ProfessorEntry] = []
        for (name, subjects) in nameToSubjects {
            let unique = Array(Set(subjects)).sorted()
            entries.append(ProfessorEntry(
                id: name,
                name: name,
                subjects: unique,
                subjectId: nameToSubjectId[name]
            ))
        }

        return entries.sorted { $0.name < $1.name }
    }

    private func initials(_ name: String) -> String {
        let parts = name.components(separatedBy: " ").filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String((parts.first?.prefix(1) ?? "") + (parts.last?.prefix(1) ?? ""))
                .uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}
