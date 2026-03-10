import SwiftUI
import WebKit

// MARK: - Constants

private let defaultCanvasInstanceUrl = "https://ulbra.instructure.com"

/// JS injected after login to scrape Canvas data via REST API using session cookies.
/// Reports progress via window.webkit.messageHandlers.onProgress.postMessage()
/// Calls window.webkit.messageHandlers.onDataScraped.postMessage() with final results.
private let scrapeCanvasJS = """
(async function() {
    var API = window.location.origin + '/api/v1';
    var results = { courses: [], assignments: [], files: [], calendarEvents: [], user: null, errors: [] };

    function apiFetch(path) {
        return fetch(API + path, { credentials: 'include', headers: { 'Accept': 'application/json' } })
            .then(function(r) { if (!r.ok) throw new Error(path + ': ' + r.status); return r.json(); });
    }

    function apiFetchAll(path, maxPages) {
        maxPages = maxPages || 10;
        var url = API + path;
        var all = [];
        var page = 0;
        function next() {
            if (!url || page >= maxPages) return Promise.resolve(all);
            return fetch(url, { credentials: 'include', headers: { 'Accept': 'application/json' } })
                .then(function(r) {
                    if (!r.ok) throw new Error(path + ': ' + r.status);
                    var link = r.headers.get('Link') || '';
                    var m = link.match(/<([^>]+)>;\\s*rel="next"/);
                    url = m ? m[1] : null;
                    page++;
                    return r.json();
                })
                .then(function(data) {
                    if (Array.isArray(data)) { all = all.concat(data); return next(); }
                    else { all.push(data); return all; }
                });
        }
        return next();
    }

    // Step 1: User info
    window.webkit.messageHandlers.onProgress.postMessage({step: 1, total: 5, message: 'Verificando conta...'});
    try { results.user = await apiFetch('/users/self'); } catch(e) { results.errors.push('user: ' + e.message); window.webkit.messageHandlers.onDataScraped.postMessage(JSON.stringify(results)); return; }

    // Step 2: Courses
    window.webkit.messageHandlers.onProgress.postMessage({step: 2, total: 5, message: 'Buscando disciplinas...'});
    try {
        var courses = await apiFetchAll('/courses?enrollment_state=active&include[]=total_scores&include[]=term&per_page=50');
        results.courses = courses.filter(function(c) { return c.name && !c.access_restricted_by_date; }).map(function(c) {
            return { canvasCourseId: c.id, name: c.name, code: c.course_code || null, term: (c.term && c.term.name) || null, enrollmentType: (c.enrollments && c.enrollments[0] && c.enrollments[0].type) || 'student' };
        });
    } catch(e) { results.errors.push('courses: ' + e.message); }
    window.webkit.messageHandlers.onProgress.postMessage({step: 2, total: 5, message: results.courses.length + ' disciplinas encontradas'});

    // Step 3: Assignments + Files per course
    window.webkit.messageHandlers.onProgress.postMessage({step: 3, total: 5, message: 'Buscando tarefas e PDFs...'});
    var totalAssignments = 0;
    var totalFiles = 0;
    for (var i = 0; i < Math.min(results.courses.length, 15); i++) {
        var cid = results.courses[i].canvasCourseId;
        var courseName = results.courses[i].name.substring(0, 30);
        window.webkit.messageHandlers.onProgress.postMessage({step: 3, total: 5, message: courseName + '...'});

        try {
            var assignments = await apiFetchAll('/courses/' + cid + '/assignments?per_page=50&order_by=due_at');
            for (var j = 0; j < assignments.length; j++) {
                var a = assignments[j];
                results.assignments.push({ canvasAssignmentId: a.id, canvasCourseId: cid, name: a.name, description: a.description ? a.description.replace(/<[^>]*>/g, '').slice(0, 500) : null, dueAt: a.due_at || null, pointsPossible: a.points_possible || null });
            }
            totalAssignments += assignments.length;
        } catch(e) { results.errors.push('assignments/' + cid + ': ' + e.message); }

        try {
            var files = await apiFetchAll('/courses/' + cid + '/files?per_page=50&sort=updated_at&order=desc');
            for (var k = 0; k < files.length; k++) {
                var f = files[k];
                var ct = (f.content_type || '').toLowerCase();
                if (ct.indexOf('pdf') < 0 && ct.indexOf('presentation') < 0 && ct.indexOf('document') < 0 && ct.indexOf('text') < 0 && ct.indexOf('image') < 0) continue;
                results.files.push({ canvasFileId: f.id, canvasCourseId: cid, displayName: f.display_name || f.filename, contentType: f.content_type, size: f.size || 0, downloadUrl: f.url || null });
                totalFiles++;
            }
        } catch(e) { /* some courses restrict file access */ }
    }
    window.webkit.messageHandlers.onProgress.postMessage({step: 3, total: 5, message: totalAssignments + ' tarefas, ' + totalFiles + ' arquivos'});

    // Step 4: Calendar events
    window.webkit.messageHandlers.onProgress.postMessage({step: 4, total: 5, message: 'Buscando calendario...'});
    try {
        var now = new Date();
        var later = new Date(now.getTime() + 90*24*60*60*1000);
        var sd = now.toISOString().split('T')[0];
        var ed = later.toISOString().split('T')[0];
        var events = await apiFetchAll('/calendar_events?start_date=' + sd + '&end_date=' + ed + '&per_page=100&type=event');
        for (var m = 0; m < events.length; m++) {
            var ev = events[m];
            results.calendarEvents.push({ canvasEventId: ev.id, title: ev.title, startAt: ev.start_at, endAt: ev.end_at, contextType: ev.context_code || null });
        }
        var aEvents = await apiFetchAll('/calendar_events?start_date=' + sd + '&end_date=' + ed + '&per_page=100&type=assignment');
        for (var n = 0; n < aEvents.length; n++) {
            var ae = aEvents[n];
            results.calendarEvents.push({ canvasEventId: ae.id || (ae.assignment && ae.assignment.id), title: ae.title, startAt: ae.start_at || (ae.assignment && ae.assignment.due_at), endAt: ae.end_at, contextType: ae.context_code || null });
        }
    } catch(e) { results.errors.push('calendar: ' + e.message); }
    window.webkit.messageHandlers.onProgress.postMessage({step: 4, total: 5, message: results.calendarEvents.length + ' eventos encontrados'});

    // Step 5: Done
    window.webkit.messageHandlers.onProgress.postMessage({step: 5, total: 5, message: 'Enviando dados...'});
    window.webkit.messageHandlers.onDataScraped.postMessage(JSON.stringify(results));
})();
"""

