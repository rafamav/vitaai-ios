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

    /// Retained delegate for native Apple Sign In flow
    private var appleSignInDelegate: AppleSignInDelegate?

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
            error = "URL invalida"
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

    // MARK: - Native Apple Sign In

    func signInWithApple() {
        error = nil
        isLoading = true

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let credential):
                    await self.handleAppleCredential(credential)
                case .failure(let err):
                    self.isLoading = false
                    if (err as NSError).code == ASAuthorizationError.canceled.rawValue {
                        return
                    }
                    self.error = "Erro ao conectar com Apple: \(err.localizedDescription)"
                }
            }
        }
        self.appleSignInDelegate = delegate
        controller.delegate = delegate
        controller.presentationContextProvider = ASWebAuthContextProvider.shared
        controller.performRequests()
    }

    private func handleAppleCredential(_ credential: ASAuthorizationAppleIDCredential) async {
        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            error = "Token Apple nao recebido"
            isLoading = false
            return
        }

        let fullName: String? = {
            guard let name = credential.fullName else { return nil }
            let parts = [name.givenName, name.familyName].compactMap { $0 }
            return parts.isEmpty ? nil : parts.joined(separator: " ")
        }()

        guard let url = URL(string: "\(AppConfig.authBaseURL)/api/auth/mobile-apple") else {
            error = "URL invalida"
            isLoading = false
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = ["identityToken": identityToken]
        if let fullName { body["fullName"] = fullName }
        if let email = credential.email { body["email"] = email }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                error = "Resposta invalida"
                isLoading = false
                return
            }

            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

            if (200...299).contains(http.statusCode), let token = json?["token"] as? String {
                let name = json?["name"] as? String ?? fullName
                let email = json?["email"] as? String ?? credential.email
                let image = json?["image"] as? String

                await tokenStore.saveSession(token: token, name: name, email: email, image: image)
                userName = name
                userEmail = email
                userImage = image
                isLoggedIn = true

                if let email {
                    SentryConfig.setUser(id: email, email: email)
                    VitaPostHogConfig.identify(userId: email, properties: [
                        "name": name ?? "",
                        "platform": "ios",
                    ])
                }
                VitaPostHogConfig.capture(event: "login", properties: ["method": "apple"])
            } else {
                error = json?["error"] as? String ?? "Erro no login com Apple"
            }
        } catch {
            self.error = "Erro de conexao"
        }
        isLoading = false
    }

    // MARK: - Email Auth

    func signInWithEmail(email: String, password: String) async {
        error = nil

        guard let url = URL(string: "\(AppConfig.authBaseURL)/api/auth/sign-in/email") else {
            error = "URL invalida"; return
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
            error = "URL invalida"; return
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
                error = "Resposta invalida"; return
            }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if (200...299).contains(http.statusCode) {
                var token: String?
                if let setCookies = http.allHeaderFields["Set-Cookie"] as? String {
                    token = extractSessionToken(from: setCookies)
                }
                if token == nil {
                    token = json?["token"] as? String
                }

                let user = json?["user"] as? [String: Any]
                let name = user?["name"] as? String ?? json?["name"] as? String
                let image = user?["image"] as? String
                guard let token else {
                    error = "Credenciais invalidas"; return
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
            self.error = "Erro de conexao"
        }
    }

    private func extractSessionToken(from setCookie: String) -> String? {
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

    // MARK: - OAuth Callback (Google)

    private func handleCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            error = "Callback invalido"
            return
        }

        let params = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0.replacingOccurrences(of: "+", with: " ")) }
        })

        guard let token = params["token"] else {
            error = "Token nao recebido"
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
        lastLoginAt = Date()
    }

    /// Tracks when login last succeeded
    private var lastLoginAt: Date?

    func logout() {
        if let loginTime = lastLoginAt, Date().timeIntervalSince(loginTime) < 5 {
            NSLog("[AuthManager] Ignoring 401 logout — login was %.1fs ago", Date().timeIntervalSince(loginTime))
            return
        }
        Task {
            await tokenStore.clearSession()
            userName = nil
            userEmail = nil
            userImage = nil
            isLoggedIn = false
            lastLoginAt = nil
            SentryConfig.clearUser()
            VitaPostHogConfig.capture(event: "logout")
            VitaPostHogConfig.reset()
        }
    }
}

// MARK: - Apple Sign In Delegate

private final class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let completion: (Result<ASAuthorizationAppleIDCredential, Error>) -> Void

    init(completion: @escaping (Result<ASAuthorizationAppleIDCredential, Error>) -> Void) {
        self.completion = completion
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
            completion(.success(credential))
        } else {
            completion(.failure(NSError(domain: "AppleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Credencial invalida"])))
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}

// MARK: - Presentation context provider

final class ASWebAuthContextProvider: NSObject, ASWebAuthenticationPresentationContextProviding, ASAuthorizationControllerPresentationContextProviding {
    static let shared = ASWebAuthContextProvider()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}
