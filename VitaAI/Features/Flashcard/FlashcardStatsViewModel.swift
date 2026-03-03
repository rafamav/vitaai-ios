import Foundation
import Observation

// MARK: - FlashcardStatsViewModel

@Observable
@MainActor
final class FlashcardStatsViewModel {

    // MARK: Loading
    private(set) var isLoading = true

    // MARK: Card counts
    private(set) var totalCards = 0
    private(set) var newCards = 0
    private(set) var youngCards = 0
    private(set) var matureCards = 0

    // MARK: Performance stats
    private(set) var retentionRate: Double = 0
    private(set) var streakDays = 0
    private(set) var totalStudyMinutes = 0
    private(set) var totalReviews = 0
    private(set) var todayReviews = 0

    // MARK: Chart data
    private(set) var reviewsPerDay: [String: Int] = [:]
    private(set) var forecastNext7Days: [Int] = Array(repeating: 0, count: 7)
    private(set) var dailyRetention: [DailyRetentionEntry] = []

    private let api: VitaAPI

    init(api: VitaAPI) {
        self.api = api
    }

    // MARK: - Load

    func load() async {
        isLoading = true

        // Parallel: deck cards + progress aggregate
        async let decksTask = api.getFlashcardDecks(dueOnly: false)
        async let progressTask = api.getProgress()

        do {
            let (decks, progress) = try await (decksTask, progressTask)
            computeLocally(decks: decks, progress: progress)
        } catch {
            // Partial failure — leave defaults
        }

        // Optionally enrich with server-side review history
        if let stats = try? await api.getFlashcardStats() {
            enrichFromServer(stats)
        }

        isLoading = false
    }

    // MARK: - Local computation from deck entries

    private func computeLocally(decks: [FlashcardDeckEntry], progress: ProgressResponse) {
        let allCards = decks.flatMap { $0.cards }

        var newCount = 0
        var youngCount = 0
        var matureCount = 0
        var forecastCounts = Array(repeating: 0, count: 7)

        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let isoParser = ISO8601DateFormatter()

        for card in allCards {
            // Maturity classification — mirrors Android FsrsDao logic
            // new: never reviewed, young: scheduledDays 1-21, mature: scheduledDays > 21
            if card.repetitions == 0 {
                newCount += 1
            } else if card.interval > 21 {
                matureCount += 1
            } else {
                youngCount += 1
            }

            // 7-day review forecast from nextReviewAt
            guard let nextStr = card.nextReviewAt,
                  let nextDate = isoParser.date(from: nextStr) else { continue }

            let nextDay = calendar.startOfDay(for: nextDate)
            for offset in 0..<7 {
                guard let target = calendar.date(byAdding: .day, value: offset, to: todayStart) else { continue }
                if nextDay == target {
                    forecastCounts[offset] += 1
                    break
                }
            }
            // Cards already overdue count toward today
            if nextDay < todayStart {
                forecastCounts[0] += 1
            }
        }

        totalCards = allCards.count
        newCards = newCount
        youngCards = youngCount
        matureCards = matureCount
        forecastNext7Days = forecastCounts

        // Aggregate stats from ProgressResponse
        streakDays = progress.streakDays
        retentionRate = progress.avgAccuracy
        totalStudyMinutes = Int(progress.totalStudyHours * 60)
        todayReviews = progress.todayCompleted
    }

    // MARK: - Enrich from API stats endpoint

    private func enrichFromServer(_ stats: FlashcardStatsResponse) {
        if stats.totalCards > 0     { totalCards = stats.totalCards }
        if stats.newCards > 0       { newCards = stats.newCards }
        if stats.youngCards > 0     { youngCards = stats.youngCards }
        if stats.matureCards > 0    { matureCards = stats.matureCards }
        if stats.totalReviews > 0   { totalReviews = stats.totalReviews }
        if stats.retentionRate > 0  { retentionRate = stats.retentionRate }
        if stats.streakDays > 0     { streakDays = stats.streakDays }
        if stats.totalStudyMinutes > 0 { totalStudyMinutes = stats.totalStudyMinutes }
        if stats.todayReviews > 0   { todayReviews = stats.todayReviews }
        if !stats.reviewsPerDay.isEmpty  { reviewsPerDay = stats.reviewsPerDay }
        if !stats.forecastNext7Days.isEmpty { forecastNext7Days = stats.forecastNext7Days }
        if !stats.dailyRetention.isEmpty    { dailyRetention = stats.dailyRetention }
    }
}
