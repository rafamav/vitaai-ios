import Foundation
import SwiftUI

@MainActor
@Observable
final class OsceViewModel {

    // MARK: - Phase

    enum OscePhase: Equatable {
        case selectSpecialty
        case caseActive
        case completed
    }

    // MARK: - Exchange (a completed step: user response + AI evaluation)

    struct OsceExchange: Identifiable {
        let id = UUID()
        let step: Int
        let stepName: String
        let userResponse: String
        let aiEvaluation: String
    }

    // MARK: - Constants (mirrors Android OsceViewModel)

    static let stepNames = [
        "Anamnese",
        "Exame Físico",
        "Hipóteses Diagnósticas",
        "Exames Complementares",
        "Conduta",
    ]

    /// Default specialties — used as fallback until API provides them
    private static let defaultSpecialties = [
        "Cardiologia",
        "Pediatria",
        "Ginecologia",
        "Cirurgia Geral",
        "Clínica Médica",
        "Emergência",
        "Neurologia",
        "Ortopedia",
    ]

    // MARK: - State

    var specialties: [String] = defaultSpecialties
    var phase: OscePhase = .selectSpecialty
    var specialty: String = ""
    var attemptId: String? = nil
    var currentStep: Int = 1
    var patientContext: OscePatientContext? = nil
    var exchanges: [OsceExchange] = []
    var currentPrompt: String = ""
    var currentResponse: String = ""
    var score: Int? = nil
    var feedback: String = ""
    var isStreaming: Bool = false
    var isLoading: Bool = false
    var error: String? = nil

    // MARK: - Dependencies

    private let api: VitaAPI
    private let sseClient: OsceSseClient
    private let gamificationEvents: GamificationEventManager
    private var caseStartDate = Date()

    init(api: VitaAPI, sseClient: OsceSseClient, gamificationEvents: GamificationEventManager) {
        self.api = api
        self.sseClient = sseClient
        self.gamificationEvents = gamificationEvents
    }

    // MARK: - Load specialties from API

    func loadSpecialties() {
        Task {
            do {
                let list: [String] = try await api.getOsceSpecialties()
                if !list.isEmpty {
                    specialties = list
                }
            } catch {
                // API may not have this endpoint yet — keep defaults
                NSLog("[OSCE] Specialties fetch failed (using defaults): %@", String(describing: error))
            }
        }
    }

    // MARK: - Start case

    func startCase(specialty: String) {
        self.specialty = specialty
        isLoading = true
        error = nil

        Task {
            do {
                let resp = try await api.startOsceCase(specialty: specialty)
                isLoading = false
                phase = .caseActive
                caseStartDate = Date()
                attemptId = resp.attemptId
                currentStep = resp.currentStep
                patientContext = resp.patientContext
                currentPrompt = resp.prompt
                exchanges = []
                currentResponse = ""
            } catch {
                isLoading = false
                self.error = "Erro ao iniciar caso: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Submit response (streams evaluation via SSE)

    func submitResponse() {
        let trimmed = currentResponse.trimmingCharacters(in: .whitespaces)
        guard let attemptId, !trimmed.isEmpty, !isStreaming else { return }

        let stepAtSubmit = currentStep
        let stepNameAtSubmit = Self.stepNames.indices.contains(stepAtSubmit - 1)
            ? Self.stepNames[stepAtSubmit - 1]
            : "Passo \(stepAtSubmit)"

        isStreaming = true
        error = nil
        currentResponse = ""

        Task {
            var aiText = ""
            var completedStep = stepAtSubmit
            var completedStepName = stepNameAtSubmit
            var stepScore: Int? = nil

            do {
                for try await event in await sseClient.streamRespond(attemptId: attemptId, response: trimmed) {
                    switch event {
                    case .textDelta(let text):
                        aiText += text
                        currentPrompt = aiText
                    case .stepComplete(let nextStep, let name, let score):
                        completedStep = nextStep
                        completedStepName = name
                        stepScore = score
                    case .done:
                        break
                    case .error(let msg):
                        self.error = msg
                        isStreaming = false
                        return
                    }
                }

                let exchange = OsceExchange(
                    step: stepAtSubmit,
                    stepName: stepNameAtSubmit,
                    userResponse: trimmed,
                    aiEvaluation: aiText
                )

                if completedStep > Self.stepNames.count {
                    // Last step completed — show results
                    exchanges.append(exchange)
                    if let s = stepScore { self.score = s }
                    feedback = aiText
                    isStreaming = false
                    phase = .completed

                    // Log OSCE completion for gamification
                    let durationMinutes = Int(Date().timeIntervalSince(caseStartDate) / 60)
                    Task { [api, gamificationEvents] in
                        if let result = try? await api.logActivity(
                            action: "osce_complete",
                            metadata: ["durationMinutes": String(durationMinutes)]
                        ) {
                            gamificationEvents.handleActivityResponse(result, previousLevel: nil)
                        }
                    }
                } else {
                    exchanges.append(exchange)
                    currentStep = completedStep
                    currentPrompt = aiText
                    if let s = stepScore { self.score = s }
                    isStreaming = false
                }
            } catch {
                self.error = "Erro ao enviar resposta: \(error.localizedDescription)"
                isStreaming = false
            }
        }
    }

    // MARK: - Reset

    func resetCase() {
        phase = .selectSpecialty
        specialty = ""
        attemptId = nil
        currentStep = 1
        patientContext = nil
        exchanges = []
        currentPrompt = ""
        currentResponse = ""
        score = nil
        feedback = ""
        isStreaming = false
        isLoading = false
        error = nil
    }
}
