import Foundation
import UIKit
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

    init(api: VitaAPI) {
        self.api = api
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
            let profile = try await api.getProfile()
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
                let syncTime = conn.lastPingAt ?? conn.lastSyncAt

                switch conn.portalType {
                case "canvas":
                    canvas.status = status
                    canvas.lastSync = syncTime.flatMap { formatRelativeTime($0) }
                    canvas.instanceUrl = conn.instanceUrl
                    canvas.stats = [
                        (conn.counts?.subjects ?? 0, "disciplinas"),
                        (conn.counts?.evaluations ?? 0, "avaliacoes"),
                        (conn.counts?.documents ?? 0, "arquivos"),
                    ]
                case "mannesoft":
                    mannesoft.status = status
                    mannesoft.lastSync = syncTime.flatMap { formatRelativeTime($0) }
                    mannesoft.instanceUrl = conn.instanceUrl
                    mannesoft.stats = [
                        (conn.counts?.subjects ?? 0, "disciplinas"),
                        (conn.counts?.evaluations ?? 0, "notas"),
                        (conn.counts?.schedule ?? 0, "aulas"),
                    ]
                default:
                    break
                }
            }

            if canvas.status == .expired, let url = canvas.instanceUrl, !url.isEmpty {
                NSLog("[Connectors] Canvas expired — triggering silent reauth")
                canvas.status = .loading
                Task {
                    let success = await CanvasSilentReauth.shared.forceReauth(instanceUrl: url, api: api)
                    if success {
                        await loadPortalConnections()
                    } else {
                        canvas.status = .expired
                    }
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
        _ = await (cal, drv)

        // Spotify, Apple Health, WhatsApp: load from unified /api/integrations
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
                case "whatsapp":
                    whatsapp.status = connectionStatus(from: item.status)
                    whatsapp.lastSync = item.lastSyncAt.flatMap { formatRelativeTime($0) }
                default: break
                }
            }
        } catch {
            print("[Connectors] Integrations load failed: \(error)")
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
                try await api.disconnectGoogleCalendar()
                calendar = ConnectorState(id: "google_calendar", name: "Google Calendar")
            case "google_drive":
                try await api.disconnectGoogleDrive()
                drive = ConnectorState(id: "google_drive", name: "Google Drive")
            case "spotify":
                try await api.disconnectIntegration("spotify")
                spotify = ConnectorState(id: "spotify", name: "Spotify")
            case "apple_health":
                appleHealth = ConnectorState(id: "apple_health", name: "Apple Health")
            case "whatsapp":
                try await api.disconnectIntegration("whatsapp")
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

    func connectIntegration(_ connectorId: String) async {
        do {
            let data = try await api.startIntegrationOAuth(connectorId)
            if let authUrl = data.authUrl, let url = URL(string: authUrl) {
                await MainActor.run {
                    UIApplication.shared.open(url)
                }
            }
        } catch {
            toastMessage = "Erro ao conectar"
            toastType = .error
        }
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

// MARK: - ConnectorState

struct ConnectorState {
    let id: String
    let name: String
    var status: ConnectionItemStatus = .disconnected
    var lastSync: String?
    var stats: [(value: Int, label: String)] = []
    var subtitle: String?
    var instanceUrl: String?
}
