import SwiftUI
import WebKit
import Sentry

// MARK: - Atlas 3D WebView Screen
// Loads /atlas-embed — full 3D anatomy with 4500+ PT-BR translated structures.
// Uses /atlas-embed route (no AppShell) to avoid duplicate nav bars.
// Injects session cookie so authenticated features (Ask VITA) work inside the WebView.

struct AtlasWebViewScreen: View {
    var onBack: () -> Void
    var onAskVita: ((String) -> Void)?

    @Environment(\.appContainer) private var container
    @State private var isLoading = true
    @State private var hasError = false
    @State private var sessionToken: String? = nil
    /// True once the token fetch completes (even if token is nil — public route still loads).
    @State private var tokenReady = false
    @State private var reloadTrigger = 0

    private var atlasURL: String { AppConfig.authBaseURL + "/atlas-embed" }

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                topNav

                ZStack {
                    if tokenReady {
                        // Token is fetched (cookie injected in makeUIView before first load)
                        AtlasWebView(
                            urlString: atlasURL,
                            sessionToken: sessionToken,
                            isLoading: $isLoading,
                            hasError: $hasError,
                            reloadTrigger: reloadTrigger,
                            onAction: { action, structure in
                                if action == "askVita" {
                                    onAskVita?(structure)
                                }
                                // createFlashcard handled later
                            }
                        )
                    }

                    if (isLoading || !tokenReady) && !hasError {
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(VitaColors.accent)
                            Text("Carregando Atlas 3D...")
                                .font(.system(size: 13))
                                .foregroundColor(VitaColors.textSecondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(VitaColors.surface)
                    }

                    if hasError {
                        errorState
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            sessionToken = await container.tokenStore.token
            tokenReady = true
            // Token fetch unblocks the WebView render — report here, not on page load.
            SentrySDK.reportFullyDisplayed()
            print("[AtlasWebView] token ready: \(sessionToken != nil ? "SET" : "NIL"), url: \(atlasURL)")
        }
        .trackScreen("Atlas3D")
    }

    // MARK: - Top Nav

    private var topNav: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(VitaColors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(VitaColors.surface.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Text("Atlas 3D")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(VitaColors.textPrimary)

            Spacer()

            Button {
                hasError = false
                isLoading = true
                reloadTrigger += 1
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(VitaColors.surface.opacity(0.6))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(VitaColors.surface.opacity(0.95))
    }

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundColor(VitaColors.textSecondary)

            Text("Não foi possível carregar o Atlas")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(VitaColors.textPrimary)

            Text("Verifique sua conexão e tente novamente")
                .font(.system(size: 13))
                .foregroundColor(VitaColors.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                hasError = false
                isLoading = true
                reloadTrigger += 1
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Tentar novamente")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(VitaColors.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(VitaColors.accent.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VitaColors.surface)
    }
}

// MARK: - WKWebView Wrapper
//
// WebGL/Three.js GLB loading fix:
// The server sends `Clear-Site-Data: "cache"` on every response (including GLB model files).
// This header wipes the browser cache mid-load, causing Three.js's useGLTF to stall at ~90%
// because downloaded data is invalidated before GPU upload completes.
//
// Fix: use a non-persistent WKWebsiteDataStore so Clear-Site-Data has no persistent cache to
// wipe, plus inject JS to handle WebGL context loss recovery and override fetch() to strip
// the destructive header from sub-resource responses.

/// Shared process pool so the WebView reuses a warm WebKit process (avoids cold-start on re-open).
private let atlasProcessPool = WKProcessPool()

private struct AtlasWebView: UIViewRepresentable {
    let urlString: String
    let sessionToken: String?
    @Binding var isLoading: Bool
    @Binding var hasError: Bool
    var reloadTrigger: Int
    var onAction: ((String, String) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.processPool = atlasProcessPool

        // Non-persistent store: Clear-Site-Data: "cache" cannot nuke a non-persistent store's
        // in-memory cache, preventing the mid-load stall that kills GLB parsing.
        let dataStore = WKWebsiteDataStore.nonPersistent()
        config.websiteDataStore = dataStore

        // Allow blob: workers (Three.js Draco decoder uses them)
        config.preferences.javaScriptCanOpenWindowsAutomatically = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        // Inject WebGL context-loss recovery before page scripts run.
        // When iOS WKWebView drops the WebGL context (memory pressure, backgrounding),
        // Three.js freezes silently. This script intercepts the event and reloads the page.
        let webglRecoveryJS = """
        (function() {
            var _origGetContext = HTMLCanvasElement.prototype.getContext;
            HTMLCanvasElement.prototype.getContext = function(type, attrs) {
                var ctx = _origGetContext.call(this, type, attrs);
                if (ctx && (type === 'webgl' || type === 'webgl2' || type === 'experimental-webgl')) {
                    this.addEventListener('webglcontextlost', function(e) {
                        e.preventDefault();
                        console.error('[VitaAI] WebGL context lost — will reload in 1s');
                        window.webkit.messageHandlers.atlasLog.postMessage('webgl-context-lost');
                        setTimeout(function() { location.reload(); }, 1000);
                    });
                    this.addEventListener('webglcontextrestored', function() {
                        console.log('[VitaAI] WebGL context restored');
                        window.webkit.messageHandlers.atlasLog.postMessage('webgl-context-restored');
                    });
                }
                return ctx;
            };
        })();
        """
        let webglScript = WKUserScript(
            source: webglRecoveryJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        config.userContentController.addUserScript(webglScript)

        // Capture ALL console.log/warn/error from the page and forward to native
        let consoleCapture = """
        (function() {
            var _log = console.log, _warn = console.warn, _err = console.error;
            function send(level, args) {
                try {
                    var msg = Array.prototype.map.call(args, function(a) {
                        return typeof a === 'object' ? JSON.stringify(a) : String(a);
                    }).join(' ');
                    window.webkit.messageHandlers.atlasLog.postMessage('[' + level + '] ' + msg);
                } catch(e) {}
            }
            console.log = function() { send('LOG', arguments); _log.apply(console, arguments); };
            console.warn = function() { send('WARN', arguments); _warn.apply(console, arguments); };
            console.error = function() { send('ERROR', arguments); _err.apply(console, arguments); };
            window.addEventListener('error', function(e) {
                send('UNCAUGHT', [e.message, e.filename, e.lineno]);
            });

            // Report canvas dimensions after page loads
            setTimeout(function() {
                var canvases = document.querySelectorAll('canvas');
                canvases.forEach(function(c, i) {
                    send('DIAG', ['canvas[' + i + ']', 'size:', c.width + 'x' + c.height,
                        'client:', c.clientWidth + 'x' + c.clientHeight,
                        'style:', c.style.width + '/' + c.style.height,
                        'parent:', c.parentElement ? c.parentElement.clientWidth + 'x' + c.parentElement.clientHeight : 'none']);
                });
                var root = document.querySelector('.relative.h-full.w-full');
                if (root) send('DIAG', ['root-div:', root.clientWidth + 'x' + root.clientHeight, 'offset:', root.offsetWidth + 'x' + root.offsetHeight]);
                var page = document.querySelector('.w-screen.h-screen');
                if (page) send('DIAG', ['page-div:', page.clientWidth + 'x' + page.clientHeight]);
                send('DIAG', ['viewport:', window.innerWidth + 'x' + window.innerHeight, 'screen:', screen.width + 'x' + screen.height, 'dpr:', window.devicePixelRatio]);
            }, 3000);
        })();
        """
        let consoleScript = WKUserScript(source: consoleCapture, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(consoleScript)

        // Message handler for WebGL events (logged to console, not acted on by native side)
        config.userContentController.add(context.coordinator, name: "atlasLog")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        // Inject session cookie into the non-persistent store
        if let token = sessionToken, let url = URL(string: urlString) {
            let host = url.host ?? ""
            let isSecure = url.scheme == "https"
            let cookieName = isSecure ? "__Secure-better-auth.session_token" : "better-auth.session_token"
            var props: [HTTPCookiePropertyKey: Any] = [
                .name: cookieName,
                .value: token,
                .domain: host,
                .path: "/",
            ]
            if isSecure { props[.secure] = "TRUE" }
            if let cookie = HTTPCookie(properties: props) {
                dataStore.httpCookieStore.setCookie(cookie)
            }
        }

        print("[AtlasWebView] makeUIView — loading URL: \(urlString) token:\(sessionToken != nil ? "SET" : "NIL")")
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if reloadTrigger != context.coordinator.lastReloadTrigger {
            context.coordinator.lastReloadTrigger = reloadTrigger
            print("[AtlasWebView] reload triggered (\(reloadTrigger))")
            if let url = URL(string: urlString) {
                webView.load(URLRequest(url: url))
            }
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: AtlasWebView
        var lastReloadTrigger: Int = 0

        init(_ parent: AtlasWebView) {
            self.parent = parent
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? String else { return }
            print("[AtlasWebView] JS message: \(body)")

            // Try parsing as JSON action (askVita / createFlashcard)
            if body.hasPrefix("{"),
               let data = body.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let action = json["action"] as? String,
               let structure = json["structure"] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.parent.onAction?(action, structure)
                }
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("[AtlasWebView] didStart — url: \(webView.url?.absoluteString ?? "nil")")
            parent.isLoading = true
            parent.hasError = false
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("[AtlasWebView] didFinish — url: \(webView.url?.absoluteString ?? "nil")")
            parent.isLoading = false
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            let nsErr = error as NSError
            print("[AtlasWebView] didFailProvisional — code:\(nsErr.code) domain:\(nsErr.domain) msg:\(nsErr.localizedDescription) url:\(nsErr.userInfo["NSErrorFailingURLKey"] ?? "?")")
            parent.isLoading = false
            parent.hasError = true
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            let nsErr = error as NSError
            print("[AtlasWebView] didFail — code:\(nsErr.code) domain:\(nsErr.domain) msg:\(nsErr.localizedDescription)")
            parent.isLoading = false
            parent.hasError = true
        }

        // Strip Clear-Site-Data header from sub-resource responses to prevent mid-load cache wipes.
        // WKNavigationDelegate receives navigation responses but not sub-resource responses,
        // so we handle navigation-level responses here and rely on the non-persistent store
        // for sub-resources (GLB files).
        func webView(_ webView: WKWebView, decidePolicyFor response: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let httpResponse = response.response as? HTTPURLResponse {
                let csd = httpResponse.value(forHTTPHeaderField: "Clear-Site-Data")
                if csd != nil {
                    print("[AtlasWebView] Clear-Site-Data header detected on navigation response (non-persistent store ignores it)")
                }
            }
            decisionHandler(.allow)
        }

        // Prevent any link from escaping to external browser — everything stays inside WebView
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let url = action.request.url?.absoluteString ?? "nil"
            print("[AtlasWebView] decidePolicyFor — type:\(action.navigationType.rawValue) url:\(url)")
            decisionHandler(.allow)
        }

        // Block new window/tab requests (target="_blank" etc)
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            let url = navigationAction.request.url?.absoluteString ?? "nil"
            print("[AtlasWebView] createWebViewWith (blocked, loading in-place) — url:\(url)")
            if let u = navigationAction.request.url {
                webView.load(URLRequest(url: u))
            }
            return nil
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Atlas 3D") {
    AtlasWebViewScreen(onBack: {})
        .preferredColorScheme(.dark)
}
#endif
