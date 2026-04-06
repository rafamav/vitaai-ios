import SwiftUI

// Stub type for portal page capture (used by SilentPortalSync)
struct CapturedPortalPage {
    let type: String
    let html: String
    let linkText: String?
}

// MARK: - ConnectionsScreen
// Matches conectores-mobile-v1.html mockup

struct ConnectionsScreen: View {
    var onCanvasConnect:         (() -> Void)?
    var onWebAlunoConnect:       (() -> Void)?
    var onGoogleCalendarConnect: (() -> Void)?
    var onGoogleDriveConnect:    (() -> Void)?
    var onBack:                  (() -> Void)?

    @Environment(\.appContainer) private var container

    // University portals (loaded from profile)
    @State private var universityPortals: [UniversityPortal] = []
    @State private var universityName: String = ""

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
    @State private var webAlunoDisciplines: Int = 0
    @State private var webalunoNotes:       Int = 0

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

    // Direct WebView for WebAluno connect/sync (skip intermediate screen)
    @State private var showWebalunoWebView: Bool = false
    @State private var isExtractingWebaluno: Bool = false
    @State private var capturedSessionCookie: String?
    @State private var toastState = VitaToastState()

    // MARK: - Colors (gold palette)
    private let goldPrimary  = VitaColors.accentHover   // → VitaColors
    private let goldAccent   = VitaColors.accent          // → VitaColors.accent
    private let goldSubtle   = VitaColors.accentLight     // → VitaColors.accentLight
    private let borderColor  = VitaColors.glassBorder     // → VitaColors.glassBorder
    private let cardBg       = VitaColors.glassBg         // → VitaColors.glassBg
    private let bg           = VitaColors.surface          // → VitaColors.surface

    // MARK: - Portal definitions
    private struct PortalDef {
        let id: String
        let letter: String
        let name: String
        let iconBg: Color
        let iconBorder: Color
        let iconText: Color
    }

