import Foundation
import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    private let api: VitaAPI

    // Data from unified /api/mockup/dashboard endpoint
    var greeting: String = ""
    var subtitle: String = ""
    var upcomingExams: [UpcomingExam] = []
    var subjects: [DashboardSubject] = []
    var agenda: [DashboardAgendaItem] = []
    var flashcardsDueTotal: Int = 0
    var xpLevel: Int = 1
    var isLoading = true
    var error: String?

    init(api: VitaAPI) {
        self.api = api
    }

    func loadDashboard() async {
        isLoading = true
        error = nil

        // Load dashboard (greeting, exams, subjects, agenda)
        do {
            let resp = try await api.getDashboard()
            apply(dashboard: resp)
        } catch {
            // Silently continue — progress may still work
        }

        // Load progress data (subjects, exams, flashcards)
        do {
            let progress = try await api.getProgress()
            apply(progress: progress, preserveExistingSubjects: true)
        } catch {
            // Silently continue — dashboard data may be enough
        }

        if subjects.isEmpty && upcomingExams.isEmpty && greeting.isEmpty {
            self.error = "Nao foi possivel carregar o dashboard."
        }

        isLoading = false
    }

    private func apply(dashboard: DashboardResponse) {
        greeting = dashboard.greeting
        subtitle = dashboard.subtitle
        if dashboard.flashcardsDueTotal > 0 { flashcardsDueTotal = dashboard.flashcardsDueTotal }
        if let xp = dashboard.xp { xpLevel = xp.level }
        if !dashboard.subjects.isEmpty { subjects = dashboard.subjects }
        if !dashboard.agenda.isEmpty { agenda = dashboard.agenda }
        // Map hero cards (new API) to upcoming exams
        let examHeroes = dashboard.hero.filter { $0.type == "exam" }
        if !examHeroes.isEmpty {
            upcomingExams = examHeroes.map { card in
                let daysText = card.pills.first(where: { $0.icon == "calendar" })?.text
                    .replacingOccurrences(of: "Em ", with: "")
                    .replacingOccurrences(of: " dias", with: "")
                    .trimmingCharacters(in: .whitespaces)
                let days = daysText.flatMap { Int($0) } ?? 0
                return UpcomingExam(
                    id: card.id,
                    subject: card.subtitle ?? "",
                    type: card.title,
                    date: Date().addingTimeInterval(TimeInterval(days * 86400)),
                    daysUntil: days,
                    conceptCards: 0,
                    practiceCards: 0
                )
            }
        }
        // Legacy exams fallback
        if let exams = dashboard.exams, !exams.isEmpty, upcomingExams.isEmpty {
            upcomingExams = exams.map { exam in
                UpcomingExam(
                    id: exam.id,
                    subject: exam.subject,
                    type: exam.title,
                    date: Date().addingTimeInterval(TimeInterval(exam.daysUntil * 86400)),
                    daysUntil: exam.daysUntil,
                    conceptCards: exam.conceptCards,
                    practiceCards: exam.practiceCards
                )
            }
        }
    }

    private func apply(progress: ProgressResponse, preserveExistingSubjects: Bool) {
        if !progress.subjects.isEmpty && (!preserveExistingSubjects || subjects.isEmpty) {
            subjects = progress.subjects.map { sp in
                DashboardSubject(name: sp.subjectId)
            }
        }
        if progress.flashcardsDue > 0 {
            flashcardsDueTotal = progress.flashcardsDue
        }
        if !progress.upcomingExams.isEmpty && upcomingExams.isEmpty {
            upcomingExams = progress.upcomingExams.map { exam in
                UpcomingExam(
                    id: exam.id,
                    subject: exam.subjectName ?? exam.subjectId ?? "",
                    type: exam.title,
                    date: Date().addingTimeInterval(TimeInterval(exam.daysUntil * 86400)),
                    daysUntil: exam.daysUntil,
                    conceptCards: exam.conceptCards ?? 0,
                    practiceCards: exam.practiceCards ?? 0
                )
            }
        }
    }
}
