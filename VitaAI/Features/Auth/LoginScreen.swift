import SwiftUI

struct LoginScreen: View {
    let authManager: AuthManager

    enum AuthMode { case signIn, signUp, forgotPassword }

    @State private var mode: AuthMode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    @State private var showPassword = false
    @State private var isSubmitting = false
    @State private var successMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field { case name, email, password }

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            // Subtle ambient top glow
            RadialGradient(
                colors: [VitaColors.accent.opacity(0.07), .clear],
                center: UnitPoint(x: 0.5, y: 0),
                startRadius: 0,
                endRadius: 350
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 60)

                    // "V" badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VitaColors.accent)
                            .frame(width: 48, height: 48)
                        Text("V")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color(hex: 0x040809))
                    }
                    .padding(.bottom, 20)

                    // Title
                    Text(titleText)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .padding(.bottom, 6)

                    // Subtitle
                    Text(subtitleText)
                        .font(.system(size: 14))
                        .foregroundStyle(VitaColors.textSecondary)
                        .padding(.bottom, 32)

                    // Card
                    VStack(spacing: 14) {

                        // Google (sign in / sign up only)
                        if mode != .forgotPassword {
                            Button(action: { authManager.signInWithGoogle() }) {
                                HStack(spacing: 10) {
                                    GoogleIcon()
                                    Text("Continuar com Google")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(VitaColors.textPrimary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 48)
                                .background(VitaColors.surfaceElevated)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(VitaColors.surfaceBorder, lineWidth: 1))
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)

                            // OR separator
                            HStack(spacing: 12) {
                                Rectangle().fill(VitaColors.surfaceBorder).frame(height: 1)
                                Text("ou").font(.system(size: 12)).foregroundStyle(VitaColors.textTertiary)
                                Rectangle().fill(VitaColors.surfaceBorder).frame(height: 1)
                            }
                        }

                        // Name (sign up only)
                        if mode == .signUp {
                            authTextField("Nome completo", text: $name, field: .name)
                                .autocapitalization(.words)
                        }

                        // Email
                        authTextField("Email", text: $email, field: .email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()

                        // Password
                        if mode != .forgotPassword {
                            HStack(spacing: 10) {
                                Group {
                                    if showPassword {
                                        TextField("Senha", text: $password)
                                            .focused($focusedField, equals: .password)
                                    } else {
                                        SecureField("Senha", text: $password)
                                            .focused($focusedField, equals: .password)
                                    }
                                }
                                .font(.system(size: 15))
                                .foregroundStyle(VitaColors.textPrimary)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .submitLabel(.go)
                                .onSubmit { submit() }

                                Button(action: { showPassword.toggle() }) {
                                    Image(systemName: showPassword ? "eye.slash" : "eye")
                                        .font(.system(size: 14))
                                        .foregroundStyle(VitaColors.textTertiary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 48)
                            .background(VitaColors.surfaceElevated)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(VitaColors.surfaceBorder, lineWidth: 1))
                            .cornerRadius(10)
                        }

                        // Error
                        if let error = authManager.error {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundStyle(.red.opacity(0.85))
                                .multilineTextAlignment(.center)
                        }

                        // Success
                        if let msg = successMessage {
                            Text(msg)
                                .font(.system(size: 13))
                                .foregroundStyle(VitaColors.accent)
                                .multilineTextAlignment(.center)
                        }

                        // Submit button
                        Button(action: submit) {
                            Group {
                                if isSubmitting {
                                    ProgressView().tint(Color(hex: 0x040809))
                                } else {
                                    Text(submitLabel)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color(hex: 0x040809))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(VitaColors.accent)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(isSubmitting)

                        // Forgot password link (sign in only)
                        if mode == .signIn {
                            Button("Esqueci a senha") {
                                withAnimation(.easeInOut(duration: 0.2)) { mode = .forgotPassword }
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(VitaColors.textSecondary)
                        }
                    }
                    .padding(20)
                    .background(VitaColors.surfaceCard)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(VitaColors.surfaceBorder, lineWidth: 1))
                    .cornerRadius(16)
                    .padding(.horizontal, 24)

                    Spacer().frame(height: 24)

                    // Toggle sign in / sign up
                    HStack(spacing: 4) {
                        Text(toggleLabel)
                            .foregroundStyle(VitaColors.textSecondary)
                        Button(toggleAction) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                mode = (mode == .signIn) ? .signUp : .signIn
                                clearFields()
                            }
                        }
                        .foregroundStyle(VitaColors.accent)
                    }
                    .font(.system(size: 14))

                    // Apple sign in
                    Spacer().frame(height: 16)
                    Button(action: { authManager.signInWithApple() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "apple.logo")
                                .font(.system(size: 13))
                            Text("Continuar com Apple")
                                .font(.system(size: 13))
                        }
                        .foregroundStyle(VitaColors.textTertiary)
                    }
                    .buttonStyle(.plain)

                    Spacer().frame(height: 48)
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .onAppear { authManager.error = nil }
    }

    // MARK: - Helpers

    private var titleText: String {
        switch mode {
        case .signIn: return "Entrar no VitaAI"
        case .signUp: return "Criar conta"
        case .forgotPassword: return "Recuperar senha"
        }
    }

    private var subtitleText: String {
        switch mode {
        case .signIn: return "Seu estudo inteligente"
        case .signUp: return "Comece seu estudo inteligente"
        case .forgotPassword: return "Enviaremos um link para seu email"
        }
    }

    private var submitLabel: String {
        switch mode {
        case .signIn: return "Entrar"
        case .signUp: return "Criar conta"
        case .forgotPassword: return "Enviar link"
        }
    }

    private var toggleLabel: String {
        switch mode {
        case .signIn: return "Não tem conta?"
        case .signUp: return "Já tem conta?"
        case .forgotPassword: return "Lembrou a senha?"
        }
    }

    private var toggleAction: String {
        switch mode {
        case .signIn: return "Criar conta"
        case .signUp, .forgotPassword: return "Entrar"
        }
    }

    private func submit() {
        successMessage = nil
        authManager.error = nil
        focusedField = nil

        switch mode {
        case .signIn:
            guard !email.isEmpty, !password.isEmpty else { return }
            isSubmitting = true
            Task {
                await authManager.signInWithEmail(email: email, password: password)
                isSubmitting = false
            }
        case .signUp:
            guard !email.isEmpty, !password.isEmpty, !name.isEmpty else { return }
            isSubmitting = true
            Task {
                await authManager.signUpWithEmail(email: email, password: password, name: name)
                isSubmitting = false
            }
        case .forgotPassword:
            guard !email.isEmpty else { return }
            isSubmitting = true
            Task {
                await authManager.forgotPassword(email: email)
                isSubmitting = false
                successMessage = "Link enviado para \(email)"
            }
        }
    }

    private func clearFields() {
        email = ""; password = ""; name = ""; successMessage = nil; authManager.error = nil
    }

    @ViewBuilder
    private func authTextField(_ placeholder: String, text: Binding<String>, field: Field) -> some View {
        TextField(placeholder, text: text)
            .focused($focusedField, equals: field)
            .font(.system(size: 15))
            .foregroundStyle(VitaColors.textPrimary)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(VitaColors.surfaceElevated)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(VitaColors.surfaceBorder, lineWidth: 1))
            .cornerRadius(10)
    }
}

// MARK: - Google icon (mimics web SVG)

private struct GoogleIcon: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 22, height: 22)
            Text("G")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(red: 0.259, green: 0.522, blue: 0.957))
        }
    }
}
