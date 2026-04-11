import SwiftUI
import WebKit
import AuthenticationServices

// MARK: - Inline Portal WebView (appears inside onboarding, below Vita mascot)

struct InlinePortalWebView: View {
    let portalType: String
    let university: University?
    let api: VitaAPI
    let onClose: () -> Void
    var onSyncStarted: ((String) -> Void)?

    @State private var isConnected = false
    @State private var isConnecting = false

    private var portalURL: String {
        if let portals = university?.portals {
            if let match = portals.first(where: { $0.portalType == portalType }) {
                return match.instanceUrl ?? ""
            }
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            if isConnected {
                // Success inline
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(VitaColors.dataGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(University.displayName(for: portalType)) conectado!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text(String(localized: "connect_syncing_data"))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                    Button(action: onClose) {
                        Text(String(localized: "connect_ok"))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.accent)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(VitaColors.dataGreen.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VitaColors.dataGreen.opacity(0.15), lineWidth: 1))
                )
            } else {
                // WebView header
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                    Text(portalURL.isEmpty ? String(localized: "connect_portal_generic") : portalURL)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.35))
                        .lineLimit(1)
                    Spacer()
                    if isConnecting {
                        ProgressView().tint(VitaColors.accent).scaleEffect(0.6)
                    }
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.4))
                            .frame(width: 24, height: 24)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Circle())
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "connect_a11y_close"))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.03))

                // Universal portal WebView — captures session cookies for any portal type
                PortalWebView(
                    portalType: portalType,
                    portalURL: portalURL,
                    onSessionCaptured: { cookie in handleSession(cookie) }
                )
                .frame(height: 320)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isConnected ? VitaColors.dataGreen.opacity(0.15) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func handleSession(_ cookie: String) {
        guard !portalURL.isEmpty else { return }
        isConnecting = true
        Task {
            do {
                let instanceUrl = portalURL.hasPrefix("http") ? portalURL : "https://\(portalURL)"
                let result = try await api.startVitaCrawl(cookies: cookie, instanceUrl: instanceUrl)
                if let syncId = result.syncId {
                    onSyncStarted?(syncId)
                    pollSyncProgress(syncId: syncId)
                }
                withAnimation { isConnected = true }
            } catch {
                print("[InlinePortalWebView] vita-crawl failed: \(error)")
                withAnimation { isConnected = true }
            }
            isConnecting = false
        }
    }

    private func pollSyncProgress(syncId: String) {
        Task {
            for _ in 0..<60 { // max 2 min
                try? await Task.sleep(for: .seconds(2))
                guard let progress = try? await api.getSyncProgress(syncId: syncId) else { continue }
                if progress.isDone || progress.isError { break }
            }
        }
    }
}

// MARK: - OnboardingConnectSheet (kept as fallback)

/// Clean connect sheet for onboarding — shows portal login inline
/// Never takes the user out of Vita's context
struct OnboardingConnectSheet: View {
    let portalType: String
    let university: University?
    let api: VitaAPI
    let onDismiss: () -> Void

    @State private var showWebView = false
    @State private var isConnecting = false
    @State private var isConnected = false
    @State private var statusMessage = ""

    private var portalName: String {
        University.displayName(for: portalType)
    }

    private var portalURL: String {
        // Find URL from university portals
        if let portals = university?.portals {
            if let match = portals.first(where: { $0.portalType == portalType }) {
                return match.instanceUrl ?? ""
            }
        }
        // no legacy fallback
        return ""
    }

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with close button
                header

