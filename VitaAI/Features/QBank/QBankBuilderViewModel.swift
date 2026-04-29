import Foundation
import Observation

// MARK: - QBankBuilderViewModel — Fase 3 reescrita gold-standard
//
// Substitui QBankViewModel + QBankHomeContent + QBankConfigContent.
// State único pra tela Builder: Hero + Lente + Filtros + Recents + CTA.
// SOT: agent-brain/specs/2026-04-28_estudos-3-paginas-spec.md §6
//
// API:
//  - GET  /api/qbank/filters?lens=  → groups + institutions + topics + years + difficulties
//  - POST /api/qbank/preview        → count dinâmico (debounced 300ms)
//  - GET  /api/qbank/progress       → hero stats
//  - GET  /api/qbank/sessions       → recentes
//  - POST /api/qbank/sessions       → cria sessão e navega

// MARK: - State

struct QBankBuilderState {
    // Lente
    var lens: ContentOrganizationMode = .greatAreas

    // Filters carregados do backend (lens-aware)
    var groups: [QBankGroup] = []
    var institutions: [QBankInstitution] = []
    var years: [Int] = []
    var difficulties: [QBankDifficultyStat] = []
    var totalQuestions: Int = 0
    var stage: String? = nil

    // Seleções do user
    var selectedGroupSlugs: Set<String> = []
    /// Slugs do level 2 (clusters PBL ou topic IDs Tradicional). Composto
    /// como "parent/child" pra permitir mesmo cluster em múltiplos sistemas.
    var selectedSubgroupIds: Set<String> = []  // formato: "parentSlug/childSlug"
    /// Sistemas/disciplinas com children expandidos na UI.
    var expandedGroupSlugs: Set<String> = []
    var selectedInstitutionIds: Set<Int> = []
    var selectedYearMin: Int? = nil
    var selectedYearMax: Int? = nil
    var selectedDifficulties: Set<String> = []
    var selectedFormats: Set<String> = []  // 'objective' | 'discursive' | 'withImage'

    // Toggles avançadas
    var hideAnswered: Bool = false
    var hideAnnulled: Bool = false
    var hideReviewed: Bool = false
    var excludeNoExplanation: Bool = true
    var includeSynthetic: Bool = false  // default false: oficial only

    // Configuração da sessão
    var questionCount: Int = 20
    var mode: QBankMode = .pratica

    // Preview live count
    var previewCount: Int? = nil
    var previewLoading: Bool = false

    // Hero (progress)
    var progressTotal: Int = 0
    var progressAnswered: Int = 0
    var progressAccuracy: Double = 0.0

    // Recents
    var recentSessions: [QBankSessionSummary] = []

    // Loading flags
    var filtersLoading: Bool = true
    var creatingSession: Bool = false
    var error: String? = nil

