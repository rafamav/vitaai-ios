import Foundation
import Observation

// MARK: - SimuladoBuilderViewModel — Fase 4 reescrita gold-standard
//
// Substitui SimuladoHomeScreen + SimuladoConfigScreen por uma tela única
// (SimuladoBuilderScreen) com Hero + toggle Template/Custom + builder.
// Espelha a arquitetura do QBankBuilderViewModel (Fase 3), adaptado pra
// simulado: cronômetro visível, defaults Qtd [20,30,50,100], modo template.
//
// SOT layout: agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md §3.2 + §11.3
// SOT API: openapi.yaml (simulados/screen, simulados/templates, simulados/from-template, simulados/generate)

// MARK: - Mode

enum SimuladoBuilderMode: String, CaseIterable, Identifiable, Hashable {
    case template
    case custom
    var id: String { rawValue }
    var label: String {
        switch self {
        case .template: return "Template"
        case .custom: return "Custom"
        }
    }
    var icon: String {
        switch self {
        case .template: return "rectangle.stack.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}

// MARK: - DTOs locais (decodificam a resposta crua do backend)
//
// Generated/Models não tem SimuladoScreen/SimuladoTemplate/SimuladoAttempt
// gerados. ATLAS roda codegen na Onda 3; até lá usamos modelos locais
// equivalentes ao schema do openapi.yaml §components.schemas.SimuladoScreen.

struct SimuladoTemplateDTO: Decodable, Identifiable, Hashable {
    let id: String
    let slug: String
    let name: String
    let description: String?
    let source: String
    let totalQuestions: Int
    let timeLimitMinutes: Int?
    let passingScore: Double?
    let isOfficial: Bool?

    var iconName: String {
        switch source {
        case "revalida": return "globe.americas.fill"
        case "enare": return "rosette"
        case "residencia": return "stethoscope"
        case "rapido": return "bolt.fill"
        case "internato": return "cross.case.fill"
        default: return "rectangle.stack.fill"
        }
    }
}

private struct SimuladoTemplatesEnvelope: Decodable {
    let templates: [SimuladoTemplateDTO]
}

private struct SimuladoScreenStats: Decodable {
    var totalAttempts: Int = 0
    var completedAttempts: Int = 0
    var totalQuestions: Int = 0
    var totalCorrect: Int = 0
    var avgScore: Double = 0
    private enum CodingKeys: String, CodingKey {
        case totalAttempts, completedAttempts, totalQuestions, totalCorrect, avgScore
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalAttempts = (try? c.decode(Int.self, forKey: .totalAttempts)) ?? 0
        completedAttempts = (try? c.decode(Int.self, forKey: .completedAttempts)) ?? 0
        totalQuestions = (try? c.decode(Int.self, forKey: .totalQuestions)) ?? 0
        totalCorrect = (try? c.decode(Int.self, forKey: .totalCorrect)) ?? 0
        avgScore = (try? c.decode(Double.self, forKey: .avgScore)) ?? 0
    }
}

private struct SimuladoScreenInProgress: Decodable {
    let attemptId: String
    let answeredCount: Int?
    let totalCount: Int?
    let elapsedSeconds: Int?
}

private struct SimuladoScreenResponse: Decodable {
    var attempts: [SimuladoAttemptEntry] = []
    var stats: SimuladoScreenStats = .init()
    var templates: [SimuladoTemplateDTO] = []
    var inProgress: SimuladoScreenInProgress? = nil

    private enum CodingKeys: String, CodingKey {
        case attempts, stats, templates, inProgress
    }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attempts = (try? c.decode([SimuladoAttemptEntry].self, forKey: .attempts)) ?? []
        stats = (try? c.decode(SimuladoScreenStats.self, forKey: .stats)) ?? .init()
        templates = (try? c.decode([SimuladoTemplateDTO].self, forKey: .templates)) ?? []
        inProgress = try? c.decode(SimuladoScreenInProgress.self, forKey: .inProgress)
    }
}

private struct SimuladoFromTemplateBody: Encodable {
    let templateSlug: String
}

private struct SimuladoFromTemplateResponse: Decodable {
    let id: String
}

// MARK: - State

struct SimuladoBuilderState {
    // Modo principal (Template ⇄ Custom)
    var mode: SimuladoBuilderMode = .template

    // Lente (default herdado do profile)
    var lens: ContentOrganizationMode = .greatAreas

    // Filters (lente-aware) — igual QBank
    var groups: [QBankGroup] = []
    var institutions: [QBankInstitution] = []
    var difficulties: [QBankDifficultyStat] = []
    var totalQuestions: Int = 0

    // Seleções (modo Custom)
    var selectedGroupSlugs: Set<String> = []
    var selectedSubgroupIds: Set<String> = []
    var selectedInstitutionIds: Set<Int> = []
    var selectedDifficulties: Set<String> = []
    var selectedFormats: Set<String> = []
    var selectedYearMin: Int? = nil
    var selectedYearMax: Int? = nil

    // Cronômetro (visível, NÃO em Avançadas — spec §11.3)
    var timerEnabled: Bool = true
    var timerMinutes: Int = 60

    // Quantidade (defaults Simulado: [20,30,50,100])
    var questionCount: Int = 30

    // Template
    var templates: [SimuladoTemplateDTO] = []
    var selectedTemplateSlug: String? = nil

    // Hero stats
    var statsCompletedAttempts: Int = 0
    var statsAvgScore: Double = 0
    var statsTotalQuestions: Int = 0

    // Recents (attempts)
    var recentAttempts: [SimuladoAttemptEntry] = []
    var inProgressAttemptId: String? = nil

    // Preview live count (Custom)
    var previewCount: Int? = nil
    var previewLoading: Bool = false

    // Loading
    var screenLoading: Bool = true
    var filtersLoading: Bool = true
    var creatingSession: Bool = false
    var error: String? = nil

    var displayCount: Int {
        previewCount ?? totalQuestions
    }

    var hasActiveFilters: Bool {
        !selectedGroupSlugs.isEmpty
            || !selectedInstitutionIds.isEmpty
            || !selectedDifficulties.isEmpty
            || !selectedFormats.isEmpty
            || selectedYearMin != nil
            || selectedYearMax != nil
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class SimuladoBuilderViewModel {
    var state = SimuladoBuilderState()

    private let api: VitaAPI
    private let dataManager: AppDataManager

    private var previewTask: Task<Void, Never>?

    init(api: VitaAPI, dataManager: AppDataManager) {
        self.api = api
        self.dataManager = dataManager
    }

    // MARK: - Boot

    func boot() {
        if let mode = dataManager.profile?.contentOrganizationMode {
            state.lens = mode
        }
        Task { await loadAll() }
    }

    private func loadAll() async {
        state.screenLoading = true
        state.filtersLoading = true
        state.previewLoading = true
        async let screenTask: Void = loadScreen()
        async let filtersTask: Void = loadFilters()
        async let previewTask: Void = refreshPreview()
        _ = await (screenTask, filtersTask, previewTask)
        state.screenLoading = false
        state.filtersLoading = false
    }

    // MARK: - Screen BFF

    private func loadScreen() async {
        do {
            let resp: SimuladoScreenResponse = try await api.client.get("simulados/screen")
            state.recentAttempts = resp.attempts
            state.statsCompletedAttempts = resp.stats.completedAttempts
            state.statsAvgScore = resp.stats.avgScore
            state.statsTotalQuestions = resp.stats.totalQuestions
            state.templates = resp.templates
            state.inProgressAttemptId = resp.inProgress?.attemptId
            // Pre-select primeiro template oficial se nenhum escolhido
            if state.selectedTemplateSlug == nil, let first = resp.templates.first {
                state.selectedTemplateSlug = first.slug
            }
        } catch {
            NSLog("[SimuladoBuilder] loadScreen ERROR: %@", String(describing: error))
            // Fallback: tenta /api/simulados/templates direto + listSimulados pra recents.
            await loadTemplatesFallback()
            await loadAttemptsFallback()
        }
    }

    private func loadTemplatesFallback() async {
        do {
            let env: SimuladoTemplatesEnvelope = try await api.client.get("simulados/templates")
            state.templates = env.templates
            if state.selectedTemplateSlug == nil, let first = env.templates.first {
                state.selectedTemplateSlug = first.slug
            }
        } catch {
            NSLog("[SimuladoBuilder] loadTemplates fallback ERROR: %@", String(describing: error))
        }
    }

    private func loadAttemptsFallback() async {
        do {
            let resp = try await api.listSimulados()
            state.recentAttempts = resp.attempts
            state.statsCompletedAttempts = resp.stats.completedAttempts
            state.statsAvgScore = resp.stats.avgScore
            state.statsTotalQuestions = resp.stats.totalQuestions
        } catch {
            NSLog("[SimuladoBuilder] listSimulados fallback ERROR: %@", String(describing: error))
        }
    }

    // MARK: - Filters (Custom mode)

    private func loadFilters() async {
        do {
            let resp = try await api.getQBankFilters(lens: state.lens.rawValue)
            state.groups = resp.groups
            state.institutions = resp.institutions
            state.difficulties = resp.difficulties
            state.totalQuestions = resp.totalQuestions
        } catch {
            NSLog("[SimuladoBuilder] loadFilters ERROR: %@", String(describing: error))
        }
    }

    // MARK: - Mode toggle

    func setMode(_ mode: SimuladoBuilderMode) {
        guard state.mode != mode else { return }
        state.mode = mode
        if mode == .custom {
            scheduleRefreshPreview()
        }
    }

    // MARK: - Template

    func selectTemplate(slug: String) {
        state.selectedTemplateSlug = slug
    }

    // MARK: - Lens

    func setLens(_ lens: ContentOrganizationMode) {
        guard state.lens != lens else { return }
        state.lens = lens
        state.selectedGroupSlugs.removeAll()
        state.selectedSubgroupIds.removeAll()
        Task {
            await loadFilters()
            scheduleRefreshPreview()
        }
    }

    // MARK: - Filter mutations

    func toggleGroup(slug: String) {
        if state.selectedGroupSlugs.contains(slug) {
            state.selectedGroupSlugs.remove(slug)
            state.selectedSubgroupIds = state.selectedSubgroupIds.filter { !$0.hasPrefix("\(slug)/") }
        } else {
            state.selectedGroupSlugs.insert(slug)
        }
        scheduleRefreshPreview()
    }

    func toggleSubgroup(parentSlug: String, childSlug: String) {
        let id = "\(parentSlug)/\(childSlug)"
        if state.selectedSubgroupIds.contains(id) {
            state.selectedSubgroupIds.remove(id)
        } else {
            state.selectedSubgroupIds.insert(id)
            state.selectedGroupSlugs.insert(parentSlug)
        }
        scheduleRefreshPreview()
    }

    func toggleInstitution(id: Int) {
        if state.selectedInstitutionIds.contains(id) {
            state.selectedInstitutionIds.remove(id)
        } else {
            state.selectedInstitutionIds.insert(id)
        }
        scheduleRefreshPreview()
    }

    func toggleDifficulty(_ d: String) {
        if state.selectedDifficulties.contains(d) {
            state.selectedDifficulties.remove(d)
        } else {
            state.selectedDifficulties.insert(d)
        }
        scheduleRefreshPreview()
    }

    func toggleFormat(_ f: String) {
        if state.selectedFormats.contains(f) {
            state.selectedFormats.remove(f)
        } else {
            state.selectedFormats.insert(f)
        }
        scheduleRefreshPreview()
    }

    func clearAllFilters() {
        state.selectedGroupSlugs.removeAll()
        state.selectedSubgroupIds.removeAll()
        state.selectedInstitutionIds.removeAll()
        state.selectedDifficulties.removeAll()
        state.selectedFormats.removeAll()
        state.selectedYearMin = nil
        state.selectedYearMax = nil
        scheduleRefreshPreview()
    }

    // MARK: - Quantity / Timer

    func setQuestionCount(_ n: Int) { state.questionCount = max(1, min(200, n)) }

    func setTimerEnabled(_ on: Bool) { state.timerEnabled = on }
    func setTimerMinutes(_ min: Int) { state.timerMinutes = max(5, min) }

    // MARK: - Preview (debounced)

    func scheduleRefreshPreview() {
        previewTask?.cancel()
        previewTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            await self.refreshPreview()
        }
    }

    private func refreshPreview() async {
        // Preview só faz sentido em Custom; em Template o backend escolhe.
        guard state.mode == .custom else {
            state.previewCount = nil
            state.previewLoading = false
            return
        }
        state.previewLoading = true
        defer { state.previewLoading = false }

        let groupSlugsArr = Array(state.selectedGroupSlugs)
        let subgroupSlugs = state.selectedSubgroupIds.compactMap { id -> String? in
            id.split(separator: "/", maxSplits: 1).last.map(String.init)
        }
        let years: QBankPreviewYears? = (state.selectedYearMin == nil && state.selectedYearMax == nil)
            ? nil
            : QBankPreviewYears(min: state.selectedYearMin, max: state.selectedYearMax)

        let body = QBankPreviewBody(
            lens: state.lens.rawValue,
            groupSlugs: groupSlugsArr.nilIfEmpty,
            subgroupSlugs: subgroupSlugs.nilIfEmpty,
            institutionIds: Array(state.selectedInstitutionIds).nilIfEmpty,
            topicIds: nil,
            years: years,
            difficulties: Array(state.selectedDifficulties).nilIfEmpty,
            format: Array(state.selectedFormats).nilIfEmpty,
            hideAnswered: nil,
            hideAnnulled: nil,
            hideReviewed: nil,
            excludeNoExplanation: true,
            includeSynthetic: false
        )

        do {
            let resp = try await api.previewQBankPool(body: body)
            state.previewCount = resp.total
        } catch {
            state.previewCount = nil
        }
    }

    // MARK: - Create session

    /// Cria sessão. Template → POST /simulados/from-template.
    /// Custom → POST /simulados/generate (rota legacy ainda viva no backend).
    func createSession() async -> String? {
        state.creatingSession = true
        defer { state.creatingSession = false }

        switch state.mode {
        case .template:
            return await createFromTemplate()
        case .custom:
            return await createCustom()
        }
    }

    private func createFromTemplate() async -> String? {
        guard let slug = state.selectedTemplateSlug else {
            state.error = "Escolha um template antes de gerar"
            return nil
        }
        do {
            let resp: SimuladoFromTemplateResponse = try await api.client.post(
                "simulados/from-template",
                body: SimuladoFromTemplateBody(templateSlug: slug)
            )
            return resp.id
        } catch {
            NSLog("[SimuladoBuilder] from-template ERROR: %@", String(describing: error))
            state.error = "Não foi possível gerar simulado a partir do template"
            return nil
        }
    }

    private func createCustom() async -> String? {
        let subject = state.selectedGroupSlugs.first
            ?? state.selectedTemplateSlug
            ?? "Geral"
        let firstDifficulty = state.selectedDifficulties.first ?? "medium"
        let mode = state.timerEnabled ? "exam" : "immediate"

        do {
            let resp = try await api.generateSimulado(.init(
                subject: subject,
                difficulty: firstDifficulty,
                questionCount: state.questionCount,
                mode: mode,
                sourceDocumentIds: nil,
                courseId: nil
            ))
            return resp.id.isEmpty ? nil : resp.id
        } catch {
            NSLog("[SimuladoBuilder] generateSimulado ERROR: %@", String(describing: error))
            state.error = "Não foi possível gerar simulado custom"
            return nil
        }
    }
}

// MARK: - Helpers

private extension Array where Element: Hashable {
    var nilIfEmpty: [Element]? { isEmpty ? nil : self }
}

private extension Array where Element == String {
    var nilIfEmpty: [String]? { isEmpty ? nil : self }
}

private extension Array where Element == Int {
    var nilIfEmpty: [Int]? { isEmpty ? nil : self }
}
