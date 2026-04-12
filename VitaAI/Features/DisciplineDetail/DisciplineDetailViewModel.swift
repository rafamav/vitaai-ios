import Foundation
import SwiftUI

// MARK: - DisciplineDetailViewModel
// Real API data: progress, exams, flashcard decks, trabalhos.
// All API calls fire in parallel via async let.

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
    private(set) var exams: [ExamEntry] = []
    private(set) var flashcardDecks: [FlashcardDeckEntry] = []
    private(set) var trabalhos: TrabalhosResponse?

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
            .filter { matchesDiscipline($0.subjectName) }
            .sorted { a, b in
                // Sort by date ascending; treat empty date as far future
                a.date < b.date
            }
    }

    var nextExam: ExamEntry? {
        subjectExams.first { $0.daysUntil >= 0 }
    }

    // MARK: - Computed: grades from scored exams

    var gradeSlots: (p1: Double?, p2: Double?, p3: Double?, sf: Double?) {
        let scored = subjectExams.filter { $0.result != nil }
        func slot(_ label: String) -> Double? {
            scored.first { $0.examType?.lowercased() == label || $0.title.lowercased().contains(label) }?.result
        }
        let p1 = slot("p1") ?? slot("prova 1") ?? slot("av1")
        let p2 = slot("p2") ?? slot("prova 2") ?? slot("av2")
        let p3 = slot("p3") ?? slot("prova 3") ?? slot("av3")
        let sf = slot("sf") ?? slot("sub") ?? slot("substitutiva")
        return (p1, p2, p3, sf)
    }

    var hasGradeRisk: Bool {
        let g = gradeSlots
        let vals = [g.p1, g.p2, g.p3].compactMap { $0 }
        return vals.contains { $0 < 5.0 }
    }

    // MARK: - Computed: attendance / professor / semester

    var attendance: Double? {
        // SubjectProgress does not expose attendance — return nil until API provides it
        nil
    }

    var professorName: String? {
        // SubjectProgress has no professorName field; will be nil until API adds it
        nil
    }

    var semester: String? {
        nil
    }

    // MARK: - Computed: flashcards

    var subjectDecks: [FlashcardDeckEntry] {
        flashcardDecks.filter { deck in
            // Match by subjectId, or fall back to title similarity
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

    var pendingAssignments: [TrabalhoItem] {
        guard let t = trabalhos else { return [] }
        return (t.pending + t.overdue).filter { matchesDiscipline($0.subjectName) }
    }

    // MARK: - Computed: VitaScore (0-100)
    // 45% difficulty (1 - accuracy), 35% gradeRisk, 20% urgency (next exam proximity)

    var vitaScore: Int {
        let accuracy = subjectProgress?.accuracy ?? 0.5
        let diffScore = (1.0 - accuracy) * 45.0

        let grades = gradeSlots
        let gradeVals = [grades.p1, grades.p2, grades.p3].compactMap { $0 }
        let gradeRisk: Double
        if gradeVals.isEmpty {
            gradeRisk = 0
        } else {
            let below = gradeVals.filter { $0 < 5.0 }.count
            gradeRisk = Double(below) / Double(gradeVals.count) * 35.0
        }

        let urgency: Double
        if let days = nextExam?.daysUntil {
            if days <= 3 { urgency = 20.0 }
            else if days <= 7 { urgency = 14.0 }
            else if days <= 14 { urgency = 7.0 }
            else { urgency = 2.0 }
        } else {
            urgency = 0
        }

        return min(100, Int(diffScore + gradeRisk + urgency))
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        error = nil

        async let progressTask = api.getProgress()
        async let examsTask = api.getExams()
        async let decksTask = api.getFlashcardDecks()
        async let trabalhosTask = api.getTrabalhos()

        do {
            let (progressResponse, examsResponse, decks, trabalhosResponse) = try await (
                progressTask,
                examsTask,
                decksTask,
                trabalhosTask
            )
            subjectProgress = progressResponse.subjects.first { matchesDiscipline($0.name) }
            exams = examsResponse.exams
            flashcardDecks = decks
            trabalhos = trabalhosResponse
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Helper

    private func matchesDiscipline(_ candidate: String?) -> Bool {
        guard let candidate else { return false }
        let a = disciplineName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let b = candidate.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return a == b || b.contains(a) || a.contains(b)
    }
}