// MARK: - CanvasWebViewScreen

struct CanvasWebViewScreen: View {
    var instanceUrl: String = defaultCanvasInstanceUrl
    var onBack: () -> Void
    /// Called once when Canvas data has been scraped. Provides raw JSON, the instance URL,
    /// and a cookie string suitable for server-side background sync.
    var onDataScraped: (String, String, String?) -> Void

    @State private var isLoading: Bool = true
    @State private var loadProgress: Double = 0
    @State private var isScraping: Bool = false
    @State private var progressStep: Int = 0
    @State private var progressTotal: Int = 5
    @State private var progressMessage: String = ""

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                navBar

                if isLoading && !isScraping {
                    ProgressView(value: loadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: VitaColors.accent))
                        .frame(height: 2)
                        .animation(.easeInOut(duration: 0.2), value: loadProgress)
                }

                ZStack {
                    CanvasWebView(
                        instanceUrl: instanceUrl,
                        isLoading: $isLoading,
                        loadProgress: $loadProgress,
                        isScraping: $isScraping,
                        progressStep: $progressStep,
                        progressTotal: $progressTotal,
                        progressMessage: $progressMessage,
                        onDataScraped: onDataScraped
                    )

                    if isScraping {
                        scrapingOverlay
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: isScraping)
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

            Text(isScraping ? "Sincronizando Canvas" : "Entrar no Canvas")
                .font(VitaTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundColor(VitaColors.textPrimary)
                .animation(.easeInOut(duration: 0.2), value: isScraping)

            Spacer()

            Color.clear
                .frame(width: 70, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .background(VitaColors.surface)
    }

    // MARK: - Scraping overlay

    private var scrapingOverlay: some View {
        ZStack {
            VitaColors.surface.opacity(0.95).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 24) {
                    // Circular progress ring
                    ZStack {
                        Circle()
                            .stroke(VitaColors.accent.opacity(0.15), lineWidth: 6)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(
                                from: 0,
                                to: progressTotal > 0
                                    ? CGFloat(progressStep) / CGFloat(progressTotal)
                                    : 0
                            )
                            .stroke(
                                VitaColors.accent,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.4), value: progressStep)

                        Text("\(progressStep)/\(progressTotal)")
                            .font(VitaTypography.labelSmall)
                            .fontWeight(.semibold)
                            .foregroundColor(VitaColors.textSecondary)
                    }

                    VStack(spacing: 6) {
                        Text("Sincronizando Canvas")
                            .font(VitaTypography.titleMedium)
                            .fontWeight(.bold)
                            .foregroundColor(VitaColors.textPrimary)

                        Text(progressMessage)
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(VitaColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .animation(.easeInOut(duration: 0.15), value: progressMessage)
                    }

                    // Step indicators
                    VStack(alignment: .leading, spacing: 10) {
                        canvasSyncStep(label: "Verificando conta", step: 1)
                        canvasSyncStep(label: "Disciplinas", step: 2)
                        canvasSyncStep(label: "Tarefas e PDFs", step: 3)
                        canvasSyncStep(label: "Calendario", step: 4)
                        canvasSyncStep(label: "Enviando dados", step: 5)
                    }
                    .padding(16)
                    .background(VitaColors.surfaceCard.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 32)

                Spacer()
            }
        }
    }

    @ViewBuilder
    private func canvasSyncStep(label: String, step: Int) -> some View {
        let isDone = progressStep > step
        let isActive = progressStep == step

        HStack(spacing: 10) {
            ZStack {
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(VitaColors.dataGreen)
                } else if isActive {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: VitaColors.accent))
                        .scaleEffect(0.75)
                        .frame(width: 18, height: 18)
                } else {
                    Circle()
                        .stroke(VitaColors.textTertiary.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 16, height: 16)
                }
            }
            .frame(width: 20, height: 20)

            Text(label)
                .font(VitaTypography.bodySmall)
                .fontWeight(isActive ? .semibold : .regular)
                .foregroundColor(
                    isDone ? VitaColors.dataGreen
                    : isActive ? VitaColors.textPrimary
                    : VitaColors.textTertiary.opacity(0.5)
                )
                .animation(.easeInOut(duration: 0.2), value: progressStep)
        }
    }
}

