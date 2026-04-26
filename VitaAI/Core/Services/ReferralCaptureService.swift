import Foundation
import UIKit

// MARK: - ReferralCaptureService
//
// Captura código de referral por 3 caminhos (Rafael 2026-04-26 spec):
//   1. Universal Link /r/CODE → DeepLinkHandler dispara captureCode(code:, source: "universal_link")
//   2. Pasteboard sniff no first launch → checkPasteboardForReferral()
//      lê UIPasteboard.general.string ONE-TIME, regex /vita-ai\.cloud\/r\/([A-Z0-9-]+)/i
//   3. Manual em Settings (window 7d) → ReferralScreen tem fallback
//
// Código capturado fica em UserDefaults("vita_pending_referral") com source.
// Auto-redeem (POST /api/referrals/redeem) acontece após:
//   - Auth concluída (authManager.isLoggedIn = true)
//   - Onboarding terminou (profile.onboardingCompleted = true)
//   - User abriu o app pela 1ª vez pós-onboarding
//
// Idempotente: redeem é UNIQUE no backend, falha silenciosamente se já redimido.

@MainActor
final class ReferralCaptureService {
    static let shared = ReferralCaptureService()
    private init() {}

    private static let codeKey = "vita_pending_referral_code"
    private static let sourceKey = "vita_pending_referral_source"
    private static let pasteboardCheckedKey = "vita_pasteboard_checked_v1"
    private static let codeRegex = #"vita-ai\.cloud/r/([A-Z0-9-]+)"#

    /// Chama no first launch do app (VitaAIApp.swift .onAppear). One-time:
    /// usa UserDefaults flag pra evitar reler clipboard após primeira leitura
    /// (iOS 17+ tem alert de privacidade; ler só uma vez já é suficiente).
    func checkPasteboardForReferral() {
        guard !UserDefaults.standard.bool(forKey: Self.pasteboardCheckedKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: Self.pasteboardCheckedKey) }

        // Pré-check sem alert: detectPatterns(for: [.URL]) (iOS 14+)
        // só retorna patterns que o app declarou no .uipasteboard usage description.
        // Se contém URL, então acessa string (mostra alert no iOS 16+).
        guard UIPasteboard.general.hasStrings else { return }
        guard let raw = UIPasteboard.general.string else { return }

        if let code = extractCode(from: raw) {
            captureCode(code: code, source: "pasteboard")
        }
    }

    /// Persiste código + source pra consumo posterior.
    func captureCode(code: String, source: String) {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.count >= 4, normalized.count <= 20 else { return }
        UserDefaults.standard.set(normalized, forKey: Self.codeKey)
        UserDefaults.standard.set(source, forKey: Self.sourceKey)
    }

    /// Lê o código pendente (não consome). Use pra mostrar "Indicado por..."
    /// no onboarding final. Marca consumed via clearPending() após redeem.
    func pendingCode() -> (code: String, source: String)? {
        guard let code = UserDefaults.standard.string(forKey: Self.codeKey),
              let source = UserDefaults.standard.string(forKey: Self.sourceKey) else {
            return nil
        }
        return (code, source)
    }

    /// Redime o código pendente via API. Chama após auth + onboarding completos.
    /// Idempotente: se backend retornar already_redeemed, limpa pending também.
    func redeemPendingIfAny(api: VitaAPI) async {
        guard let (code, sourceStr) = pendingCode() else { return }
        let source: RedeemReferralCodeRequest.Source = {
            switch sourceStr {
            case "pasteboard": return .pasteboard
            case "manual": return .manual
            default: return .universalLink
            }
        }()
        do {
            _ = try await api.redeemReferralCode(code: code, source: source)
            clearPending()
        } catch {
            // Falha 409 (already_redeemed) ou 400 (invalid_code) → também limpa
            // pra não tentar de novo no próximo launch. Só falha de network
            // mantém o pending pra retry.
            let nsErr = error as NSError
            let msg = nsErr.localizedDescription.lowercased()
            let isClientError = msg.contains("400")
                || msg.contains("409")
                || msg.contains("already_redeemed")
                || msg.contains("invalid_code")
                || msg.contains("cannot_self_refer")
                || msg.contains("window_expired")
            if isClientError {
                clearPending()
            }
        }
    }

    func clearPending() {
        UserDefaults.standard.removeObject(forKey: Self.codeKey)
        UserDefaults.standard.removeObject(forKey: Self.sourceKey)
    }

    // MARK: - Regex

    private func extractCode(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: Self.codeRegex, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let codeRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[codeRange]).uppercased()
    }
}
