import Foundation
import Observation
import Combine

@MainActor
@Observable
final class AuthViewModel {
    private let authManager: AuthManager

    var isLoading: Bool { authManager.isLoading }
    var isLoggedIn: Bool { authManager.isLoggedIn }
    var error: String? { authManager.error }
    var userName: String? { authManager.userName }
    var userImage: String? { authManager.userImage }

    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    func signInWithGoogle() {
        authManager.signInWithGoogle()
    }

    func signInWithApple() {
        authManager.signInWithApple()
    }

    func logout() {
        authManager.logout()
    }
}
