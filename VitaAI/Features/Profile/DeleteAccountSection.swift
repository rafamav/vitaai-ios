import SwiftUI
import Sentry

// MARK: - DeleteAccountSection
//
// Bloco "Zona de risco" reutilizável: glass card com 1 linha "Excluir conta
// permanentemente" + alert nativo com TextField "Digite DELETAR" + alert de
// erro. Antes vivia em ConfiguracoesScreen (linhas 357-403) — extraído em
// 2026-04-25 quando Rafael decidiu mover só pro Profile (padrão Duolingo:
// ação destrutiva mora atrás do perfil pessoal, não em settings de app).

struct DeleteAccountSection: View {
    let authManager: AuthManager

    @Environment(\.appContainer) private var appContainer

    @State private var showDeleteAlert: Bool = false
    @State private var deleteConfirmInput: String = ""
    @State private var isDeletingAccount: Bool = false
    @State private var deleteErrorMessage: String?

    private let logoutColor = Color(red: 1.0, green: 0.47, blue: 0.31)

    var body: some View {
        VitaGlassCard {
            Button(action: {
                deleteConfirmInput = ""
                showDeleteAlert = true
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(logoutColor.opacity(0.08))
                            .frame(width: 34, height: 34)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(logoutColor.opacity(0.18), lineWidth: 1)
                            )
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(logoutColor.opacity(0.85))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Excluir conta permanentemente")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(logoutColor.opacity(0.85))
                        Text("Apaga todos os dados. Acao irreversivel.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                    }

                    Spacer()

                    if isDeletingAccount {
                        ProgressView()
                            .controlSize(.small)
                            .tint(logoutColor.opacity(0.8))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(logoutColor.opacity(0.4))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isDeletingAccount)
            .accessibilityIdentifier("deleteAccountRow")
        }
        // vita-modals-ignore: SwiftUI .alert nativo é necessário aqui — TextField input ("Digite DELETAR") não cabe no VitaAlert (2 botões fixos)
        .alert("Excluir conta permanentemente", isPresented: $showDeleteAlert) {
            TextField("Digite DELETAR", text: $deleteConfirmInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button("Cancelar", role: .cancel) {
                deleteConfirmInput = ""
            }
            Button("Excluir tudo", role: .destructive) {
                Task { await performAccountDeletion() }
            }
            .disabled(deleteConfirmInput.trimmingCharacters(in: .whitespaces).uppercased() != "DELETAR")
        } message: {
            Text("Isto apaga PERMANENTEMENTE sua conta, notas, flashcards, conexoes de portal, assinaturas e todo historico. Acao IRREVERSIVEL. Digite DELETAR para confirmar.")
        }
        // vita-modals-ignore: SwiftUI .alert nativo (mensagem dinâmica, OK only) — VitaAlert é destrutivo 2 botões
        .alert("Erro ao excluir", isPresented: .init(
            get: { deleteErrorMessage != nil },
            set: { if !$0 { deleteErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { deleteErrorMessage = nil }
        } message: {
            Text(deleteErrorMessage ?? "")
        }
    }

    private func performAccountDeletion() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            _ = try await appContainer.api.deleteUserData()
            deleteConfirmInput = ""
            authManager.logout()
        } catch {
            deleteErrorMessage = "Nao foi possivel excluir agora. Tente novamente ou entre em contato com suporte."
        }
    }
}
