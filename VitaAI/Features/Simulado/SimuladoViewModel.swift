import Foundation
import Observation

// MARK: - UI State

struct SimuladoUiState {
    // Home
    var isLoading = true
    var attempts: [SimuladoAttemptEntry] = []
    var stats = SimuladoStats()
    var bySubject: [SubjectSummary] = []
    var bySemester: [SemesterSummary] = []
    var selectedSemester: String? = nil
    // Config
    var courses: [Course] = []
    var coursesLoading = false
    var selectedCourse: Course? = nil
    var files: [CanvasFile] = []
    var filesLoading = false
    var selectedFileIds: Set<String> = []
    var selectedSubject = ""
    var selectedDifficulty = "medium"
    var selectedQuestionCount = 25
    var selectedMode = "immediate"
    var isGenerating = false
    // Config redesign
    var templates: [SimuladoTemplate] = SimuladoTemplate.defaults
    var disciplines: [SimuladoDiscipline] = []
    var disciplinesLoading = false
    var selectedDisciplineName: String? = nil
    var timedMode = true
    // Session
    var currentAttemptId: String? = nil
    var questions: [SimuladoQuestionEntry] = []
    var currentQuestionIndex = 0
    var answers: [String: Int] = [:]
    var markedQuestions: Set<Int> = []
    var showFeedback = false
    var lastAnswerCorrect: Bool? = nil
    var sessionStartDate = Date()
    var questionStartDate = Date()
    // Explanation
    var currentExplanation: ExplainResponse? = nil
    var isLoadingExplanation = false
    // Result
    var result: FinishSimuladoResponse? = nil
    // Diagnostics
    var diagnostics: SimuladoDiagnosticsResponse? = nil
    var reviewFilter = "all"
    var error: String? = nil

    var currentQuestion: SimuladoQuestionEntry? {
        questions.indices.contains(currentQuestionIndex) ? questions[currentQuestionIndex] : nil
    }

    var progress: Double {
        questions.isEmpty ? 0 : Double(answers.count) / Double(questions.count)
    }

    var isExamMode: Bool { selectedMode == "exam" }

