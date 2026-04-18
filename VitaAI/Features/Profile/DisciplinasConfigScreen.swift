import SwiftUI

// MARK: - DisciplinasConfigScreen
// Lists all active subjects with difficulty selector (Fácil/Médio/Difícil).
// Difficulty feeds VitaScore (0-30 difficulty component).
// Pushed from Configurações → Disciplinas.

struct DisciplinasConfigScreen: View {
    var onBack: (() -> Void)?

    @Environment(\.appContainer) private var container
    @Environment(\.appData) private var appData
    @State private var subjects: [SubjectDifficultyItem] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                headerBar
                    .padding(.top, 8)

                if isLoading {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .padding(.top, 80)
                } else if subjects.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
                    Text("Defina a dificuldade de cada disciplina para o VitaScore priorizar seus estudos.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                        .padding(.horizontal, 18)
                        .padding(.top, 16)
                        .padding(.bottom, 12)

                    VitaGlassCard {
                        VStack(spacing: 0) {
                            ForEach(Array(subjects.enumerated()), id: \.element.id) { index, subject in
                                if index > 0 {
                                    Rectangle()
                                        .fill(VitaColors.textWarm.opacity(0.05))
                                        .frame(height: 1)
                                        .padding(.horizontal, 14)
                                }
                                subjectRow(subject)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }

                Spacer().frame(height: 120)
            }
        }
        .task { await loadSubjects() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 10) {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.75))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)

                Text("Disciplinas")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 32))
                .foregroundStyle(VitaColors.textWarm.opacity(0.25))
            Text("Nenhuma disciplina ativa")
                .font(.system(size: 14))
                .foregroundStyle(VitaColors.textWarm.opacity(0.40))
        }
    }

    // MARK: - Subject Row

    private func subjectRow(_ subject: SubjectDifficultyItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(SubjectColors.colorFor(subject: subject.name))
                    .frame(width: 8, height: 8)
                Text(subject.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(DifficultyOption.allCases, id: \.key) { opt in
                    let selected = subject.difficulty == opt.key
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            updateDifficulty(subjectId: subject.id, newValue: selected ? nil : opt.key)
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: opt.icon)
                                .font(.system(size: 11))
                            Text(opt.label)
                                .font(.system(size: 12, weight: selected ? .bold : .semibold))
                        }
                        .foregroundStyle(selected ? opt.selectedColor : VitaColors.textWarm.opacity(0.45))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selected ? opt.selectedColor.opacity(0.12) : Color.white.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selected ? opt.selectedColor.opacity(0.35) : VitaColors.textWarm.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    // MARK: - Data

    private func loadSubjects() async {
        isLoading = true
        // SOT: AppDataManager.enrolledDisciplines (populated by the shared
        // refresh cycle with status=in_progress). Screens must never issue
        // their own /api/subjects call. If the store is empty (cold launch
        // straight into this screen), trigger a load so the cache hydrates
        // for every other screen too instead of doing a private fetch.
        if appData.enrolledDisciplines.isEmpty {
            await appData.loadIfNeeded()
        }
        if !appData.enrolledDisciplines.isEmpty {
            subjects = appData.enrolledDisciplines.map {
                SubjectDifficultyItem(id: $0.id, name: $0.name, difficulty: $0.difficulty)
            }
            isLoading = false
            return
        }
        // Last-resort fallback: hit the API with the canonical status the
        // backend actually stores ("in_progress", NOT "cursando" — the old
        // call was always returning empty).
        do {
            let resp = try await container.api.getSubjects(status: "in_progress")
            subjects = resp.subjects.map {
                SubjectDifficultyItem(id: $0.id, name: $0.name, difficulty: $0.difficulty)
            }
        } catch {
            subjects = []
        }
        isLoading = false
    }

    private func updateDifficulty(subjectId: String, newValue: String?) {
        guard let idx = subjects.firstIndex(where: { $0.id == subjectId }) else { return }
        let previous = subjects[idx].difficulty
        subjects[idx].difficulty = newValue
        Task {
            do {
                _ = try await container.api.updateSubjectDifficulty(id: subjectId, difficulty: newValue)
            } catch {
                subjects[idx].difficulty = previous
            }
        }
    }
}

// MARK: - Models

private struct SubjectDifficultyItem: Identifiable {
    var id: String
    let name: String
    var difficulty: String?
}

private enum DifficultyOption: CaseIterable {
    case facil, medio, dificil

    var key: String {
        switch self {
        case .facil: "facil"
        case .medio: "medio"
        case .dificil: "dificil"
        }
    }

    var label: String {
        switch self {
        case .facil: "Facil"
        case .medio: "Medio"
        case .dificil: "Dificil"
        }
    }

    var icon: String {
        switch self {
        case .facil: "tortoise"
        case .medio: "gauge.with.dots.needle.33percent"
        case .dificil: "flame"
        }
    }

    var selectedColor: Color {
        switch self {
        case .facil: VitaColors.dataGreen
        case .medio: VitaColors.accent
        case .dificil: VitaColors.dataRed
        }
    }
}
