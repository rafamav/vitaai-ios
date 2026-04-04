import SwiftUI

// MARK: - ProgressoTab — pill navigation tabs

enum ProgressoTab: String, CaseIterable, Identifiable {
    case resumo = "Resumo"
    case disciplinas = "Disciplinas"
    case qbank = "QBank"
    case simulados = "Simulados"
    case retencao = "Retencao"
    case gamificacao = "Gamificacao"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .resumo: return "chart.bar.fill"
        case .disciplinas: return "books.vertical.fill"
        case .qbank: return "list.bullet.rectangle.fill"
        case .simulados: return "doc.text.fill"
        case .retencao: return "brain.fill"
        case .gamificacao: return "trophy.fill"
        }
    }

    var localizedTitle: String {
        switch self {
        case .resumo: return String(localized: "progresso_tab_resumo")
        case .disciplinas: return String(localized: "progresso_tab_disciplinas")
        case .qbank: return String(localized: "progresso_tab_qbank")
        case .simulados: return String(localized: "progresso_tab_simulados")
        case .retencao: return String(localized: "progresso_tab_retencao")
        case .gamificacao: return String(localized: "progresso_tab_gamificacao")
        }
    }
}

// MARK: - ProgressoViewModel

@MainActor
@Observable
final class ProgressoViewModel {
    private let api: VitaAPI

    // MARK: State
    var isLoading = true
    var error: String?
    var selectedTab: ProgressoTab = .resumo

    // MARK: Resumo Geral (section 1)
    var streakDays = 0
    var totalStudyHours = 0.0
    var avgAccuracy = 0.0
    var flashcardsDue = 0
    var userProgress: UserProgress?

    // MARK: Desempenho por Disciplina (section 2)
    var subjects: [SubjectProgress] = []

    // MARK: QBank (section 3)
    var qbankProgress: QBankProgressResponse?

    // MARK: Simulados (section 4)
    var simuladoDiagnostics: SimuladoDiagnosticsResponse?

    // MARK: Retencao (section 5)
    var flashcardStats: FlashcardStatsResponse?

    // MARK: Gamificacao (section 6)
    var leaderboard: [LeaderboardEntry] = []
    var selectedLeaderboardPeriod: String = "weekly"

    var myLeaderboardEntry: LeaderboardEntry? {
        leaderboard.first(where: { $0.isMe })
    }

    // MARK: Weekly chart
    var weeklyHours: [Double] = Array(repeating: 0, count: 7)
    var weeklyActualHours = 0.0
    var weeklyGoalHours = 0.0

    // MARK: Heatmap (91 days)
    var heatmap: [Int] = []

    init(api: VitaAPI) { self.api = api }

    // MARK: - Load All Data

    func load() async {
        isLoading = true
        error = nil

        var anySuccess = false

        // Load all endpoints concurrently
        async let progressTask: ProgressResponse? = {
            try? await self.api.getProgress()
        }()
        async let gamTask: GamificationStatsResponse? = {
            try? await self.api.getGamificationStats()
        }()
        async let leaderboardTask: [LeaderboardEntry]? = {
            try? await self.api.getLeaderboard(period: self.selectedLeaderboardPeriod, limit: 10)
        }()
        async let qbankTask: QBankProgressResponse? = {
            try? await self.api.getQBankProgress()
        }()
        async let simuladoTask: SimuladoDiagnosticsResponse? = {
            try? await self.api.getSimuladoDiagnostics()
        }()
        async let flashcardTask: FlashcardStatsResponse? = {
            try? await self.api.getFlashcardStats()
        }()

        let progress = await progressTask
        let gam = await gamTask
        let lb = await leaderboardTask
        let qbank = await qbankTask
        let simulado = await simuladoTask
        let flashcard = await flashcardTask

        // Apply progress
        if let progress {
            totalStudyHours = progress.totalStudyHours
            avgAccuracy = progress.avgAccuracy
            flashcardsDue = progress.flashcardsDue
            subjects = progress.subjects
            heatmap = progress.heatmap
            weeklyHours = progress.weeklyHours
            weeklyActualHours = progress.weeklyActualHours
            weeklyGoalHours = progress.weeklyGoalHours
            streakDays = progress.streakDays
            anySuccess = true
        }

        // Apply gamification
        if let gam {
            streakDays = gam.streakDays
            userProgress = UserProgress(
                totalXp: gam.totalXp,
                level: gam.level,
                currentLevelXp: gam.currentLevelXp,
                xpToNextLevel: gam.xpToNextLevel,
                currentStreak: gam.streakDays,
                longestStreak: gam.streakDays,
                badges: gam.achievements.filter(\.earned).map {
                    VitaBadge(
                        id: $0.id,
                        name: $0.name,
                        description: $0.description,
                        icon: $0.icon,
                        earnedAt: $0.earnedAt.map { Date(timeIntervalSince1970: Double($0) / 1000) },
                        category: .milestone
                    )
                },
                dailyXp: gam.dailyXp ?? 0
            )
            anySuccess = true
        }

        // Apply leaderboard
        if let lb {
            leaderboard = lb
            anySuccess = true
        }

        // Apply QBank
        if let qbank {
            qbankProgress = qbank
            anySuccess = true
        }

        // Apply Simulados
        if let simulado {
            simuladoDiagnostics = simulado
            anySuccess = true
        }

        // Apply Flashcard stats
        if let flashcard {
            flashcardStats = flashcard
            anySuccess = true
        }

        if !anySuccess {
            self.error = String(localized: "progresso_error_load")
        }
        isLoading = false
    }

    // MARK: - Reload leaderboard with different period

    func reloadLeaderboard(period: String) async {
        selectedLeaderboardPeriod = period
        do {
            leaderboard = try await api.getLeaderboard(period: period, limit: 10)
        } catch {
            print("[PROGRESSO] getLeaderboard(\(period)) failed: \(error)")
        }
    }

    // MARK: - Computed helpers

    var sortedSubjectsByAccuracy: [SubjectProgress] {
        subjects.sorted { $0.accuracy > $1.accuracy }
    }

    var weakSubjects: [SubjectProgress] {
        subjects.sorted { $0.accuracy < $1.accuracy }.prefix(5).map { $0 }
    }

    var allBadges: [VitaBadge] {
        userProgress?.badges ?? []
    }
}
