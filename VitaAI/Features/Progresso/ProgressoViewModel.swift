import SwiftUI

@MainActor
@Observable
final class ProgressoViewModel {
    private let api: VitaAPI

    // Loading / error
    var isLoading = true
    var error: String?

    // Stats
    var streakDays = 0
    var longestStreak = 0
    var totalStudyHours = 0.0
    var avgAccuracy = 0.0
    var totalQuestions = 0

    // Gamification
    var userProgress: UserProgress?

    // Weekly chart (hours per day Mon-Sun)
    var weeklyHours: [Double] = Array(repeating: 0, count: 7)
    var weeklyActualHours = 0.0
    var weeklyGoalHours = 0.0

    // Heatmap (91 days, levels 0-4)
    var heatmap: [Int] = []

    // Subjects for "onde melhorar"
    var subjects: [SubjectProgress] = []

    // Leaderboard
    var leaderboard: [LeaderboardEntry] = []

    // Achievements (badges)
    var badges: [BadgeWithStatus] = []

    // Activity feed (recent XP-earning actions)
    var activity: [ActivityFeedItem] = []

    var myLeaderboardEntry: LeaderboardEntry? {
        leaderboard.first(where: { $0.isMe })
    }

    init(api: VitaAPI) { self.api = api }

    func load() async {
        isLoading = true
        error = nil

        var anySuccess = false

        // Fire all 5 independent requests in parallel — was serial (3-4s), now max(endpoint)
        async let progressResult = api.getProgress()
        async let statsResult = api.getGamificationStats()
        async let leaderboardResult = api.getLeaderboard(period: leaderboardPeriod, limit: 10)
        async let achievementsResult = api.getAchievements()
        async let activityResult = api.getActivityFeed(limit: 8, offset: 0)

        // Progress
        do {
            let progress = try await progressResult
            totalStudyHours = progress.totalStudyHours
            avgAccuracy = progress.avgAccuracy
            totalQuestions = progress.totalAnswered
            subjects = progress.subjects
            heatmap = progress.heatmap
            weeklyHours = progress.weeklyHours
            weeklyActualHours = progress.weeklyActualHours
            weeklyGoalHours = progress.weeklyGoalHours
            streakDays = progress.streakDays
            anySuccess = true
        } catch {
            print("[PROGRESSO] getProgress failed: \(error)")
        }

        // Load XP/level from gamification stats endpoint (server is source of truth)
        do {
            let stats = try await statsResult
            // streakDays from stats takes priority over progress endpoint if available
            if stats.streakDays > 0 { streakDays = stats.streakDays }
            longestStreak = streakDays
            // server provides currentLevelXp and xpToNextLevel directly — use them
            let currentLvlXp = stats.currentLevelXp > 0
                ? stats.currentLevelXp
                : LevelThresholds.currentLevelXp(totalXp: stats.totalXp, level: stats.level)
            let xpToNext = stats.xpToNextLevel > 0
                ? stats.xpToNextLevel
                : LevelThresholds.xpToNextLevel(stats.level)
            userProgress = UserProgress(
                totalXp: stats.totalXp,
                level: max(1, stats.level),
                currentLevelXp: currentLvlXp,
                xpToNextLevel: xpToNext,
                currentStreak: streakDays,
                longestStreak: streakDays,
                badges: [],
                dailyXp: 0
            )
            anySuccess = true
        } catch {
            print("[PROGRESSO] getGamificationStats failed: \(error) — falling back to dashboard")
            // Fallback: derive level data from dashboard XP using local formula
            do {
                let dashboard = try await api.getDashboard()
                let totalXp = dashboard.xp?.total ?? 0
                let level = dashboard.xp?.level ?? LevelThresholds.level(for: totalXp)
                longestStreak = streakDays
                userProgress = UserProgress(
                    totalXp: totalXp,
                    level: level,
                    currentLevelXp: LevelThresholds.currentLevelXp(totalXp: totalXp, level: level),
                    xpToNextLevel: LevelThresholds.xpToNextLevel(level),
                    currentStreak: streakDays,
                    longestStreak: streakDays,
                    badges: [],
                    dailyXp: 0
                )
                anySuccess = true
            } catch {
                print("[PROGRESSO] getDashboard fallback failed: \(error)")
            }
        }

        // Leaderboard (parallel fetch joined here)
        do {
            leaderboard = try await leaderboardResult
            if !leaderboard.isEmpty { anySuccess = true }
        } catch {
            print("[PROGRESSO] getLeaderboard failed: \(error)")
        }

        // Achievements + activity feed (parallel fetches joined here)
        do {
            badges = try await achievementsResult
            if !badges.isEmpty { anySuccess = true }
        } catch {
            print("[PROGRESSO] getAchievements failed: \(error)")
        }

        do {
            activity = try await activityResult
            if !activity.isEmpty { anySuccess = true }
        } catch {
            print("[PROGRESSO] getActivityFeed failed: \(error)")
        }

        if !anySuccess {
            self.error = "Não foi possível carregar os dados de progresso."
        }
        isLoading = false
    }

    // Selected leaderboard period (weekly/monthly/total). UI binds to this.
    var leaderboardPeriod: String = "weekly"

    func loadLeaderboard(period: String) async {
        leaderboardPeriod = period
        do {
            leaderboard = try await api.getLeaderboard(period: period, limit: 10)
        } catch {
            print("[PROGRESSO] getLeaderboard(\(period)) failed: \(error)")
        }
    }
}
