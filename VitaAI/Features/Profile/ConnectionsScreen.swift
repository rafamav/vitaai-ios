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

    // Direct WebView flows (no intermediate screen)
    @State private var showWebalunoWebView = false
    @State private var webalunoInstanceUrl: String = ""
    @State private var showCanvasWebView = false
    @State private var canvasInstanceUrl: String = ""

    // WhatsApp linking flow
    @State private var showWhatsAppSheet = false
    @State private var waPhone: String = ""
    @State private var waCode: String = ""
    @State private var waStep: Int = 0
    @State private var waError: String?
    @State private var waSending = false

    // Sync overlay state
    @State private var syncing = false
    @State private var syncConnectorName: String = ""
    @State private var syncPhase: String = "login"
    @State private var syncMessage: String?
    @State private var syncProgress: Double = 0 // 0-100, used for webaluno+mannesoft overlay
    @State private var canvasSyncPhase: CanvasSyncOrchestrator.Phase = .starting
    @State private var canvasSyncProgress: Double = 0
    @State private var isCanvasSync = false

    // Design tokens
    private let goldSubtle = VitaColors.accentLight
    private let borderColor = VitaColors.glassBorder
    private let cardBg = VitaColors.glassBg

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
            // Starry ambient background (same as all screens)
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
        // WebAluno login — full-page navigationDestination (inside shell)
        .navigationDestination(isPresented: $showWebalunoWebView) {
            WebAlunoWebViewScreen(
                onBack: { showWebalunoWebView = false },
                onSessionCaptured: { cookie in
                    // Don't dismiss yet — bridge.js needs the WebView to extract data
                    connectWebaluno(cookie: cookie)
                },
                onPagesExtracted: { pages in
                    NSLog("[Connections] Bridge extracted %d pages, sending to backend", pages.count)
                    showWebalunoWebView = false
                    sendExtractedPages(pages)
                },
                userEmail: container.authManager.userEmail,
                portalInstanceUrl: webalunoInstanceUrl
            )
        }
        // Canvas WebView — pushed inside NavigationStack (keeps shell)
        .navigationDestination(isPresented: $showCanvasWebView) {
            canvasWebViewFullScreen
        }
        // WhatsApp linking sheet
        .sheet(isPresented: $showWhatsAppSheet) {
            whatsAppLinkSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .background(Color(red: 0.047, green: 0.035, blue: 0.027))
        }
        // Sync overlay (shared for both Canvas and WebAluno)
        .overlay {
            if syncing {
                ZStack {
                    VitaColors.surface.opacity(0.95)
                        .ignoresSafeArea()
                    if isCanvasSync {
                        ConnectorSyncView(
                            connectorName: "Canvas",
                            steps: SyncStep.canvasSteps(phase: canvasSyncPhase),
                            message: syncMessage,
                            progress: canvasSyncProgress < 100 ? canvasSyncProgress : nil
                        )
                    } else {
                        ConnectorSyncView(
                            connectorName: syncConnectorName,
                            steps: SyncStep.webalunoSteps(phase: syncPhase),
                            message: syncMessage,
                            progress: syncProgress > 0 && syncProgress < 100 ? syncProgress : nil
                        )
                    }
                }
                .transition(.opacity)
            }
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

                // Integracoes section
                sectionLabel("INTEGRACOES")
                    .padding(.top, 18)

                VStack(spacing: 8) {
                    integrationCard(
                        letter: "G", name: "Google Calendar",
                        color: Color(red: 0.26, green: 0.52, blue: 0.96),
                        connectorId: "google_calendar",
                        state: vm.calendar, vm: vm
                    )
                    integrationCard(
                        letter: "G", name: "Google Drive",
                        color: Color(red: 0.13, green: 0.59, blue: 0.33),
                        connectorId: "google_drive",
                        state: vm.drive, vm: vm
                    )
                    integrationCard(
                        letter: "S", name: "Spotify",
                        color: Color(red: 0.11, green: 0.73, blue: 0.33),
                        connectorId: "spotify",
                        state: vm.spotify, vm: vm
                    )
                    integrationCard(
                        letter: "♥", name: "Apple Health",
                        color: Color(red: 0.96, green: 0.26, blue: 0.36),
                        connectorId: "apple_health",
                        state: vm.appleHealth, vm: vm
                    )
                    ConnectorCard(
                        letter: "W",
                        name: "WhatsApp",
                        status: vm.whatsapp.status,
                        color: Color(red: 0.15, green: 0.68, blue: 0.38),
                        lastSync: vm.whatsapp.lastSync,
                        stats: vm.whatsapp.stats,
                        onConnect: {
                            waStep = 0; waPhone = ""; waCode = ""; waError = nil
                            showWhatsAppSheet = true
                        },
                        onDisconnect: { Task { await vm.disconnect("whatsapp") } },
                        onTapConnected: {
                            waStep = 0; waPhone = vm.whatsapp.subtitle ?? ""; waCode = ""; waError = nil
                            showWhatsAppSheet = true
                        }
                    )
                }
                .padding(.horizontal, 14)

                // Como funciona
                sectionLabel("COMO FUNCIONA")
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
        .refreshable { await vm.loadAll() }
    }

    // MARK: - Institucional Section

    @ViewBuilder
    private func institucionalSection(vm: ConnectorsViewModel) -> some View {
        let hasUniversity = !vm.universityName.isEmpty
        // Fallback: se o catalogo getUniversities() nao retornou portals (universidade fora do
        // catalogo ou backend incompleto), constroi portais a partir do state real do VM.
        // Isso garante que usuario com conexao ativa sempre ve o card, independente do catalogo.
        let fallbackPortals: [UniversityPortal] = {
            guard vm.universityPortals.isEmpty else { return [] }
            var result: [UniversityPortal] = []
            if vm.mannesoft.status != .disconnected {
                result.append(UniversityPortal(
                    id: "fallback-mannesoft",
                    portalType: "mannesoft",
                    portalName: "Portal Academico",
                    instanceUrl: vm.mannesoft.instanceUrl
                ))
            }
            if vm.canvas.status != .disconnected {
                result.append(UniversityPortal(
                    id: "fallback-canvas",
                    portalType: "canvas",
                    portalName: "Canvas",
                    instanceUrl: vm.canvas.instanceUrl
                ))
            }
            return result
        }()
        let detectedPortals = vm.universityPortals.isEmpty ? fallbackPortals : vm.universityPortals
        let detectedTypes = Set(detectedPortals.map(\.portalType))
        let otherPortals = allPortalTypes.filter { !detectedTypes.contains($0.type) }

        // Section header
        sectionLabel("INSTITUCIONAL")
            .padding(.top, 18)

        // University subtitle (name + city from API)
        if hasUniversity {
            HStack(spacing: 6) {
                Image(systemName: "building.columns")
                    .font(.system(size: 11))
                    .foregroundColor(goldSubtle.opacity(0.40))
                Text(universityDisplayLine(vm: vm))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 8)
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
                        lastPing: connState.lastPing,
                        isStale: connState.isStale,
                        stats: connState.stats,
                        isPrimary: portal.isPrimary,
                        onConnect: { handleConnect(portalType: portal.portalType, instanceUrl: portal.instanceUrl) },
                        onDisconnect: { Task { await vm.disconnect(portal.portalType) } },
                        onTapConnected: { activeSheet = portal.portalType }
                    )
                }
            } else if !hasUniversity {
                // No university — show hint
                noUniversityHint
            }

            // "Outros portais" toggle
            if !otherPortals.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3)) { showAllPortals.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showAllPortals ? "minus.circle" : "plus.circle")
                            .font(.system(size: 13))
                        Text(showAllPortals ? "Ocultar outros portais" : "Outros portais")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Image(systemName: showAllPortals ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 14)
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
                        onConnect: { handleConnect(portalType: portal.type, instanceUrl: nil) },
                        onDisconnect: { Task { await vm.disconnect(portal.type) } },
                        onTapConnected: { activeSheet = portal.type }
                    )
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 14)
    }

    // MARK: - University Display

    private func universityDisplayLine(vm: ConnectorsViewModel) -> String {
        if vm.universityCity.isEmpty {
            return vm.universityName
        }
        return "\(vm.universityName) \u{00B7} \(vm.universityCity)"
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
            onConnect: { handleConnect(portalType: connectorId, instanceUrl: nil) },
            onDisconnect: { Task { await vm.disconnect(connectorId) } },
            onTapConnected: { activeSheet = connectorId }
        )
    }

    // MARK: - Integration Card (OAuth connectors)

    // MARK: - WhatsApp Link Sheet

    @ViewBuilder
    private var whatsAppLinkSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer().frame(height: 10)
                Image(systemName: waStep == 2 ? "checkmark.circle.fill" : "message.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(waStep == 2 ? .green : Color(red: 0.15, green: 0.68, blue: 0.38))

                if waStep == 0 {
                    Text("Conectar WhatsApp").font(.title2.bold()).foregroundStyle(.white)
                    Text("Receba notificacoes e converse com a VITA pelo WhatsApp")
                        .font(.subheadline).foregroundStyle(.gray).multilineTextAlignment(.center).padding(.horizontal)
                    TextField("51989484243", text: $waPhone)
                        .keyboardType(.phonePad).textContentType(.telephoneNumber)
                        .padding().background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 24).foregroundStyle(.white)
                    if let err = waError { Text(err).font(.caption).foregroundStyle(.red) }
                    Button {
                        Task { await sendWACode() }
                    } label: {
                        HStack {
                            if waSending { ProgressView().tint(.black) }
                            Text("Enviar codigo").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color(red: 0.15, green: 0.68, blue: 0.38))
                        .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(waPhone.count < 8 || waSending).padding(.horizontal, 24)

                } else if waStep == 1 {
                    Text("Digite o codigo").font(.title2.bold()).foregroundStyle(.white)
                    Text("Enviamos um codigo de 6 digitos para seu WhatsApp")
                        .font(.subheadline).foregroundStyle(.gray).multilineTextAlignment(.center).padding(.horizontal)
                    TextField("000000", text: $waCode)
                        .keyboardType(.numberPad).textContentType(.oneTimeCode)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .padding().background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 60).foregroundStyle(.white)
                    if let err = waError { Text(err).font(.caption).foregroundStyle(.red) }
                    Button {
                        Task { await verifyWACode() }
                    } label: {
                        HStack {
                            if waSending { ProgressView().tint(.black) }
                            Text("Verificar").fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(Color(red: 0.15, green: 0.68, blue: 0.38))
                        .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(waCode.count < 6 || waSending).padding(.horizontal, 24)
                    Button("Reenviar codigo") { Task { await sendWACode() } }
                        .font(.caption).foregroundStyle(goldSubtle)

                } else {
                    Text("WhatsApp conectado!").font(.title2.bold()).foregroundStyle(.white)
                    Text("A VITA vai te mandar uma mensagem de boas-vindas")
                        .font(.subheadline).foregroundStyle(.gray)
                }
                Spacer()
            }
            .padding(.top, 20)
            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { showWhatsAppSheet = false }.foregroundStyle(.gray)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func sendWACode() async {
        guard let vm else { return }
        waSending = true; waError = nil
        do {
            try await vm.linkWhatsApp(phone: waPhone)
            waStep = 1
        } catch { waError = "Erro ao enviar codigo" }
        waSending = false
    }

    private func verifyWACode() async {
        guard let vm else { return }
        waSending = true; waError = nil
        do {
            try await vm.verifyWhatsApp(code: waCode)
            waStep = 2
            try? await Task.sleep(for: .seconds(2))
            showWhatsAppSheet = false
        } catch { waError = "Codigo invalido ou expirado" }
        waSending = false
    }

        private func integrationCard(
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
            onConnect: { Task { await vm.connectIntegration(connectorId) } },
            onDisconnect: { Task { await vm.disconnect(connectorId) } },
            onTapConnected: { activeSheet = connectorId }
        )
    }

    // MARK: - Handle Connect (direct flow, no intermediate screen)

    private func handleConnect(portalType: String, instanceUrl: String?) {
        switch portalType {
        case "webaluno", "mannesoft":
            webalunoInstanceUrl = instanceUrl ?? vm?.mannesoft.instanceUrl ?? ""
            NSLog("[Connections] handleConnect webaluno — instanceUrl param: %@, vm.mannesoft.instanceUrl: %@, resolved: %@",
                  instanceUrl ?? "nil", vm?.mannesoft.instanceUrl ?? "nil", webalunoInstanceUrl)
            showWebalunoWebView = true
        case "canvas":
            canvasInstanceUrl = instanceUrl ?? vm?.canvas.instanceUrl ?? "https://ulbra.instructure.com"
            showCanvasWebView = true
        default:
            // Unknown portal — fallback to connect screen
            onPortalConnect?(portalType)
        }
    }

    private func sendExtractedPages(_ pages: [CapturedPortalPage]) {
        guard let vm else { return }
        // Bridge has captured the HTML. Backend POST /extract returns in ~400ms
        // with a syncId; the actual Haiku extraction runs in background (~1-2min).
        // We MUST poll /portal/sync-progress?syncId=X until isDone, otherwise the
        // overlay closes with grades=0/schedule=0 (still-running state) and the
        // user has no idea anything is happening. Fix: 2s poll loop up to 180s.
        isCanvasSync = false
        syncConnectorName = "Portal Acadêmico"
        syncPhase = "extracting"
        syncMessage = "Vita analisando \(pages.count) páginas…"
        syncProgress = 10
        withAnimation { syncing = true }
        Task { await runExtraction(pages: pages, vm: vm) }
    }

    @MainActor
    private func runExtraction(pages: [CapturedPortalPage], vm: ConnectorsViewModel) async {
        let apiPages = pages.map { page in
            PortalExtractRequestPagesInner(type: page.type, html: page.html, linkText: page.linkText)
        }
        guard !apiPages.isEmpty else {
            withAnimation { syncing = false }
            return
        }
        let portalUrl = vm.universityPortals.first(where: { $0.portalType == "webaluno" || $0.portalType == "mannesoft" })?.instanceUrl ?? webalunoInstanceUrl
        let result: PortalExtract200Response
        do {
            result = try await container.api.extractPortalPages(
                pages: apiPages,
                instanceUrl: portalUrl,
                university: ""
            )
        } catch {
            NSLog("[Connections] Extract failed: %@", error.localizedDescription)
            withAnimation { syncing = false }
            toastState.show("Falha ao extrair dados do portal. Tenta reconectar.", type: .error)
            return
        }
        NSLog("[Connections] POST /extract returned, syncId=%@", result.syncId ?? "nil")
        guard let syncId = result.syncId, !syncId.isEmpty else {
            finishSync(grades: result.grades ?? 0, schedule: result.schedule ?? 0, vm: vm)
            return
        }
        await pollUntilDone(syncId: syncId, pagesCount: pages.count, vm: vm)
    }

    /// Polls /api/portal/sync-progress until the backend reports done/error.
    /// Timer-driven fallback percent keeps the progress bar moving even when the
    /// in-memory sync store returns 404 (happens after vita-web container
    /// restart). Hard cap at 180s.
    @MainActor
    private func pollUntilDone(syncId: String, pagesCount: Int, vm: ConnectorsViewModel) async {
        let estimatedTotalSeconds = 120.0
        // Honesty guard: if we never hear back from the sync store (404 or network
        // error for 5 consecutive polls = 10s silent), we STOP claiming "Vita
        // analisando" and surface a real error. The user never gets stuck
        // watching a lying progress bar for 3 minutes.
        var consecutiveMisses = 0
        let missThreshold = 5
        for tick in 0..<90 {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            let elapsed = Double(tick + 1) * 2.0
            let timerPct = min(95.0, (elapsed / estimatedTotalSeconds) * 90.0 + 10.0)
            var progress: SyncProgressResponse? = nil
            do {
                progress = try await container.api.getSyncProgress(syncId: syncId)
            } catch {
                NSLog("[Connections] poll err: %@", error.localizedDescription)
            }
            if let p = progress {
                consecutiveMisses = 0
                let label: String = {
                    if let lbl = p.label, !lbl.isEmpty { return lbl }
                    return "Vita trabalhando… (\(Int(elapsed))s)"
                }()
                syncMessage = label
                syncPhase = phaseFromLabel(label)
                syncProgress = p.percent ?? timerPct
                if p.isDone {
                    syncProgress = 100
                    await vm.loadAll()
                    let s = vm.state(for: "mannesoft")
                    let subjects = s.stats.first(where: { $0.label == "disciplinas" })?.value ?? 0
                    let evals = s.stats.first(where: { $0.label == "notas" })?.value ?? 0
                    finishSync(grades: subjects, schedule: evals, vm: vm, label: "notas")
                    return
                }
                if p.isError {
                    withAnimation { syncing = false }
                    toastState.show(label, type: .error)
                    return
                }
            } else {
                consecutiveMisses += 1
                if consecutiveMisses >= missThreshold {
                    NSLog("[Connections] %d consecutive poll misses — surfacing error", consecutiveMisses)
                    withAnimation { syncing = false }
                    toastState.show("Vita não conseguiu processar o portal. Tenta reconectar em alguns minutos.", type: .error)
                    return
                }
                syncMessage = "Aguardando Vita responder… (\(Int(elapsed))s)"
                syncProgress = timerPct
            }
        }
        NSLog("[Connections] sync-progress timed out after 180s")
        withAnimation { syncing = false }
        toastState.show("Processamento demorou mais que o esperado. Verifique depois se as notas apareceram.", type: .error)
    }

    /// Close the overlay after extraction completes. Called both for the
    /// synchronous path (no syncId in response) and at the end of the poll loop.
    @MainActor
    private func finishSync(grades: Int, schedule: Int, vm: ConnectorsViewModel, label: String = "aulas") {
        syncPhase = "done"
        let msg: String
        if grades > 0 {
            msg = "Pronto! \(grades) matérias · \(schedule) \(label)."
        } else {
            msg = "Pronto! Dados atualizados."
        }
        syncMessage = msg
        Task {
            await vm.loadAll()
            // Linger so user reads the success state
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            withAnimation { syncing = false }
            toastState.show(msg, type: .success)
        }
    }

    /// Map the free-text progress label from backend into the webalunoSteps phase enum.
    private func phaseFromLabel(_ label: String) -> String {
        let l = label.lowercased()
        if l.contains("disciplina") || l.contains("matéria") { return "disciplines" }
        if l.contains("nota") || l.contains("grade") { return "grades" }
        if l.contains("horário") || l.contains("aula") || l.contains("schedule") { return "schedule" }
        if l.contains("extrai") || l.contains("extract") || l.contains("process") || l.contains("analis") {
            return "extracting"
        }
        if l.contains("conclu") || l.contains("done") || l.contains("pronto") { return "done" }
        return "extracting"
    }

    /// Registers the captured Mannesoft/WebAluno session with the backend.
    ///
    /// In the current client-bridge architecture this call is just the cookie
    /// hand-off — the backend persists PHPSESSID + Cloudflare cookies and returns
    /// immediately. Actual data extraction happens a moment later when
    /// `onPagesExtracted` fires and `sendExtractedPages` POSTs to /api/portal/extract.
    ///
    /// We do NOT show a sync overlay here. The overlay is owned by
    /// `sendExtractedPages` so it stays visible across the full Hub VITA
    /// processing window (~1-2min) — not just the 500ms it takes to save cookies.
    /// Previous legacy code looped getSyncProgress for up to 2min against
    /// startVitaCrawl which is Mannesoft-incompatible (Cloudflare blocks
    /// server-side validation) — it always fell through silently before the
    /// bridge even finished, leaving the user in the WebView with zero feedback.
    private func connectWebaluno(cookie: String) {
        guard let vm else { return }
        Task {
            do {
                let portalUrl = vm.universityPortals.first(where: { $0.portalType == "webaluno" || $0.portalType == "mannesoft" })?.instanceUrl ?? webalunoInstanceUrl
                _ = try await container.api.startVitaCrawl(
                    cookies: "PHPSESSID=\(cookie)",
                    instanceUrl: portalUrl
                )
                NSLog("[Connections] Session registered with backend; waiting for bridge extraction")
            } catch {
                NSLog("[Connections] Connect failed (will still try bridge path): %@", error.localizedDescription)
            }
        }
    }

    private func connectCanvas(cookies: String) {
        guard let vm else { return }
        isCanvasSync = true
        canvasSyncPhase = .starting
        canvasSyncProgress = 0
        syncMessage = CanvasSyncOrchestrator.Phase.starting.rawValue
        withAnimation { syncing = true }
        Task {
            let orchestrator = CanvasSyncOrchestrator(
                cookies: cookies,
                instanceUrl: canvasInstanceUrl,
                vitaAPI: container.api,
                onProgress: { [self] progress in
                    Task { @MainActor in
                        self.canvasSyncPhase = progress.phase
                        self.canvasSyncProgress = progress.percent
                        if let detail = progress.detail {
                            self.syncMessage = "\(progress.phase.rawValue) \(detail)"
                        } else {
                            self.syncMessage = progress.phase.rawValue
                        }
                    }
                }
            )
            do {
                let result = try await orchestrator.run()
                withAnimation { syncing = false }
                let summary = [
                    result.courses.map { "\($0) disciplinas" },
                    result.assignments.map { "\($0) atividades" },
                    result.pdfExtracted.map { "\($0) PDFs processados" },
                ].compactMap { $0 }.joined(separator: ", ")
                toastState.show(summary.isEmpty ? "Extração completa!" : "Pronto! \(summary)", type: .success)
                await vm.loadAll()
            } catch {
                withAnimation { syncing = false }
                toastState.show("Erro: \(error.localizedDescription)", type: .error)
            }
        }
    }

    // MARK: - Canvas WebView Full Screen

    private var canvasWebViewFullScreen: some View {
        VStack(spacing: 0) {
            // Nav bar
            HStack(spacing: 4) {
                Button(action: { showCanvasWebView = false }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Voltar")
                            .font(VitaTypography.bodyLarge)
                    }
                    .foregroundColor(VitaColors.accent)
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                Spacer()
                Text("Canvas LMS")
                    .font(VitaTypography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(VitaColors.textPrimary)
                Spacer()
                Color.clear.frame(width: 70, height: 44)
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            // Instructions
            VitaGlassCard {
                HStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 20))
                        .foregroundColor(VitaColors.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Faça login no Canvas")
                            .font(VitaTypography.titleSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(VitaColors.textPrimary)
                        Text("Vita importa disciplinas, notas e materiais")
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(16)
            }
            .padding(.horizontal, 20)

            // URL bar + WebView
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundColor(VitaColors.textTertiary)
                    Text(canvasInstanceUrl.replacingOccurrences(of: "https://", with: ""))
                        .font(.system(size: 10))
                        .foregroundColor(VitaColors.textTertiary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.03))

                PortalWebView(
                    portalType: "canvas",
                    portalURL: canvasInstanceUrl.replacingOccurrences(of: "https://", with: ""),
                    onSessionCaptured: { cookie in
                        showCanvasWebView = false
                        connectCanvas(cookies: cookie)
                    }
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(VitaColors.surface.ignoresSafeArea())
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
                lastSyncAbsolute: state.lastSyncAbsolute,
                lastPing: state.lastPing,
                isStale: state.isStale,
                isExpired: state.status == .expired,
                stats: state.stats.map { ConnectorStat(value: $0.value, label: $0.label) },
                syncNote: syncNote,
                onSync: {
                    activeSheet = nil
                    Task {
                        switch connectorId {
                        case "canvas": await vm.syncCanvas()
                        case "webaluno", "mannesoft":
                            if SharedPortalWebView.shared.hasWebView {
                                // Session alive — sync silently using same WebView
                                SilentPortalSync.shared.resetThrottle()
                                SilentPortalSync.shared.syncIfNeeded(api: container.api)
                            } else {
                                // No session — need login WebView
                                webalunoInstanceUrl = vm.mannesoft.instanceUrl ?? ""
                                showWebalunoWebView = true
                            }
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
        case "spotify": ("music.note", nil)
        case "apple_health": ("heart.fill", nil)
        case "whatsapp": ("message.fill", nil)
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
                Text("Sincronize notas e horários automaticamente")
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
            .tracking(0.8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
    }

    // MARK: - Como Funciona

    private var comoFunciona: some View {
        VStack(alignment: .leading, spacing: 12) {
            howItWorksRow("1", "Conecte seu portal acadêmico com suas credenciais")
            howItWorksRow("2", "Disciplinas, notas e horários sao importados")
            howItWorksRow("3", "Dados sincronizam automaticamente a cada 15 minutos")
            howItWorksRow("4", "Desconecte a qualquer momento — seus dados sao excluidos")
        }
    }

    private func howItWorksRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(VitaColors.glassInnerLight.opacity(0.12))
                    .frame(width: 22, height: 22)
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
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
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
