import SwiftUI
import WebKit

// MARK: - Constants

/// Landing page — loads first to establish Mannesoft domain cookies,
/// then auto-triggers loginGoogle() to start OAuth flow.
// MARK: - WebAlunoWebViewScreen

/// Presents the WebAluno portal in a WKWebView.
/// Loads /webaluno/ to establish cookies, then auto-redirects to Google OAuth
/// with login_hint so the user never types their email again.
struct WebAlunoWebViewScreen: View {
    var onBack: () -> Void
    /// Called once when a valid PHPSESSID is detected after login
    var onSessionCaptured: (String) -> Void
    /// Called when bridge.js extracts pages from the portal
    var onPagesExtracted: (([CapturedPortalPage]) -> Void)?
    /// User's institutional email from VitaAI login — used as login_hint for Google OAuth
    var userEmail: String?
    /// Portal instance URL — comes from university portal config, no hardcoded fallback
    var portalInstanceUrl: String = ""

    /// Build the webaluno URL from the portal instance URL
    private var webalunoWebURL: String {
        guard !portalInstanceUrl.isEmpty else { return "" }
        let base = portalInstanceUrl.hasSuffix("/") ? portalInstanceUrl : portalInstanceUrl + "/"
        return base.contains("/webaluno") ? base : base + "webaluno/"
    }

    @State private var isLoading: Bool = true
    @State private var loadProgress: Double = 0

