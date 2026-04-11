import Foundation
import WebKit

/// Silent Canvas re-authentication using persistent Google OAuth cookies.
///
/// Canvas session cookies expire after ~24h (absolute timeout, ignoring activity).
/// But Google OAuth cookies in WKWebView's .default() data store last weeks.
/// This class exploits that gap: loads Canvas /login/google in a hidden WebView,
/// Google auto-authenticates, Canvas issues fresh cookies, we capture and send to backend.
///
/// Zero user interaction required as long as Google session is alive.
@MainActor
final class CanvasSilentReauth {
    static let shared = CanvasSilentReauth()

    private var webView: WKWebView?
    private var isRunning = false
    private var navigationDelegate: ReauthNavigationDelegate?

    /// How long before expiry to proactively re-auth (23h — Canvas expires at ~24h).
    static let proactiveReauthThreshold: TimeInterval = 23 * 3600

    private init() {}

    /// Check if Canvas needs reauth and do it silently.
    /// Call on app foreground or when ConnectionsScreen loads.
    func reauthIfNeeded(api: VitaAPI) {
        guard !isRunning else { return }

        Task {
            do {
                let status = try await api.getCanvasStatus()
                guard let canvasConn = status.canvasConnection else { return }

                let needsReauth: Bool
                if canvasConn.status == "expired" {
                    needsReauth = true
                    NSLog("[CanvasReauth] Canvas expired, attempting silent reauth")
                } else if canvasConn.status == "active", let lastSync = canvasConn.lastSyncAt {
                    // Proactive: reauth before the ~24h Canvas timeout hits
                    let fmt = ISO8601DateFormatter()
                    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let syncDate = fmt.date(from: lastSync) ?? ISO8601DateFormatter().date(from: lastSync) {
                        let elapsed = Date().timeIntervalSince(syncDate)
                        needsReauth = elapsed > Self.proactiveReauthThreshold
                    } else {
                        needsReauth = false
                    }
                } else {
                    needsReauth = false
                }

                guard needsReauth else {
                    NSLog("[CanvasReauth] Canvas OK, no reauth needed")
                    return
                }

                guard let instanceUrl = canvasConn.instanceUrl, !instanceUrl.isEmpty else {
                    NSLog("[CanvasReauth] No Canvas instanceUrl found")
                    return
                }

                await performSilentReauth(instanceUrl: instanceUrl, api: api)
            } catch {
                NSLog("[CanvasReauth] Status check failed: %@", String(describing: error))
            }
        }
    }

    /// Force a silent reauth attempt for a specific Canvas instance.
    func forceReauth(instanceUrl: String, api: VitaAPI) async -> Bool {
        guard !isRunning else { return false }
        return await performSilentReauth(instanceUrl: instanceUrl, api: api)
    }

    // MARK: - Core Reauth Flow

    @discardableResult
    private func performSilentReauth(instanceUrl: String, api: VitaAPI) async -> Bool {
        isRunning = true
        defer { cleanup() }

        NSLog("[CanvasReauth] Starting silent reauth for %@", instanceUrl)

        // Create hidden WKWebView with shared cookie store (has Google OAuth cookies)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.applicationNameForUserAgent = "Version/17.0 Safari/605.1.15"

        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 375, height: 812), configuration: config)
        self.webView = wv

        // Navigate to Canvas Google login
        let canvasBase = instanceUrl.hasSuffix("/") ? String(instanceUrl.dropLast()) : instanceUrl
        guard let loginURL = URL(string: "\(canvasBase)/login/google") else {
            NSLog("[CanvasReauth] Invalid instanceUrl: %@", instanceUrl)
            return false
        }
        NSLog("[CanvasReauth] Loading %@", loginURL.absoluteString)

        // Set up navigation delegate that watches for auth completion
        let delegate = ReauthNavigationDelegate(canvasHost: loginURL.host ?? "")
        self.navigationDelegate = delegate
        wv.navigationDelegate = delegate

        wv.load(URLRequest(url: loginURL))

        // Wait for auth to complete (up to 45 seconds).
        // Google OAuth can redirect through multiple pages (account chooser, consent)
        // before landing back on Canvas. 45s covers slow networks + multi-step flows.
        let cookies: String? = await withCheckedContinuation { continuation in
            // Guard against double-resume (success + timeout race)
            let resumed = ResumeGuard()

            delegate.onComplete = { cookies in
                guard resumed.tryConsume() else { return }
                continuation.resume(returning: cookies)
            }

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(45))
                guard resumed.tryConsume() else { return }
                NSLog("[CanvasReauth] Timeout — Google session may have expired")
                delegate.completed = true
                continuation.resume(returning: nil)
            }
        }

        guard let cookies, !cookies.isEmpty else {
            NSLog("[CanvasReauth] Failed — no cookies captured")
            return false
        }

        NSLog("[CanvasReauth] Got fresh cookies (%d chars) — running orchestrator", cookies.count)

        // Run full Canvas sync with fresh cookies.
        // CanvasSyncOrchestrator posts to /portal/ingest with `sessionCookies` in the payload,
        // which upserts portal_connections.sessionCookie + sets status='active' atomically.
        // No separate /portal/connect call needed (that endpoint is Mannesoft-centric and
        // would corrupt Canvas cookies by force-prefixing `PHPSESSID=`).
        let orchestrator = CanvasSyncOrchestrator(
            cookies: cookies,
            instanceUrl: instanceUrl,
            vitaAPI: api,
            onProgress: { progress in
                NSLog("[CanvasReauth/Sync] %@ (%.0f%%)", progress.phase.rawValue, progress.percent)
            }
        )

        do {
            let result = try await orchestrator.run()
            NSLog(
                "[CanvasReauth] SUCCESS — courses=%d, assignments=%d, files=%d, pdfs=%d",
                result.courses ?? 0,
                result.assignments ?? 0,
                result.files ?? 0,
                result.pdfExtracted ?? 0
            )
            return true
        } catch {
            NSLog("[CanvasReauth] Orchestrator failed: %@", String(describing: error))
            return false
        }
    }

    private func cleanup() {
        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView = nil
        navigationDelegate = nil
        isRunning = false
    }
}

