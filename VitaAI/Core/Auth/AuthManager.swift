import AuthenticationServices
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    private let tokenStore: TokenStore
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = true
    @Published var error: String?
    @Published var userName: String?
    @Published var userEmail: String?
    @Published var userImage: String?

    init(tokenStore: TokenStore) {
        self.tokenStore = tokenStore
        Task { await checkLoginStatus() }
    }

    private func checkLoginStatus() async {
        let loggedIn = await tokenStore.isLoggedIn
        let name = await tokenStore.userName
        let email = await tokenStore.userEmail
        let image = await tokenStore.userImage
        isLoggedIn = loggedIn
        userName = name
        userEmail = email
        userImage = image
        isLoading = false

        // Set monitoring user context if already logged in
        if loggedIn, let email {
            SentryConfig.setUser(id: email, email: email)
            VitaPostHogConfig.identify(userId: email, properties: [
                "name": name ?? "",
                "platform": "ios",
            ])
        }
    }

    func signIn(provider: String) {
        error = nil
        isLoading = true
        let urlString = "\(AppConfig.authBaseURL)/api/auth/mobile-start?provider=\(provider)"
        guard let authURL = URL(string: urlString) else {
            error = "URL inválida"
            isLoading = false
            return
        }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: AppConfig.deepLinkScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.isLoading = false
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        return // User cancelled
                    }
                    self.error = "Erro ao conectar: \(error.localizedDescription)"
                    return
                }
                guard let url = callbackURL else {
                    self.isLoading = false
                    self.error = "Nenhuma resposta recebida"
                    return
                }
                await self.handleCallback(url: url)
                self.isLoading = false
            }
        }
        session.prefersEphemeralWebBrowserSession = false
        session.presentationContextProvider = ASWebAuthContextProvider.shared
        session.start()
    }

    func signInWithGoogle() { signIn(provider: "google") }
    func signInWithApple() { signIn(provider: "apple") }

    func signInWithEmail(email: String, password: String) async {
        error = nil

        guard let url = URL(string: "\(AppConfig.authBaseURL)/api/auth/sign-in/email") else {
            error = "URL inválida"; return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "password": password, "callbackURL": "/"])

        await performEmailAuthRequest(req, email: email)
    }

    func signUpWithEmail(email: String, password: String, name: String) async {
        error = nil

        guard let url = URL(string: "\(AppConfig.authBaseURL)/api/auth/sign-up/email") else {
            error = "URL inválida"; return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "password": password, "name": name, "callbackURL": "/"])

        await performEmailAuthRequest(req, email: email)
    }

    func forgotPassword(email: String) async {
        guard let url = URL(string: "\(AppConfig.authBaseURL)/api/auth/forget-password") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "email": email,
            "redirectTo": "\(AppConfig.authBaseURL)/reset-password"
        ])
        _ = try? await session.data(for: req)
    }

    private func performEmailAuthRequest(_ request: URLRequest, email: String) async {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                error = "Resposta inválida"; return
            }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if (200...299).contains(http.statusCode) {
                // Better Auth sends the real session token in Set-Cookie header, not in JSON body
                // Extract from Set-Cookie: better-auth.session_token=VALUE;...
                var token: String?
                if let setCookies = http.allHeaderFields["Set-Cookie"] as? String {
                    token = extractSessionToken(from: setCookies)
                }
                // Fallback: try JSON body token
                if token == nil {
                    token = json?["token"] as? String
                }

                let user = json?["user"] as? [String: Any]
                let name = user?["name"] as? String ?? json?["name"] as? String
                let image = user?["image"] as? String
                guard let token else {
                    error = "Credenciais inválidas"; return
                }
                await tokenStore.saveSession(token: token, name: name, email: email, image: image)
                userName = name
                userEmail = email
                userImage = image
                isLoggedIn = true
                SentryConfig.setUser(id: email, email: email)
                VitaPostHogConfig.identify(userId: email, properties: [
                    "name": name ?? "",
                    "platform": "ios",
                ])
                VitaPostHogConfig.capture(event: "login", properties: ["method": "email"])
            } else {
                error = json?["message"] as? String ?? "Email ou senha incorretos"
            }
        } catch {
            self.error = "Erro de conexão"
        }
    }

    private func extractSessionToken(from setCookie: String) -> String? {
        // Parse: better-auth.session_token=VALUE; Max-Age=...
        for part in setCookie.components(separatedBy: ",") {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("better-auth.session_token=") {
                if let range = trimmed.range(of: "better-auth.session_token=") {
                    let afterPrefix = trimmed[range.upperBound...]
                    let value = afterPrefix.components(separatedBy: ";").first ?? ""
                    let decoded = value.removingPercentEncoding ?? String(value)
                    if !decoded.isEmpty { return decoded }
                }
            }
        }
        return nil
    }

    private func handleCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            error = "Callback inválido"
            return
        }

        let params = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0.replacingOccurrences(of: "+", with: " ")) }
        })

        guard let token = params["token"] else {
            error = "Token não recebido"
            return
        }

        await tokenStore.saveSession(
            token: token,
            name: params["name"],
            email: params["email"],
            image: params["image"]
        )

        userName = params["name"]
        userEmail = params["email"]
        userImage = params["image"]
        isLoggedIn = true

        if let email = params["email"] {
            SentryConfig.setUser(id: email, email: email)
            VitaPostHogConfig.identify(userId: email, properties: [
                "name": params["name"] ?? "",
                "platform": "ios",
            ])
        }
        VitaPostHogConfig.capture(event: "login", properties: ["method": "oauth"])
    }

    func logout() {
        // Already @MainActor — no need for Task wrapper which causes race conditions
        Task {
            await tokenStore.clearSession()
            userName = nil
            userEmail = nil
            userImage = nil
            isLoggedIn = false
            SentryConfig.clearUser()
            VitaPostHogConfig.capture(event: "logout")
            VitaPostHogConfig.reset()
        }
    }
}

// MARK: - ASWebAuthenticationSession context provider

final class ASWebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = ASWebAuthContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