    var body: some View {
        ZStack {
            VitaAmbientBackground { Color.clear }
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar
                navBar

                // Loading progress bar
                if isLoading {
                    ProgressView(value: loadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: VitaColors.accent))
                        .frame(height: 2)
                        .animation(.easeInOut(duration: 0.2), value: loadProgress)
                }

                // WebView — loads portal, auto-triggers Google OAuth with login_hint
                if let url = URL(string: webalunoWebURL), !webalunoWebURL.isEmpty {
                    WebAlunoWebView(
                        url: url,
                        userEmail: userEmail,
                        isLoading: $isLoading,
                        loadProgress: $loadProgress,
                        onSessionCaptured: onSessionCaptured,
                        onPagesExtracted: onPagesExtracted
                    )
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(VitaColors.accent)
                        Text("URL do portal não configurada")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                        Text("Verifique a configuração do conector")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack(spacing: 4) {
            Button(action: onBack) {
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

            Text("Conectar WebAluno")
                .font(VitaTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(VitaColors.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 70, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(Color(red: 0.06, green: 0.04, blue: 0.03))
        .zIndex(1)
    }
}

// MARK: - WebAlunoWebView (UIViewRepresentable)

struct WebAlunoWebView: UIViewRepresentable {
    let url: URL
    let userEmail: String?
    @Binding var isLoading: Bool
    @Binding var loadProgress: Double
    var onSessionCaptured: (String) -> Void
    /// Called when bridge.js extracts pages from the portal (after session capture)
    var onPagesExtracted: (([CapturedPortalPage]) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Only clear PHPSESSID for fresh login — NEVER clear all cookies.
        // Cloudflare uses __cf_bm and cf_clearance for bot detection;
        // wiping them triggers "You have been blocked".
        WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
            for cookie in cookies where cookie.name.lowercased() == "phpsessid" {
                WKWebsiteDataStore.default().httpCookieStore.delete(cookie)
            }
        }

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        // Allow all content — equivalent to Android's mixed content compat
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.allowsInlineMediaPlayback = true

        // DO NOT set customUserAgent — mismatches TLS fingerprint, triggers Cloudflare.
        // Instead, applicationNameForUserAgent APPENDS to the default UA, making it look
        // like real Safari so Google OAuth doesn't block it as "embedded browser".
        // TLS fingerprint stays the same (real WebKit), so Cloudflare is happy.
        configuration.applicationNameForUserAgent = "Version/18.0 Mobile/15E148 Safari/605.1.15"

        configuration.defaultWebpagePreferences.preferredContentMode = .mobile

        // Register vitaBridge message handler for bridge.js extraction
        configuration.userContentController.add(context.coordinator, name: "vitaBridge")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = true

        // Progress binding
        context.coordinator.webView = webView
        context.coordinator.progressObservation = webView.observe(
            \.estimatedProgress,
            options: [.new]
        ) { _, change in
            DispatchQueue.main.async {
                self.loadProgress = change.newValue ?? 0
            }
        }

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: WebAlunoWebView
        var webView: WKWebView?
        var sessionFound = false
        var bridgeInjected = false
        var progressObservation: NSKeyValueObservation?

        init(parent: WebAlunoWebView) {
            self.parent = parent
        }

        deinit {
            progressObservation?.invalidate()
        }

        // MARK: - WKScriptMessageHandler (bridge.js messages)

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard message.name == "vitaBridge",
                  let dict = message.body as? [String: Any],
                  let type = dict["type"] as? String else { return }

            switch type {
            case "vita-bridge-progress":
                let label = dict["label"] as? String ?? ""
                NSLog("[WebAluno/Bridge] Progress: %@", label)

            case "vita-bridge-complete":
                guard let pagesArray = dict["pages"] as? [[String: Any]] else { return }
                let pages = pagesArray.compactMap { pageDict -> CapturedPortalPage? in
                    guard let pType = pageDict["type"] as? String,
                          let html = pageDict["html"] as? String,
                          let linkText = pageDict["linkText"] as? String else { return nil }
                    return CapturedPortalPage(type: pType, html: html, linkText: linkText)
                }
                NSLog("[WebAluno/Bridge] Extraction complete: %d pages", pages.count)

                // Re-save cookies AFTER bridge.js — PHP may have regenerated the session
                if let wv = webView {
                    WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                        let portalCookies = cookies.filter { $0.domain.contains("mannesoftprime") }
                        let cookieStr = portalCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                        if !cookieStr.isEmpty {
                            MannesoftCookieStore.save(cookieStr, domain: wv.url?.absoluteString ?? "")
                            NSLog("[WebAluno/Bridge] Re-persisted %d cookies after bridge (%d chars)", portalCookies.count, cookieStr.count)
                        }
                    }
                }

                DispatchQueue.main.async {
                    self.parent.onPagesExtracted?(pages)
                }

            case "vita-bridge-error":
                let error = dict["error"] as? String ?? "Unknown"
                NSLog("[WebAluno/Bridge] Error: %@", error)

            default:
                break
            }
        }

        // Keep all navigation inside the WebView
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }

            let currentURL = webView.url?.absoluteString ?? ""
            NSLog("[WebAluno] didFinish URL: %@", currentURL)

            // Google OAuth pages render oversized in WKWebView — inject viewport meta
            // to force mobile-width rendering. Only targets accounts.google.com.
            if currentURL.contains("accounts.google.com") {
                let fixZoomJS = """
                    (function() {
                        var meta = document.querySelector('meta[name="viewport"]');
                        if (!meta) {
                            meta = document.createElement('meta');
                            meta.name = 'viewport';
                            document.head.appendChild(meta);
                        }
                        meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0';
                    })();
                """
                webView.evaluateJavaScript(fixZoomJS) { _, _ in }
            }

            guard !sessionFound else { return }

            // Auto-trigger Google OAuth — any page under /webaluno/ that isn't Google/OAuth itself
            let isMannesoftPage = currentURL.contains("/webaluno")
                && !currentURL.contains("accounts.google.com")
                && !currentURL.contains("/autenticacao/")
            NSLog("[WebAluno] isMannesoftPage=%d sessionFound=%d url=%@",
                  isMannesoftPage ? 1 : 0, sessionFound ? 1 : 0, currentURL)
            if isMannesoftPage && !sessionFound {
                // Call loginGoogle() directly — skip the Mannesoft UI entirely.
                // The function is defined in the page and triggers Google OAuth redirect.
                let oauthJS = """
                    (function() {
                        try {
                            // Mannesoft defines redirect_uri and client_id as globals.
                            // The button calls: loginGoogle(redirect_uri, client_id)
                            if (typeof loginGoogle === 'function' && typeof redirect_uri !== 'undefined' && typeof client_id !== 'undefined') {
                                loginGoogle(redirect_uri, client_id);
                                return 'called-loginGoogle';
                            }
                            // Fallback: click the actual button
                            var btn = document.querySelector('#GOOGLE_ALUNO_BTN, [onclick*="loginGoogle"]');
                            if (btn) { btn.click(); return 'clicked: ' + btn.id; }
                            return 'no-google-auth-found';
                        } catch(e) {
                            return 'error: ' + e.message;
                        }
                    })();
                """
                webView.evaluateJavaScript(oauthJS) { result, error in
                    if let error {
                        NSLog("[WebAluno] OAuth auto-trigger error: %@", error.localizedDescription)
                    }
                    NSLog("[WebAluno] OAuth auto-trigger: %@", String(describing: result))
                }
            }

            // Inspect cookies for PHPSESSID after page load — but only capture
            // session if the page is actually the logged-in portal (not login page).
            // Check via JS: login page has a login form; logged-in page has menu links.
            webView.evaluateJavaScript("""
                JSON.stringify({
                    hasLoginForm: !!document.querySelector('input[type="password"], #GOOGLE_ALUNO, .btn-google, [onclick*="loginGoogle"]'),
                    hasMenuLinks: document.querySelectorAll('a[href*="index.php?"]').length,
                    hasFrames: document.querySelectorAll('iframe, frame').length,
                    title: document.title,
                    bodyLen: document.body ? document.body.innerHTML.length : 0
                })
            """) { [weak self] result, error in
                if let error {
                    NSLog("[WebAluno] Page check JS failed: %@ — skipping session capture", error.localizedDescription)
                    return
                }
                guard let self, let jsonStr = result as? String,
                      let data = jsonStr.data(using: .utf8),
                      let info = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    NSLog("[WebAluno] Page check: could not parse result=%@", String(describing: result))
                    return
                }

                let hasLoginForm = info["hasLoginForm"] as? Bool ?? false
                let hasMenuLinks = info["hasMenuLinks"] as? Int ?? 0
                let hasFrames = info["hasFrames"] as? Int ?? 0
                let title = info["title"] as? String ?? ""
                NSLog("[WebAluno] Page check: loginForm=%d, menuLinks=%d, frames=%d, title=%@",
                      hasLoginForm ? 1 : 0, hasMenuLinks, hasFrames, title)

                // If page has a login form, it's NOT logged in — skip session capture
                if hasLoginForm {
                    NSLog("[WebAluno] Login form detected — NOT capturing session (waiting for real login)")
                    return
                }

                // Transient post-OAuth stubs (webaluno_login.php&AUTENTICADO=1, redirect=1)
                // finish with empty DOM (menuLinks=0, frames=0) ~650ms BEFORE Mannesoft
                // navigates to the real landing page (webaluno_aviso.view.php). If we
                // capture+inject here, sessionFound=true blocks the next didFinish, and
                // the bridge we just injected is destroyed by WebKit's navigation —
                // no vita-bridge-complete, no POST /api/portal/extract, silent failure.
                // See connector incident 2026-04-17_bridge-empty-html-webview-inject-too-early.md.
                if hasMenuLinks == 0 && hasFrames == 0 {
                    NSLog("[WebAluno] Empty transient page (menuLinks=0, frames=0) — waiting for real landing page")
                    return
                }

                self.captureSessionIfValid(webView: webView, currentURL: currentURL)
            }
        }