    private var academicPortals: [PortalDef] {
        [
            PortalDef(
                id: "webaluno",
                letter: "W",
                name: "WebAluno",
                iconBg: Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.22),
                iconBorder: Color(red: 0.231, green: 0.510, blue: 0.965).opacity(0.18),
                iconText: Color(red: 0.576, green: 0.773, blue: 0.992).opacity(0.90)
            ),
            PortalDef(
                id: "canvas",
                letter: "C",
                name: "Canvas LMS",
                iconBg: Color(red: 0.937, green: 0.267, blue: 0.267).opacity(0.18),
                iconBorder: Color(red: 0.937, green: 0.267, blue: 0.267).opacity(0.16),
                iconText: Color(red: 0.988, green: 0.647, blue: 0.647).opacity(0.90)
            ),
            PortalDef(
                id: "moodle",
                letter: "M",
                name: "Moodle",
                iconBg: Color(red: 0.976, green: 0.451, blue: 0.086).opacity(0.18),
                iconBorder: Color(red: 0.976, green: 0.451, blue: 0.086).opacity(0.16),
                iconText: Color(red: 0.992, green: 0.729, blue: 0.455).opacity(0.90)
            ),
            PortalDef(
                id: "sigaa",
                letter: "S",
                name: "SIGAA",
                iconBg: Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.18),
                iconBorder: Color(red: 0.133, green: 0.773, blue: 0.369).opacity(0.16),
                iconText: Color(red: 0.525, green: 0.937, blue: 0.675).opacity(0.90)
            ),
            PortalDef(
                id: "totvs",
                letter: "T",
                name: "TOTVS RM",
                iconBg: Color(red: 0.408, green: 0.200, blue: 0.835).opacity(0.18),
                iconBorder: Color(red: 0.408, green: 0.200, blue: 0.835).opacity(0.16),
                iconText: Color(red: 0.690, green: 0.525, blue: 0.965).opacity(0.90)
            ),
            PortalDef(
                id: "lyceum",
                letter: "L",
                name: "Lyceum",
                iconBg: Color(red: 0.114, green: 0.631, blue: 0.667).opacity(0.18),
                iconBorder: Color(red: 0.114, green: 0.631, blue: 0.667).opacity(0.16),
                iconText: Color(red: 0.400, green: 0.855, blue: 0.878).opacity(0.90)
            ),
            PortalDef(
                id: "sagres",
                letter: "Sa",
                name: "Sagres",
                iconBg: Color(red: 0.820, green: 0.557, blue: 0.102).opacity(0.18),
                iconBorder: Color(red: 0.820, green: 0.557, blue: 0.102).opacity(0.16),
                iconText: Color(red: 0.945, green: 0.776, blue: 0.396).opacity(0.90)
            ),
            PortalDef(
                id: "blackboard",
                letter: "Bb",
                name: "Blackboard",
                iconBg: Color(red: 0.267, green: 0.267, blue: 0.267).opacity(0.18),
                iconBorder: Color(red: 0.267, green: 0.267, blue: 0.267).opacity(0.16),
                iconText: Color(red: 0.680, green: 0.680, blue: 0.680).opacity(0.90)
            ),
            PortalDef(
                id: "platos",
                letter: "P",
                name: "Platos",
                iconBg: Color(red: 0.827, green: 0.184, blue: 0.463).opacity(0.18),
                iconBorder: Color(red: 0.827, green: 0.184, blue: 0.463).opacity(0.16),
                iconText: Color(red: 0.937, green: 0.533, blue: 0.706).opacity(0.90)
            ),
        ]
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            bg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Top nav spacer
                    Color.clear.frame(height: 64)

                    // Connected count card
                    connectedCountCard
                        .padding(.horizontal, 14)
                        .padding(.top, 4)

                    // Section label
                    Text("Portais")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(goldSubtle.opacity(0.35))
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.top, 18)
                        .padding(.bottom, 4)

                    // Portal cards
                    VStack(spacing: 8) {
                        if universityPortals.isEmpty {
                            ForEach(academicPortals, id: \.id) { portal in
                                portalCard(portal)
                            }
                        } else {
                            ForEach(universityPortals, id: \.id) { portal in
                                let def = academicPortals.first(where: { $0.id == portal.portalType })
                                    ?? PortalDef(
                                        id: portal.portalType,
                                        letter: University.letter(for: portal.portalType),
                                        name: portal.displayName.isEmpty ? University.displayName(for: portal.portalType) : portal.displayName,
                                        iconBg: goldAccent.opacity(0.12),
                                        iconBorder: goldAccent.opacity(0.18),
                                        iconText: goldPrimary.opacity(0.90)
                                    )
                                portalCard(def)
                            }
                        }
                    }
                    .padding(.horizontal, 14)

                    // Como funciona — label outside card (matches mockup)
                    Text("Como funciona")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(goldSubtle.opacity(0.35))
                        .tracking(0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.top, 20)
                        .padding(.bottom, 4)

                    comoFunciona
                        .padding(14)
                        .background(cardBg)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
                        .padding(.horizontal, 14)

                    Spacer().frame(height: 120)
                }
            }

            // topNav removed — VitaTopBar is persistent shell
        }
        .task { await loadAllStatuses() }
        .task(id: "refresh-timer") {
            // Refresh portal status every 30s for live timestamps
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                await loadPortalConnections()
            }
        }
        // Canvas bottom sheet
        .sheet(isPresented: $showCanvasSheet) {
            canvasConnectedSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .background(Color(red: 0.047, green: 0.035, blue: 0.027))
        }
        // WebAluno bottom sheet
        .sheet(isPresented: $showWebalunoSheet) {
            webalunoConnectedSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .background(Color(red: 0.047, green: 0.035, blue: 0.027))
        }
        // Google Calendar bottom sheet
        .sheet(isPresented: $showCalendarSheet) {
            googleCalendarConnectedSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .background(Color(red: 0.047, green: 0.035, blue: 0.027))
        }
        // Google Drive bottom sheet
        .sheet(isPresented: $showDriveSheet) {
            googleDriveConnectedSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .background(Color(red: 0.047, green: 0.035, blue: 0.027))
        }
        // Direct WebAluno WebView (skip intermediate screen)
        .fullScreenCover(isPresented: $showWebalunoWebView) {
            WebAlunoWebViewScreen(
                onBack: { showWebalunoWebView = false },
                onSessionCaptured: { cookie in
                    capturedSessionCookie = "PHPSESSID=\(cookie)"
                    showWebalunoWebView = false
                    Task { await connectWebalunoWithSession(cookie) }
                },
                userEmail: container.authManager.userEmail
            )
        }
        .vitaToastHost(toastState)
    }

    // MARK: - Top Nav

    private var topNav: some View {
        HStack(spacing: 10) {
            Button(action: { onBack?() }) {
                navCircle(icon: "chevron.left")
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("Conectores")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.90))
                Text("Portais academicos")
                    .font(.system(size: 10.5))
                    .foregroundColor(goldSubtle.opacity(0.35))
            }

            Spacer()

            Button(action: { Task { await loadAllStatuses() } }) {
                navCircle(icon: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.141, green: 0.094, blue: 0.071).opacity(0.60),
                            Color(red: 0.063, green: 0.043, blue: 0.039).opacity(0.68)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(Capsule().stroke(Color(red: 1.0, green: 0.910, blue: 0.761).opacity(0.14), lineWidth: 1))
                .shadow(color: .black.opacity(0.20), radius: 21, x: 0, y: 10)
        )
        .padding(.horizontal, 16)
        .padding(.top, 2)
    }

    private func navCircle(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(goldSubtle.opacity(0.68))
            .frame(width: 36, height: 36)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [
                            goldSubtle.opacity(0.075),
                            goldSubtle.opacity(0.03)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            )
            .overlay(Circle().stroke(goldSubtle.opacity(0.16), lineWidth: 1))
    }

    // MARK: - Connected Count Card

    private var connectedCountCard: some View {
        let connectedCount = totalConnected
        let total = totalPortals

        return HStack {
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
                Text("\(connectedCount)")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.90))
                Text("/\(total)")
                    .font(.system(size: 11))
                    .foregroundColor(goldSubtle.opacity(0.30))
            }
        }
        .padding(14)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
    }

    private var totalConnected: Int {
        var count = 0
        if webalunoStatus == .connected { count += 1 }
        if canvasStatus == .connected   { count += 1 }
        return count
    }

    private var totalPortals: Int {
        return 4
    }

    // MARK: - Portal Card (academic)

    @ViewBuilder
    private func portalCard(_ portal: PortalDef) -> some View {
        let (status, lastSync, disc, grades, schedule) = statusForPortalId(portal.id)
        let isConnected = status == .connected

        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                // Letter icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(portal.iconBg)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(portal.iconBorder, lineWidth: 1)
                        )
                    Text(portal.letter)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(portal.iconText)
                }

                // Name + status
                VStack(alignment: .leading, spacing: 3) {
                    Text(portal.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.988, blue: 0.973).opacity(0.90))
                    statusRow(isConnected: isConnected, status: status)
                }

                Spacer()

                // Action button
                actionButton(isConnected: isConnected, isMoodle: false) {
                    if isConnected {
                        switch portal.id {
                        case "webaluno": disconnectWebaluno()
                        case "canvas":   disconnectCanvas()
                        default: break
                        }
                    } else {
                        switch portal.id {
                        case "webaluno": showWebalunoWebView = true
                        case "canvas":   onCanvasConnect?()
                        default: break // moodle/sigaa coming soon
                        }
                    }
                }
            }
            .padding(14)

            // Meta row (when connected)
            if isConnected {
                metaRow(lastSync: lastSync, disciplines: disc, grades: grades, schedule: schedule, portalId: portal.id)
            }
        }
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
        .onTapGesture {
            if isConnected {
                switch portal.id {
                case "webaluno": showWebalunoSheet = true
                case "canvas":   showCanvasSheet = true
                default: break
                }
            }
        }
    }

    // MARK: - Portal Card (Google)

    @ViewBuilder
    private func portalCardGoogle(
        letter: String, name: String,
        iconBg: Color, iconBorder: Color, iconText: Color,
        status: ConnectionItemStatus, lastSync: String?,
        disciplines: Int, grades: Int,
        onConnect: @escaping () -> Void,
        onDisconnect: @escaping () -> Void,
        onTapConnected: @escaping () -> Void
    ) -> some View {
        let isConnected = status == .connected

        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBg)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(iconBorder, lineWidth: 1)
                        )
                    Text(letter)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(iconText)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.988, blue: 0.973).opacity(0.90))
                    statusRow(isConnected: isConnected, status: status)
                }

                Spacer()

                actionButton(isConnected: isConnected, isMoodle: false) {
                    if isConnected { onDisconnect() }
                    else           { onConnect() }
                }
            }
            .padding(14)

            if isConnected {
                metaRow(lastSync: lastSync, disciplines: disciplines, grades: grades)
            }
        }
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(borderColor, lineWidth: 1))
        .onTapGesture {
            if isConnected { onTapConnected() }
        }
    }

    // MARK: - Card sub-views

    @ViewBuilder
    private func statusRow(isConnected: Bool, status: ConnectionItemStatus) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(
                    isConnected
                        ? Color(red: 0.510, green: 0.784, blue: 0.549).opacity(0.75)
                        : Color.white.opacity(0.12)
                )
                .frame(width: 7, height: 7)
                .shadow(color: isConnected ? Color(red: 0.510, green: 0.784, blue: 0.549).opacity(0.30) : .clear, radius: 3)
            Text(isConnected ? "Conectado" : "Disponivel")
                .font(.system(size: 10.5))
                .foregroundColor(
                    isConnected
                        ? Color(red: 0.510, green: 0.784, blue: 0.549).opacity(0.65)
                        : goldSubtle.opacity(0.35)
                )
        }
    }

    @ViewBuilder
    private func actionButton(isConnected: Bool, isMoodle: Bool, action: @escaping () -> Void) -> some View {
        if isMoodle {
            // Coming soon — disabled style
            Text("Em breve")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(goldSubtle.opacity(0.25))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(goldSubtle.opacity(0.06), lineWidth: 1)
                )
        } else {
            Button(action: action) {
                Text(isConnected ? "Desconectar" : "Conectar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(
                        isConnected
                            ? Color(red: 1.0, green: 0.471, blue: 0.314).opacity(0.70)
                            : Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.80)
                    )
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        isConnected
                            ? Color(red: 1.0, green: 0.471, blue: 0.314).opacity(0.06)
                            : VitaColors.glassInnerLight.opacity(0.12)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8).stroke(
                            isConnected
                                ? Color(red: 1.0, green: 0.471, blue: 0.314).opacity(0.12)
                                : Color(red: 1.0, green: 0.784, blue: 0.471).opacity(0.16),
                            lineWidth: 1
                        )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func metaRow(lastSync: String?, disciplines: Int, grades: Int, schedule: Int = 0, portalId: String? = nil) -> some View {
        let hasData = disciplines > 0 || grades > 0 || schedule > 0
        let hasSync = lastSync != nil

        if hasSync || hasData {
            Rectangle()
                .fill(goldSubtle.opacity(0.04))
                .frame(height: 1)

            HStack(spacing: 6) {
                if let sync = lastSync {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                        .foregroundColor(goldSubtle.opacity(0.25))
                    Text(sync)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.55))
                }

                if hasSync && hasData {
                    dot
                }

                if disciplines > 0 {
                    metaChip("\(disciplines)", "disciplinas")
                }
                if grades > 0 {
                    metaChip("\(grades)", "notas")
                }
                if schedule > 0 {
                    metaChip("\(schedule)", "aulas")
                }

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private func metaChip(_ value: String, _ label: String) -> some View {
        HStack(spacing: 2) {
            Text(value)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(red: 1.0, green: 0.863, blue: 0.627).opacity(0.55))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(goldSubtle.opacity(0.30))
        }
    }

    private var dot: some View {
        Circle()
            .fill(goldSubtle.opacity(0.20))
            .frame(width: 3, height: 3)
    }

    // MARK: - Como Funciona

    private var comoFunciona: some View {
        VStack(spacing: 10) {
            howItWorksStep("1", "Conecte seu portal academico com suas credenciais")
            howItWorksStep("2", "A Vita importa disciplinas, notas e horarios")
            howItWorksStep("3", "Dados sincronizados automaticamente a cada 15 minutos")
            howItWorksStep("4", "Desconecte a qualquer momento — seus dados sao excluidos")
                .padding(.bottom, 0)
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

    // MARK: - Portal helpers

    private func statusForPortalId(_ id: String) -> (ConnectionItemStatus, String?, Int, Int, Int) {
        switch id {
        case "canvas":   return (canvasStatus,   canvasLastSync,   canvasCourses,        canvasAssignments, 0)
        case "webaluno": return (webalunoStatus,  webalunoLastSync, webAlunoDisciplines,  webalunoGrades,    webalunoSchedule)
        default:         return (.disconnected, nil, 0, 0, 0)
        }
    }

    private func statusForPortal(_ type: String) -> (ConnectionItemStatus, String?, Int, Int, Int) {
        statusForPortalId(type)
    }

    // MARK: - Bottom Sheets

    private var canvasConnectedSheet: some View {
        ConnectedServiceSheet(
            serviceName: "Canvas LMS",
            icon: "building.columns",
            lastSync: canvasLastSync,
            stats: [
                StatItem(value: canvasCourses, label: "Disciplinas"),
                StatItem(value: canvasAssignments, label: "Avaliações"),
                StatItem(value: canvasFiles, label: "Arquivos"),
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
                StatItem(value: webAlunoDisciplines, label: "Disciplinas"),
                StatItem(value: webalunoGrades, label: "Notas"),
                StatItem(value: webalunoSchedule, label: "Aulas"),
            ],
            syncNote: "Sincroniza automaticamente a cada 15 min",
            onSync: {
                showWebalunoSheet = false
                showWebalunoWebView = true
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
        await loadUniversityPortals()
        await loadPortalConnections()
        async let calendar = loadCalendar()
        async let drive    = loadDrive()
        _ = await (calendar, drive)
    }

    private func loadUniversityPortals() async {
        do {
            let profile = try await container.api.getProfile()
            if let uniName = profile.university, !uniName.isEmpty {
                universityName = uniName
                let response = try await container.api.getUniversities(query: uniName)
                if let uni = response.universities.first, let portals = uni.portals, !portals.isEmpty {
                    universityPortals = portals
                }
            }
        } catch {
            print("[Connections] University portals load failed: \(error)")
        }
    }

    /// Single call to GET /api/portal/status — parses all connectors from connections[]
    private func loadPortalConnections() async {
        do {
            let data = try await container.api.getCanvasStatus()
            // Always parse connections — even inactive ones — so UI reflects real state
            guard let connections = data.connections, !connections.isEmpty else {
                canvasStatus = .disconnected
                webalunoStatus = .disconnected
                return
            }

            for conn in connections {
                let status: ConnectionItemStatus = switch conn.status {
                    case "expired": .expired
                    case "inactive", "disconnected": .disconnected
                    default: .connected
                }
                // Use lastPingAt for "session alive" indicator, lastSyncAt for "data freshness"
                let syncTime = conn.lastPingAt ?? conn.lastSyncAt

                switch conn.portalType {
                case "canvas":
                    canvasStatus      = status
                    canvasLastSync    = syncTime.flatMap { formatRelativeTime($0) }
                    canvasCourses     = conn.counts?.subjects ?? 0
                    canvasFiles       = conn.counts?.documents ?? 0
                    canvasAssignments = conn.counts?.evaluations ?? 0
                case "mannesoft":
                    webalunoStatus      = status
                    webalunoLastSync    = syncTime.flatMap { formatRelativeTime($0) }
                    webalunoGrades      = conn.counts?.evaluations ?? 0
                    webalunoSchedule    = conn.counts?.schedule ?? 0
                    webAlunoDisciplines = conn.counts?.subjects ?? 0
                default:
                    break
                }
            }
        } catch {
            print("[Connections] Portal status load failed: \(error)")
        }
    }

    // Legacy compat — these now just call loadPortalConnections()
    private func loadCanvas() async { await loadPortalConnections() }
    private func loadWebaluno() async { /* handled by loadPortalConnections */ }

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
            } catch { print("[Conectores] error: \(error)") }
        }
    }

    private func connectWebalunoWithSession(_ cookie: String) async {
        do {
            toastState.show("Conectando WebAluno...", type: .success)
            webalunoStatus = .connected
            let _ = try await container.api.startVitaCrawl(
                cookies: "PHPSESSID=\(cookie)",
                instanceUrl: "https://ac3949.mannesoftprime.com.br"
            )
            toastState.show("WebAluno conectado! Extraindo dados...", type: .success)
            await loadPortalConnections()
        } catch {
            print("[Conectores] WebAluno connect error: \(error)")
            toastState.show("Erro ao conectar: \(error.localizedDescription)", type: .error)
        }
    }

    private func disconnectWebaluno() {
        Task {
            do {
                try await container.api.disconnectWebaluno()
                webalunoStatus      = .disconnected
                webalunoLastSync    = nil
                webalunoGrades      = 0
                webalunoSchedule    = 0
                webAlunoDisciplines = 0
            } catch { print("[Conectores] error: \(error)") }
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
            } catch { print("[Conectores] error: \(error)") }
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
            } catch { print("[Conectores] error: \(error)") }
        }
    }

    // MARK: - WebAluno: Handle captured pages from WebView

    private func handleWebalunoPagesCaptured(_ capturedPages: [CapturedPortalPage]) {
        Task {
            isExtractingWebaluno = true
            let pages = capturedPages.map { page in
                PortalExtractRequestPagesInner(type: page.type, html: page.html, linkText: page.linkText)
            }
            guard !pages.isEmpty else {
                isExtractingWebaluno = false
                toastState.show("Nenhuma pagina capturada do portal.", type: .error)
                return
            }
            do {
                let result = try await container.api.extractPortalPages(
                    pages: pages,
                    instanceUrl: "https://ac3949.mannesoftprime.com.br",
                    university: "ULBRA",
                    sessionCookie: capturedSessionCookie
                )
                isExtractingWebaluno = false
                if result.success == true {
                    let grades = result.grades ?? 0
                    let schedule = result.schedule ?? 0
                    if grades > 0 || schedule > 0 {
                        toastState.show("Pronto! \(grades) notas, \(schedule) aulas importadas", type: .success)
                    } else {
                        toastState.show("Conectado! Dados serao sincronizados em background.", type: .success)
                    }
                    await loadWebaluno()
                } else {
                    toastState.show("Falha na extracao. Tente novamente.", type: .error)
                }
            } catch {
                isExtractingWebaluno = false
                toastState.show("Erro de conexao. Verifique sua internet.", type: .error)
            }
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
        let fmt = DateFormatter()
        fmt.dateFormat = "dd MMM"
        fmt.locale = Locale(identifier: "pt_BR")
        return fmt.string(from: date)
    }
}

