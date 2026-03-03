import Foundation
import SwiftUI

@MainActor
@Observable
final class InsightsViewModel {
    private let api: VitaAPI

    // MARK: - Study progress stats (from /progress)
    var streakDays: Int = 0
    var avgAccuracy: Double = 0
    var totalHours: Double = 0
    var totalCards: Int = 0
    var flashcardsDue: Int = 0
    var todayCompleted: Int = 0
    var todayTotal: Int = 0
    var todayMinutes: Int = 0
    var subjects: [SubjectProgress] = []
    var upcomingExams: [ExamEntry] = []

    // MARK: - Grades data (from /grades + /canvas/courses + /webaluno/grades)
    var studyStats: StudyStats? = nil
    var courseGrades: [CourseGrade] = []
    var webalunoGrades: [WebalunoGrade] = []
    var webalunoSummary: WebalunoGradesSummary? = nil
    var webalunoConnected: Bool = false

    // MARK: - Chart data
    var retentionHistory: [RetentionPoint] = []
    var studyHeatmap: [StudyDay] = []
    var forecastData: [ForecastDay] = []
    var cardDistribution: [CardCategory] = []

    // MARK: - UI state
    var isLoading: Bool = true
    var error: String? = nil

    // MARK: - Computed

    /// Best available average: WebAluno average if present, else avgAccuracy from progress
    var displayAverage: Double {
        webalunoSummary?.averageGrade ?? avgAccuracy
    }

    var isEmptyState: Bool {
        !isLoading && error == nil && studyStats == nil && courseGrades.isEmpty && webalunoGrades.isEmpty
    }

    var isErrorState: Bool {
        !isLoading && error != nil && studyStats == nil
    }

    init(api: VitaAPI) { self.api = api }

    // MARK: - Load

    func load() async {
        // Reset stagger animations by clearing studyStats before loading
        studyStats = nil
        isLoading = true
        error = nil

        // Load mock immediately so skeleton → data feels snappy
        loadMock()

        do {
            // Fire all requests concurrently
            async let progressTask = api.getProgress()
            async let gradesTask: [GradeEntry] = api.getGrades(limit: 100)
            async let coursesTask = api.getCourses()
            async let webalunoTask = tryFetchWebalunoGrades()

            let (progress, grades, coursesResp, webalunoResp) = try await (
                progressTask, gradesTask, coursesTask, webalunoTask
            )

            // Update progress stats
            streakDays = progress.streakDays
            avgAccuracy = progress.avgAccuracy
            totalHours = progress.totalStudyHours
            totalCards = progress.totalCards
            flashcardsDue = progress.flashcardsDue
            todayCompleted = progress.todayCompleted
            todayTotal = progress.todayTotal
            todayMinutes = progress.todayStudyMinutes
            subjects = progress.subjects
            upcomingExams = progress.upcomingExams

            // Build StudyStats for overview card
            studyStats = StudyStats(
                totalHoursThisWeek: progress.totalStudyHours,
                averageGrade: progress.avgAccuracy,
                completedAssignments: progress.todayCompleted,
                pendingAssignments: progress.todayTotal - progress.todayCompleted,
                streak: progress.streakDays
            )

            // Build CourseGrades from Canvas courses + grade entries
            let gradesBySubject = Dictionary(grouping: grades, by: \.subjectId)
            courseGrades = coursesResp.courses.map { course in
                let subjectGrades = gradesBySubject[course.id] ?? []
                let avgGrade: Double
                if subjectGrades.isEmpty {
                    avgGrade = 0.0
                } else {
                    avgGrade = subjectGrades.reduce(0.0) { $0 + $1.value } / Double(subjectGrades.count)
                }
                return CourseGrade(
                    id: course.id,
                    courseName: course.name,
                    grade: avgGrade,
                    assignments: course.assignmentsCount,
                    completed: subjectGrades.count
                )
            }

            // WebAluno grades
            webalunoGrades = webalunoResp?.grades ?? []
            webalunoSummary = webalunoResp?.summary
            webalunoConnected = webalunoResp != nil

            // Rebuild chart data from real API values
            retentionHistory = buildRetentionCurve(accuracy: avgAccuracy)
            studyHeatmap = buildHeatmap(streak: streakDays, totalHours: totalHours)
            forecastData = buildForecast(due: flashcardsDue)
            cardDistribution = buildDistribution(total: totalCards, due: flashcardsDue)

        } catch {
            self.error = error.localizedDescription
            // Keep mock data so screen isn't blank if we had it
        }

        isLoading = false
    }

    /// Fetches WebAluno grades, returning nil on error (WebAluno is optional / may not be connected).
    private func tryFetchWebalunoGrades() async -> WebalunoGradesResponse? {
        do { return try await api.getWebalunoGrades() } catch { return nil }
    }

    // MARK: - Mock data (shown during initial load)