        /// Capture session only after confirming user is actually logged in
        private func captureSessionIfValid(webView: WKWebView, currentURL: String) {
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self else { return }
                NSLog("[WebAluno] getAllCookies: %d total cookies for URL %@", cookies.count, currentURL)

                if let phpSession = self.extractPhpSessionId(from: cookies, for: currentURL) {
                    NSLog("[WebAluno] Session extracted: %d chars", phpSession.count)
                    // Don't fire during OAuth flow
                    let isAuthFlow = currentURL.contains("accounts.google.com")
                        || currentURL.contains("/autenticacao/")
                        || currentURL.contains("/login")
                    guard !isAuthFlow else {
                        NSLog("[WebAluno] Skipping session capture — auth flow URL")
                        return
                    }

                    // User is logged in (no login form, valid PHPSESSID)
                    NSLog("[WebAluno] Session captured! Firing onSessionCaptured")
                    self.sessionFound = true

                    // Store this WebView for SilentSync reuse — same browser fingerprint
                    SharedPortalWebView.shared.store(webView, url: currentURL)

                    // Persist ALL cookies for this domain for SilentSync
                    // WKWebView cookies don't survive app termination
                    // Log all cookies to diagnose which ones are needed
                    for c in cookies {
                        NSLog("[WebAluno] Cookie: name=%@ domain=%@ value=%d chars", c.name, c.domain, c.value.count)
                    }
                    // Save ALL cookies from the portal domain (not just PHPSESSID)
                    let portalDomain = URL(string: currentURL)?.host ?? ""
                    let allPortalCookies = cookies.filter { c in
                        c.domain.contains("mannesoftprime") || c.domain == portalDomain
                    }
                    let cookieStr = allPortalCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                    MannesoftCookieStore.save(cookieStr, domain: currentURL)
                    NSLog("[WebAluno] Persisted %d cookies (%d chars) for SilentSync", allPortalCookies.count, cookieStr.count)

                    // Inject bridge.js FIRST — it needs the WebView alive.
                    // onSessionCaptured triggers state changes that can invalidate the view.
                    self.injectBridgeJS(into: webView)
                    // Delay onSessionCaptured so bridge fetch starts before any SwiftUI state change
                    let capturedSession = phpSession
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.parent.onSessionCaptured(capturedSession)
                    }
                } else {
                    NSLog("[WebAluno] extractPhpSessionId returned nil")
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }

