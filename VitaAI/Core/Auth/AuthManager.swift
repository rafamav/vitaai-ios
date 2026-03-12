import AuthenticationServices
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    private let tokenStore: TokenStore

    @Published var isLoggedIn: Bool = false
    @Published var isLoading: Bool = true
    @Published var error: String?
    @Published var userName: String?
    @Published var userImage: String?

    init(tokenStore: TokenStore) {
        self.tokenStore = tokenStore
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

    func signIn(provider: String) {
        error = nil
        let urlString = "\(AppConfig.authBaseURL)/api/auth/mobile-start?provider=\(provider)"
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
        session.start()
    }

    func signInWithGoogle() { signIn(provider: "google") }
    func signInWithApple() { signIn(provider: "apple") }

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(AppConfig.authBaseURL)/api/auth/mobile-email-login") else {
            error = "URL inválida"; return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "password": password, "callbackURL": "/"])

        await performEmailAuthRequest(req, email: email)
    }

    func signUpWithEmail(email: String, password: String, name: String) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(AppConfig.authBaseURL)/api/auth/mobile-email-register") else {
            error = "URL inválida"; return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email, "password": password, "name": name])

        await performEmailAuthRequest(req, email: email)
    }

    func forgotPassword(email: String) async {
        guard let url = URL(string: "\(AppConfig.authBaseURL)/api/auth/mobile-forgot-password") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["email": email])
        _ = try? await URLSession.shared.data(for: req)
    }

    private func performEmailAuthRequest(_ request: URLRequest, email: String) async {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                error = "Resposta inválida"; return
            }
            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            if (200...299).contains(http.statusCode) {
                let token = json?["token"] as? String
                let user = json?["user"] as? [String: Any]
                let name = user?["name"] as? String ?? json?["name"] as? String
                let image = user?["image"] as? String
                guard let token else {
                    error = "Credenciais inválidas"; return
                }
                await tokenStore.saveSession(token: token, name: name, email: email, image: image)
                userName = name
                userImage = image
                isLoggedIn = true
            } else {
                error = json?["message"] as? String ?? "Email ou senha incorretos"
            }
        } catch {
            self.error = "Erro de conexão"
        }
    }

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
