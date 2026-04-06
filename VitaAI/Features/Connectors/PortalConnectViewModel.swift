import Foundation
import Observation

// MARK: - PortalConnectViewModel
// Unified ViewModel for the portal connect screen. Replaces 4 separate ViewModels:
// CanvasConnectViewModel, WebAlunoConnectViewModel, GoogleCalendarConnectViewModel, GoogleDriveConnectViewModel.
// Uses portalType to dispatch to the correct API calls.

@MainActor
@Observable
final class PortalConnectViewModel {
    let portalType: String

    // Common state
    var isLoading = true
    var isConnected = false
    var isSyncing = false
    var isConnecting = false
    var isDisconnecting = false
    var lastSync: String?
    var subtitle: String?       // email for Google, URL for portals
    var stats: [(value: Int, label: String)] = []
    var instanceUrl: String = ""
    var error: String?
    var successMessage: String?

    // Canvas-specific sync state
    var canvasSyncPhase: CanvasSyncOrchestrator.Phase = .starting
    var canvasSyncProgress: Double = 0
    var canvasSyncMessage: String?

    private let api: VitaAPI
    private var syncTask: Task<Void, Never>?

    init(portalType: String, api: VitaAPI) {
        self.portalType = portalType
        self.api = api
    }

    // MARK: - Display Config

    var displayName: String { PortalConnectConfig.displayName(for: portalType) }
    var icon: String { PortalConnectConfig.icon(for: portalType) }
    var connectedIcon: String { PortalConnectConfig.connectedIcon(for: portalType) }
    var disconnectedIcon: String { PortalConnectConfig.disconnectedIcon(for: portalType) }
    var howItWorks: [String] { PortalConnectConfig.howItWorks(for: portalType) }
    var isOAuth: Bool { portalType.hasPrefix("google_") }
    var isWebViewPortal: Bool { !isOAuth }

    // MARK: - Load Status

    func loadStatus() async {
        isLoading = true
        error = nil
        do {
            switch portalType {
            case "canvas":
                let status = try await api.getCanvasStatus()
                if let conn = status.canvasConnection, conn.status == "active" {
                    isConnected = true
                    if let url = conn.instanceUrl, !url.isEmpty { instanceUrl = url }
                    else { instanceUrl = "https://ulbra.instructure.com" }
                    lastSync = conn.lastSyncAt.flatMap { formatRelativeTime($0) }
                    stats = [
                        (conn.counts?.subjects ?? 0, "disciplinas"),
                        (conn.counts?.evaluations ?? 0, "avaliacoes"),
                        (conn.counts?.documents ?? 0, "arquivos"),
                    ]
                } else {
                    isConnected = false
                    instanceUrl = "https://ulbra.instructure.com"
                }

            case "webaluno", "mannesoft":
                let resp = try await api.getWebalunoStatus()
                isConnected = resp.connected
                instanceUrl = resp.connection?.instanceUrl ?? ""
                lastSync = resp.connection?.lastSyncAt.flatMap { formatRelativeTime($0) }
                stats = [
                    (resp.counts?.grades ?? 0, "notas"),
                    (resp.counts?.schedule ?? 0, "aulas"),
                    (resp.counts?.semesters ?? 0, "semestres"),
                ]

            case "google_calendar":
                let data = try await api.getGoogleCalendarStatus()
                isConnected = data.connected
                subtitle = data.googleEmail
                lastSync = data.lastSyncAt.flatMap { formatRelativeTime($0) }
                stats = [(data.counts?.events ?? 0, "eventos")]

            case "google_drive":
                let data = try await api.getGoogleDriveStatus()
                isConnected = data.connected
                subtitle = data.googleEmail
                lastSync = data.lastSyncAt.flatMap { formatRelativeTime($0) }
                stats = [(data.counts?.files ?? 0, "arquivos")]

            default:
                isConnected = false
            }
        } catch {
            isConnected = false
        }
        isLoading = false
    }

    // MARK: - Connect WebAluno (server-side crawl)

