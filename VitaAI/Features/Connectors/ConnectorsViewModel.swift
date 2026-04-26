import Foundation
import UIKit
import SafariServices
import Observation

// MARK: - ConnectorsViewModel
// Unified state for all portal connections, used by ConnectionsScreen.

@MainActor
@Observable
final class ConnectorsViewModel {
    // Per-connector state — academic
    var canvas = ConnectorState(id: "canvas", name: "Canvas LMS")
    var mannesoft = ConnectorState(id: "mannesoft", name: "Portal Academico")

    // Per-connector state — productivity
    var calendar = ConnectorState(id: "google_calendar", name: "Google Calendar")
    var drive = ConnectorState(id: "google_drive", name: "Google Drive")
    var spotify = ConnectorState(id: "spotify", name: "Spotify")
    var appleHealth = ConnectorState(id: "apple_health", name: "Apple Health")
    var whatsapp = ConnectorState(id: "whatsapp", name: "WhatsApp")

    // University data
    var universityPortals: [UniversityPortal] = []
    var universityName: String = ""
    var universityCity: String = ""

    // Toast
    var toastMessage: String?
    var toastType: VitaToastType = .success

    private let api: VitaAPI
    private weak var dataManager: AppDataManager?

    // SFSafariViewController apresentado para OAuth in-app (Spotify, Google Drive,
    // Google Calendar). Guardado pra poder dismissar quando o deep link callback
    // (vitaai://integrations/done) volta — SafariViewController não fecha sozinho
    // como ASWebAuthenticationSession faria.
    private weak var presentedOAuthSafari: SFSafariViewController?