// MARK: - CanvasWebView (UIViewRepresentable)

private struct CanvasWebView: UIViewRepresentable {
    let instanceUrl: String
    @Binding var isLoading: Bool
    @Binding var loadProgress: Double
    @Binding var isScraping: Bool
    @Binding var progressStep: Int
    @Binding var progressTotal: Int
    @Binding var progressMessage: String
    var onDataScraped: (String, String, String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Clear stale cookies before starting a fresh session
        WKWebsiteDataStore.default().removeData(
            ofTypes: [WKWebsiteDataTypeCookies],
            modifiedSince: .distantPast,
            completionHandler: {}
        )

        // JS message handlers for the scraping bridge
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "onProgress")
        userContentController.add(context.coordinator, name: "onDataScraped")

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.userContentController = userContentController
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.backgroundColor = UIColor(VitaColors.surface)
        webView.isOpaque = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never

        // Strip WebView marker from user-agent so Google OAuth does not block us
        webView.evaluateJavaScript("navigator.userAgent") { result, _ in
            if let ua = result as? String {
                let cleanedUA = ua
                    .replacingOccurrences(of: " wv", with: "")
                    .replacingOccurrences(of: "(wv)", with: "()")
                webView.customUserAgent = cleanedUA
            }
        }

        // Progress observation
        context.coordinator.webView = webView
        context.coordinator.progressObservation = webView.observe(
            \.estimatedProgress,
            options: [.new]
        ) { _, change in
            DispatchQueue.main.async {
                self.loadProgress = change.newValue ?? 0
            }
        }

        // Go directly to /login/google — /login redirects to /login/canvas (email form)
        let loginUrl = instanceUrl.trimmingCharacters(in: .init(charactersIn: "/")) + "/login/google"
        if let url = URL(string: loginUrl) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let parent: CanvasWebView
        var webView: WKWebView?
        var scraped = false
        var progressObservation: NSKeyValueObservation?

        init(parent: CanvasWebView) {
            self.parent = parent
        }

        deinit {
            progressObservation?.invalidate()
        }

        // MARK: WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "onProgress":
                guard let body = message.body as? [String: Any] else { return }
                let step = body["step"] as? Int ?? 0
                let total = body["total"] as? Int ?? 5
                let msg = body["message"] as? String ?? ""
                DispatchQueue.main.async {
                    self.parent.progressStep = step
                    self.parent.progressTotal = total
                    self.parent.progressMessage = msg
                }

            case "onDataScraped":
                guard !scraped, let json = message.body as? String, !json.isEmpty else { return }
                scraped = true

                // Capture all session cookies for server-side background sync
                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
                    guard let self else { return }
                    let instanceUrl = self.parent.instanceUrl

                    // Build a single "name=value; name2=value2" cookie string
                    let cookieString: String? = cookies.isEmpty ? nil : cookies
                        .map { "\($0.name)=\($0.value)" }
                        .joined(separator: "; ")

                    DispatchQueue.main.async {
                        self.parent.onDataScraped(json, instanceUrl, cookieString)
                    }
                }

            default:
                break
            }
        }

        // MARK: WKNavigationDelegate

        // Allow all navigation to stay inside the WebView
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

            guard !scraped else { return }

            let currentUrl = webView.url?.absoluteString ?? ""
            let instanceBase = parent.instanceUrl.trimmingCharacters(in: .init(charactersIn: "/"))

            // Detect successful login: URL no longer contains /login and belongs to Canvas instance
            let isLoggedIn = !currentUrl.contains("/login")
                && !currentUrl.contains("/logout")
                && currentUrl.hasPrefix(instanceBase)

            guard isLoggedIn && !parent.isScraping else { return }

            DispatchQueue.main.async {
                self.parent.isScraping = true
            }

            webView.evaluateJavaScript(scrapeCanvasJS, completionHandler: nil)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("CanvasWebViewScreen") {
    CanvasWebViewScreen(
        instanceUrl: "https://ulbra.instructure.com",
        onBack: {},
        onDataScraped: { json, url, cookies in
            print("Scraped \(json.count) chars from \(url), cookies: \(cookies?.prefix(80) ?? "nil")")
        }
    )
    .preferredColorScheme(.dark)
}
#endif
