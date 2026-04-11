import Foundation
import SwiftUI

// MARK: - DisciplineDetailViewModel
// Mirrors mockup: disciplina-detalhe-mobile-v1.html
// Aggregates: exams, flashcard stats, topics, PDFs, videos, vita suggestion

@MainActor
@Observable
final class DisciplineDetailViewModel {
    private let api: VitaAPI
    let disciplineId: String
    let disciplineName: String

    // MARK: - State

    private(set) var isLoading = true
    private(set) var error: String?

    // Quick counts
    private(set) var totalCards: Int = 0
    private(set) var totalQuestions: Int = 0
    private(set) var cardsDue: Int = 0
    private(set) var accuracy: Double = 0

    // Exams
    private(set) var exams: [ExamEntry] = []
    private(set) var nearestExamDays: Int? = nil
    private(set) var examTopics: [String] = []

    // Flashcard decks
    private(set) var flashcardDecks: [FlashcardDeckEntry] = []

    // Topic rows (Conteúdo da prova)
    private(set) var topicRows: [TopicRow] = []

    // PDFs (Matériais)
    private(set) var pdfs: [PDFEntry] = []

    // Videos
    private(set) var videos: [VideoEntry] = []

    // Vita score (0-100)
    private(set) var vitaScore: Int = 50

    // MARK: - Init

    init(api: VitaAPI, disciplineId: String, disciplineName: String) {
        self.api = api
        self.disciplineId = disciplineId
        self.disciplineName = disciplineName
    }

    // MARK: - Load

    func load() async {
        isLoading = true
        error = nil

        do {
            async let progressTask = api.getProgress()
            async let examsTask   = api.getExams(upcoming: true)
            async let decksTask   = api.getFlashcardDecks(subjectId: disciplineId)

            let (progressResp, examsResp, decks) = try await (progressTask, examsTask, decksTask)

            // Subject progress
            let subject = progressResp.subjects.first { sub in
                sub.subjectId == disciplineId || matchesDiscipline(sub.subjectId, disciplineName)
            }
            if let subject {
                accuracy  = subject.accuracy
                cardsDue  = subject.cardsDue
            }

            // Exams
            exams = examsResp.exams.filter { matchesDiscipline($0.subjectName ?? "", disciplineName) }
            nearestExamDays = exams.first?.daysUntil

            // Flashcards
            flashcardDecks = decks
            totalCards     = decks.reduce(0) { $0 + $1.cards.count }

            // VitaScore v1: difficulty * 0.45 + gradeRisk * 0.35 + urgency * 0.20
            // Measures risk (0 = safe, 100 = danger)
            // difficulty is set on academic_subjects and comes via /api/dashboard
            // DisciplineDetail doesn't have it locally, so use neutral fallback
            let diffScore: Double = 50

            let urgencyScore: Double = {
                guard let days = nearestExamDays else { return 30 }
                if days <= 0 { return 100 }
                if days >= 30 { return 0 }
                return Double(Int((1.0 - Double(days) / 30.0) * 100))
            }()

            // gradeRisk from exam scores — same as backend
            let gradeRisk: Double = 60 // default when no exams graded yet
            // Note: actual gradeRisk computed from exam scores is done server-side
            // in /api/dashboard. This is a local fallback for DisciplineDetail.

            vitaScore = max(0, min(100, Int(diffScore * 0.45 + gradeRisk * 0.35 + urgencyScore * 0.20)))

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Computed

    /// Short display name (strip common latin suffixes)
    var shortName: String {
        disciplineName
            .replacingOccurrences(of: "MEDICA",  with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "MEDICO",  with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " III", with: "")
            .replacingOccurrences(of: " II",  with: "")
            .replacingOccurrences(of: " I",   with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Hero image asset name
    var heroImageName: String {
        let k = normalize(disciplineName)
        let mapping: [(keyword: String, asset: String)] = [
            ("farmacologia",  "disc-farmacologia"),
            ("patologia",     "disc-patologia-geral"),
            ("legal",         "disc-medicina-legal"),
            ("ética",         "disc-etica-medica"),
            ("familia",       "disc-mfc"),
            ("comunidade",    "disc-mfc"),
            ("histologia",    "disc-histologia"),
            ("anatomia",      "disc-anatomia"),
            ("cardiologia",   "disc-cardiologia"),
            ("bioquimica",    "disc-bioquimica"),
            ("embriologia",   "disc-embriologia"),
            ("semiologia",    "disc-semiologia"),
            ("microbiologia", "disc-microbiologia"),
            ("fisiologia",    "disc-fisiologia-1"),
        ]
        for (keyword, asset) in mapping {
            if k.contains(keyword) { return asset }
        }
        return "disc-interprofissional"
    }

    /// Hero subtitle (mockup: "Prof. Dr. Marcos Ribeiro · Peso 4 · 60h")
    var heroSubtitle: String {
        // Pull from exam notes or fallback to generic
        if let exam = exams.first, let notes = exam.notes, !notes.isEmpty {
            return notes
        }
        return ""
    }

    /// Period label (mockup: "3o Período")
    var periodLabel: String {
        // In a real app this comes from the curriculum endpoint
        return "3o Período"
    }

    /// Vita suggestion text
    var vitaSuggestion: String {
        if let weakTopic = topicRows.first(where: { ($0.accuracy ?? 100) < 50 }) {
            return "Foque em \(weakTopic.name) — seu acerto está em \(weakTopic.accuracy ?? 0)%. Recomendo 20 questões + revisar flashcards antes da próxima prova."
        } else if cardsDue > 0 {
            return "Você tem \(cardsDue) cards pendentes em \(shortName). Revise antes da prova!"
        } else if let days = nearestExamDays {
            return "Prova de \(shortName) em \(days) dias. Bora revisar!"
        } else {
            return "Continue praticando \(shortName) para manter o conhecimento fresco."
        }
    }

    // MARK: - Helpers

    private func matchesDiscipline(_ a: String, _ b: String) -> Bool {
        let normA = normalize(a)
        let normB = normalize(b)
        if normA == normB || normA.contains(normB) || normB.contains(normA) { return true }
        let ignore = Set(["médica","médico","medicina","saúde","educação","geral","especial","básica","clínica","aplicada","práticas","comunidade"])
        let wordsA = normA.split(separator: " ").map(String.init).filter { $0.count > 4 && !ignore.contains($0) }
        let wordsB = normB.split(separator: " ").map(String.init).filter { $0.count > 4 && !ignore.contains($0) }
        guard !wordsA.isEmpty, !wordsB.isEmpty else { return false }
        return wordsA.contains { wa in wordsB.contains { wb in wa == wb } }
    }

    private func normalize(_ s: String) -> String {
        s.lowercased()
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "pt_BR"))
            .filter { $0.isLetter || $0.isNumber || $0 == " " }
            .split(separator: " ")
            .joined(separator: " ")
    }

}

// MARK: - Domain Models

struct TopicRow: Identifiable {
    let id: String
    let name: String
    let subtitle: String
    let accuracy: Int?
    let statusIcon: String
    let iconColor: Color
    let badgeColor: Color
}

struct PDFEntry: Identifiable {
    let id: String
    let name: String
    let meta: String
}

struct VideoEntry: Identifiable {
    let id: String
    let title: String
    let channel: String
    let duration: String
    let thumbColors: [Color]
    let playIconColor: Color
}