    /// Display count: prefere preview live; fallback `totalQuestions` da última carga.
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
            || hideAnswered || hideAnnulled || hideReviewed
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class QBankBuilderViewModel {
    var state = QBankBuilderState()

    private let api: VitaAPI
    private let dataManager: AppDataManager

    /// Debounce de preview (cancela request anterior se user mexer rápido).
    private var previewTask: Task<Void, Never>?

    init(api: VitaAPI, dataManager: AppDataManager) {
        self.api = api
        self.dataManager = dataManager
    }

    // MARK: - Boot

    /// Hidrata lente do profile + carrega filters + progress + recents em paralelo.
    func boot() {
        if let mode = dataManager.profile?.contentOrganizationMode {
            state.lens = mode
        }
        Task { await loadAll() }
    }

    private func loadAll() async {
        state.filtersLoading = true
        async let filters = loadFilters()
        async let progress = loadProgress()
        async let recents = loadRecents()
        _ = await (filters, progress, recents)
        state.filtersLoading = false
        // Após carga, dispara preview inicial pra hidratar count com filtros vazios
        scheduleRefreshPreview()
    }

    // MARK: - Filters

    func loadFilters() async {
        do {
            let resp = try await api.getQBankFilters(lens: state.lens.rawValue)
            NSLog("[QBankBuilder] loadFilters lens=%@ groups=%d insts=%d total=%d",
                  state.lens.rawValue,
                  resp.groups.count,
                  resp.institutions.count,
                  resp.totalQuestions)
            if let first = resp.groups.first {
                NSLog("[QBankBuilder] first group: %@ (%d Q)", first.name, first.count)
            }
            state.groups = resp.groups
            state.institutions = resp.institutions
            state.years = resp.years
            state.difficulties = resp.difficulties
            state.totalQuestions = resp.totalQuestions
            state.stage = resp.lens // echo da lente aplicada
        } catch {
            NSLog("[QBankBuilder] loadFilters ERROR: %@", String(describing: error))
            state.error = "Não foi possível carregar filtros"
        }
    }

    private func loadProgress() async {
        do {
            let resp = try await api.getQBankProgress(disciplineSlugs: [])
            state.progressTotal = resp.totalAvailable
            state.progressAnswered = resp.totalAnswered
            state.progressAccuracy = resp.normalizedAccuracy
        } catch {
            print("[QBankBuilder] loadProgress: \(error)")
        }
    }

    private func loadRecents() async {
        do {
            let resp = try await api.getQBankSessions(limit: 5)
            state.recentSessions = resp.sessions
        } catch {
            print("[QBankBuilder] loadRecents: \(error)")
        }
    }

    // MARK: - Lens

    func setLens(_ lens: ContentOrganizationMode) {
        guard state.lens != lens else { return }
        state.lens = lens
        // Reset slugs antigos (não fazem sentido na nova lente)
        state.selectedGroupSlugs.removeAll()
        Task {
            await loadFilters()
            scheduleRefreshPreview()
        }
    }

    // MARK: - Filters mutations

    func toggleGroup(slug: String) {
        if state.selectedGroupSlugs.contains(slug) {
            state.selectedGroupSlugs.remove(slug)
            // Ao desselecionar group, derruba subgroups dele
            state.selectedSubgroupIds = state.selectedSubgroupIds.filter { !$0.hasPrefix("\(slug)/") }
        } else {
            state.selectedGroupSlugs.insert(slug)
        }
        scheduleRefreshPreview()
    }

    func toggleExpand(slug: String) {
        if state.expandedGroupSlugs.contains(slug) {
            state.expandedGroupSlugs.remove(slug)
        } else {
            state.expandedGroupSlugs.insert(slug)
        }
    }

    /// Toggla um subgroup (cluster/topic). Auto-seleciona o group pai se ainda não.
    func toggleSubgroup(parentSlug: String, childSlug: String) {
        let id = "\(parentSlug)/\(childSlug)"
        if state.selectedSubgroupIds.contains(id) {
            state.selectedSubgroupIds.remove(id)
        } else {
            state.selectedSubgroupIds.insert(id)
            // Auto-seleciona pai
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

    func setYearRange(min: Int?, max: Int?) {
        state.selectedYearMin = min
        state.selectedYearMax = max
        scheduleRefreshPreview()
    }

    func setHideAnswered(_ v: Bool) { state.hideAnswered = v; scheduleRefreshPreview() }
    func setHideAnnulled(_ v: Bool) { state.hideAnnulled = v; scheduleRefreshPreview() }
    func setHideReviewed(_ v: Bool) { state.hideReviewed = v; scheduleRefreshPreview() }
    func setExcludeNoExplanation(_ v: Bool) { state.excludeNoExplanation = v; scheduleRefreshPreview() }
    func setIncludeSynthetic(_ v: Bool) { state.includeSynthetic = v; scheduleRefreshPreview() }

    func setQuestionCount(_ n: Int) { state.questionCount = max(1, min(100, n)) }
    func setMode(_ m: QBankMode) { state.mode = m }

    func clearAllFilters() {
        state.selectedGroupSlugs.removeAll()
        state.selectedInstitutionIds.removeAll()
        state.selectedDifficulties.removeAll()
        state.selectedFormats.removeAll()
        state.selectedYearMin = nil
        state.selectedYearMax = nil
        state.hideAnswered = false
        state.hideAnnulled = false
        state.hideReviewed = false
        scheduleRefreshPreview()
    }

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
        state.previewLoading = true
        defer { state.previewLoading = false }

        let groupSlugsArr = Array(state.selectedGroupSlugs)
        NSLog("[QBankBuilder] preview body lens=%@ groupSlugs=%@ insts=%@ diffs=%@",
              state.lens.rawValue,
              String(describing: groupSlugsArr),
              String(describing: Array(state.selectedInstitutionIds)),
              String(describing: Array(state.selectedDifficulties)))

        // subgroupSlugs: extrair só o childSlug do "parent/child" composto
        let subgroupSlugs = state.selectedSubgroupIds.compactMap { id -> String? in
            id.split(separator: "/", maxSplits: 1).last.map(String.init)
        }

        let body = QBankPreviewBody(
            lens: state.lens.rawValue,
            groupSlugs: groupSlugsArr.nilIfEmpty,
            subgroupSlugs: subgroupSlugs.nilIfEmpty,
            institutionIds: Array(state.selectedInstitutionIds).nilIfEmpty,
            topicIds: nil,
            years: yearsBody(),
            difficulties: Array(state.selectedDifficulties).nilIfEmpty,
            format: Array(state.selectedFormats).nilIfEmpty,
            hideAnswered: state.hideAnswered ? true : nil,
            hideAnnulled: state.hideAnnulled ? true : nil,
            hideReviewed: state.hideReviewed ? true : nil,
            excludeNoExplanation: state.excludeNoExplanation,
            includeSynthetic: state.includeSynthetic
        )

        do {
            let resp = try await api.previewQBankPool(body: body)
            NSLog("[QBankBuilder] preview RESPONSE total=%d", resp.total)
            state.previewCount = resp.total
        } catch {
            NSLog("[QBankBuilder] preview ERROR: %@", String(describing: error))
            state.previewCount = nil
        }
    }

    private func yearsBody() -> QBankPreviewYears? {
        if state.selectedYearMin == nil && state.selectedYearMax == nil { return nil }
        return QBankPreviewYears(min: state.selectedYearMin, max: state.selectedYearMax)
    }

    // MARK: - Create session

    /// Cria sessão com filtros aplicados. Retorna sessionId pra navegação.
    func createSession() async -> String? {
        state.creatingSession = true
        defer { state.creatingSession = false }

        let req = QBankCreateSessionRequest(
            questionCount: state.questionCount,
            institutionIds: Array(state.selectedInstitutionIds).nilIfEmpty,
            years: nil,
            difficulties: Array(state.selectedDifficulties).nilIfEmpty,
            topicIds: nil,
            disciplineIds: nil,
            disciplineSlugs: state.lens == .tradicional ? Array(state.selectedGroupSlugs).nilIfEmpty : nil,
            onlyResidence: nil,
            onlyUnanswered: state.hideAnswered ? true : nil,
            title: nil,
            status: nil,
            excludeNoExplanation: state.excludeNoExplanation,
            includeSynthetic: state.includeSynthetic
        )

        do {
            let session = try await api.createQBankSession(request: req)
            return session.id
        } catch {
            print("[QBankBuilder] createSession: \(error)")
            state.error = "Não foi possível iniciar a sessão"
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
