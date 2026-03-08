import SwiftUI

struct ConnectionsScreen: View {
    var onCanvasConnect: (() -> Void)?
    var onWebAlunoConnect: (() -> Void)?
    var onGoogleCalendarConnect: (() -> Void)?
    var onGoogleDriveConnect: (() -> Void)?
    var onBack: (() -> Void)?

    @Environment(\.appContainer) private var container
    @State private var canvasStatus: ConnectionItemStatus = .loading
    @State private var webalunoStatus: ConnectionItemStatus = .loading
    @State private var googleCalendarStatus: ConnectionItemStatus = .loading
    @State private var googleDriveStatus: ConnectionItemStatus = .loading
    @State private var canvasLastSync: String?
    @State private var webalunoLastSync: String?
    @State private var googleCalendarLastSync: String?
    @State private var googleDriveLastSync: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Button(action: { onBack?() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    Spacer()
                    Text("Conexoes")
                        .font(VitaTypography.titleMedium)
                        .foregroundStyle(VitaColors.textPrimary)
                    Spacer()
                    // Balance spacer
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16))
                        .opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Text("Gerencie suas integracoes com plataformas academicas.")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textTertiary)
                    .padding(.horizontal, 20)

                // Canvas LMS
                connectionCard(
                    name: "Canvas LMS",
                    description: "Materiais, notas e deadlines",
                    icon: "building.columns",
                    status: canvasStatus,
                    lastSync: canvasLastSync,
                    onConnect: { onCanvasConnect?() },
                    onDisconnect: { disconnectCanvas() },
                    onSync: { syncCanvas() }
                )

                // Portal Academico
                connectionCard(
                    name: "Portal Academico",
                    description: "Boletim e grade horaria",
                    icon: "graduationcap",
                    status: webalunoStatus,
                    lastSync: webalunoLastSync,
                    onConnect: { onWebAlunoConnect?() },
                    onDisconnect: { disconnectWebaluno() },
                    onSync: { syncWebaluno() }
                )

                // Google Calendar
                connectionCard(
                    name: "Google Calendar",
                    description: "Sincronizar eventos e compromissos",
                    icon: "calendar",
                    status: googleCalendarStatus,
                    lastSync: googleCalendarLastSync,
                    onConnect: { onGoogleCalendarConnect?() },
                    onDisconnect: { disconnectGoogleCalendar() },
                    onSync: { syncGoogleCalendar() }
                )

                // Google Drive
                connectionCard(
                    name: "Google Drive",
                    description: "Importar arquivos e PDFs",
                    icon: "externaldrive",
                    status: googleDriveStatus,
                    lastSync: googleDriveLastSync,
                    onConnect: { onGoogleDriveConnect?() },
                    onDisconnect: { disconnectGoogleDrive() },
                    onSync: { syncGoogleDrive() }
                )

                Spacer().frame(height: 60)
            }
        }
        .background(VitaColors.surface.ignoresSafeArea())
        .task { await loadStatuses() }
    }

    // MARK: - Connection Card

    private func connectionCard(
        name: String,
        description: String,
        icon: String,
        status: ConnectionItemStatus,
        lastSync: String?,
        onConnect: @escaping () -> Void,
        onDisconnect: @escaping () -> Void,
        onSync: @escaping () -> Void
    ) -> some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    // Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(status.accentColor.opacity(0.1))
                            .frame(width: 40, height: 40)
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundStyle(status.accentColor)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(name)
                                .font(VitaTypography.labelLarge)
                                .foregroundStyle(VitaColors.textPrimary)

                            status.badge
                        }

                        Text(description)
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textTertiary)

                        if let lastSync {
                            Text("Ultima sinc: \(lastSync)")
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textTertiary)
                                .padding(.top, 2)
                        }
                    }

                    Spacer()
                }

                // Actions
                HStack(spacing: 8) {
                    Spacer().frame(width: 52)

                    switch status {
                    case .connected:
                        Button(action: onSync) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12))
                                Text("Sincronizar")
                                    .font(VitaTypography.labelSmall)
                            }
                            .foregroundStyle(VitaColors.accent)
                        }
                        .buttonStyle(.plain)

                        Button(action: onDisconnect) {
                            HStack(spacing: 4) {
                                Image(systemName: "link.badge.plus")
                                    .font(.system(size: 12))
                                    .rotationEffect(.degrees(45))
                                Text("Desconectar")
                                    .font(VitaTypography.labelSmall)
                            }
                            .foregroundStyle(.red.opacity(0.8))
                        }
                        .buttonStyle(.plain)

                    case .expired:
                        Button(action: onConnect) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 12))
                                Text("Reconectar")
                                    .font(VitaTypography.labelSmall)
                            }
                            .foregroundStyle(VitaColors.accent)
                        }
                        .buttonStyle(.plain)

                    case .disconnected:
                        Button(action: onConnect) {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.system(size: 12))
                                Text("Conectar")
                                    .font(VitaTypography.labelSmall)
                            }
                            .foregroundStyle(VitaColors.accent)
                        }
                        .buttonStyle(.plain)

                    case .loading:
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(VitaColors.accent)
                    }
                }
            }
            .padding(16)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - API Calls

    private func loadStatuses() async {
        // Canvas
        do {
            let data = try await container.api.getCanvasStatus()
            if data.connected {
                canvasStatus = data.status == "expired" ? .expired : .connected
                canvasLastSync = data.lastSyncAt.map { formatRelativeTime($0) }
            } else {
                canvasStatus = .disconnected
            }
        } catch {
            canvasStatus = .disconnected
        }

        // WebAluno
        do {
            let data = try await container.api.getWebalunoStatus()
            if data.connected {
                webalunoStatus = data.connection?.status == "expired" ? .expired : .connected
                webalunoLastSync = data.connection?.lastSyncAt.map { formatRelativeTime($0) }
            } else {
                webalunoStatus = .disconnected
            }
        } catch {
            webalunoStatus = .disconnected
        }

        // Google Calendar
        do {
            let data = try await container.api.getGoogleCalendarStatus()
            if data.connected {
                googleCalendarStatus = data.status == "expired" ? .expired : .connected
                googleCalendarLastSync = data.lastSyncAt.map { formatRelativeTime($0) }
            } else {
                googleCalendarStatus = .disconnected
            }
        } catch {
            googleCalendarStatus = .disconnected
        }

        // Google Drive
        do {
            let data = try await container.api.getGoogleDriveStatus()
            if data.connected {
                googleDriveStatus = data.status == "expired" ? .expired : .connected
                googleDriveLastSync = data.lastSyncAt.map { formatRelativeTime($0) }
            } else {
                googleDriveStatus = .disconnected
            }
        } catch {
            googleDriveStatus = .disconnected
        }
    }

    private func disconnectCanvas() {
        Task {
            do {
                try await container.api.disconnectCanvas()
                canvasStatus = .disconnected
                canvasLastSync = nil
            } catch { }
        }
    }

    private func syncCanvas() {
        Task {
            canvasStatus = .loading
            do {
                try await container.api.syncCanvas()
                let data = try await container.api.getCanvasStatus()
                canvasStatus = data.connected ? .connected : .disconnected
                canvasLastSync = data.lastSyncAt.map { formatRelativeTime($0) }
            } catch {
                canvasStatus = .connected
            }
        }
    }

    private func disconnectWebaluno() {
        Task {
            do {
                try await container.api.disconnectWebaluno()
                webalunoStatus = .disconnected
                webalunoLastSync = nil
            } catch { }
        }
    }

    private func syncWebaluno() {
        Task {
            webalunoStatus = .loading
            do {
                try await container.api.syncWebaluno()
                let data = try await container.api.getWebalunoStatus()
                webalunoStatus = data.connected ? .connected : .disconnected
                webalunoLastSync = data.connection?.lastSyncAt.map { formatRelativeTime($0) }
            } catch {
                webalunoStatus = .connected
            }
        }
    }

    private func disconnectGoogleCalendar() {
        Task {
            do {
                try await container.api.disconnectGoogleCalendar()
                googleCalendarStatus = .disconnected
                googleCalendarLastSync = nil
            } catch { }
        }
    }

    private func syncGoogleCalendar() {
        Task {
            googleCalendarStatus = .loading
            do {
                try await container.api.syncGoogleCalendar()
                let data = try await container.api.getGoogleCalendarStatus()
                googleCalendarStatus = data.connected ? .connected : .disconnected
                googleCalendarLastSync = data.lastSyncAt.map { formatRelativeTime($0) }
            } catch {
                googleCalendarStatus = .connected
            }
        }
    }

    private func disconnectGoogleDrive() {
        Task {
            do {
                try await container.api.disconnectGoogleDrive()
                googleDriveStatus = .disconnected
                googleDriveLastSync = nil
            } catch { }
        }
    }

    private func syncGoogleDrive() {
        Task {
            googleDriveStatus = .loading
            do {
                try await container.api.syncGoogleDrive()
                let data = try await container.api.getGoogleDriveStatus()
                googleDriveStatus = data.connected ? .connected : .disconnected
                googleDriveLastSync = data.lastSyncAt.map { formatRelativeTime($0) }
            } catch {
                googleDriveStatus = .connected
            }
        }
    }

    private func formatRelativeTime(_ isoDate: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: isoDate) ?? ISO8601DateFormatter().date(from: isoDate) else {
            return isoDate
        }
        let diff = Date().timeIntervalSince(date)
        let minutes = Int(diff / 60)
        if minutes < 1 { return "agora" }
        if minutes < 60 { return "\(minutes)min atras" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h atras" }
        return "\(hours / 24)d atras"
    }
}

// MARK: - Status Enum

enum ConnectionItemStatus {
    case loading, connected, expired, disconnected

    var accentColor: Color {
        switch self {
        case .connected: return .green
        case .expired: return .orange
        case .disconnected, .loading: return VitaColors.textTertiary
        }
    }

    @ViewBuilder
    var badge: some View {
        switch self {
        case .connected:
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10))
                Text("Conectado")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(.green)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.green.opacity(0.1))
            .clipShape(Capsule())

        case .expired:
            HStack(spacing: 3) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                Text("Expirado")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.orange.opacity(0.1))
            .clipShape(Capsule())

        case .disconnected:
            HStack(spacing: 3) {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 10))
                Text("Desconectado")
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(VitaColors.textTertiary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(VitaColors.textTertiary.opacity(0.1))
            .clipShape(Capsule())

        case .loading:
            EmptyView()
        }
    }
}
