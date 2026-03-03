import SwiftUI

// MARK: - EmailAuthSheet
// Bottom sheet for email/password authentication.
// Mirrors Android EmailAuthSheet.kt — same tabs, same flow, same copy.

struct EmailAuthSheet: View {
    let authManager: AuthManager

    @State private var viewModel: EmailAuthViewModel

    init(authManager: AuthManager) {
        self.authManager = authManager
        _viewModel = State(initialValue: EmailAuthViewModel(authManager: authManager))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sheetHeader

                if viewModel.showForgot {
                    ForgotContent(vm: viewModel)
                        .padding(.horizontal, 24)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        EmailTabSwitcher(selected: viewModel.tab) { newTab in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            viewModel.switchTab(to: newTab)
                        }
                        .padding(.horizontal, 24)

                        Spacer().frame(height: 24)

                        Group {
                            if viewModel.tab == .signIn {
                                SignInContent(vm: viewModel)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .leading).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            } else {
                                SignUpContent(vm: viewModel)
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .trailing).combined(with: .opacity)
                                    ))
                            }
                        }
                        .animation(.easeInOut(duration: 0.2), value: viewModel.tab)
                        .padding(.horizontal, 24)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }

                Spacer().frame(height: 32)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.showForgot)
        .scrollBounceBehavior(.basedOnSize)
        .background(VitaColors.surfaceElevated.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(VitaColors.surfaceElevated)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Header

    @ViewBuilder
    private var sheetHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(viewModel.showForgot ? "Recuperar senha" : "Acesse sua conta")
                .font(VitaTypography.headlineSmall)
                .foregroundStyle(VitaColors.textPrimary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: viewModel.showForgot)

            Text(viewModel.showForgot
                 ? "Enviaremos um link para criar uma nova senha"
                 : "Faça login ou crie sua conta abaixo")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: viewModel.showForgot)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 20)
    }
}

// MARK: - Email Tab Switcher

private struct EmailTabSwitcher: View {
    let selected: EmailAuthViewModel.Tab
    let onSelect: (EmailAuthViewModel.Tab) -> Void

