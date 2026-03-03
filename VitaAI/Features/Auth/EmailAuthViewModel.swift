import Foundation
import Observation

// MARK: - EmailAuthViewModel

@Observable
@MainActor
final class EmailAuthViewModel {

    // MARK: - Tab

    enum Tab: Hashable { case signIn, signUp }

    var tab: Tab = .signIn
    var showForgot = false

    // MARK: - Sign In fields
    var signInEmail = ""
    var signInPassword = ""
    var signInPasswordVisible = false

    // MARK: - Sign Up fields
    var signUpName = ""
    var signUpEmail = ""
    var signUpPassword = ""
    var signUpPasswordVisible = false

    // MARK: - Forgot Password
    var forgotEmail = ""
    var forgotSent = false

    // MARK: - State
    var isLoading = false
    var error: String? = nil

    // MARK: - Validation

    var canSignIn: Bool {
        !signInEmail.trimmingCharacters(in: .whitespaces).isEmpty &&
        signInPassword.count >= 8
    }

    var canSignUp: Bool {
        !signUpName.trimmingCharacters(in: .whitespaces).isEmpty &&
        isValidEmail(signUpEmail) &&
        signUpPassword.count >= 8
    }

    /// Inline email error — shown only after user has typed something invalid.
    var signInEmailError: String? {
        guard !signInEmail.isEmpty, !isValidEmail(signInEmail) else { return nil }
        return "Email inválido"
    }

    var signUpEmailError: String? {
        guard !signUpEmail.isEmpty, !isValidEmail(signUpEmail) else { return nil }
        return "Email inválido"
    }

    /// Helper shown below the password field while typing (not a hard error).
    var signUpPasswordHelper: String? {
        guard !signUpPassword.isEmpty, signUpPassword.count < 8 else { return nil }
        return "Mínimo 8 caracteres"
    }

    // MARK: - Init

    private let authManager: AuthManager

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    // MARK: - Helpers

    private func isValidEmail(_ email: String) -> Bool {
        let t = email.trimmingCharacters(in: .whitespaces)
        return t.contains("@") && t.contains(".")
    }

    // MARK: - Actions

    func signIn() async {
        guard canSignIn else { return }
        isLoading = true
        error = nil
        await authManager.signInWithEmail(
            email: signInEmail.trimmingCharacters(in: .whitespaces),
            password: signInPassword
        )
        isLoading = false
        error = authManager.error
    }

    func signUp() async {
        guard canSignUp else { return }
        isLoading = true
        error = nil
        await authManager.signUpWithEmail(
            email: signUpEmail.trimmingCharacters(in: .whitespaces),
            password: signUpPassword,
            name: signUpName.trimmingCharacters(in: .whitespaces)
        )
        isLoading = false
        error = authManager.error
    }

    func sendPasswordReset() async {
        let email = forgotEmail.trimmingCharacters(in: .whitespaces)
        guard !email.isEmpty else { return }
        isLoading = true
        await authManager.forgotPassword(email: email)
        isLoading = false
        forgotSent = true
    }

    func clearError() {
        error = nil
    }

    func switchTab(to newTab: Tab) {
        guard newTab != tab else { return }
        clearError()
        withAnimation(.easeInOut(duration: 0.2)) { tab = newTab }
    }

    func goToForgot() {
        forgotEmail = (tab == .signIn ? signInEmail : signUpEmail)
            .trimmingCharacters(in: .whitespaces)
        withAnimation(.easeInOut(duration: 0.25)) { showForgot = true }
    }

    func backFromForgot() {
        withAnimation(.easeInOut(duration: 0.25)) { showForgot = false }
        forgotSent = false
        clearError()
    }
}
