import Foundation
import Observation

// MARK: - ConnectorsViewModel
// Unified state for all portal connections, used by ConnectionsScreen.
// Replaces the ~30 @State vars scattered across ConnectionsScreen.
// When KMP lands, this file gets deleted and replaced by shared Kotlin ViewModel.

@MainActor
@Observable
final class ConnectorsViewModel {
    // Per-connector state
    var canvas = ConnectorState(id: "canvas", name: "Canvas LMS")
    var webaluno = ConnectorState(id: "webaluno", name: "WebAluno")
    var calendar = ConnectorState(id: "google_calendar", name: "Google Calendar")
    var drive = ConnectorState(id: "google_drive", name: "Google Drive")

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

    // MARK: - Computed

    var connectedCount: Int {
        [canvas, webaluno, calendar, drive].filter { $0.status == .connected }.count
    }

    var totalPortals: Int { 4 }

    func state(for portalId: String) -> ConnectorState {
        switch portalId {
        case "canvas": canvas
        case "webaluno", "mannesoft": webaluno
        case "google_calendar": calendar
        case "google_drive": drive
        default: ConnectorState(id: portalId, name: portalId)
        }
    }

    // MARK: - Load All

    func loadAll() async {
        await loadUniversityPortals()
        await loadPortalConnections()
        async let cal = loadCalendar()
        async let drv = loadDrive()
        _ = await (cal, drv)
    }

    // MARK: - University Portals

    private func loadUniversityPortals() async {
        do {
            let profile = try await api.getProfile()
            if let uniName = profile.university, !uniName.isEmpty {
                universityName = uniName
                let response = try await api.getUniversities(query: uniName)
                if let uni = response.universities.first {
                    universityName = uni.shortName.isEmpty ? uni.name : uni.shortName
                    universityCity = uni.city
                    if let portals = uni.portals, !portals.isEmpty {
                        universityPortals = portals
                    }
                }
            }
        } catch {
            print("[Connectors] University portals load failed: \(error)")
        }
    }

    // MARK: - Portal Connections (Canvas + WebAluno via single endpoint)

    func loadPortalConnections() async {
        do {
            let data = try await api.getCanvasStatus()
            guard let connections = data.connections, !connections.isEmpty else {
                canvas.status = .disconnected
                webaluno.status = .disconnected
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
                    canvas.stats = [
                        (conn.counts?.subjects ?? 0, "disciplinas"),
                        (conn.counts?.evaluations ?? 0, "avaliacoes"),
                        (conn.counts?.documents ?? 0, "arquivos"),
                    ]
                case "mannesoft":
                    webaluno.status = status
                    webaluno.lastSync = syncTime.flatMap { formatRelativeTime($0) }
                    webaluno.stats = [
                        (conn.counts?.subjects ?? 0, "disciplinas"),
                        (conn.counts?.evaluations ?? 0, "notas"),
                        (conn.counts?.schedule ?? 0, "aulas"),
                    ]
                default:
                    break
                }
            }
        } catch {
            print("[Connectors] Portal status load failed: \(error)")
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
                try await api.disconnectWebaluno()
                webaluno = ConnectorState(id: "webaluno", name: "WebAluno")
            case "google_calendar":
                try await api.disconnectGoogleCalendar()
                calendar = ConnectorState(id: "google_calendar", name: "Google Calendar")
            case "google_drive":
                try await api.disconnectGoogleDrive()
                drive = ConnectorState(id: "google_drive", name: "Google Drive")
            default: break
            }
        } catch {
            print("[Connectors] Disconnect \(connectorId) error: \(error)")
        }
    }

    // MARK: - Connect WebAluno with session

    func connectWebaluno(cookie: String) async {
        do {
            toastMessage = "Conectando WebAluno..."
            toastType = .success
            webaluno.status = .connected
            let _ = try await api.startVitaCrawl(
                cookies: "PHPSESSID=\(cookie)",
                instanceUrl: "https://ac3949.mannesoftprime.com.br"
            )
            toastMessage = "WebAluno conectado! Extraindo dados..."
            toastType = .success
            await loadPortalConnections()
        } catch {
            print("[Connectors] WebAluno connect error: \(error)")
            toastMessage = "Erro ao conectar: \(error.localizedDescription)"
            toastType = .error
        }
    }

    // MARK: - Sync

    func syncCanvas() async {
        canvas.status = .loading
        do {
            _ = try await api.syncCanvas()
            await loadPortalConnections()
        } catch {
            canvas.status = .connected
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
}
