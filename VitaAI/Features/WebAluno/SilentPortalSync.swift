import Foundation
import WebKit

/// Silent portal sync — runs on app launch to keep data fresh.
/// Uses persisted WKWebView cookies (same .default() data store as the login WebView).
/// If Mannesoft session is still valid, bridge.js extracts and syncs silently.
/// If session expired, marks connection as expired so the user sees a "Reconecte" banner.
@MainActor
final class SilentPortalSync {
    static let shared = SilentPortalSync()

    private let minSyncInterval: TimeInterval = 3600 // 1 hour between syncs
    private var sessionCheckURL: String = ""
    private var webView: WKWebView?
    private var isRunning = false

    private init() {}

    /// Call on app foreground / dashboard appear.
    /// Does nothing if last sync was recent or no active connection exists.
    /// Also triggers Canvas silent reauth if needed.
    func syncIfNeeded(api: VitaAPI) {
        guard !isRunning else { return }

        // Also check Canvas reauth (runs independently)
        CanvasSilentReauth.shared.reauthIfNeeded(api: api)

        Task {
            // Check if we have an active portal connection
            do {
                let status = try await api.getPortalStatus()
                guard status.connected else { return }

                // Get the portal connection for mannesoft/webaluno
                let conn = status.connections?.first(where: { $0.portalType == "mannesoft" || $0.portalType == "webaluno" })

                // Check if enough time has passed since last sync
                if let lastSync = conn?.lastSyncAt,
                   let syncDate = parseISO(lastSync) {
                    let elapsed = Date().timeIntervalSince(syncDate)
                    if elapsed < minSyncInterval {
                        NSLog("[SilentSync] Last sync %.0fm ago, skipping (min: %.0fm)", elapsed / 60, minSyncInterval / 60)
                        return
                    }
                }

                // Get instance URL from the connection (not hardcoded)
                guard let portalUrl = conn?.instanceUrl, !portalUrl.isEmpty else {
                    NSLog("[SilentSync] No portal instance URL found, skipping")
                    return
                }
                let baseUrl = portalUrl.hasSuffix("/") ? portalUrl : portalUrl + "/"
                sessionCheckURL = baseUrl + (baseUrl.contains("/webaluno") ? "" : "webaluno/")

                NSLog("[SilentSync] Starting silent sync for %@", sessionCheckURL)
                await performSilentSync(api: api)
            } catch {
                NSLog("[SilentSync] Status check failed: %@", String(describing: error))
            }
        }
    }

    private func performSilentSync(api: VitaAPI) async {
        isRunning = true
        defer { isRunning = false }

        // Create a hidden WKWebView with the SAME data store (shares cookies with login WebView)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        config.applicationNameForUserAgent = "Version/17.0 Safari/605.1.15"

        let handler = SilentBridgeHandler()
        config.userContentController.add(handler, name: "vitaBridge")

        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        self.webView = wv

        // Load the Mannesoft portal — cookies should auto-login
        let url = URL(string: sessionCheckURL)!
        wv.load(URLRequest(url: url))

        // Wait for navigation to complete
        let loadResult = await waitForLoad(wv, timeout: 15)
        guard loadResult else {
            NSLog("[SilentSync] Page load timeout/failed")
            cleanup()
            return
        }

        // Check if we landed on logged-in page (index.php) or login page
        let currentURL = wv.url?.absoluteString ?? ""
        let isLoggedIn = currentURL.contains("index.php") || currentURL.contains("modulo=")
        let isAuthPage = currentURL.contains("autenticacao") || currentURL.contains("oauth") || currentURL.contains("login")

        if !isLoggedIn || isAuthPage {
            NSLog("[SilentSync] Session expired (landed on: %@)", currentURL)
            // Mark connection as expired via API
            // The user will see "Reconecte" next time they open the portal screen
            cleanup()
            return
        }

        NSLog("[SilentSync] Session valid! Injecting bridge.js...")

        // Capture PHPSESSID from WKWebView cookies for server-side sync
        let sessionCookie = await extractPHPSESSID(from: wv)

        // Wait 2s for page to render
        try? await Task.sleep(for: .seconds(2))

        // Fetch and inject bridge.js
        guard let bridgeJS = await fetchBridgeJS(api: api) else {
            NSLog("[SilentSync] Could not fetch bridge.js")
            cleanup()
            return
        }

        handler.onComplete = { [weak self] pages in
            guard let self else { return }
            Task { @MainActor in
                NSLog("[SilentSync] Bridge captured %d pages, sending to extract...", pages.count)
                await self.sendToExtract(pages: pages, api: api, sessionCookie: sessionCookie)
                self.cleanup()
            }
        }

        handler.onError = { [weak self] error in
            NSLog("[SilentSync] Bridge error: %@", error)
            Task { @MainActor in self?.cleanup() }
        }

        // Inject bridge.js
        do {
            try await wv.evaluateJavaScript(bridgeJS)
            NSLog("[SilentSync] Bridge injected, waiting for extraction...")
        } catch {
            NSLog("[SilentSync] Bridge injection failed: %@", String(describing: error))
            cleanup()
            return
        }

        // Wait up to 30s for bridge to complete
        try? await Task.sleep(for: .seconds(30))
        if isRunning {
            NSLog("[SilentSync] Bridge timeout")
            cleanup()
        }
    }