    var body: some View {
        HStack(spacing: 4) {
            tabButton(.signIn, label: "Entrar")
            tabButton(.signUp, label: "Criar conta")
        }
        .padding(4)
        .background(VitaColors.glassBg, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func tabButton(_ tab: EmailAuthViewModel.Tab, label: String) -> some View {
        let isSelected = selected == tab
        Button {
            onSelect(tab)
        } label: {
            Text(label)
                .font(isSelected ? VitaTypography.labelLarge : VitaTypography.bodyMedium)
                .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? VitaColors.accent.opacity(0.12) : .clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(isSelected ? VitaColors.accent.opacity(0.3) : .clear, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Sign In Content

private struct SignInContent: View {
    @Bindable var vm: EmailAuthViewModel

    @FocusState private var focus: Field?
    private enum Field: Hashable { case email, password }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VitaInput(
                value: $vm.signInEmail,
                label: "Email",
                placeholder: "seu@email.com",
                errorMessage: vm.signInEmailError,
                leadingSystemImage: "envelope",
                showClearButton: false,
                keyboardType: .emailAddress,
                submitLabel: .next,
                onSubmit: { focus = .password }
            )
            .focused($focus, equals: .email)

            Spacer().frame(height: 12)

            VitaInput(
                value: $vm.signInPassword,
                label: "Senha",
                placeholder: "••••••••",
                errorMessage: vm.error,
                leadingSystemImage: "lock",
                showClearButton: false,
                trailingSystemImage: vm.signInPasswordVisible ? "eye.slash" : "eye",
                onTrailingIconTap: { vm.signInPasswordVisible.toggle() },
                isSecure: !vm.signInPasswordVisible,
                submitLabel: .done,
                onSubmit: { Task { await vm.signIn() } }
            )
            .focused($focus, equals: .password)
            .onChange(of: vm.signInPassword) { vm.clearError() }

            Spacer().frame(height: 8)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                focus = nil
                vm.goToForgot()
            } label: {
                Text("Esqueci minha senha")
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.accent.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            Spacer().frame(height: 20)

            VitaButton(
                text: vm.isLoading ? "" : "Entrar",
                action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    focus = nil
                    Task { await vm.signIn() }
                },
                variant: .primary,
                size: .lg,
                isEnabled: vm.canSignIn,
                isLoading: vm.isLoading
            )
            .frame(maxWidth: .infinity)
        }
        .onAppear { focus = .email }
    }
}

// MARK: - Sign Up Content

private struct SignUpContent: View {
    @Bindable var vm: EmailAuthViewModel

    @FocusState private var focus: Field?
    private enum Field: Hashable { case name, email, password }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VitaInput(
                value: $vm.signUpName,
                label: "Nome completo",
                placeholder: "Seu nome",
                leadingSystemImage: "person",
                showClearButton: false,
                submitLabel: .next,
                onSubmit: { focus = .email }
            )
            .focused($focus, equals: .name)

            Spacer().frame(height: 12)

            VitaInput(
                value: $vm.signUpEmail,
                label: "Email",
                placeholder: "seu@email.com",
                errorMessage: vm.signUpEmailError,
                leadingSystemImage: "envelope",
                showClearButton: false,
                keyboardType: .emailAddress,
                submitLabel: .next,
                onSubmit: { focus = .password }
            )
            .focused($focus, equals: .email)

            Spacer().frame(height: 12)

            VitaInput(
                value: $vm.signUpPassword,
                label: "Senha",
                placeholder: "Mínimo 8 caracteres",
                helperText: vm.signUpPasswordHelper,
                errorMessage: vm.error,
                leadingSystemImage: "lock",
                showClearButton: false,
                trailingSystemImage: vm.signUpPasswordVisible ? "eye.slash" : "eye",
                onTrailingIconTap: { vm.signUpPasswordVisible.toggle() },
                isSecure: !vm.signUpPasswordVisible,
                submitLabel: .done,
                onSubmit: { Task { await vm.signUp() } }
            )
            .focused($focus, equals: .password)
            .onChange(of: vm.signUpPassword) { vm.clearError() }

            Spacer().frame(height: 20)

            VitaButton(
                text: vm.isLoading ? "" : "Criar conta",
                action: {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    focus = nil
                    Task { await vm.signUp() }
                },
                variant: .primary,
                size: .lg,
                isEnabled: vm.canSignUp,
                isLoading: vm.isLoading
            )
            .frame(maxWidth: .infinity)
        }
        .onAppear { focus = .name }
    }
}

// MARK: - Forgot Password Content

private struct ForgotContent: View {
    @Bindable var vm: EmailAuthViewModel

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if vm.forgotSent {
                // Success state
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(VitaColors.dataGreen)

                    Text("Email enviado!")
                        .font(VitaTypography.titleLarge)
                        .foregroundStyle(VitaColors.textPrimary)

                    Text("Verifique sua caixa de entrada e spam.\nO link expira em 1 hora.")
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            } else {
                // Input state
                VitaInput(
                    value: $vm.forgotEmail,
                    label: "Email",
                    placeholder: "seu@email.com",
                    leadingSystemImage: "envelope",
                    showClearButton: false,
                    keyboardType: .emailAddress,
                    submitLabel: .done,
                    onSubmit: { Task { await vm.sendPasswordReset() } }
                )
                .focused($isFocused)

                Spacer().frame(height: 20)

                VitaButton(
                    text: vm.isLoading ? "" : "Enviar link",
                    action: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        isFocused = false
                        Task { await vm.sendPasswordReset() }
                    },
                    variant: .primary,
                    size: .lg,
                    isEnabled: !vm.forgotEmail.trimmingCharacters(in: .whitespaces).isEmpty,
                    isLoading: vm.isLoading
                )
                .frame(maxWidth: .infinity)

                Spacer().frame(height: 4)
            }

            // Back button
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                vm.backFromForgot()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .medium))
                    Text("Voltar")
                        .font(VitaTypography.labelMedium)
                }
                .foregroundStyle(VitaColors.accent.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: vm.forgotSent ? .center : .leading)
        }
        .onAppear { if !vm.forgotSent { isFocused = true } }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("EmailAuthSheet") {
    Color.black
        .ignoresSafeArea()
        .sheet(isPresented: .constant(true)) {
            let store = TokenStore()
            let manager = AuthManager(tokenStore: store)
            EmailAuthSheet(authManager: manager)
        }
}
#endif