                if isConnected {
                    connectedView
                } else if showWebView {
                    webViewSection
                } else {
                    promptView
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .background(VitaColors.surface)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.06))
                    .clipShape(Circle())
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "connect_a11y_close"))

            Spacer()

            Text(String(localized: "connect_portal_button").replacingOccurrences(of: "%@", with: portalName))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))

            Spacer()

            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Prompt (before opening WebView)

    private var promptView: some View {
        VStack(spacing: 24) {
            Spacer()

            // Portal icon
            ZStack {
                Circle()
                    .fill(VitaColors.accent.opacity(0.1))
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(VitaColors.accent.opacity(0.2), lineWidth: 1))

                Text(University.letter(for: portalType))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(VitaColors.accent)
            }

            VStack(spacing: 8) {
                Text(portalName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))

                if !portalURL.isEmpty {
                    Text(portalURL)
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Text(String(localized: "connect_login_instruction"))
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            Button {
                withAnimation { showWebView = true }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .font(.system(size: 15))
                    Text(String(localized: "connect_open_login"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(VitaColors.surface)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white))
            }
            .padding(.horizontal, 32)

            Button("Pular por agora", action: onDismiss)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.3))

            Spacer()
            Spacer()
        }
    }

    // MARK: - WebView (inline portal login)

    private var webViewSection: some View {
        VStack(spacing: 0) {
            // URL bar
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.3))
                Text(portalURL.isEmpty ? String(localized: "connect_portal_generic") : portalURL)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04))

            // WebView
            PortalWebView(
                portalType: portalType,
                portalURL: portalURL,
                onSessionCaptured: { cookie in
                    handleSessionCaptured(cookie: cookie)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 0))

            if isConnecting {
                HStack(spacing: 8) {
                    ProgressView().tint(VitaColors.accent).scaleEffect(0.8)
                    Text(String(localized: "connect_connecting"))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.vertical, 10)
            }
        }
    }

    // MARK: - Connected success

    private var connectedView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(VitaColors.dataGreen.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(VitaColors.dataGreen)
            }

            Text(String(localized: "connect_portal_connected").replacingOccurrences(of: "%@", with: portalName))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))

            Text(statusMessage)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)

            Button {
                onDismiss()
            } label: {
                Text(String(localized: "onboarding_btn_continue"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VitaColors.surface)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white))
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Session handler

    private func handleSessionCaptured(cookie: String) {
        guard !portalURL.isEmpty else { return }
        isConnecting = true
        Task {
            do {
                let url = portalURL.hasPrefix("http") ? portalURL : "https://\(portalURL)"
                // Universal: Vita crawls any portal server-side
                let result = try await api.startVitaCrawl(cookies: cookie, instanceUrl: url)
                statusMessage = "Vita extraindo dados do portal..."
                withAnimation { isConnected = true }
                // Poll progress
                if let syncId = result.syncId {
                    for _ in 0..<60 {
                        try? await Task.sleep(for: .seconds(2))
                        if let progress = try? await api.getSyncProgress(syncId: syncId) {
                            statusMessage = (progress.label ?? "").isEmpty ? "Vita trabalhando..." : (progress.label ?? "")
                            if progress.isDone {
                                statusMessage = "Extração completa!"
                                break
                            }
                            if progress.isError {
                                statusMessage = (progress.label ?? "").isEmpty ? "Erro na extração" : (progress.label ?? "")
                                break
                            }
                        }
                    }
                }
            } catch {
                statusMessage = "Erro ao conectar. Tente novamente."
            }
            isConnecting = false
        }
    }
}

// MARK: - Portal WebView (captures session cookies)

// MARK: - Universal Portal WebView (captures ALL cookies after login)
// Used by both InlinePortalWebView and OnboardingConnectSheet

