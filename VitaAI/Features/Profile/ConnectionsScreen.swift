import SwiftUI

// Stub type for portal page capture (used by SilentPortalSync)
struct CapturedPortalPage {
    let type: String
    let html: String
    let linkText: String?
}

// MARK: - ConnectionsScreen
// University-aware connector list — mirrors the onboarding ConnectStep UX.
// Shows the student's university portals (from API), Google integrations, and
// an expandable "Outros portais" section for portal types not detected.

struct ConnectionsScreen: View {
    /// Single callback for navigating to any portal's connect screen.
    var onPortalConnect: ((String) -> Void)?
    var onBack: (() -> Void)?

    @Environment(\.appContainer) private var container

    @State private var vm: ConnectorsViewModel?
    @State private var toastState = VitaToastState()

    // Sheet visibility
    @State private var activeSheet: String?
    @State private var showAllPortals = false

    // Design tokens
    private let goldSubtle = VitaColors.accentLight
    private let borderColor = VitaColors.glassBorder
    private let cardBg = VitaColors.glassBg
    private let bg = VitaColors.surface

    // All known portal types (for "Outros portais" fallback)
    private let allPortalTypes: [PortalTypeInfo] = [
        PortalTypeInfo(type: "canvas"),
        PortalTypeInfo(type: "webaluno"),
        PortalTypeInfo(type: "moodle"),
        PortalTypeInfo(type: "sigaa"),
        PortalTypeInfo(type: "totvs"),
        PortalTypeInfo(type: "lyceum"),
        PortalTypeInfo(type: "sagres"),
        PortalTypeInfo(type: "blackboard"),
        PortalTypeInfo(type: "platos"),
    ]

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            bg.ignoresSafeArea()

