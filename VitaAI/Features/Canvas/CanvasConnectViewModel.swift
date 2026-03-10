import Foundation

// MARK: - State

struct CanvasConnectViewState {
    var isLoading: Bool = true
    var isConnected: Bool = false
    var status: String? = nil
    var instanceUrl: String = "https://ulbra.instructure.com"
    var lastSyncAt: String? = nil

    // Form
    var tokenInput: String = ""
    var instanceUrlInput: String = "https://ulbra.instructure.com"

    // Operations
    var isConnecting: Bool = false
    var isSyncing: Bool = false
    var isDisconnecting: Bool = false
    var isIngestingWebView: Bool = false

    // Sheet
    var showingWebViewSheet: Bool = false

    // Messages
    var error: String? = nil
    var successMessage: String? = nil

    // Sync results
    var lastSyncCourses: Int = 0
    var lastSyncFiles: Int = 0
    var lastSyncAssignments: Int = 0
}

// MARK: - ViewModel

@MainActor
@Observable
final class CanvasConnectViewModel {
    var state = CanvasConnectViewState()

    private let api: VitaAPI

    init(api: VitaAPI) {
        self.api = api
    }

    func onAppear() {
        Task { await loadStatus() }
    }

    // MARK: - Input

    func updateTokenInput(_ value: String) {
        state.tokenInput = value
        state.error = nil
    }

    func updateInstanceUrlInput(_ value: String) {
        state.instanceUrlInput = value
        state.error = nil
    }

    // MARK: - Status

    func loadStatus() async {
        state.isLoading = true
        state.error = nil
        do {
            let status = try await api.getCanvasStatus()
            state.isLoading = false
            state.isConnected = status.connected
            state.status = status.status
            if let url = status.instanceUrl, !url.isEmpty {
                state.instanceUrl = url
            }
            state.lastSyncAt = status.lastSyncAt
        } catch {
            state.isLoading = false
            state.isConnected = false
        }
    }

    // MARK: - Connect

    func connect() {
        let token = state.tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            state.error = "Insira o token de acesso do Canvas"
            return
        }
        Task {
            state.isConnecting = true
            state.error = nil
            state.successMessage = nil
            do {
                let result = try await api.connectCanvas(
                    accessToken: token,
                    instanceUrl: state.instanceUrlInput.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                if result.success {
                    state.isConnecting = false
                    state.isConnected = true
                    state.status = "active"
                    state.tokenInput = ""
                    state.successMessage = "Canvas conectado com sucesso!"
                    // Auto-sync after connecting
                    await sync()
                } else {
                    state.isConnecting = false
                    state.error = result.error ?? "Falha ao conectar. Verifique o token."
                }
            } catch {
                state.isConnecting = false
                state.error = "Erro de conexão. Verifique sua internet."
            }
        }
    }

    // MARK: - Sync

    func sync() async {
        state.isSyncing = true
        state.error = nil
        state.successMessage = nil
        do {
            let result = try await api.syncCanvas()
            state.isSyncing = false
            state.lastSyncCourses = result.courses
            state.lastSyncFiles = result.files
            state.lastSyncAssignments = result.assignments
            state.successMessage = "Sincronizado: \(result.courses) disciplinas, \(result.files) arquivos, \(result.assignments) atividades"
            // Refresh status to get new lastSyncAt
            await loadStatus()
        } catch {
            state.isSyncing = false
            state.error = "Falha na sincronização"
        }
    }

    func syncNow() {
        Task { await sync() }
    }

    // MARK: - Disconnect

    func disconnect() {
        Task {
            state.isDisconnecting = true
            state.error = nil
            state.successMessage = nil
            do {
                try await api.disconnectCanvas()
                state = CanvasConnectViewState(
                    isLoading: false,
                    isConnected: false,
                    successMessage: "Canvas desconectado"
                )
            } catch {
                state.isDisconnecting = false
                state.error = "Falha ao desconectar"
            }
        }
    }

    // MARK: - WebView connect

    func openWebViewSheet() {
        state.showingWebViewSheet = true
        state.error = nil
        state.successMessage = nil
    }

    func closeWebViewSheet() {
        state.showingWebViewSheet = false
    }

    /// Called by CanvasWebViewScreen after successful scraping.
    /// Sends the scraped JSON and session cookies to the server via canvas/ingest.
    func connectWithScrapedData(json: String, instanceUrl: String, nativeCookies: String?) {
        Task {
            state.showingWebViewSheet = false
            state.isIngestingWebView = true
            state.error = nil
            state.successMessage = nil
            do {
                let result = try await api.canvasIngest(
                    instanceUrl: instanceUrl,
                    scrapedJson: json,
                    nativeCookies: nativeCookies
                )
                state.isIngestingWebView = false
                if result.success {
                    state.isConnected = true
                    state.status = "active"
                    state.instanceUrl = instanceUrl
                    state.successMessage = "Canvas conectado! \(result.courses) disciplinas importadas."
                    // Refresh status to get lastSyncAt
                    await loadStatus()
                } else {
                    state.error = result.error ?? "Falha ao processar dados do Canvas"
                }
            } catch {
                state.isIngestingWebView = false
                state.error = "Erro ao enviar dados. Verifique sua internet."
            }
        }
    }

    // MARK: - Dismiss

    func dismissMessages() {
        state.error = nil
        state.successMessage = nil
    }
}
