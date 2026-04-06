import Foundation
import Observation

// MARK: - State

struct CanvasConnectViewState {
    var isLoading: Bool = true
    var isConnected: Bool = false
    var status: String? = nil
    var instanceUrl: String = "https://ulbra.instructure.com"
    var lastSyncAt: String? = nil

    // Sync progress
    var isSyncing: Bool = false
    var syncPhase: CanvasSyncOrchestrator.Phase = .starting
    var syncDetail: String? = nil
    var syncPercent: Double = 0

    // Operations
    var isDisconnecting: Bool = false

    // Messages
    var error: String? = nil
    var successMessage: String? = nil
}

// MARK: - ViewModel

@MainActor
@Observable
final class CanvasConnectViewModel {
    var state = CanvasConnectViewState()

    private let api: VitaAPI
    private var syncTask: Task<Void, Never>?

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
            let status = try await api.getCanvasStatus()
            state.isLoading = false
            if let conn = status.canvasConnection, conn.status == "active" {
                state.isConnected = true
                state.status = conn.status
                if let url = conn.instanceUrl, !url.isEmpty {
                    state.instanceUrl = url
                }
                state.lastSyncAt = conn.lastSyncAt
            } else {
                state.isConnected = false
            }
        } catch {
            state.isLoading = false
            state.isConnected = false
        }
    }

    // MARK: - Sync via on-device Canvas fetch

    /// Called after WebView login: fetches Canvas data directly from iOS (IP-bound),
    /// filters plano PDFs, downloads them, and sends everything to backend for LLM processing.
    func syncWithWebView(cookies: String, instanceUrl: String) {
        syncTask?.cancel()
        syncTask = Task { @MainActor [weak self] in
            guard let self else { return }
            state.isSyncing = true
            state.error = nil
            state.syncPhase = .starting
            state.syncPercent = 0
            state.successMessage = CanvasSyncOrchestrator.Phase.starting.rawValue

            let orchestrator = CanvasSyncOrchestrator(
                cookies: cookies,
                instanceUrl: instanceUrl,
                vitaAPI: api,
                onProgress: { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        self.state.syncPhase = progress.phase
                        self.state.syncDetail = progress.detail
                        self.state.syncPercent = progress.percent
                        if let detail = progress.detail {
                            self.state.successMessage = "\(progress.phase.rawValue) \(detail)"
                        } else {
                            self.state.successMessage = progress.phase.rawValue
                        }
                    }
                }
            )

            do {
                let result = try await orchestrator.run()
                try Task.checkCancellation()

                state.isSyncing = false
                state.isConnected = true
                state.status = "active"
                state.syncPhase = .done

                let summary = [
                    result.courses.map { "\($0) disciplinas" },
                    result.assignments.map { "\($0) atividades" },
                    result.pdfExtracted.map { "\($0) PDFs processados" },
                ].compactMap { $0 }.joined(separator: ", ")

                state.successMessage = summary.isEmpty ? "Extração completa!" : "Pronto! \(summary)"
                NSLog("[CanvasSync] Done: %@", summary)

                await loadStatus()
            } catch is CancellationError {
                NSLog("[CanvasSync] Task cancelled")
            } catch {
                NSLog("[CanvasSync] Error: %@", error.localizedDescription)
                state.isSyncing = false
                state.syncPhase = .error
                state.error = "Erro: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Re-sync (when already connected)

    func syncNow() {
        // Re-sync requires fresh cookies — reopen WebView
        // For now show message
        state.error = "Para re-sincronizar, reconecte ao Canvas"
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
                    isConnected: false
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
