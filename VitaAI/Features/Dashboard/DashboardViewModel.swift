import Foundation
import SwiftUI

@MainActor
@Observable
final class DashboardViewModel {
    private let api: VitaAPI
    private weak var dataManager: AppDataManager?

    // Data from unified /api/mockup/dashboard endpoint
    var greeting: String = ""
    var subtitle: String = ""
    var upcomingExams: [UpcomingExam] = []
    var subjects: [DashboardSubject] = []
    var agenda: [DashboardAgendaItem] = []
    var flashcardsDueTotal: Int = 0
    var xpLevel: Int = 1
    var streakDays: Int = 0
    var totalStudyHours: Double = 0
    var heroCards: [DashboardHeroCard] = []
    var isLoading = true
    var error: String?

    init(api: VitaAPI, dataManager: AppDataManager? = nil) {
        self.api = api
        self.dataManager = dataManager
    }

    func loadDashboard() async {
        isLoading = true
        error = nil

        // Load dashboard (greeting, exams, subjects, agenda)
        do {
            let resp = try await api.getDashboard()
            NSLog("[Dashboard] loaded hero=\(resp.hero?.count ?? 0) subjects=\(resp.subjects?.count ?? 0)")
            apply(dashboard: resp)
        } catch {
            NSLog("[Dashboard] getDashboard FAILED: \(error)")
        }

        // Load progress data (subjects, exams, flashcards)
        do {
            let progress = try await api.getProgress()
            apply(progress: progress, preserveExistingSubjects: true)
        } catch {
            // Silently continue — dashboard data may be enough
        }

        if subjects.isEmpty && upcomingExams.isEmpty && greeting.isEmpty {
            self.error = "Não foi possível carregar o dashboard."
        }

        isLoading = false
    }

    private func apply(dashboard: DashboardResponse) {
        greeting = dashboard.greeting ?? ""
        subtitle = dashboard.subtitle ?? ""
        if let fc = dashboard.flashcardsDueTotal, fc > 0 { flashcardsDueTotal = fc }
        if let xp = dashboard.xp, let lvl = xp.level { xpLevel = lvl }
        if let subs = dashboard.subjects, !subs.isEmpty {
            subjects = subs.sorted { ($0.vitaScore ?? 0) > ($1.vitaScore ?? 0) }
            dataManager?.dashboardSubjects = subjects
        }
        if let ag = dashboard.agenda, !ag.isEmpty { agenda = ag }
        // Store server-driven hero cards directly (sorted by urgency from backend)
        if let hero = dashboard.hero, !hero.isEmpty {
            heroCards = hero
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
        streakDays = progress.streakDays
        totalStudyHours = progress.totalStudyHours
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