    private func loadMock() {
        streakDays = 7
        avgAccuracy = 72.0
        totalHours = 48.5
        totalCards = 234
        flashcardsDue = 12
        todayCompleted = 3
        todayTotal = 5
        todayMinutes = 95
        subjects = [
            SubjectProgress(subjectId: "cm-cardio", accuracy: 78.0, hoursSpent: 12.5, cardsDue: 3),
            SubjectProgress(subjectId: "cm-pneumo", accuracy: 65.0, hoursSpent: 8.0, cardsDue: 5),
            SubjectProgress(subjectId: "cm-gastro", accuracy: 82.0, hoursSpent: 10.0, cardsDue: 1),
            SubjectProgress(subjectId: "cir-geral", accuracy: 55.0, hoursSpent: 6.0, cardsDue: 8),
            SubjectProgress(subjectId: "ped-geral", accuracy: 70.0, hoursSpent: 5.0, cardsDue: 2),
        ]
        upcomingExams = [
            ExamEntry(id: "e1", subjectName: "Cardiologia", examType: "Prova", date: "2025-02-15", daysUntil: 12),
            ExamEntry(id: "e2", subjectName: "Internato", examType: "OSCE", date: "2025-02-28", daysUntil: 25),
        ]
        // studyStats is left nil — the skeleton shows until real data arrives
        // Build chart data from mock values
        retentionHistory = buildRetentionCurve(accuracy: 72.0)
        studyHeatmap = buildHeatmap(streak: 7, totalHours: 48.5)
        forecastData = buildForecast(due: 12)
        cardDistribution = buildDistribution(total: 234, due: 12)
    }

    // MARK: - Chart data builders

    /// Ebbinghaus forgetting curve scaled to the user's average accuracy.
    private func buildRetentionCurve(accuracy: Double) -> [RetentionPoint] {
        let R0 = max(20.0, min(accuracy, 95.0))
        // Stability S: higher accuracy → slower forgetting
        let S = 28.0 * (R0 / 70.0)
        return [0, 1, 7, 14, 30, 60, 90].map { day in
            let retention = day == 0 ? 100.0 : max(5.0, 100.0 * exp(-Double(day) / S))
            return RetentionPoint(day: day, retention: retention)
        }
    }

    /// Deterministic heatmap for the last 91 days (13 weeks) based on streak + total hours.
    private func buildHeatmap(streak: Int, totalHours: Double) -> [StudyDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        let today = Date()
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]

        let dailyMinutes = streak > 0 ? Int(totalHours * 60.0 / Double(streak)) : 60

        var result: [StudyDay] = []
        for offset in stride(from: -90, through: 0, by: 1) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let daysAgo = -offset
            let dateId = fmt.string(from: date)

            let minutes: Int
            if daysAgo < streak {
                // Within streak: regular study, slight alternation for realism
                minutes = max(15, dailyMinutes + (daysAgo % 2 == 0 ? 15 : -10))
            } else if daysAgo < streak * 3 {
                // Pre-streak zone: occasional sessions
                minutes = (daysAgo - streak) % 3 == 0 ? Int(Double(dailyMinutes) * 0.6) : 0
            } else {
                // Older: sparse
                minutes = daysAgo % 7 == 0 ? Int(Double(dailyMinutes) * 0.4) : 0
            }
            result.append(StudyDay(id: dateId, date: date, minutesStudied: max(0, minutes)))
        }
        return result
    }

    /// Distributes `due` cards across the next 7 days with front-loaded weighting.
    private func buildForecast(due: Int) -> [ForecastDay] {
        let weights: [Double] = [0.30, 0.20, 0.15, 0.12, 0.10, 0.08, 0.05]
        let total = Double(due)
        let calendar = Calendar.current
        let today = Date()
        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            let cards = max(0, Int((total * weights[offset]).rounded()))
            return ForecastDay(date: date, cardsCount: cards)
        }
    }

    /// Estimates card state distribution from totalCards + due count.
    private func buildDistribution(total: Int, due: Int) -> [CardCategory] {
        guard total > 0 else { return [] }
        let mastered = Int(Double(total) * 0.50)
        let review   = min(due, total - mastered)
        let learning = min(Int(Double(total) * 0.20), max(0, total - mastered - review))
        let new      = max(0, total - mastered - review - learning)
        return [
            CardCategory(name: "Novo",       count: new,      color: VitaColors.dataBlue),
            CardCategory(name: "Aprendendo", count: learning,  color: VitaColors.dataAmber),
            CardCategory(name: "Revisão",    count: review,    color: VitaColors.accent),
            CardCategory(name: "Dominado",   count: mastered,  color: VitaColors.dataGreen),
        ]
    }

    // MARK: - Helpers

    func accuracyColor(for accuracy: Double) -> Color {
        if accuracy >= 70 { return VitaColors.dataGreen }
        if accuracy >= 50 { return VitaColors.dataAmber }
        return VitaColors.dataRed
    }

    func subjectName(for id: String) -> String {
        let names: [String: String] = [
            "cm-cardio": "Cardiologia",
            "cm-pneumo": "Pneumologia",
            "cm-gastro": "Gastroenterologia",
            "cm-nefro": "Nefrologia",
            "cm-endocrino": "Endocrinologia",
            "cm-reumato": "Reumatologia",
            "cm-hemato": "Hematologia",
            "cm-infecto": "Infectologia",
            "cm-neuro": "Neurologia",
            "cir-geral": "Cirurgia Geral",
            "cir-trauma": "Cirurgia do Trauma",
            "ped-geral": "Pediatria",
            "go-obstetricia": "Obstetrícia",
            "go-ginecologia": "Ginecologia",
            "prev-epidemio": "Epidemiologia",
            "prev-bioestat": "Bioestatística",
        ]
        return names[id] ?? id
    }
}