            if let vm {
                mainContent(vm: vm)
            } else {
                ProgressView().tint(VitaColors.accent)
            }
        }
        .onAppear {
            if vm == nil {
                let viewModel = ConnectorsViewModel(api: container.api)
                vm = viewModel
                Task { await viewModel.loadAll() }
            }
        }
        .task(id: "refresh-timer") {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await vm?.loadPortalConnections()
            }
        }
        // Status sheet for connected portals
        .sheet(item: $activeSheet) { sheetId in
            sheetContent(for: sheetId)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .background(Color(red: 0.047, green: 0.035, blue: 0.027))
        }
        .vitaToastHost(toastState)
        .onChange(of: vm?.toastMessage) { msg in
            if let msg {
                toastState.show(msg, type: vm?.toastType ?? .success)
                vm?.toastMessage = nil
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func mainContent(vm: ConnectorsViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                Color.clear.frame(height: 64)

                // Connected count card
                connectedCountCard(vm: vm)
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                // Institucional section
                institucionalSection(vm: vm)

                // Google section
                sectionLabel("Google")
                    .padding(.top, 18)

                VStack(spacing: 8) {
                    portalCard(
                        letter: "G", name: "Google Calendar",
                        color: Color(red: 0.26, green: 0.52, blue: 0.96),
                        connectorId: "google_calendar",
                        state: vm.calendar, vm: vm
                    )
                    portalCard(
                        letter: "G", name: "Google Drive",
                        color: Color(red: 0.13, green: 0.59, blue: 0.33),
                        connectorId: "google_drive",
                        state: vm.drive, vm: vm
                    )
                }
                .padding(.horizontal, 14)

                // Como funciona
                sectionLabel("Como funciona")
                    .padding(.top, 20)

                comoFunciona
                    .padding(14)
                    .background(cardBg)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
                    .padding(.horizontal, 14)

                Spacer().frame(height: 120)
            }
        }
    }

    // MARK: - Institucional Section

    @ViewBuilder
    private func institucionalSection(vm: ConnectorsViewModel) -> some View {
        let hasUniversity = !vm.universityName.isEmpty
        let detectedPortals = vm.universityPortals
        let detectedTypes = Set(detectedPortals.map(\.portalType))
        let otherPortals = allPortalTypes.filter { !detectedTypes.contains($0.type) }

        // Section label: university name or generic
        if hasUniversity {
            sectionLabel(vm.universityName)
                .padding(.top, 18)
        } else {
            sectionLabel("Portais Academicos")
                .padding(.top, 18)
        }

        VStack(spacing: 8) {
            if !detectedPortals.isEmpty {
                // Detected portals for this university
                ForEach(detectedPortals, id: \.id) { portal in
                    let connState = vm.state(for: portal.portalType)
                    ConnectorCard(
                        letter: University.letter(for: portal.portalType),
                        name: portal.displayName.isEmpty
                            ? University.displayName(for: portal.portalType)
                            : portal.displayName,
                        status: connState.status,
                        color: University.color(for: portal.portalType),
                        lastSync: connState.lastSync,
                        stats: connState.stats,
                        isPrimary: portal.isPrimary,
                        onConnect: { onPortalConnect?(portal.portalType) },
                        onDisconnect: { Task { await vm.disconnect(portal.portalType) } },
                        onTapConnected: { activeSheet = portal.portalType }
                    )
                }
            } else if !hasUniversity {
                // No university — show hint
                noUniversityHint
            }

            // "Outros portais" expandable
            if !showAllPortals && !otherPortals.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3)) { showAllPortals = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle").font(.system(size: 13))
                        Text("Outros portais")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            if showAllPortals {
                ForEach(otherPortals) { portal in
                    let connState = vm.state(for: portal.type)
                    ConnectorCard(
                        letter: portal.letter,
                        name: portal.displayName,
                        status: connState.status,
                        color: portal.color,
                        onConnect: { onPortalConnect?(portal.type) },
                        onDisconnect: { Task { await vm.disconnect(portal.type) } },
                        onTapConnected: { activeSheet = portal.type }
                    )
                }
            }
        }
        .padding(.horizontal, 14)
    }

    // MARK: - No University Hint

    private var noUniversityHint: some View {
        VStack(spacing: 8) {
            Image(systemName: "building.columns")
                .font(.system(size: 24))
                .foregroundColor(goldSubtle.opacity(0.30))
            Text("Nenhuma universidade detectada")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Text("Complete seu perfil para ver os portais da sua faculdade")
                .font(.system(size: 11))
                .foregroundColor(goldSubtle.opacity(0.30))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
    }

    // MARK: - Portal Card (generic)

    @ViewBuilder
    private func portalCard(
        letter: String, name: String, color: Color,
        connectorId: String, state: ConnectorState,
        vm: ConnectorsViewModel
    ) -> some View {
        ConnectorCard(
            letter: letter,
            name: name,
            status: state.status,
            color: color,
            lastSync: state.lastSync,
            stats: state.stats,
            onConnect: { onPortalConnect?(connectorId) },
            onDisconnect: { Task { await vm.disconnect(connectorId) } },
            onTapConnected: { activeSheet = connectorId }
        )
    }

    // MARK: - Sheet Content

    @ViewBuilder
    private func sheetContent(for connectorId: String) -> some View {
        if let vm {
            let state = vm.state(for: connectorId)
            let (icon, syncNote) = sheetMeta(for: connectorId)

            ConnectorStatusSheet(
                serviceName: state.name,
                icon: icon,
                subtitle: state.subtitle,
                lastSync: state.lastSync,
                stats: state.stats.map { ConnectorStat(value: $0.value, label: $0.label) },
                syncNote: syncNote,
                onSync: {
                    activeSheet = nil
                    Task {
                        switch connectorId {
                        case "canvas": await vm.syncCanvas()
                        case "webaluno": onPortalConnect?("webaluno") // re-connect flow
                        case "google_calendar": await vm.syncCalendar()
                        case "google_drive": await vm.syncDrive()
                        default: break
                        }
                    }
                },
                onDisconnect: {
                    activeSheet = nil
                    Task { await vm.disconnect(connectorId) }
                }
            )
        }
    }

    private func sheetMeta(for id: String) -> (icon: String, syncNote: String?) {
        switch id {
        case "canvas": ("building.columns", nil)
        case "webaluno": ("graduationcap", "Sincroniza automaticamente a cada 15 min")
        case "google_calendar": ("calendar", nil)
        case "google_drive": ("externaldrive", nil)
        default: ("link", nil)
        }
    }

    // MARK: - Connected Count Card

    private func connectedCountCard(vm: ConnectorsViewModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Portais conectados")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.988, blue: 0.973).opacity(0.88))
                Text("Sincronize notas e horarios automaticamente")
                    .font(.system(size: 10.5))
                    .foregroundColor(goldSubtle.opacity(0.35))
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(vm.connectedCount)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.90))
                Text("/\(vm.totalPortals)")
                    .font(.system(size: 11))
                    .foregroundColor(goldSubtle.opacity(0.30))
            }
        }
        .padding(14)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(goldSubtle.opacity(0.35))
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
    }

    // MARK: - Como Funciona

    private var comoFunciona: some View {
        VStack(spacing: 10) {
            howItWorksStep("1", "Conecte seu portal academico com suas credenciais")
            howItWorksStep("2", "A Vita importa disciplinas, notas e horarios")
            howItWorksStep("3", "Dados sincronizados automaticamente a cada 15 minutos")
            howItWorksStep("4", "Desconecte a qualquer momento — seus dados sao excluidos")
        }
    }

    private func howItWorksStep(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(VitaColors.glassInnerLight.opacity(0.12))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle().stroke(Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.12), lineWidth: 1)
                    )
                Text(number)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.80))
            }
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(goldSubtle.opacity(0.45))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }
}

// MARK: - String+Identifiable (for sheet binding)

extension String: @retroactive Identifiable {
    public var id: String { self }
}

// MARK: - ConnectionItemStatus

enum ConnectionItemStatus: Equatable {
    case loading, connected, expired, disconnected

    var accentColor: Color {
        switch self {
        case .connected:              return Color(red: 0.29, green: 0.87, blue: 0.50)
        case .expired:                return VitaColors.dataAmber
        case .disconnected, .loading: return VitaColors.textTertiary
        }
    }

    @ViewBuilder
    var badge: some View {
        switch self {
        case .connected:
            statusBadge(icon: "checkmark.circle.fill", label: "Conectado",    color: Color(red: 0.29, green: 0.87, blue: 0.50))
        case .expired:
            statusBadge(icon: "exclamationmark.triangle.fill", label: "Expirado", color: VitaColors.dataAmber)
        case .disconnected:
            statusBadge(icon: "xmark.circle", label: "Desconectado", color: VitaColors.textTertiary)
        case .loading:
            EmptyView()
        }
    }

    @ViewBuilder
    private func statusBadge(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10))
            Text(label).font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