// MARK: - Resume Guard

/// Thread-safe single-consumer guard to prevent double-resume of a CheckedContinuation
/// when success callback and timeout race each other.
private final class ResumeGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var consumed = false

    func tryConsume() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if consumed { return false }
        consumed = true
        return true
    }
}

// MARK: - Navigation Delegate

/// Watches WKWebView navigation during Canvas reauth.
/// Handles:  Canvas → Google OAuth → auto-advance → Canvas dashboard → capture cookies.
private class ReauthNavigationDelegate: NSObject, WKNavigationDelegate {
    let canvasHost: String
    var onComplete: ((String?) -> Void)?
    var completed = false
    private var googleAdvanceCount = 0

    init(canvasHost: String) {
        self.canvasHost = canvasHost
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !completed else { return }

        let currentURL = webView.url?.absoluteString ?? ""
        let currentHost = webView.url?.host ?? ""

        NSLog("[CanvasReauth] didFinish: %@", currentURL)

        // On Google auth pages: auto-advance (click account chooser or Next button)
        if currentHost.contains("accounts.google.com") {
            googleAdvanceCount += 1

            // Don't loop forever — if we've tried 5 times, Google session is probably dead
            guard googleAdvanceCount <= 5 else {
                NSLog("[CanvasReauth] Too many Google auth pages — session likely expired")
                completed = true
                onComplete?(nil)
                return
            }

            let autoAdvance = """
                (function() {
                    // Account chooser: click the first account
                    var accounts = document.querySelectorAll('[data-identifier]');
                    if (accounts.length > 0) {
                        accounts[0].click();
                        return 'clicked account: ' + accounts[0].getAttribute('data-identifier');
                    }
                    // Email step: click Next (login_hint should pre-fill)
                    var nextBtn = document.getElementById('identifierNext');
                    if (nextBtn) {
                        nextBtn.click();
                        return 'clicked identifierNext';
                    }
                    // Password step shouldn't happen (SSO), but just in case
                    var passNext = document.getElementById('passwordNext');
                    if (passNext) {
                        passNext.click();
                        return 'clicked passwordNext';
                    }
                    // Consent screen: click Allow
                    var allow = document.getElementById('submit_approve_access');
                    if (allow) {
                        allow.click();
                        return 'clicked approve_access';
                    }
                    return 'no action (waiting for redirect)';
                })();
            """
            webView.evaluateJavaScript(autoAdvance) { result, _ in
                NSLog("[CanvasReauth] Google auto-advance: %@", String(describing: result ?? "nil"))
            }
            return
        }

        // On Canvas domain: check if we're past login (i.e., auth succeeded)
        if currentHost.contains(canvasHost) || canvasHost.contains(currentHost) {
            let path = webView.url?.path ?? ""
            let isLoginPage = path.contains("/login")

            if !isLoginPage {
                // We're on Canvas dashboard — auth succeeded!
                NSLog("[CanvasReauth] Landed on Canvas dashboard: %@", currentURL)
                captureCanvasCookies(from: webView)
            } else {
                NSLog("[CanvasReauth] Still on login page: %@", currentURL)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        NSLog("[CanvasReauth] Navigation failed: %@", error.localizedDescription)
    }

    private func captureCanvasCookies(from webView: WKWebView) {
        guard !completed else { return }

        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self, !self.completed else { return }

            let canvasCookies = cookies.filter { cookie in
                let domain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
                return self.canvasHost.hasSuffix(domain) || domain == self.canvasHost
            }

            guard !canvasCookies.isEmpty else {
                NSLog("[CanvasReauth] No Canvas cookies found")
                self.completed = true
                self.onComplete?(nil)
                return
            }

            let cookieString = canvasCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            NSLog("[CanvasReauth] Captured %d Canvas cookies (%d chars)", canvasCookies.count, cookieString.count)
            NSLog("[CanvasReauth] Cookie names: %@", canvasCookies.map(\.name).joined(separator: ", "))

            self.completed = true
            DispatchQueue.main.async {
                self.onComplete?(cookieString)
            }
        }
    }
}