        // MARK: - WKUIDelegate — handle popups (OAuth opens via window.open)

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            // Don't create a new WebView — load the popup URL in the current one
            if let url = navigationAction.request.url {
                NSLog("[WebAluno] Popup intercepted → loading in same view: %@", url.absoluteString)
                webView.load(URLRequest(url: url))
            }
            return nil
        }

        // MARK: - Bridge.js injection

        private func injectBridgeJS(into webView: WKWebView) {
            guard !bridgeInjected else { return }
            bridgeInjected = true

            NSLog("[WebAluno/Bridge] Fetching bridge.js from server...")
            guard let bridgeURL = URL(string: AppConfig.apiBaseURL + "/portal/bridge") else {
                NSLog("[WebAluno/Bridge] Invalid bridge URL")
                return
            }

            Task {
                do {
                    let (data, response) = try await URLSession.shared.data(from: bridgeURL)
                    guard (response as? HTTPURLResponse)?.statusCode == 200,
                          let js = String(data: data, encoding: .utf8) else {
                        NSLog("[WebAluno/Bridge] Failed to fetch bridge.js")
                        return
                    }
                    NSLog("[WebAluno/Bridge] Injecting bridge.js (%d bytes)", js.count)
                    // Inject immediately — bridge.js has its own DOMContentLoaded wait
                    await MainActor.run {
                        webView.evaluateJavaScript(js) { _, error in
                            if let error {
                                NSLog("[WebAluno/Bridge] Injection error: %@", error.localizedDescription)
                            } else {
                                NSLog("[WebAluno/Bridge] Injected successfully, extraction running...")
                            }
                        }
                    }
                } catch {
                    NSLog("[WebAluno/Bridge] Error: %@", error.localizedDescription)
                }
            }
        }

        // MARK: - Session extraction

        private func extractPhpSessionId(from cookies: [HTTPCookie], for urlString: String) -> String? {
            // Return just the PHPSESSID value — backend wraps with "PHPSESSID=" if needed
            return cookies
                .first { $0.name.lowercased() == "phpsessid" && !$0.value.isEmpty }
                .map { $0.value }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("WebAlunoWebViewScreen") {
    WebAlunoWebViewScreen(
        onBack: {},
        onSessionCaptured: { cookie in
            print("Session captured: \(cookie)")
        },
        userEmail: "rafaelfloureiro93@rede.ulbra.br"
    )
    .preferredColorScheme(.dark)
}
#endif