    func connectWebaluno(cookie: String) {
        Task {
            isConnecting = true
            error = nil
            successMessage = nil
            do {
                let url = instanceUrl.isEmpty ? "https://ac3949.mannesoftprime.com.br" : instanceUrl
                let crawlResult = try await api.startVitaCrawl(cookies: cookie, instanceUrl: url)
                isConnecting = false
                isConnected = true
                successMessage = "Vita extraindo dados do portal..."
                if let syncId = crawlResult.syncId, !syncId.isEmpty {
                    for _ in 0..<60 {
                        try await Task.sleep(for: .seconds(2))
                        let progress = try await api.getSyncProgress(syncId: syncId)
                        successMessage = (progress.label ?? "").isEmpty ? "Vita trabalhando..." : (progress.label ?? "")
                        if progress.isDone {
                            successMessage = "Extracao completa!"
                            await loadStatus()
                            return
                        }
                        if progress.isError {
                            error = (progress.label ?? "").isEmpty ? "Erro na extracao" : (progress.label ?? "")
                            return
                        }
                    }
                    successMessage = "Vita continua em background..."
                }
            } catch {
                isConnecting = false
                self.error = "Erro de conexao. Verifique sua internet."
            }
        }
    }

    // MARK: - Connect Canvas (on-device orchestrator)

    func connectCanvas(cookies: String, instanceUrl: String) {
        syncTask?.cancel()
        syncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSyncing = true
            self.error = nil
            self.canvasSyncPhase = .starting
            self.canvasSyncProgress = 0
            self.canvasSyncMessage = CanvasSyncOrchestrator.Phase.starting.rawValue

            let orchestrator = CanvasSyncOrchestrator(
                cookies: cookies,
                instanceUrl: instanceUrl,
                vitaAPI: api,
                onProgress: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.canvasSyncPhase = progress.phase
                        self.canvasSyncProgress = progress.percent
                        if let detail = progress.detail {
                            self.canvasSyncMessage = "\(progress.phase.rawValue) \(detail)"
                        } else {
                            self.canvasSyncMessage = progress.phase.rawValue
                        }
                    }
                }
            )

            do {
                let result = try await orchestrator.run()
                try Task.checkCancellation()
                self.isSyncing = false
                self.isConnected = true
                self.canvasSyncPhase = .done
                let summary = [
                    result.courses.map { "\($0) disciplinas" },
                    result.assignments.map { "\($0) atividades" },
                    result.pdfExtracted.map { "\($0) PDFs processados" },
                ].compactMap { $0 }.joined(separator: ", ")
                self.successMessage = summary.isEmpty ? "Extracao completa!" : "Pronto! \(summary)"
                await self.loadStatus()
            } catch is CancellationError {
                // cancelled
            } catch {
                self.isSyncing = false
                self.canvasSyncPhase = .error
                self.error = "Erro: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Sync

    func sync() {
        Task {
            isSyncing = true
            error = nil
            successMessage = nil
            do {
                switch portalType {
                case "canvas":
                    _ = try await api.syncCanvas()
                case "webaluno", "mannesoft":
                    let result = try await api.syncWebaluno()
                    if !result.success {
                        isSyncing = false
                        error = result.error ?? "Falha na sincronizacao"
                        return
                    }
                    successMessage = "Sincronizado: \(result.grades) notas, \(result.schedule) aulas"
                case "google_calendar":
                    let result = try await api.syncGoogleCalendar()
                    let count = result.events > 0 ? result.events : result.synced
                    successMessage = "Sincronizado: \(count) eventos"
                case "google_drive":
                    let result = try await api.syncGoogleDrive()
                    let count = result.files > 0 ? result.files : result.synced
                    successMessage = "Sincronizado: \(count) arquivo(s)"
                default: break
                }
                isSyncing = false
                await loadStatus()
            } catch {
                isSyncing = false
                self.error = "Falha na sincronizacao"
            }
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        Task {
            isDisconnecting = true
            error = nil
            successMessage = nil
            do {
                switch portalType {
                case "canvas":
                    try await api.disconnectCanvas()
                case "webaluno", "mannesoft":
                    try await api.disconnectWebaluno()
                case "google_calendar":
                    try await api.disconnectGoogleCalendar()
                case "google_drive":
                    try await api.disconnectGoogleDrive()
                default: break
                }
                isDisconnecting = false
                isConnected = false
                stats = []
                lastSync = nil
                subtitle = nil
                successMessage = "\(displayName) desconectado"
            } catch {
                isDisconnecting = false
                self.error = "Falha ao desconectar"
            }
        }
    }

    // MARK: - OAuth URL (Google services)

    func oauthURL() -> URL? {
        switch portalType {
        case "google_calendar":
            return URL(string: "\(AppConfig.apiBaseURL)/google/calendar/authorize")
        case "google_drive":
            return URL(string: "\(AppConfig.apiBaseURL)/google/drive/authorize")
        default:
            return nil
        }
    }

    // MARK: - Dismiss

    func dismissMessages() {
        error = nil
        successMessage = nil
    }

    // MARK: - Helpers

    private func formatRelativeTime(_ isoDate: String) -> String? {
        var date: Date?
        let fullFmt = ISO8601DateFormatter()
        fullFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        date = fullFmt.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate)
        guard let date else { return nil }
        let minutes = Int(Date().timeIntervalSince(date) / 60)
        if minutes < 1  { return "agora" }
        if minutes < 60 { return "\(minutes)min atras" }
        let hours = minutes / 60
        if hours < 24   { return "\(hours)h atras" }
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM"
        fmt.locale = Locale(identifier: "pt_BR")
        return fmt.string(from: date)
    }
}