struct PortalWebView: UIViewRepresentable {
    let portalType: String
    let portalURL: String
    let onSessionCaptured: (String) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        if let url = URL(string: Self.buildURL(portalType: portalType, portalURL: portalURL)) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        // Extract the portal's base host so the coordinator only captures cookies
        // when navigated back to the portal domain (not on Google/Microsoft SSO pages)
        let portalHost = URL(string: portalURL.hasPrefix("http") ? portalURL : "https://\(portalURL)")?.host ?? portalURL
        return Coordinator(portalType: portalType, portalBaseHost: portalHost, onSessionCaptured: onSessionCaptured)
    }

    /// Build the login URL for each portal type
    static func buildURL(portalType: String, portalURL: String) -> String {
        guard !portalURL.isEmpty else { return "" }
        let base = portalURL.hasPrefix("http") ? portalURL : "https://\(portalURL)"

        switch portalType {
        case "canvas":
            // Canvas LMS: /login/google goes directly to Google SSO
            let canvasBase = base.hasSuffix("/") ? String(base.dropLast()) : base
            return "\(canvasBase)/login/google"
        case "webaluno":
            // WebAluno: append /webaluno/ if not already
            return base.hasSuffix("/webaluno/") ? base : "\(base)/webaluno/"
        case "moodle":
            // Moodle: /login/index.php is the standard login
            return "\(base)/login/index.php"
        case "sigaa":
            // SIGAA: /sigaa/verTelaLogin.do is the standard entry
            return "\(base)/sigaa/verTelaLogin.do"
        case "totvs":
            // TOTVS RM Portal: usually /FrameHTML/web/app/edu/PortalEducacional/login
            return base
        case "sagres":
            // Sagres: /Logon/Logon is the standard
            return "\(base)/Logon/Logon"
        case "lyceum":
            // Lyceum: portal root
            return base
        default:
            // Custom/unknown: just load the URL as-is
            return base
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let portalType: String
        let portalBaseHost: String
        let onSessionCaptured: (String) -> Void
        private var capturedSession = false
        private var navigationCount = 0

        init(portalType: String, portalBaseHost: String, onSessionCaptured: @escaping (String) -> Void) {
            self.portalType = portalType
            self.portalBaseHost = portalBaseHost
            self.onSessionCaptured = onSessionCaptured
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !capturedSession else { return }
            navigationCount += 1

            let currentURL = webView.url?.absoluteString ?? ""
            let currentHost = webView.url?.host ?? ""
            let currentPath = webView.url?.path ?? ""

            NSLog("[PortalWebView] %@: didFinish nav #%d → %@ (portalHost: %@)", portalType, navigationCount, currentURL, portalBaseHost)

            // CRITICAL: Only capture when on the portal's own domain.
            // During SSO (Google, Microsoft), the WebView navigates through third-party auth pages.
            // We must wait until the redirect back to the portal completes.
            let isOnPortalDomain = !currentHost.isEmpty && (
                currentHost == portalBaseHost
                || currentHost.hasSuffix(".\(portalBaseHost)")
                || portalBaseHost.hasSuffix(".\(currentHost)")
            )
            guard isOnPortalDomain else { return }

            // On portal domain: check if we're past the login page
            let isLoginPage = currentPath.contains("/login") || currentPath.contains("/auth")
            let isPortalDashboard = !isLoginPage

            // Capture if: on portal dashboard (login complete) OR 2+ navs on portal domain
            guard isPortalDashboard || navigationCount >= 3 else { return }

            // Capture ALL cookies from the portal domain — backend decides which ones matter
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self, !self.capturedSession else { return }

                // Get cookies from the portal's domain only (not third-party like Google)
                let relevantCookies = cookies.filter { cookie in
                    let cookieDomain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    return currentHost.hasSuffix(cookieDomain) || cookieDomain == currentHost
                }

                guard !relevantCookies.isEmpty else {
                    NSLog("[PortalWebView] %@: on portal domain but no portal cookies found", self.portalType)
                    return
                }

                let cookieString = relevantCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")

                NSLog("[PortalWebView] %@: captured %d cookies (%d bytes) after nav to %@", self.portalType, relevantCookies.count, cookieString.count, currentURL)
                NSLog("[PortalWebView] Cookie names: %@", relevantCookies.map(\.name).joined(separator: ", "))

                self.capturedSession = true
                DispatchQueue.main.async {
                    self.onSessionCaptured(cookieString)
                }
            }
        }
    }
}
import SwiftUI