    var filteredAttempts: [SimuladoAttemptEntry] {
        guard let sem = selectedSemester else { return attempts }
        return attempts.filter { attempt in
            guard let raw = attempt.startedAt, raw.count >= 10 else { return false }
            let datePart = String(raw.prefix(10))
            let parts = datePart.split(separator: "-")
            guard parts.count == 3,
                  let month = Int(parts[1]) else { return false }
            let half = month <= 6 ? "1" : "2"
            return "\(parts[0]).\(half)" == sem
        }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class SimuladoViewModel {

    var state = SimuladoUiState()
    private let api: VitaAPI
    private let gamificationEvents: GamificationEventManager
    private let dataManager: AppDataManager

    init(api: VitaAPI, gamificationEvents: GamificationEventManager, dataManager: AppDataManager) {
        self.api = api
        self.gamificationEvents = gamificationEvents
        self.dataManager = dataManager
    }

    // MARK: - Home

    func loadAttempts() {
        Task {
            state.isLoading = true
            do {
                let response = try await api.listSimulados()
                state.attempts = response.attempts
                state.stats = response.stats
                state.bySubject = response.bySubject
                state.bySemester = response.bySemester
                state.error = nil
            } catch {
                NSLog("[SimuladoVM] loadAttempts error: %@", "\(error)")
                state.error = "Erro ao carregar simulados"
            }
            state.isLoading = false
        }
    }

    func deleteAttempt(_ id: String) {
        state.attempts.removeAll { $0.id == id }
        Task {
            try? await api.deleteSimulado(attemptId: id)
        }
    }

    func archiveAttempt(_ id: String) {
        state.attempts.removeAll { $0.id == id }
        Task {
            try? await api.archiveSimulado(attemptId: id)
        }
    }

    func selectSemester(_ semester: String?) {
        state.selectedSemester = state.selectedSemester == semester ? nil : semester
    }

    // MARK: - Config

    func loadCourses() {
        // 2026-04-23: api.getCourses() é rota legacy Canvas 404. Simulado
        // gera a partir de QBank questions, não de Canvas courses. Skip
        // chamada pra evitar delay de 9.7s sem benefício.
        state.courses = []
        state.coursesLoading = false
    }

    func selectCourse(_ course: Course?) {
        state.selectedCourse = course
        state.selectedSubject = course.map { cleanCourseName($0.name) } ?? ""
        state.files = []
        state.selectedFileIds = []
        guard let course else { return }
        state.filesLoading = true
        Task {
            do {
                let response = try await api.getFiles(courseId: course.id)
                state.files = response.files.filter { $0.hasText }
            } catch {
                state.files = []
            }
            state.filesLoading = false
        }
    }

    func setSubject(_ subject: String) { state.selectedSubject = subject }
    func toggleFile(_ id: String) {
        if state.selectedFileIds.contains(id) { state.selectedFileIds.remove(id) }
        else { state.selectedFileIds.insert(id) }
    }
    func setDifficulty(_ d: String) { state.selectedDifficulty = d }
    func setQuestionCount(_ n: Int) { state.selectedQuestionCount = n }
    func setMode(_ m: String) { state.selectedMode = m }

    func loadConfigData() {
        state.templates = SimuladoTemplate.defaults
        state.disciplinesLoading = true
        Task { @MainActor in
            // SOT: AppDataManager.enrolledDisciplines → /api/subjects with
            // questionCount pre-computed server-side from qbank_topics.
            // No more /api/qbank/filters detour — same endpoint QBank uses.
            if dataManager.enrolledDisciplines.isEmpty {
                await dataManager.silentRefresh()
            }
            let enrolled = dataManager.enrolledDisciplines
                .sorted { dataManager.vitaScore(for: $0.displayName) > dataManager.vitaScore(for: $1.displayName) }
            state.disciplines = enrolled.map {
                SimuladoDiscipline(name: $0.displayName, count: $0.questionCount ?? 0)
            }
            state.disciplinesLoading = false
        }
    }

    func selectSimuladoDiscipline(_ name: String?) {
        state.selectedDisciplineName = name
    }

    func toggleTimedMode() {
        state.timedMode.toggle()
    }

    func applyTemplate(_ template: SimuladoTemplate) {
        state.selectedQuestionCount = template.count
        state.timedMode = template.timed
        state.selectedDisciplineName = template.disciplineName
        VitaPostHogConfig.capture(event: "simulado_template_selected", properties: [
            "template_id": template.id,
            "template_name": template.name,
            "question_count": template.count,
            "timed": template.timed,
        ])
        generateSimulado()
    }

    func generateSimulado() {
        let subject = state.selectedDisciplineName ?? "Geral"
        Task {
            state.isGenerating = true
            state.error = nil
            do {
                let response = try await api.generateSimulado(.init(
                    subject: subject,
                    difficulty: state.selectedDifficulty,
                    questionCount: state.selectedQuestionCount,
                    mode: state.timedMode ? "exam" : "immediate",
                    sourceDocumentIds: nil,
                    courseId: nil
                ))
                let now = Date()
                state.currentAttemptId = response.id
                state.questions = response.questions
                state.currentQuestionIndex = 0
                state.answers = [:]
                state.markedQuestions = []
                state.showFeedback = false
                state.lastAnswerCorrect = nil
                state.sessionStartDate = now
                state.questionStartDate = now
                state.result = nil
                VitaPostHogConfig.capture(event: "simulado_started", properties: [
                    "simulado_id": response.id,
                    "question_count": response.questions.count,
                    "subject": subject,
                    "difficulty": state.selectedDifficulty,
                    "mode": state.timedMode ? "exam" : "immediate",
                ])
            } catch {
                state.error = "Erro ao gerar simulado: \(error.localizedDescription)"
                VitaPostHogConfig.capture(event: "simulado_start_failed", properties: [
                    "subject": subject,
                    "reason": error.localizedDescription,
                ])
            }
            state.isGenerating = false
        }
    }

    // MARK: - Session

    func loadSession(_ attemptId: String) {
        Task {
            state.isLoading = true
            do {
                let response = try await api.listSimulados()
                if let attempt = response.attempts.first(where: { $0.id == attemptId }) {
                    let answered = Dictionary(
                        uniqueKeysWithValues: attempt.questions
                            .compactMap { q -> (String, Int)? in
                                guard let idx = q.chosenIdx else { return nil }
                                return (q.id, idx)
                            }
                    )
                    let now = Date()
                    state.currentAttemptId = attemptId
                    state.questions = attempt.questions
                    state.answers = answered
                    state.currentQuestionIndex = 0
                    state.sessionStartDate = now
                    state.questionStartDate = now
                    // Restore result for finished attempts
                    if attempt.status == "finished" {
                        state.result = FinishSimuladoResponse(
                            id: attempt.id,
                            correctQ: attempt.correctQ,
                            totalQ: attempt.totalQ,
                            score: attempt.score
                        )
                    }
                }
            } catch {
                state.error = "Erro ao carregar sessão"
            }
            state.isLoading = false
        }
    }

    func selectAnswer(questionId: String, chosenIdx: Int) {
        guard !state.showFeedback else { return }
        state.answers[questionId] = chosenIdx
    }

    func confirmAnswer() {
        guard let question = state.currentQuestion,
              let chosenIdx = state.answers[question.id] else { return }

        let responseTimeMs = Int64(Date().timeIntervalSince(state.questionStartDate) * 1000)
        let isCorrect = chosenIdx == question.correctIdx
        VitaPostHogConfig.capture(event: "simulado_question_answered", properties: [
            "simulado_id": state.currentAttemptId ?? "",
            "question_index": state.currentQuestionIndex,
            "seconds_elapsed": Int(responseTimeMs / 1000),
            "correct": isCorrect,
            "mode": state.isExamMode ? "exam" : "immediate",
        ])

        if state.isExamMode {
            syncAnswerToAPI(questionId: question.id, chosenIdx: chosenIdx, responseTimeMs: responseTimeMs)
            advanceToNext()
        } else {
            state.showFeedback = true
            state.lastAnswerCorrect = isCorrect
            syncAnswerToAPI(questionId: question.id, chosenIdx: chosenIdx, responseTimeMs: responseTimeMs)
        }
    }

    private func syncAnswerToAPI(questionId: String, chosenIdx: Int, responseTimeMs: Int64) {
        guard let attemptId = state.currentAttemptId else { return }
        Task {
            var lastError: Error?
            for attempt in 0..<3 {
                if attempt > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
                }
                do {
                    _ = try await api.answerSimuladoQuestion(
                        attemptId: attemptId,
                        body: .init(questionId: questionId, chosenIdx: chosenIdx, responseTimeMs: responseTimeMs)
                    )
                    return
                } catch {
                    lastError = error
                }
            }
            print("[SimuladoVM] Failed to sync answer after 3 attempts: \(lastError?.localizedDescription ?? "unknown")")
        }
    }

    func nextQuestion() { advanceToNext() }

    func previousQuestion() {
        guard state.currentQuestionIndex > 0 else { return }
        state.currentQuestionIndex -= 1
        state.showFeedback = false
        state.lastAnswerCorrect = nil
        state.questionStartDate = Date()
        state.currentExplanation = nil
    }

    func goToQuestion(_ index: Int) {
        guard state.questions.indices.contains(index) else { return }
        state.currentQuestionIndex = index
        state.showFeedback = false
        state.lastAnswerCorrect = nil
        state.questionStartDate = Date()
        state.currentExplanation = nil
    }

    func toggleMark(_ questionNo: Int) {
        if state.markedQuestions.contains(questionNo) {
            state.markedQuestions.remove(questionNo)
        } else {
            state.markedQuestions.insert(questionNo)
        }
    }

    func finishSimulado() {
        guard let attemptId = state.currentAttemptId else { return }
        Task {
            state.isLoading = true
            do {
                let ms = Int64(Date().timeIntervalSince(state.sessionStartDate) * 1000)
                let response = try await api.finishSimulado(attemptId: attemptId, timeTakenMs: ms)
                state.result = response
                state.error = nil

                let percent = response.totalQ > 0
                    ? Double(response.correctQ) / Double(response.totalQ)
                    : 0.0
                VitaPostHogConfig.capture(event: "simulado_submitted", properties: [
                    "simulado_id": response.id,
                    "correct_count": response.correctQ,
                    "total_count": response.totalQ,
                    "percent": percent,
                    "seconds_elapsed": Int(ms / 1000),
                ])

                // Log simulado completion with study duration
                let durationMinutes = Int(ms / 60_000)
                Task { [api, gamificationEvents] in
                    if let actResult = try? await api.logActivity(
                        action: "simulado_complete",
                        metadata: ["durationMinutes": String(durationMinutes)]
                    ) {
                        gamificationEvents.handleActivityResponse(actResult, previousLevel: nil)
                    }
                }
            } catch {
                state.error = "Erro ao finalizar simulado"
            }
            state.isLoading = false
        }
    }

    // MARK: - Explanation

    func loadExplanation(questionId: String) {
        guard let attemptId = state.currentAttemptId else { return }
        Task {
            state.isLoadingExplanation = true
            do {
                let response = try await api.explainQuestion(attemptId: attemptId, questionId: questionId)
                state.currentExplanation = response
            } catch {
                state.currentExplanation = nil
            }
            state.isLoadingExplanation = false
        }
    }

    func dismissExplanation() {
        state.currentExplanation = nil
        state.isLoadingExplanation = false
    }

    // MARK: - Diagnostics

    func loadDiagnostics(subject: String = "all", period: String = "30d") {
        Task {
            state.isLoading = true
            do {
                state.diagnostics = try await api.getSimuladoDiagnostics(subject: subject, period: period)
                state.error = nil
            } catch {
                state.error = "Erro ao carregar diagnóstico"
            }
            state.isLoading = false
        }
    }

    func setReviewFilter(_ filter: String) { state.reviewFilter = filter }
    func clearError() { state.error = nil }

    private func advanceToNext() {
        let next = state.currentQuestionIndex + 1
        if next >= state.questions.count {
            // Last question answered — auto-finish in exam mode
            if state.isExamMode {
                finishSimulado()
            }
            // In immediate mode, the UI shows a "Finalizar" button after feedback
            return
        }
        state.currentQuestionIndex = next
        state.showFeedback = false
        state.lastAnswerCorrect = nil
        state.questionStartDate = Date()
        state.currentExplanation = nil
    }
}

// MARK: - Helpers

private let romanNumerals = Set(["I","II","III","IV","V","VI","VII","VIII","IX","X"])
private let lowercaseWords = Set(["DE","DA","DO","DAS","DOS","E","EM","COM"])

private func cleanCourseName(_ raw: String) -> String {
    let stripped = raw.replacingOccurrences(of: #"^\d+\s*-\s*"#, with: "", options: .regularExpression)
    return stripped.split(separator: " ").map { word in
        let upper = word.uppercased()
        if romanNumerals.contains(upper) { return upper }
        if lowercaseWords.contains(upper) { return upper.lowercased() }
        return upper.prefix(1) + word.dropFirst().lowercased()
    }.joined(separator: " ")
}