// MARK: - Portal Config (display metadata)

enum PortalConnectConfig {
    static func displayName(for type: String) -> String {
        switch type {
        case "canvas": "Canvas LMS"
        case "webaluno", "mannesoft": "WebAluno"
        case "google_calendar": "Google Calendar"
        case "google_drive": "Google Drive"
        case "moodle": "Moodle"
        case "sigaa": "SIGAA"
        case "totvs": "TOTVS RM"
        case "lyceum": "Lyceum"
        case "sagres": "Sagres"
        case "blackboard": "Blackboard"
        case "platos": "Platos"
        default: University.displayName(for: type)
        }
    }

    static func icon(for type: String) -> String {
        switch type {
        case "canvas": "building.columns"
        case "webaluno", "mannesoft": "graduationcap"
        case "google_calendar": "calendar"
        case "google_drive": "externaldrive"
        case "moodle": "book.closed"
        case "sigaa": "doc.text"
        default: "link"
        }
    }

    static func connectedIcon(for type: String) -> String {
        switch type {
        case "canvas": "cloud.fill"
        case "webaluno", "mannesoft": "cloud.fill"
        case "google_calendar": "calendar.badge.checkmark"
        case "google_drive": "externaldrive.fill.badge.checkmark"
        default: "checkmark.circle.fill"
        }
    }

    static func disconnectedIcon(for type: String) -> String {
        switch type {
        case "canvas": "cloud.slash.fill"
        case "webaluno", "mannesoft": "cloud.slash.fill"
        case "google_calendar": "calendar.badge.exclamationmark"
        case "google_drive": "externaldrive.badge.exclamationmark"
        default: "xmark.circle"
        }
    }

    static func howItWorks(for type: String) -> [String] {
        switch type {
        case "canvas":
            return [
                "Disciplinas, arquivos e atividades importados",
                "Planos de ensino processados pela IA Vita",
                "Eventos do calendario na sua agenda",
                "Sincronize quando quiser dados atualizados",
            ]
        case "webaluno", "mannesoft":
            return [
                "Notas parciais e finais aparecem em Insights",
                "Grade horaria aparece na sua Agenda",
                "Sessao pode expirar — reconecte se necessario",
            ]
        case "google_calendar":
            return [
                "Eventos e compromissos importados do seu Google Calendar",
                "Provas e deadlines aparecem na sua Agenda no VitaAI",
                "Sincronizacao segura via OAuth — sem armazenar sua senha",
                "Sincronize sempre que quiser dados atualizados",
            ]
        case "google_drive":
            return [
                "Arquivos PDF do seu Drive importados para o VitaAI",
                "PDFs processados para gerar flashcards e resumos com IA",
                "Sincronizacao segura via OAuth — sem armazenar sua senha",
                "Sincronize sempre que quiser dados atualizados",
            ]
        default:
            return [
                "Dados academicos importados automaticamente",
                "Notas e horarios sincronizados com VitaAI",
            ]
        }
    }
}