    private func waitForLoad(_ wv: WKWebView, timeout: Int) async -> Bool {
        for _ in 0..<(timeout * 2) {
            try? await Task.sleep(for: .milliseconds(500))
            if !wv.isLoading { return true }
        }
        return false
    }

    private func fetchBridgeJS(api: VitaAPI) async -> String? {
        guard let url = URL(string: AppConfig.apiBaseURL + "/portal/bridge") else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    private func extractPHPSESSID(from webView: WKWebView) async -> String? {
        let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
        for cookie in cookies where cookie.name == "PHPSESSID" {
            let value = "PHPSESSID=\(cookie.value)"
            NSLog("[SilentSync] Captured PHPSESSID for server-side sync")
            return value
        }
        NSLog("[SilentSync] No PHPSESSID found in cookies")
        return nil
    }

    private func sendToExtract(pages: [CapturedPortalPage], api: VitaAPI, sessionCookie: String? = nil) async {
        let apiPages = pages.map { page in
            PortalExtractRequestPagesInner(type: page.type, html: page.html, linkText: page.linkText)
        }
        guard !apiPages.isEmpty else { return }

        do {
            // Extract base domain from sessionCheckURL for instanceUrl
            let baseInstance = sessionCheckURL.components(separatedBy: "/webaluno").first ?? sessionCheckURL
            let result = try await api.extractPortalPages(
                pages: apiPages,
                instanceUrl: baseInstance,
                university: "",
                sessionCookie: sessionCookie
            )
            NSLog("[SilentSync] Extract done: grades=%d, schedule=%d", result.grades ?? 0, result.schedule ?? 0)
        } catch {
            NSLog("[SilentSync] Extract failed: %@", String(describing: error))
        }
    }

    private func cleanup() {
        webView?.stopLoading()
        webView?.configuration.userContentController.removeAllScriptMessageHandlers()
        webView = nil
        isRunning = false
    }

    private func parseISO(_ str: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fmt.date(from: str) ?? ISO8601DateFormatter().date(from: str)
    }
}

// MARK: - Silent bridge message handler

private class SilentBridgeHandler: NSObject, WKScriptMessageHandler {
    var onComplete: (([CapturedPortalPage]) -> Void)?
    var onError: ((String) -> Void)?

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "vitaBridge",
              let dict = message.body as? [String: Any],
              let type = dict["type"] as? String else { return }

        switch type {
        case "vita-bridge-complete":
            guard let pagesArray = dict["pages"] as? [[String: Any]] else { return }
            let pages = pagesArray.compactMap { pageDict -> CapturedPortalPage? in
                guard let type = pageDict["type"] as? String,
                      let html = pageDict["html"] as? String,
                      let linkText = pageDict["linkText"] as? String else { return nil }
                return CapturedPortalPage(type: type, html: html, linkText: linkText)
            }
            onComplete?(pages)

        case "vita-bridge-error":
            let error = dict["error"] as? String ?? "Unknown error"
            onError?(error)

        default:
            break
        }
    }
}
