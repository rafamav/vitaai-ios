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

    // MARK: - Grades data (from /grades + /canvas/courses + /grades/current)
    var studyStats: StudyStats? = nil
    var courseGrades: [CourseGrade] = []
    var portalGrades: [GradeSubject] = []
    var portalSummary: GradesSummary? = nil
    var portalConnected: Bool = false

    // MARK: - Chart data
    var retentionHistory: [RetentionPoint] = []
    var studyHeatmap: [StudyDay] = []
    var forecastData: [ForecastDay] = []
    var cardDistribution: [CardCategory] = []

    // MARK: - UI state
    var isLoading: Bool = true
    var error: String? = nil

    // MARK: - Computed

    /// Best available average: portal average if present, else avgAccuracy from progress
    var displayAverage: Double {
        portalSummary?.averageGrade ?? avgAccuracy
    }

    var isEmptyState: Bool {
        !isLoading && error == nil && studyStats == nil && courseGrades.isEmpty && portalGrades.isEmpty
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

        do {
            // Fire all requests concurrently
            async let progressTask = api.getProgress()
            async let gradesTask: [GradeEntry] = api.getGrades(limit: 100)
            async let coursesTask = api.getCourses()
            async let portalTask = tryFetchPortalGrades()
            async let flashcardStatsTask = tryFetchFlashcardStats()

            let (progress, grades, coursesResp, portalResp, fcStats) = try await (
                progressTask, gradesTask, coursesTask, portalTask, flashcardStatsTask
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

            // Portal grades
            if let resp = portalResp {
                portalGrades = resp.current + resp.completed
                portalSummary = resp.summary
                portalConnected = true
            }

            // Chart data from REAL API data
            if let fc = fcStats {
                // Card distribution from real FSRS states
                cardDistribution = buildDistributionFromStats(fc)
                // Forecast from real FSRS scheduler
                forecastData = buildForecastFromStats(fc)
                // Retention from real review history
                retentionHistory = buildRetentionFromStats(fc)
            } else {
                // Fallback to progress data if flashcard stats unavailable
                cardDistribution = buildDistribution(total: totalCards, learned: progress.learnedCards, due: flashcardsDue)
                forecastData = []
                retentionHistory = []
            }
            // Heatmap from real API data
            studyHeatmap = buildHeatmapFromAPI(progress.heatmap)

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    /// Fetches portal grades, returning nil on error (portal may not be connected).
    private func tryFetchPortalGrades() async -> GradesCurrentResponse? {
        do { return try await api.getGradesCurrent() } catch { return nil }
    }

    /// Fetches flashcard stats (FSRS data), returning nil on error.
    private func tryFetchFlashcardStats() async -> FlashcardStatsResponse? {
        do { return try await api.getFlashcardStats() } catch { return nil }
    }

    // MARK: - Chart data from REAL API data

    /// Card state distribution from real FSRS states (new, young, mature).
    private func buildDistributionFromStats(_ stats: FlashcardStatsResponse) -> [CardCategory] {
        guard stats.totalCards > 0 else { return [] }
        return [
            CardCategory(name: "Novo",     count: stats.newCards,     color: VitaColors.dataBlue),
            CardCategory(name: "Jovem",    count: stats.youngCards,   color: VitaColors.dataAmber),
            CardCategory(name: "Maduro",   count: stats.matureCards,  color: VitaColors.dataGreen),
        ]
    }

    /// 7-day forecast from real FSRS scheduler.
    private func buildForecastFromStats(_ stats: FlashcardStatsResponse) -> [ForecastDay] {
        let calendar = Calendar.current
        let today = Date()
        return stats.forecastNext7Days.enumerated().compactMap { offset, cards in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return ForecastDay(date: date, cardsCount: cards)
        }
    }

    /// Retention curve from real daily retention data.
    private func buildRetentionFromStats(_ stats: FlashcardStatsResponse) -> [RetentionPoint] {
        guard !stats.dailyRetention.isEmpty else { return [] }
        return stats.dailyRetention.enumerated().map { idx, entry in
            RetentionPoint(day: idx, retention: entry.retention * 100)
        }
    }

    /// Heatmap from real API data (array of minutes per day, last 91 days).
    private func buildHeatmapFromAPI(_ heatmap: [Int]) -> [StudyDay] {
        guard !heatmap.isEmpty else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        let today = Date()
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate]

        // API returns array indexed from oldest to newest (91 days)
        let count = heatmap.count
        return heatmap.enumerated().compactMap { idx, minutes in
            let daysAgo = count - 1 - idx
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            return StudyDay(id: fmt.string(from: date), date: date, minutesStudied: minutes)
        }
    }

    /// Fallback card distribution from progress totals when flashcard stats unavailable.
    private func buildDistribution(total: Int, learned: Int, due: Int) -> [CardCategory] {
        guard total > 0 else { return [] }
        let newCards = max(0, total - learned)
        let reviewCards = min(due, learned)
        let masteredCards = max(0, learned - reviewCards)
        return [
            CardCategory(name: "Novo",     count: newCards,      color: VitaColors.dataBlue),
            CardCategory(name: "Revisão",  count: reviewCards,   color: VitaColors.accent),
            CardCategory(name: "Dominado", count: masteredCards,  color: VitaColors.dataGreen),
        ]
    }

    // MARK: - Helpers

    func accuracyColor(for accuracy: Double) -> Color {
        if accuracy >= 70 { return VitaColors.dataGreen }
        if accuracy >= 50 { return VitaColors.dataAmber }
        return VitaColors.dataRed
    }

    func subjectName(for id: String) -> String {
        // Use subject name from API data if available
        if let match = subjects.first(where: { $0.subjectId == id }), !match.name.isEmpty {
            return match.name
        }
        // Fallback: format the ID as a readable name
        return id
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
