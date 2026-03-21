import AuthenticationServices
import Foundation

@MainActor
final class AuthManager: NSObject, ObservableObject {
    private let tokenStore: TokenStore

    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = true
    @Published var error: String?
    @Published var userName: String?
    @Published var userImage: String?

    /// Retains the ASWebAuthenticationSession so it isn't deallocated mid-flow.
    private var webAuthSession: ASWebAuthenticationSession?

    init(tokenStore: TokenStore) {
        self.tokenStore = tokenStore
        super.init()
        Task { await checkLoginStatus() }
    }

    private func checkLoginStatus() async {
        let loggedIn = await tokenStore.isLoggedIn
        let name = await tokenStore.userName
        let image = await tokenStore.userImage
        isLoggedIn = loggedIn
        userName = name
        userImage = image
        isLoading = false
    }

    // MARK: - Google Sign-In (ASWebAuthenticationSession → /api/auth/mobile-start)

    func signInWithGoogle() {
        error = nil
        let urlString = "\(AppConfig.authBaseURL)/api/auth/mobile-start?provider=google"
        guard let authURL = URL(string: urlString) else {
            error = "URL inválida"
            return
        }

        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: AppConfig.deepLinkScheme
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                guard let self else { return }
                self.webAuthSession = nil
                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        return // User cancelled
                    }
                    self.error = "Erro ao conectar: \(error.localizedDescription)"
                    return
                }
                guard let url = callbackURL else {
                    self.error = "Nenhuma resposta recebida"
                    return
                }
                await self.handleCallback(url: url)
            }
        }
        session.prefersEphemeralWebBrowserSession = false
        session.presentationContextProvider = ASWebAuthContextProvider.shared
        webAuthSession = session
        session.start()
    }

    // MARK: - Apple Sign-In (Native ASAuthorizationAppleIDProvider → /api/auth/mobile-apple)
    //
    // Apple App Store requirement: Sign in with Apple on iOS MUST use
    // ASAuthorizationAppleIDProvider (native), NOT ASWebAuthenticationSession / WebView.

    func signInWithApple() {
        error = nil
        isLoading = true
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = ASWebAuthContextProvider.shared
        controller.performRequests()
    }

    private func handleAppleAuthorization(_ authorization: ASAuthorization) async {
        defer { isLoading = false }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = credential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            error = "Token Apple não recebido"
            return
        }

        // Build full name from Apple credential (only available on first sign-in)
        var fullName: String?
        if let nameComponents = credential.fullName {
            let parts = [nameComponents.givenName, nameComponents.familyName].compactMap { $0 }
            if !parts.isEmpty { fullName = parts.joined(separator: " ") }
        }

        guard let url = URL(string: "\(AppConfig.authBaseURL)/api/auth/mobile-apple") else {
            error = "URL inválida"; return
        }

        var body: [String: Any] = ["identityToken": identityToken]
        if let fullName { body["fullName"] = fullName }
        if let email = credential.email { body["email"] = email }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        await performAuthRequest(req, email: credential.email)
    }

    // MARK: - Email Auth

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        // BYM-1180: Use better-auth standard route (handled by [...all] catch-all)
        guard let url = URL(string: "\(AppConfig.authBaseURL)/api/auth/sign-in/email") else {
            error = "URL inválida"; return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "password": password])

        await performAuthRequest(req, email: email)
    }

    func signUpWithEmail(email: String, password: String, name: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(AppConfig.authBaseURL)/api/auth/sign-up/email") else {
            error = "URL inválida"; return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "password": password, "name": name])

        await performAuthRequest(req, email: email)
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
        _ = try? await URLSession.shared.data(for: req)
    }

    // MARK: - Unified Response Parsing
    //
    // Handles two response formats:
    //   better-auth standard: { session: { token }, user: { name, email, image } }
    //   mobile-apple / mobile-callback: { token, name, email, image }

    private func performAuthRequest(_ request: URLRequest, email: String?) async {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                error = "Resposta inválida"; return
            }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]

            if (200...299).contains(http.statusCode) {
                // Extract token: try session.token (better-auth) then top-level (mobile endpoints)
                let token: String?
                if let session = json?["session"] as? [String: Any] {
                    token = session["token"] as? String
                } else {
                    token = json?["token"] as? String
                }

                // Extract user info from nested user object or top-level fields
                let user = json?["user"] as? [String: Any]
                let name = user?["name"] as? String ?? json?["name"] as? String
                let resolvedEmail = user?["email"] as? String ?? json?["email"] as? String ?? email
                let image = user?["image"] as? String ?? json?["image"] as? String

                guard let token else {
                    error = "Credenciais inválidas"; return
                }

                await tokenStore.saveSession(token: token, name: name, email: resolvedEmail, image: image)
                userName = name
                userImage = image
                isLoggedIn = true
            } else {
                error = json?["message"] as? String ?? json?["error"] as? String ?? "Email ou senha incorretos"
            }
        } catch {
            self.error = "Erro de conexão"
        }
    }

    // MARK: - OAuth Callback (deep link from mobile-callback)

    private func handleCallback(url: URL) async {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            error = "Callback inválido"
            return
        }

        let params = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
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
        userImage = params["image"]
        isLoggedIn = true
    }

    // MARK: - Demo & Logout

    func enterDemoMode() {
        Task {
            await tokenStore.saveDemoUser()
            userName = "Estudante"
            isLoggedIn = true
        }
    }

    func logout() {
        Task {
            await tokenStore.clearSession()
            userName = nil
            userImage = nil
            isLoggedIn = false
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate (Native Apple Sign-In)

extension AuthManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor [weak self] in
            await self?.handleAppleAuthorization(authorization)
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isLoading = false
            if (error as NSError).code == ASAuthorizationError.canceled.rawValue {
                return // User cancelled
            }
            self.error = "Erro ao conectar com Apple: \(error.localizedDescription)"
        }
    }
}

// MARK: - ASWebAuthenticationSession + ASAuthorizationController context provider

final class ASWebAuthContextProvider: NSObject,
    ASWebAuthenticationPresentationContextProviding,
    ASAuthorizationControllerPresentationContextProviding
{
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
