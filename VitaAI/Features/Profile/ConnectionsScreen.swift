import SwiftUI

// MARK: - ConnectionsScreen
// Android parity: ConnectionsScreen.kt
// Shows 4 integration cards grouped by status (connected / available).
// Tapping a connected service opens a bottom sheet with stats + sync/disconnect.
// Tapping a disconnected service navigates to its dedicated connect screen.

struct ConnectionsScreen: View {
    var onCanvasConnect:         (() -> Void)?
    var onWebAlunoConnect:       (() -> Void)?
    var onGoogleCalendarConnect: (() -> Void)?
    var onGoogleDriveConnect:    (() -> Void)?
    var onBack:                  (() -> Void)?

    @Environment(\.appContainer) private var container

    // Per-service status
    @State private var canvasStatus:        ConnectionItemStatus = .loading
    @State private var webalunoStatus:      ConnectionItemStatus = .loading
    @State private var calendarStatus:      ConnectionItemStatus = .loading
    @State private var driveStatus:         ConnectionItemStatus = .loading

    // Per-service last-sync label
    @State private var canvasLastSync:      String?
    @State private var webalunoLastSync:    String?
    @State private var calendarLastSync:    String?
    @State private var driveLastSync:       String?

    // Canvas sheet data
    @State private var canvasCourses:       Int = 0
    @State private var canvasFiles:         Int = 0
    @State private var canvasAssignments:   Int = 0

    // WebAluno sheet data
    @State private var webalunoGrades:      Int = 0
    @State private var webalunoSchedule:    Int = 0

    // Google Calendar sheet data
    @State private var calendarEvents:      Int = 0
    @State private var calendarEmail:       String?

    // Google Drive sheet data
    @State private var driveFiles:          Int = 0
    @State private var driveEmail:          String?

    // Bottom sheet visibility
    @State private var showCanvasSheet:     Bool = false
    @State private var showWebalunoSheet:   Bool = false
    @State private var showCalendarSheet:   Bool = false
    @State private var showDriveSheet:      Bool = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                // Header
                headerBar

                Text("Gerencie suas integracoes com plataformas academicas.")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                let connected  = connectedItems
                let available  = availableItems

                // Connected section
                if !connected.isEmpty {
                    sectionLabel("CONECTADAS")
                    ForEach(connected, id: \.id) { item in
                        connectionCard(item)
                    }
                }

                // Available section
                if !available.isEmpty {
                    sectionLabel("DISPONIVEIS")
                    ForEach(available, id: \.id) { item in
                        connectionCard(item)
                    }
                }

