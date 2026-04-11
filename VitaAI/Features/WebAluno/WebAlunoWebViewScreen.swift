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
                WebAlunoWebView(
                    url: URL(string: webalunoWebURL)!,
                    userEmail: userEmail,
                    isLoading: $isLoading,
                    loadProgress: $loadProgress,
                    onSessionCaptured: onSessionCaptured
                )
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

        // Build a real Safari UA so Google allows OAuth AND serves mobile layout.
        // Default WKWebView UA: "...AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/XXX"
        // Real Safari UA: "...AppleWebKit/605.1.15 (KHTML, like Gecko) Version/X.0 Mobile/XXX Safari/605.1.15"
        // Google requires "Safari/" to allow OAuth (403: disallowed_useragent).
        // Google requires "Mobile/" BEFORE "Safari/" to serve mobile layout.
        // TLS fingerprint matches real Safari since WKWebView uses the same WebKit engine.
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osStr = "\(osVersion.majorVersion)_\(osVersion.minorVersion)"
        let safariUA = "Mozilla/5.0 (iPhone; CPU iPhone OS \(osStr) like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(osVersion.majorVersion).0 Mobile/15E148 Safari/605.1.15"

        // Render pages at mobile viewport
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = safariUA
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

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let parent: WebAlunoWebView
        var webView: WKWebView?
        var sessionFound = false
        var oauthTriggered = false
        var progressObservation: NSKeyValueObservation?

        init(parent: WebAlunoWebView) {
            self.parent = parent
        }

        deinit {
            progressObservation?.invalidate()
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

            // Force mobile viewport on every page load — Google's login page
            // may render at desktop width if it doesn't detect mobile correctly.
            let viewportFix = """
                (function() {
                    var vp = document.querySelector('meta[name=viewport]');
                    if (vp) {
                        vp.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0';
                    } else {
                        vp = document.createElement('meta');
                        vp.name = 'viewport';
                        vp.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0';
                        document.head.appendChild(vp);
                    }
                })();
            """
            webView.evaluateJavaScript(viewportFix, completionHandler: nil)

            guard !sessionFound else { return }

            let currentURL = webView.url?.absoluteString ?? ""
            NSLog("[WebAluno] didFinish URL: %@", currentURL)

            // On Google's email entry page: auto-click Next since login_hint pre-filled email.
            // This makes the flow truly zero-friction — user never interacts with Google's page.
            if currentURL.contains("accounts.google.com") {
                let autoAdvance = """
                    (function() {
                        // Click the Next button on the email step
                        var nextBtn = document.getElementById('identifierNext');
                        if (nextBtn) {
                            nextBtn.click();
                            return 'clicked identifierNext';
                        }
                        // Click the Next button on the password step
                        var passNext = document.getElementById('passwordNext');
                        if (passNext) {
                            passNext.click();
                            return 'clicked passwordNext';
                        }
                        // For account chooser, click the matching account
                        var accounts = document.querySelectorAll('[data-identifier]');
                        for (var i = 0; i < accounts.length; i++) {
                            accounts[i].click();
                            return 'clicked account: ' + accounts[i].getAttribute('data-identifier');
                        }
                        return 'no action taken';
                    })();
                """
                webView.evaluateJavaScript(autoAdvance) { result, error in
                    NSLog("[WebAluno] Google auto-advance: %@", String(describing: result ?? error ?? "nil"))
                }
            }

            // Auto-trigger Google OAuth once landing page loads.
            // Uses login_hint from user's VitaAI email so Google skips the email entry screen.
            if !oauthTriggered && currentURL.contains("/webaluno") && !currentURL.contains("autenticacao") && !currentURL.contains("accounts.google") {
                oauthTriggered = true
                let emailHint = parent.userEmail ?? ""
                NSLog("[WebAluno] Landing page loaded, triggering Google OAuth (hint: %@)...", emailHint)
                // Derive base domain from portal URL for OAuth redirect
                let portalBase: String = {
                    guard let scheme = parent.url.scheme, let host = parent.url.host else { return "" }
                    return "\(scheme)://\(host)"
                }()
                let js = """
                    (function() {
                        var clientId = '841344683161-55h62tlo6h5f0ea7ilrsp3psr29ubo0i.apps.googleusercontent.com';
                        var portalBase = '\(portalBase)';
                        var redirectUri = encodeURIComponent(portalBase + '/autenticacao/oauth_google.php?tipo=1&origem=webaluno');
                        var loginHint = '\(emailHint)';
                        var url = 'https://accounts.google.com/o/oauth2/v2/auth'
                            + '?client_id=' + clientId
                            + '&redirect_uri=' + redirectUri
                            + '&response_type=code'
                            + '&scope=email%20profile'
                            + (loginHint && loginHint.indexOf('@') > 0 ? '&hd=' + loginHint.split('@')[1] : '')
                            + (loginHint ? '&login_hint=' + encodeURIComponent(loginHint) : '');
                        window.location.href = url;
                        return 'redirecting to Google with hint: ' + loginHint;
                    })();
                """
                webView.evaluateJavaScript(js) { result, error in
                    NSLog("[WebAluno] OAuth trigger: %@", String(describing: result ?? error ?? "nil"))
                }
                return
            }

            // Inspect cookies for PHPSESSID after page load
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                guard let self else { return }
                if let phpSession = self.extractPhpSessionId(from: cookies, for: currentURL) {
                    // Don't fire during OAuth flow — only after landing on logged-in portal
                    let isAuthFlow = currentURL.contains("accounts.google.com")
                        || currentURL.contains("/autenticacao/")
                        || currentURL.contains("/login")
                        || currentURL.hasSuffix("/webaluno/")
                        || currentURL.hasSuffix("/webaluno")
                    guard !isAuthFlow else { return }

                    // We landed on a Mannesoft page that's NOT auth — user is logged in
                    self.sessionFound = true
                    DispatchQueue.main.async {
                        self.parent.onSessionCaptured(phpSession)
                    }
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

        // MARK: - Session extraction

        private func extractPhpSessionId(from cookies: [HTTPCookie], for urlString: String) -> String? {
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
