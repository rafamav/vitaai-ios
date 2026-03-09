import Foundation

// MARK: - State

struct GoogleCalendarConnectViewState {
    var isLoading: Bool = true
    var isConnected: Bool = false
    var status: String?
    var googleEmail: String?
    var eventCount: Int = 0
    var lastSyncAt: String?

    // Operations
    var isSyncing: Bool = false
    var isDisconnecting: Bool = false

    // Messages
    var error: String?
    var successMessage: String?
}

// MARK: - ViewModel

@MainActor
@Observable
final class GoogleCalendarConnectViewModel {
    var state = GoogleCalendarConnectViewState()

    private let api: VitaAPI

    init(api: VitaAPI) {
        self.api = api
    }

    func onAppear() {
        Task { await loadStatus() }
    }

    // MARK: - Status

    func loadStatus() async {
        state.isLoading = true
        state.error = nil
        do {
            let response = try await api.getGoogleCalendarStatus()
            state.isLoading = false
            state.isConnected = response.connected
            state.status = response.status
            state.googleEmail = response.googleEmail
            state.eventCount = response.counts?.events ?? 0
            state.lastSyncAt = response.lastSyncAt
        } catch {
            state.isLoading = false
            state.isConnected = false
        }
    }

    // MARK: - Sync

    func syncNow() {
        Task {
            state.isSyncing = true
            state.error = nil
            state.successMessage = nil
            do {
                let result = try await api.syncGoogleCalendar()
                state.isSyncing = false
                let count = result.events > 0 ? result.events : result.synced
                state.successMessage = "Sincronizado: \(count) evento(s)"
                await loadStatus()
            } catch {
                state.isSyncing = false
                state.error = "Falha na sincronizacao"
            }
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        Task {
            state.isDisconnecting = true
            state.error = nil
            state.successMessage = nil
            do {
                try await api.disconnectGoogleCalendar()
                state = GoogleCalendarConnectViewState(
                    isLoading: false,
                    isConnected: false,
                    successMessage: "Google Calendar desconectado"
                )
            } catch {
                state.isDisconnecting = false
                state.error = "Falha ao desconectar"
            }
        }
    }

    // MARK: - Dismiss

    func dismissMessages() {
        state.error = nil
        state.successMessage = nil
    }
}
