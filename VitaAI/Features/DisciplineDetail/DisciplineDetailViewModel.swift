import Foundation
import SwiftUI

// MARK: - DisciplineDetailViewModel
// All data from API. Parallel loading via async let.
// Uses /grades/current as primary source for grades/attendance.

@MainActor
@Observable
final class DisciplineDetailViewModel {
    private let api: VitaAPI
    let disciplineId: String
    let disciplineName: String

    // MARK: - State

    private(set) var isLoading = true
    private(set) var error: String?

    private(set) var subjectProgress: SubjectProgress?
    private(set) var gradeSubject: GradeSubject?
    private(set) var exams: [ExamEntry] = []
    private(set) var flashcardDecks: [FlashcardDeckEntry] = []
    private(set) var documents: [VitaDocument] = []
    private(set) var classSchedule: [AgendaClassBlock] = []
    private(set) var trabalhos: TrabalhosResponse?
    /// VitaScore computed server-side in /api/dashboard (grade + urgency + difficulty).
    /// Single source of truth — NEVER recompute client-side.
    private(set) var vitaScore: Int = 0
    /// Student self-assessed difficulty: "facil", "medio", "dificil", or nil
    private(set) var difficulty: String?

    // MARK: - Init

    init(api: VitaAPI, disciplineId: String, disciplineName: String) {
        self.api = api
        self.disciplineId = disciplineId
        self.disciplineName = disciplineName
    }

    // MARK: - Computed: identity

    var subjectColor: Color {
        SubjectColors.colorFor(subject: disciplineName)
    }

    // MARK: - Computed: exams

    var subjectExams: [ExamEntry] {
        exams
            .filter { matchesDiscipline($0.subjectName) || matchesDiscipline($0.title) }
            .sorted { $0.date < $1.date }
    }

    var nextExam: ExamEntry? {
        subjectExams.first { $0.daysUntil >= 0 }
    }

    var pastExams: [ExamEntry] {
        subjectExams.filter { $0.daysUntil < 0 || $0.result != nil }
    }

    // MARK: - Computed: grades (from /grades/current — canonical source)
    // Weights come from API (backend returns weight1/weight2/weight3 from portal config)

    var grade1: Double? { gradeSubject?.grade1 }
    var grade2: Double? { gradeSubject?.grade2 }
    var grade3: Double? { gradeSubject?.grade3 }
    var finalGrade: Double? { gradeSubject?.finalGrade }
    var attendance: Double? { gradeSubject?.attendance }
    var absences: Double? { gradeSubject?.absences }
    var workload: Double? { gradeSubject?.workload }
    var subjectStatus: String? { gradeSubject?.status }

    var weight1: Double { gradeSubject?.weight1 ?? 2 }
    var weight2: Double { gradeSubject?.weight2 ?? 3 }
    var weight3: Double { gradeSubject?.weight3 ?? 5 }

    /// Normalizes a raw grade to 0-10 scale given its weight
    static func normalized(_ value: Double, weight: Double) -> Double {
        guard weight > 0 else { return 0 }
        return (value / weight) * 10.0
    }

    /// Grade slots with their weights for display: (value, weight, normalized)
    var gradeSlots: [(label: String, value: Double?, weight: Double)] {
        return [
            ("P1", grade1, weight1),
            ("P2", grade2, weight2),
            ("P3", grade3, weight3),
        ]
    }

    var hasAnyGrade: Bool {
        grade1 != nil || grade2 != nil || grade3 != nil || finalGrade != nil || attendance != nil
    }

    var hasGradeRisk: Bool {
        for slot in gradeSlots {
            guard let v = slot.value else { continue }
            if Self.normalized(v, weight: slot.weight) < 5.0 { return true }
        }
        return false
    }

    /// Weighted average on 0-10 scale
    var currentAverage: Double? {
        var totalScore = 0.0
        var totalWeight = 0.0
        for slot in gradeSlots {
            guard let v = slot.value else { continue }
            totalScore += v
            totalWeight += slot.weight
        }
        guard totalWeight > 0 else { return nil }
        return (totalScore / totalWeight) * 10.0
    }

    // MARK: - Computed: flashcards

    var subjectDecks: [FlashcardDeckEntry] {
        flashcardDecks.filter { deck in
            if let sid = deck.subjectId, sid == disciplineId { return true }
            return matchesDiscipline(deck.title)
        }
    }

    var flashcardsDue: Int {
        subjectDecks.reduce(0) { total, deck in
            let due = deck.cards.filter { card in
                guard let next = card.nextReviewAt,
                      let date = ISO8601DateFormatter().date(from: next) else {
                    return card.reps == 0
                }
                return date <= Date()
            }.count
            return total + due
        }
    }