    init(api: VitaAPI, dataManager: AppDataManager? = nil) {
        self.api = api
        self.dataManager = dataManager
        // Listen pro callback de OAuth completar (postado pelo AppRouter quando
        // recebe o deep link vitaai://integrations/done?provider=X).
        NotificationCenter.default.addObserver(
            forName: .integrationOAuthCompleted,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                self?.dismissOAuthSheet()
                if let provider = note.object as? String {
                    self?.toastMessage = "\(provider.capitalized) conectado"
                    self?.toastType = .success
                }
                await self?.loadAll()
            }
        }
    }

    @MainActor
    private func dismissOAuthSheet() {
        presentedOAuthSafari?.dismiss(animated: true)
        presentedOAuthSafari = nil
    }

    // MARK: - All integration connectors

    var allIntegrations: [ConnectorState] {
        [calendar, drive, spotify, appleHealth, whatsapp]
    }

    // MARK: - Computed

    var connectedCount: Int {
        ([canvas, mannesoft] + allIntegrations).filter { $0.status == .connected }.count
    }

    var totalPortals: Int {
        2 + allIntegrations.count
    }

    func state(for portalId: String) -> ConnectorState {
        switch portalId {
        case "canvas": canvas
        case "webaluno", "mannesoft": mannesoft
        case "google_calendar": calendar
        case "google_drive": drive
        case "spotify": spotify
        case "apple_health": appleHealth
        case "whatsapp": whatsapp
        default: ConnectorState(id: portalId, name: portalId)
        }
    }

    // MARK: - Load All

    func loadAll() async {
        await loadUniversityPortals()
        await loadPortalConnections()
        await loadIntegrations()
    }

    // MARK: - University Portals

    private func loadUniversityPortals() async {
        do {
            // Reuse the cached profile from AppDataManager when present —
            // avoids an extra /api/profile round-trip every time the user
            // opens the connectors sheet.
            let profile: ProfileResponse
            if let cached = dataManager?.profile {
                profile = cached
            } else {
                profile = try await api.getProfile()
            }
            let uniId = profile.universityId
            let uniName = profile.university
            guard let uniId, !uniId.isEmpty else { return }

            let query = uniName ?? ""
            let response = try await api.getUniversities(query: query)
            if let uni = response.universities.first(where: { $0.id == uniId }) {
                universityName = uni.shortName.isEmpty ? uni.name : uni.shortName
                universityCity = uni.city
                if let portals = uni.portals, !portals.isEmpty {
                    universityPortals = portals
                }
            } else if let uniName, !uniName.isEmpty {
                universityName = uniName
            }
        } catch {
            print("[Connectors] University portals load failed: \(error)")
        }
    }

    // MARK: - Portal Connections (Canvas + Mannesoft via single endpoint)

    func loadPortalConnections() async {
        do {
            let data = try await api.getCanvasStatus()
            guard let connections = data.connections, !connections.isEmpty else {
                canvas.status = .disconnected
                mannesoft.status = .disconnected
                return
            }

            for conn in connections {
                let status: ConnectionItemStatus = switch conn.status {
                case "expired": .expired
                case "inactive", "disconnected": .disconnected
                default: .connected
                }

                // Separamos os dois conceitos:
                // lastSyncAt  = última vez que dados foram extraídos com êxito
                // lastPingAt  = última vez que o token/sessão foi verificado vivo (keep-alive)
                // Se sync > 12h, card vira "stale" mesmo com status=connected.
                let syncRelative = conn.lastSyncAt.flatMap { formatRelativeTime($0) }
                let pingRelative = conn.lastPingAt.flatMap { formatRelativeTime($0) }
                let syncAbsolute = conn.lastSyncAt.flatMap { formatAbsoluteTime($0) }
                let stale = isStale(conn.lastSyncAt)
                // So mostra "Token vivo" se status=connected E ping for MAIS RECENTE que sync.
                // Se sync > ping, o ping antigo e irrelevante (acabou de reconectar).
                // Quando expired, token NAO e vivo — nunca mostrar.
                let pingNewerThanSync: Bool = {
                    guard let pingDate = conn.lastPingAt.flatMap({ parseISO($0) }),
                          let syncDate = conn.lastSyncAt.flatMap({ parseISO($0) }) else { return true }
                    return pingDate > syncDate
                }()
                let pingDifferent = status == .connected && pingRelative != nil && pingRelative != syncRelative && pingNewerThanSync

                switch conn.portalType {
                case "canvas":
                    canvas.status = status
                    canvas.lastSync = syncRelative ?? pingRelative
                    canvas.lastPing = pingDifferent ? pingRelative : nil
                    canvas.lastSyncAbsolute = syncAbsolute
                    canvas.isStale = stale
                    canvas.instanceUrl = conn.instanceUrl
                    canvas.stats = [
                        (conn.counts?.subjects ?? 0, "matérias"),
                        (conn.counts?.evaluations ?? 0, "atividades"),
                        (conn.counts?.documents ?? 0, "arquivos"),
                    ]
                case "mannesoft":
                    mannesoft.status = status
                    mannesoft.lastSync = syncRelative ?? pingRelative
                    mannesoft.lastPing = pingDifferent ? pingRelative : nil
                    mannesoft.lastSyncAbsolute = syncAbsolute
                    mannesoft.isStale = stale
                    mannesoft.instanceUrl = conn.instanceUrl
                    mannesoft.stats = [
                        (conn.counts?.subjects ?? 0, "matérias"),
                        (conn.counts?.evaluations ?? 0, "notas"),
                        (conn.counts?.schedule ?? 0, "aulas"),
                    ]
                default:
                    break
                }
            }

            if canvas.status == .expired, let url = canvas.instanceUrl, !url.isEmpty {
                NSLog("[Connectors] Canvas expired — triggering silent reauth")
                // Keep showing "expired" while trying — don't mask with "loading"
                Task {
                    let success = await CanvasSilentReauth.shared.forceReauth(instanceUrl: url, api: api)
                    if success {
                        await loadPortalConnections()
                    }
                    // If failed, status stays .expired (already set)
                }
            }
        } catch {
            print("[Connectors] Portal status load failed: \(error)")
        }
    }

    // MARK: - Load Integrations (unified endpoint)

    private func loadIntegrations() async {
        // Load Google Calendar & Drive via existing specific endpoints
        async let cal = loadCalendar()
        async let drv = loadDrive()
        async let wa = loadWhatsAppStatus()
        _ = await (cal, drv, wa)

        // Spotify, Apple Health: load from unified /api/integrations
        do {
            let data = try await api.getIntegrations()
            for item in data.productivity {
                switch item.id {
                case "spotify":
                    spotify.status = connectionStatus(from: item.status)
                    spotify.lastSync = item.lastSyncAt.flatMap { formatRelativeTime($0) }
                case "apple_health":
                    appleHealth.status = connectionStatus(from: item.status)
                    appleHealth.lastSync = item.lastSyncAt.flatMap { formatRelativeTime($0) }
                default: break
                }
            }
        } catch {
            print("[Connectors] Integrations load failed: \(error)")
        }
    }

    // MARK: - WhatsApp

    func loadWhatsAppStatus() async {
        do {
            let data = try await api.getWhatsAppStatus()
            if data.verified, data.phone != nil {
                whatsapp.status = .connected
                whatsapp.subtitle = Self.formatPhone(data.phone)
            } else {
                whatsapp.status = .disconnected
                whatsapp.subtitle = nil
            }
        } catch {
            whatsapp.status = .disconnected
        }
    }

    func linkWhatsApp(phone: String) async throws {
        try await api.linkWhatsApp(phone: phone)
    }

    func verifyWhatsApp(code: String) async throws {
        let result = try await api.verifyWhatsApp(code: code)
        if result.verified {
            await loadWhatsAppStatus()
        }
    }

    private func connectionStatus(from status: String) -> ConnectionItemStatus {
        switch status {
        case "active", "connected": .connected
        case "expired": .expired
        default: .disconnected
        }
    }

    // MARK: - Google Calendar

    private func loadCalendar() async {
        do {
            let data = try await api.getGoogleCalendarStatus()
            if data.connected {
                calendar.status = data.status == "expired" ? .expired : .connected
                calendar.lastSync = data.lastSyncAt.flatMap { formatRelativeTime($0) }
                calendar.stats = [(data.counts?.events ?? 0, "eventos")]
                calendar.subtitle = data.googleEmail
            } else {
                calendar.status = .disconnected
            }
        } catch {
            calendar.status = .disconnected
        }
    }

    // MARK: - Google Drive

    private func loadDrive() async {
        do {
            let data = try await api.getGoogleDriveStatus()
            if data.connected {
                drive.status = data.status == "expired" ? .expired : .connected
                drive.lastSync = data.lastSyncAt.flatMap { formatRelativeTime($0) }
                drive.stats = [(data.counts?.files ?? 0, "arquivos")]
                drive.subtitle = data.googleEmail
            } else {
                drive.status = .disconnected
            }
        } catch {
            drive.status = .disconnected
        }
    }

    // MARK: - Disconnect

    func disconnect(_ connectorId: String) async {
        do {
            switch connectorId {
            case "canvas":
                try await api.disconnectCanvas()
                canvas = ConnectorState(id: "canvas", name: "Canvas LMS")
            case "webaluno", "mannesoft":
                try await api.disconnectPortal()
                mannesoft = ConnectorState(id: "mannesoft", name: "Portal Academico")
            case "google_calendar":
                try await api.disconnectIntegration("google_calendar")
                calendar = ConnectorState(id: "google_calendar", name: "Google Calendar")
            case "google_drive":
                try await api.disconnectIntegration("google_drive")
                drive = ConnectorState(id: "google_drive", name: "Google Drive")
            case "spotify":
                try await api.disconnectIntegration("spotify")
                spotify = ConnectorState(id: "spotify", name: "Spotify")
            case "apple_health":
                appleHealth = ConnectorState(id: "apple_health", name: "Apple Health")
            case "whatsapp":
                try await api.unlinkWhatsApp()
                whatsapp = ConnectorState(id: "whatsapp", name: "WhatsApp")
            default: break
            }
            toastMessage = "Desconectado"
            toastType = .success
        } catch {
            print("[Connectors] Disconnect \(connectorId) error: \(error)")
            toastMessage = "Erro ao desconectar"
            toastType = .error
        }
    }

    // MARK: - Connect

    func connectAppleHealth() async {
        let hk = HealthKitManager.shared
        guard hk.isAvailable else {
            toastMessage = "Apple Health não disponível neste dispositivo"
            toastType = .error
            return
        }
        let granted = await hk.requestAuthorization()
        if granted {
            appleHealth.status = .connected
            async let sleepTask = hk.fetchSleepData()
            async let stepsTask = hk.fetchSteps()
            async let exerciseTask = hk.fetchExerciseMinutes()
            let (sleep, steps, exerciseMin) = await (sleepTask, stepsTask, exerciseTask)
            let totalSleepHours = sleep.reduce(0.0) { $0 + $1.hours }
            let totalSteps = steps.reduce(0) { $0 + $1.count }
            appleHealth.stats = [
                (Int(totalSleepHours), "h sono (7d)"),
                (totalSteps, "passos (7d)"),
                (Int(exerciseMin), "min exercicio"),
            ]
            appleHealth.lastSync = "agora"
            toastMessage = "Apple Health conectado!"
            toastType = .success
        } else {
            toastMessage = "Permissao negada"
            toastType = .error
        }
    }

    /// Apresenta SFSafariViewController in-app pro OAuth do provider (Spotify,
    /// Google Calendar, Google Drive). Cookies persistem no view: user loga
    /// 1x e nas próximas reconexões cai direto no "Authorize". Quando o
    /// backend retorna `vitaai://integrations/done`, o iOS abre o app e o
    /// observer de `integrationOAuthCompleted` dismissa a sheet.
    func connectIntegration(_ connectorId: String) async {
        do {
            let data = try await api.startIntegrationOAuth(connectorId)
            guard let authUrl = data.authUrl, let url = URL(string: authUrl) else { return }
            await MainActor.run { presentSafari(url: url) }
        } catch {
            toastMessage = "Erro ao conectar"
            toastType = .error
        }
    }

    @MainActor
    private func presentSafari(url: URL) {
        guard
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let root = scene.windows.first?.rootViewController
        else { return }
        // If something is already on top (e.g. a sheet), present from that.
        let presenter = root.presentedViewController ?? root
        let config = SFSafariViewController.Configuration()
        config.barCollapsingEnabled = true
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = UIColor(VitaColors.accent)
        safari.dismissButtonStyle = .cancel
        safari.modalPresentationStyle = .pageSheet
        presentedOAuthSafari = safari
        presenter.present(safari, animated: true)
    }

    // MARK: - Connect Mannesoft portal with session

    func connectMannesoft(cookie: String) async {
        do {
            toastMessage = "Conectando portal..."
            toastType = .success
            mannesoft.status = .connected
            let portalUrl = universityPortals.first(where: { $0.portalType == "webaluno" || $0.portalType == "mannesoft" })?.instanceUrl ?? ""
            let _ = try await api.startVitaCrawl(
                cookies: "PHPSESSID=\(cookie)",
                instanceUrl: portalUrl
            )
            toastMessage = "Portal conectado! Extraindo dados..."
            toastType = .success
            // Trigger SilentSync immediately — server-side can't fetch Mannesoft
            // (no Cloudflare cf_clearance), so extraction must happen client-side
            // via WKWebView + bridge.js
            SilentPortalSync.shared.syncIfNeeded(api: api)
            await loadPortalConnections()
        } catch {
            print("[Connectors] Portal connect error: \(error)")
            toastMessage = "Erro ao conectar: \(error.localizedDescription)"
            toastType = .error
        }
    }

    // MARK: - Sync

    func syncCanvas() async {
        guard let instanceUrl = canvas.instanceUrl else {
            toastMessage = "Para re-sincronizar, reconecte ao Canvas"
            toastType = .success
            return
        }

        canvas.status = .loading
        toastMessage = "Reconectando ao Canvas..."
        toastType = .success

        let success = await CanvasSilentReauth.shared.forceReauth(instanceUrl: instanceUrl, api: api)
        if success {
            toastMessage = "Canvas reconectado!"
            toastType = .success
            await loadPortalConnections()
        } else {
            toastMessage = "Sessao Google expirou — reconecte manualmente"
            toastType = .error
            canvas.status = .expired
        }
    }

    func syncCalendar() async {
        calendar.status = .loading
        do {
            _ = try await api.syncGoogleCalendar()
            await loadCalendar()
        } catch {
            calendar.status = .connected
        }
    }

    func syncDrive() async {
        drive.status = .loading
        do {
            _ = try await api.syncGoogleDrive()
            await loadDrive()
        } catch {
            drive.status = .connected
        }
    }

    // MARK: - Helpers

    private func parseISO(_ isoDate: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate)
    }

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

    /// Data absoluta em PT-BR para ancora temporal: "11 abr, 19:54"
    /// Se for hoje, vira "hoje, 19:54". Se > 7 dias, "11/04/26".
    private func formatAbsoluteTime(_ isoDate: String) -> String? {
        let fullFmt = ISO8601DateFormatter()
        fullFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fullFmt.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate) else { return nil }
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "pt_BR")
        if Calendar.current.isDateInToday(date) {
            fmt.dateFormat = "'hoje,' HH:mm"
        } else if Date().timeIntervalSince(date) < 7 * 86_400 {
            fmt.dateFormat = "dd MMM, HH:mm"
        } else {
            fmt.dateFormat = "dd/MM/yy"
        }
        return fmt.string(from: date)
    }

    /// Format BR phone: "5551989484243" → "+55 51 98948-4243"
    private static func formatPhone(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 10 else { return "+\(digits)" }
        if digits.count == 13 {
            // +CC AA 9XXXX-XXXX
            let cc = digits.prefix(2)
            let area = digits.dropFirst(2).prefix(2)
            let part1 = digits.dropFirst(4).prefix(5)
            let part2 = digits.dropFirst(9)
            return "+\(cc) \(area) \(part1)-\(part2)"
        }
        if digits.count == 11 {
            // AA 9XXXX-XXXX
            let area = digits.prefix(2)
            let part1 = digits.dropFirst(2).prefix(5)
            let part2 = digits.dropFirst(7)
            return "+55 \(area) \(part1)-\(part2)"
        }
        return "+\(digits)"
    }

    /// Considera stale quando a última extração com dados foi > 12h atrás.
    /// Usuario ve card conectado mas com aviso amarelo — sinal pra suspeitar.
    private func isStale(_ isoDate: String?) -> Bool {
        guard let isoDate else { return false }
        let fullFmt = ISO8601DateFormatter()
        fullFmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = fullFmt.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate) else { return false }
        return Date().timeIntervalSince(date) > 12 * 3600
    }
}

// MARK: - ConnectorState

struct ConnectorState {
    let id: String
    let name: String
    var status: ConnectionItemStatus = .disconnected
    var lastSync: String?          // "dados extraidos" — relativo (ex: "3h atras")
    var lastPing: String?          // "sessao viva" — relativo (so quando diferente de lastSync)
    var lastSyncAbsolute: String?  // "11 abr as 19:54" para sheet e ancora temporal
    var isStale: Bool = false      // true se lastSync > 12h (conectado mas dados velhos)
    var stats: [(value: Int, label: String)] = []
    var subtitle: String?
    var instanceUrl: String?
}
