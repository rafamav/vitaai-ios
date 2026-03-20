import AuthenticationServices
import CryptoKit
import Foundation

// MARK: - AppleSignInManager
//
// Handles native Sign in with Apple using ASAuthorizationAppleIDProvider.
// This is required by App Store guideline 4.8 — apps that offer third-party
// social login must also offer Sign in with Apple via the native API.
// Using ASWebAuthenticationSession for Apple is REJECTED by App Review.
//
// Flow:
//   1. Generate a cryptographic nonce (SHA-256 hashed, raw sent to Apple)
//   2. Request authorization via ASAuthorizationController
//   3. On success, POST identityToken + nonce to /api/auth/mobile-apple
//   4. Backend validates token via Supabase, returns { token, name, email, image }
//   5. AuthManager stores session in Keychain

@MainActor
final class AppleSignInManager: NSObject {
    typealias Completion = (Result<AppleSignInResult, Error>, String?) -> Void

    struct AppleSignInResult {
        let identityToken: String
        let fullName: String?
        let email: String?
        let nonce: String
    }

    // Stored across the async boundary — ASAuthorizationController is callback-based.
    // Both must be retained to prevent deallocation before the delegate fires.
    private var continuation: CheckedContinuation<AppleSignInResult, Error>?
    private var authorizationController: ASAuthorizationController?
    private var rawNonce: String = ""

    // MARK: - Public entry point

    func requestAuthorization() async throws -> AppleSignInResult {
        rawNonce = randomNonce()
        let hashedNonce = sha256(rawNonce)

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = hashedNonce

        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else {
                continuation.resume(throwing: AppleSignInError.deallocated)
                return
            }
            self.continuation = continuation

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            // Retain controller so it is not deallocated before the delegate fires
            self.authorizationController = controller
            controller.performRequests()
        }
    }

    // MARK: - Nonce helpers

    private func randomNonce(length: Int = 32) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        precondition(errorCode == errSecSuccess, "Unable to generate nonce: \(errorCode)")

        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInManager: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8)
        else {
            Task { @MainActor [weak self] in
                self?.continuation?.resume(throwing: AppleSignInError.missingToken)
                self?.continuation = nil
            }
            return
        }

        let fullName: String? = {
            guard let name = credential.fullName else { return nil }
            let components = [name.givenName, name.familyName].compactMap { $0 }
            return components.isEmpty ? nil : components.joined(separator: " ")
        }()

        let email = credential.email

        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = AppleSignInResult(
                identityToken: identityToken,
                fullName: fullName,
                email: email,
                nonce: self.rawNonce
            )
            self.continuation?.resume(returning: result)
            self.continuation = nil
            self.authorizationController = nil
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.continuation?.resume(throwing: error)
            self?.continuation = nil
            self?.authorizationController = nil
        }
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return ASPresentationAnchor()
        }
        return window
    }
}

// MARK: - Errors

enum AppleSignInError: LocalizedError {
    case missingToken
    case deallocated

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return NSLocalizedString(
                "Apple Sign-In did not return a valid token.",
                comment: "Apple sign-in error: missing token"
            )
        case .deallocated:
            return NSLocalizedString(
                "Sign-in session expired. Please try again.",
                comment: "Apple sign-in error: manager deallocated"
            )
        }
    }
}