// MARK: - StatItem

private struct StatItem {
    let value: Int
    let label: String
}

// MARK: - ConnectedServiceSheet

private struct ConnectedServiceSheet: View {
    let serviceName: String
    let icon:        String
    var subtitle:    String?
    let lastSync:    String?
    let stats:       [StatItem]
    var syncNote:    String?
    let onSync:      () -> Void
    let onDisconnect: () -> Void

    private let goldPrimary = VitaColors.accentHover  // → VitaColors
    private let goldAccent  = VitaColors.accent        // → VitaColors.accent
    private let goldSubtle  = VitaColors.accentLight   // → VitaColors.accentLight

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.29, green: 0.87, blue: 0.50).opacity(0.10))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle().stroke(Color(red: 0.29, green: 0.87, blue: 0.50).opacity(0.25), lineWidth: 1)
                            )
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(Color(red: 0.29, green: 0.87, blue: 0.50))
                    }
                    .padding(.top, 24)

                    Spacer().frame(height: 16)

                    Text("\(serviceName) Conectado")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.92))

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(goldSubtle.opacity(0.35))
                            .padding(.top, 4)
                    }

                    if let lastSync {
                        Text("Ultima sincronizacao: \(lastSync)")
                            .font(.system(size: 12))
                            .foregroundColor(goldSubtle.opacity(0.30))
                            .padding(.top, 4)
                    }

                    if let syncNote {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 9))
                            Text(syncNote)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(Color(red: 0.29, green: 0.87, blue: 0.50).opacity(0.60))
                        .padding(.top, 6)
                    }

                    if !stats.isEmpty {
                        HStack(spacing: 0) {
                            ForEach(stats.indices, id: \.self) { i in
                                if i > 0 {
                                    Rectangle()
                                        .fill(goldSubtle.opacity(0.08))
                                        .frame(width: 1, height: 32)
                                }
                                statPill(stats[i])
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(Color.white.opacity(0.025))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 24)
                    }

                    Button(action: onSync) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 14, weight: .medium))
                            Text("Sincronizar Agora")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.031, green: 0.024, blue: 0.039))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [goldPrimary, goldAccent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    Button(action: onDisconnect) {
                        HStack(spacing: 6) {
                            Image(systemName: "link.badge.plus")
                                .font(.system(size: 13))
                                .rotationEffect(.degrees(45))
                            Text("Desconectar \(serviceName)")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(goldSubtle.opacity(0.35))
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
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color.white.opacity(0.88))
            Text(item.label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(goldSubtle.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }
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