/// Portal connect flow for onboarding.
/// Reuses PortalWebView (login) and ConnectorSyncView (progress) from Connectors.
/// No nav bar, no disconnect, no status card — just login → sync → done.
struct OnboardingPortalFlow: View {
    let portalType: String
    let university: University?
    let api: VitaAPI
    let onBack: () -> Void
    let onConnected: () -> Void

    @State private var phase: FlowPhase = .login
    @State private var syncVM: PortalConnectViewModel?

    private enum FlowPhase {
        case login
        case syncing
        case done
    }

    private var portalURL: String {
        if let portals = university?.portals,
           let match = portals.first(where: { $0.portalType == portalType }) {
            return match.instanceUrl ?? ""
        }
        return ""
    }

    private var portalName: String {
        University.displayName(for: portalType)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Minimal top bar: back + portal name
            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .background(Color.white.opacity(0.04))
                        .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
                        .clipShape(Circle())
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(portalName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            switch phase {
            case .login:
                loginPhase

            case .syncing:
                if let vm = syncVM {
                    if portalType == "canvas" {
                        ConnectorSyncView(
                            connectorName: "Canvas",
                            steps: SyncStep.canvasSteps(phase: vm.canvasSyncPhase),
                            message: vm.canvasSyncMessage,
                            progress: vm.canvasSyncProgress
                        )
                    } else {
                        // WebAluno and others use vita-crawl polling
                        ConnectorSyncView(
                            connectorName: portalName,
                            steps: SyncStep.webalunoSteps(phase: "login"),
                            message: "Vita extraindo dados..."
                        )
                    }
                } else {
                    ProgressView().tint(VitaColors.accent)
                }

            case .done:
                donePhase
            }
        }
        .onAppear {
            let vm = PortalConnectViewModel(portalType: portalType, api: api)
            syncVM = vm
        }
    }

    // MARK: - Login Phase (WebView)

    private var loginPhase: some View {
        VStack(spacing: 0) {
            // URL bar
            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.3))
                Text(portalURL.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: ""))
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.03))

            PortalWebView(
                portalType: portalType,
                portalURL: portalURL,
                onSessionCaptured: { cookie in
                    handleSessionCaptured(cookie)
                }
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    // MARK: - Done Phase

    private var donePhase: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(VitaColors.dataGreen.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(VitaColors.dataGreen)
            }

            Text("\(portalName) conectado!")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))

            Text("Seus dados foram importados com sucesso.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.5))

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onConnected()
            } label: {
                Text("Continuar")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.surface)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 14).fill(.white))
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Session Handler

    private func handleSessionCaptured(_ cookie: String) {
        guard let vm = syncVM else { return }

        withAnimation { phase = .syncing }

        if portalType == "canvas" {
            let instanceUrl = portalURL.hasPrefix("http") ? portalURL : "https://\(portalURL)"
            vm.connectCanvas(cookies: cookie, instanceUrl: instanceUrl)

            // Watch for completion
            Task {
                while vm.canvasSyncPhase != .done && vm.canvasSyncPhase != .error {
                    try? await Task.sleep(for: .seconds(0.5))
                }
                withAnimation { phase = .done }
            }
        } else {
            // WebAluno / others: use vita-crawl
            Task {
                do {
                    let instanceUrl = portalURL.hasPrefix("http") ? portalURL : "https://\(portalURL)"
                    let result = try await api.startVitaCrawl(cookies: cookie, instanceUrl: instanceUrl)
                    if let syncId = result.syncId {
                        for _ in 0..<60 {
                            try? await Task.sleep(for: .seconds(2))
                            if let progress = try? await api.getSyncProgress(syncId: syncId) {
                                if progress.isDone || progress.isError { break }
                            }
                        }
                    }
                } catch {}
                withAnimation { phase = .done }
            }
        }
    }
}