                Spacer().frame(height: 60)
            }
        }
        .background(VitaColors.surface.ignoresSafeArea())
        .task { await loadAllStatuses() }
        // Canvas bottom sheet
        .sheet(isPresented: $showCanvasSheet) {
            canvasConnectedSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(VitaColors.surfaceElevated)
        }
        // WebAluno bottom sheet
        .sheet(isPresented: $showWebalunoSheet) {
            webalunoConnectedSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(VitaColors.surfaceElevated)
        }
        // Google Calendar bottom sheet
        .sheet(isPresented: $showCalendarSheet) {
            googleCalendarConnectedSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(VitaColors.surfaceElevated)
        }
        // Google Drive bottom sheet
        .sheet(isPresented: $showDriveSheet) {
            googleDriveConnectedSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(VitaColors.surfaceElevated)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Button(action: { onBack?() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
            }
            Spacer()
            Text("Integracoes")
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
    }

    // MARK: - Section label (Android parity: SectionLabel)

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(VitaTypography.labelSmall)
            .foregroundStyle(VitaColors.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
    }

    // MARK: - Connection card (Android parity: ConnectionCard)

    private func connectionCard(_ item: ConnectionListItem) -> some View {
        Button(action: item.onTap) {
            VitaGlassCard {
                HStack(alignment: .center, spacing: 12) {
                    // Icon container — convex glass metallic style
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.07),
                                        Color.white.opacity(0.02),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                        Image(systemName: item.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(VitaColors.textSecondary)
                    }

                    // Name + description
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(item.name)
                                .font(VitaTypography.labelLarge)
                                .foregroundStyle(VitaColors.textPrimary)
                            item.status.badge
                        }
                        Text(item.description)
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textTertiary)

                        if let lastSync = item.lastSync {
                            Text("Sinc: \(lastSync)")
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textTertiary.opacity(0.7))
                                .padding(.top, 1)
                        }
                    }

                    Spacer()

                    // Trailing indicator
                    if item.status == .connected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(VitaColors.dataGreen.opacity(0.8))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
                .padding(16)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    // MARK: - Items lists

    private var connectedItems: [ConnectionListItem] {
        [
            canvasStatus == .connected ? ConnectionListItem(
                id: "canvas",
                name: "Canvas LMS",
                description: "Disciplinas, PDFs, tarefas e calendario",
                icon: "building.columns",
                status: canvasStatus,
                lastSync: canvasLastSync,
                onTap: { showCanvasSheet = true }
            ) : nil,
            webalunoStatus == .connected ? ConnectionListItem(
                id: "webaluno",
                name: "WebAluno",
                description: "Notas, horarios e historico academico",
                icon: "graduationcap",
                status: webalunoStatus,
                lastSync: webalunoLastSync,
                onTap: { showWebalunoSheet = true }
            ) : nil,
            calendarStatus == .connected ? ConnectionListItem(
                id: "calendar",
                name: "Google Calendar",
                description: "Sincronize provas e aulas com sua agenda",
                icon: "calendar",
                status: calendarStatus,
                lastSync: calendarLastSync,
                onTap: { showCalendarSheet = true }
            ) : nil,
            driveStatus == .connected ? ConnectionListItem(
                id: "drive",
                name: "Google Drive",
                description: "Importe PDFs e slides do seu Drive",
                icon: "externaldrive",
                status: driveStatus,
                lastSync: driveLastSync,
                onTap: { showDriveSheet = true }
            ) : nil,
        ].compactMap { $0 }
    }

    private var availableItems: [ConnectionListItem] {
        [
            canvasStatus != .connected ? ConnectionListItem(
                id: "canvas",
                name: "Canvas LMS",
                description: "Disciplinas, PDFs, tarefas e calendario",
                icon: "building.columns",
                status: canvasStatus,
                lastSync: nil,
                onTap: { onCanvasConnect?() }
            ) : nil,
            webalunoStatus != .connected ? ConnectionListItem(
                id: "webaluno",
                name: "WebAluno",
                description: "Notas, horarios e historico academico",
                icon: "graduationcap",
                status: webalunoStatus,
                lastSync: nil,
                onTap: { onWebAlunoConnect?() }
            ) : nil,
            calendarStatus != .connected ? ConnectionListItem(
                id: "calendar",
                name: "Google Calendar",
                description: "Sincronize provas e aulas com sua agenda",
                icon: "calendar",
                status: calendarStatus,
                lastSync: nil,
                onTap: { onGoogleCalendarConnect?() }
            ) : nil,
            driveStatus != .connected ? ConnectionListItem(
                id: "drive",
                name: "Google Drive",
                description: "Importe PDFs e slides do seu Drive",
                icon: "externaldrive",
                status: driveStatus,
                lastSync: nil,
                onTap: { onGoogleDriveConnect?() }
            ) : nil,
        ].compactMap { $0 }
    }

    // MARK: - Bottom Sheets

    private var canvasConnectedSheet: some View {
        ConnectedServiceSheet(
            serviceName: "Canvas LMS",
            icon: "building.columns",
            lastSync: canvasLastSync,
            stats: [
                StatItem(value: canvasCourses, label: "Disciplinas"),
                StatItem(value: canvasFiles, label: "Arquivos"),
                StatItem(value: canvasAssignments, label: "Tarefas"),
            ],
            onSync: {
                showCanvasSheet = false
                syncCanvas()
            },
            onDisconnect: {
                showCanvasSheet = false
                disconnectCanvas()
            }
        )
    }

    private var webalunoConnectedSheet: some View {
        ConnectedServiceSheet(
            serviceName: "WebAluno",
            icon: "graduationcap",
            lastSync: webalunoLastSync,
            stats: [
                StatItem(value: webalunoGrades, label: "Notas"),
                StatItem(value: webalunoSchedule, label: "Aulas"),
            ],
            onSync: {
                showWebalunoSheet = false
                onWebAlunoConnect?() // opens WebView for re-scrape
            },
            onDisconnect: {
                showWebalunoSheet = false
                disconnectWebaluno()
            }
        )
    }

    private var googleCalendarConnectedSheet: some View {
        ConnectedServiceSheet(
            serviceName: "Google Calendar",
            icon: "calendar",
            subtitle: calendarEmail,
            lastSync: calendarLastSync,
            stats: [
                StatItem(value: calendarEvents, label: "Eventos"),
            ],
            onSync: {
                showCalendarSheet = false
                syncGoogleCalendar()
            },
            onDisconnect: {
                showCalendarSheet = false
                disconnectGoogleCalendar()
            }
        )
    }

    private var googleDriveConnectedSheet: some View {
        ConnectedServiceSheet(
            serviceName: "Google Drive",
            icon: "externaldrive",
            subtitle: driveEmail,
            lastSync: driveLastSync,
            stats: [
                StatItem(value: driveFiles, label: "Arquivos"),
            ],
            onSync: {
                showDriveSheet = false
                syncGoogleDrive()
            },
            onDisconnect: {
                showDriveSheet = false
                disconnectGoogleDrive()
            }
        )
    }

    // MARK: - API: Load all

    private func loadAllStatuses() async {
        async let canvas   = loadCanvas()
        async let webaluno = loadWebaluno()
        async let calendar = loadCalendar()
        async let drive    = loadDrive()
        _ = await (canvas, webaluno, calendar, drive)
    }

    private func loadCanvas() async {
        do {
            let data = try await container.api.getCanvasStatus()
            if data.connected {
                canvasStatus      = data.status == "expired" ? .expired : .connected
                canvasLastSync    = data.lastSyncAt.flatMap { formatRelativeTime($0) }
                canvasCourses     = data.courses
                canvasFiles       = data.files
                canvasAssignments = data.assignments
            } else {
                canvasStatus = .disconnected
            }
        } catch {
            canvasStatus = .disconnected
        }
    }

    private func loadWebaluno() async {
        do {
            let data = try await container.api.getWebalunoStatus()
            if data.connected {
                webalunoStatus   = data.connection?.status == "expired" ? .expired : .connected
                webalunoLastSync = data.connection?.lastSyncAt.flatMap { formatRelativeTime($0) }
                webalunoGrades   = data.counts?.grades ?? 0
                webalunoSchedule = data.counts?.schedule ?? 0
            } else {
                webalunoStatus = .disconnected
            }
        } catch {
            webalunoStatus = .disconnected
        }
    }

    private func loadCalendar() async {
        do {
            let data = try await container.api.getGoogleCalendarStatus()
            if data.connected {
                calendarStatus   = data.status == "expired" ? .expired : .connected
                calendarLastSync = data.lastSyncAt.flatMap { formatRelativeTime($0) }
                calendarEvents   = data.counts?.events ?? 0
                calendarEmail    = data.googleEmail
            } else {
                calendarStatus = .disconnected
            }
        } catch {
            calendarStatus = .disconnected
        }
    }

    private func loadDrive() async {
        do {
            let data = try await container.api.getGoogleDriveStatus()
            if data.connected {
                driveStatus   = data.status == "expired" ? .expired : .connected
                driveLastSync = data.lastSyncAt.flatMap { formatRelativeTime($0) }
                driveFiles    = data.counts?.files ?? 0
                driveEmail    = data.googleEmail
            } else {
                driveStatus = .disconnected
            }
        } catch {
            driveStatus = .disconnected
        }
    }

    // MARK: - API: Disconnect

    private func disconnectCanvas() {
        Task {
            do {
                try await container.api.disconnectCanvas()
                canvasStatus      = .disconnected
                canvasLastSync    = nil
                canvasCourses     = 0
                canvasFiles       = 0
                canvasAssignments = 0
            } catch { }
        }
    }

    private func disconnectWebaluno() {
        Task {
            do {
                try await container.api.disconnectWebaluno()
                webalunoStatus   = .disconnected
                webalunoLastSync = nil
                webalunoGrades   = 0
                webalunoSchedule = 0
            } catch { }
        }
    }

    private func disconnectGoogleCalendar() {
        Task {
            do {
                try await container.api.disconnectGoogleCalendar()
                calendarStatus   = .disconnected
                calendarLastSync = nil
                calendarEvents   = 0
                calendarEmail    = nil
            } catch { }
        }
    }

    private func disconnectGoogleDrive() {
        Task {
            do {
                try await container.api.disconnectGoogleDrive()
                driveStatus   = .disconnected
                driveLastSync = nil
                driveFiles    = 0
                driveEmail    = nil
            } catch { }
        }
    }

    // MARK: - API: Sync

    private func syncCanvas() {
        Task {
            canvasStatus = .loading
            do {
                _ = try await container.api.syncCanvas()
                await loadCanvas()
            } catch {
                canvasStatus = .connected
            }
        }
    }

    private func syncGoogleCalendar() {
        Task {
            calendarStatus = .loading
            do {
                _ = try await container.api.syncGoogleCalendar()
                await loadCalendar()
            } catch {
                calendarStatus = .connected
            }
        }
    }

    private func syncGoogleDrive() {
        Task {
            driveStatus = .loading
            do {
                _ = try await container.api.syncGoogleDrive()
                await loadDrive()
            } catch {
                driveStatus = .connected
            }
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
        return "\(hours / 24)d atras"
    }
}

