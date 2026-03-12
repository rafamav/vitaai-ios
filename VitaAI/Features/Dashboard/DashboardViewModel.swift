import Foundation

@MainActor
@Observable
final class DashboardViewModel {
    private let api: VitaAPI

    var progress: DashboardProgress?
    var userProgress: UserProgress?
    var upcomingExams: [UpcomingExam] = []
    var weekDays: [WeekDay] = []
    var todayEvents: [AgendaEvent] = []
    var miniPlayer: MiniPlayerData?
    var weakSubjects: [WeakSubject] = []
    var studyModules: [StudyModule] = []
    var studyTip: String = ""
    var suggestions: [VitaSuggestion] = []
    var isLoading = true
    var error: String?

    init(api: VitaAPI) {
        self.api = api
    }

    func loadDashboard() async {
        isLoading = true
        error = nil

        // Load mock data first for instant UI
        loadMockData()
        isLoading = false

        // Then try real API in background
        do {
            async let progressTask = api.getProgress()
            async let examsTask = api.getExams(upcoming: true)

            let (progressResp, examsResp) = try await (progressTask, examsTask)

            progress = DashboardProgress(
                progressPercent: Double(progressResp.todayCompleted) / max(Double(progressResp.todayTotal), 1),
                streak: progressResp.streakDays,
                flashcardsDue: progressResp.flashcardsDue,
                accuracy: progressResp.avgAccuracy,
                studyMinutes: progressResp.todayStudyMinutes
            )

            upcomingExams = examsResp.exams.map { exam in
                UpcomingExam(
                    id: exam.id,
                    subject: exam.subjectName,
                    type: exam.examType,
                    date: ISO8601DateFormatter().date(from: exam.date) ?? Date(),
                    daysUntil: exam.daysUntil
                )
            }
        } catch {
            // Keep mock data, silently fail
            print("Dashboard API error: \(error)")
        }
    }

    private func loadMockData() {
        progress = MockData.dashboardProgress()
        userProgress = MockData.userProgress()
        upcomingExams = MockData.upcomingExams()
        weekDays = MockData.weekDays()
        todayEvents = MockData.todayAgendaEvents()
        miniPlayer = MockData.miniPlayer()
        weakSubjects = MockData.weakSubjects()
        studyModules = MockData.studyModules()
        studyTip = MockData.studyTip()
        suggestions = MockData.vitaSuggestions()
    }
}