    var flashcardsTotal: Int {
        subjectDecks.reduce(0) { $0 + $1.cards.count }
    }

    // MARK: - Computed: trabalhos

    var subjectTrabalhos: [TrabalhoItem] {
        guard let t = trabalhos else { return [] }
        let all = t.pending + t.overdue + t.completed
        return all.filter { matchesDiscipline($0.subjectName) }
    }

    var trabalhosPending: [TrabalhoItem] {
        subjectTrabalhos.filter { !$0.submitted && $0.status != "graded" }
    }

    var trabalhosCompleted: [TrabalhoItem] {
        subjectTrabalhos.filter { $0.submitted || $0.status == "graded" }
    }

    // MARK: - Computed: documents

    var subjectDocuments: [VitaDocument] {
        guard !documents.isEmpty else { return [] }
        return documents.filter { doc in
            if let sid = doc.subjectId, sid == disciplineId { return true }
            return matchesDiscipline(doc.title)
        }
    }

    // MARK: - Computed: schedule & professor

    var subjectSchedule: [AgendaClassBlock] {
        classSchedule
            .filter { matchesDiscipline($0.subjectName) }
            .sorted { $0.dayOfWeek < $1.dayOfWeek }
    }

    var professorName: String? {
        if let p = gradeSubject?.professor, !p.isEmpty { return p }
        return subjectSchedule.compactMap(\.professor).first { !$0.isEmpty }
    }

    var room: String? {
        subjectSchedule.compactMap(\.room).first { !$0.isEmpty }
    }

    // MARK: - Load (each call independent — one failure doesn't block others)

    func load() async {
        isLoading = true
        error = nil

        async let progressTask: ProgressResponse? = try? api.getProgress()
        async let gradesTask: GradesCurrentResponse? = try? api.getGradesCurrent()
        async let examsTask: ExamsResponse? = try? api.getExams()
        async let decksTask: [FlashcardDeckEntry]? = try? api.getFlashcardDecks()
        // Filter by subjectId server-side — was nil (all user docs, 100s of MB of PDFs).
        // This endpoint's payload was the #1 DisciplineDetail TTFD bottleneck.
        async let docsTask: [VitaDocument]? = try? api.getDocuments(subjectId: disciplineId)
        async let agendaTask: AgendaResponse? = try? api.getAgenda()
        async let trabalhosTask: TrabalhosResponse? = try? api.getTrabalhos()
        async let dashboardTask: Dashboard? = try? api.getDashboard()

        let (progressResponse, gradesResponse, examsResponse, decks, docs, agenda, trabalhosResp, dash) = await (
            progressTask,
            gradesTask,
            examsTask,
            decksTask,
            docsTask,
            agendaTask,
            trabalhosTask,
            dashboardTask
        )

        // VitaScore + difficulty — read from server (canonical). Match by subject name.
        if let dash, let matched = dash.subjects?.first(where: { matchesDiscipline($0.name) }) {
            vitaScore = Int(matched.vitaScore ?? 0)
            difficulty = matched.difficulty
        }

        if let progressResponse {
            subjectProgress = progressResponse.subjects.first {
                matchesDiscipline($0.name) || matchesDiscipline($0.subjectId)
            }
        }

        if let gradesResponse {
            gradeSubject = gradesResponse.current.first { $0.subjectId == disciplineId }
                ?? gradesResponse.completed.first { $0.subjectId == disciplineId }
                ?? gradesResponse.current.first { matchesDiscipline($0.subjectName) }
                ?? gradesResponse.completed.first { matchesDiscipline($0.subjectName) }
        }

        if let examsResponse {
            exams = examsResponse.exams
        }

        flashcardDecks = decks ?? []
        documents = docs ?? []
        classSchedule = agenda?.schedule ?? []
        trabalhos = trabalhosResp

        isLoading = false
    }

    // MARK: - Actions

    func setDifficulty(_ value: String?) {
        let previous = difficulty
        difficulty = value
        Task {
            do {
                _ = try await api.updateSubjectDifficulty(id: disciplineId, difficulty: value)
                // Reload to get updated VitaScore
                await load()
            } catch {
                difficulty = previous
            }
        }
    }

    // MARK: - Helper

    private func matchesDiscipline(_ candidate: String?) -> Bool {
        guard let candidate, !candidate.isEmpty else { return false }
        let a = disciplineName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let b = candidate.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return a == b || b.contains(a) || a.contains(b)
    }
}