// MARK: - Connection list item model

private struct ConnectionListItem {
    let id:          String
    let name:        String
    let description: String
    let icon:        String
    let status:      ConnectionItemStatus
    let lastSync:    String?
    let onTap:       () -> Void
}

// MARK: - Stat item model

private struct StatItem {
    let value: Int
    let label: String
}

// MARK: - ConnectedServiceSheet
// Shared bottom sheet for all 4 connected services (Android parity: CanvasConnectedSheet / WebAlunoConnectedSheet)

private struct ConnectedServiceSheet: View {
    let serviceName: String
    let icon:        String
    var subtitle:    String?
    let lastSync:    String?
    let stats:       [StatItem]
    let onSync:      () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Pull indicator spacing
            Spacer().frame(height: 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Connected badge
                    ZStack {
                        Circle()
                            .fill(VitaColors.dataGreen.opacity(0.10))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle().stroke(VitaColors.dataGreen.opacity(0.25), lineWidth: 1)
                            )
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundStyle(VitaColors.dataGreen)
                    }
                    .padding(.top, 24)

                    Spacer().frame(height: 16)

                    Text("\(serviceName) Conectado")
                        .font(VitaTypography.titleLarge)
                        .foregroundStyle(VitaColors.textPrimary)

                    if let subtitle {
                        Text(subtitle)
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textTertiary)
                            .padding(.top, 4)
                    }

                    if let lastSync {
                        Text("Ultima sincronizacao: \(lastSync)")
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textTertiary)
                            .padding(.top, 4)
                    }

                    // Stats row
                    if !stats.isEmpty {
                        HStack(spacing: 0) {
                            ForEach(stats.indices, id: \.self) { i in
                                if i > 0 {
                                    Divider()
                                        .frame(height: 32)
                                        .background(VitaColors.glassBorder)
                                }
                                statPill(stats[i])
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(VitaColors.glassBg)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(VitaColors.glassBorder, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    }

                    // Sync button
                    VitaButton(
                        text: "Sincronizar Agora",
                        action: onSync,
                        variant: .primary,
                        size: .lg,
                        leadingSystemImage: "arrow.triangle.2.circlepath"
                    )
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    // Disconnect button
                    Button(action: onDisconnect) {
                        HStack(spacing: 6) {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 13))
                                .rotationEffect(.degrees(45))
                            Text("Desconectar \(serviceName)")
                                .font(VitaTypography.bodyMedium)
                        }
                        .foregroundStyle(VitaColors.dataRed.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func statPill(_ item: StatItem) -> some View {
        VStack(spacing: 2) {
            Text("\(item.value)")
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.textPrimary)
            Text(item.label)
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ConnectionItemStatus

enum ConnectionItemStatus: Equatable {
    case loading, connected, expired, disconnected

    var accentColor: Color {
        switch self {
        case .connected:             return VitaColors.dataGreen
        case .expired:               return VitaColors.dataAmber
        case .disconnected, .loading: return VitaColors.textTertiary
        }
    }

    @ViewBuilder
    var badge: some View {
        switch self {
        case .connected:
            statusBadge(
                icon: "checkmark.circle.fill",
                label: "Conectado",
                color: VitaColors.dataGreen
            )
        case .expired:
            statusBadge(
                icon: "exclamationmark.triangle.fill",
                label: "Expirado",
                color: VitaColors.dataAmber
            )
        case .disconnected:
            statusBadge(
                icon: "xmark.circle",
                label: "Desconectado",
                color: VitaColors.textTertiary
            )
        case .loading:
            EmptyView()
        }
    }

    @ViewBuilder
    private func statusBadge(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
