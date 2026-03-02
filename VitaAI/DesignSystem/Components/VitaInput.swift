import SwiftUI

// MARK: - VitaInput

/// Text input field for VitaAI with glass-morphism styling.
///
/// Features:
/// - Label, placeholder, error message, helper text
/// - Leading icon (SF Symbol), trailing clear button or custom icon
/// - States: default (glass bg), focused (accent border), error (red border), disabled
/// - Glass-style background matching VitaGlassCard aesthetics
/// - 44pt minimum touch target (accessibility)
///
/// Usage:
/// ```swift
/// VitaInput(
///     value: $email,
///     label: "E-mail",
///     placeholder: "seu@email.com",
///     leadingSystemImage: "envelope",
///     keyboardType: .emailAddress
/// )
/// ```
struct VitaInput: View {
    @Binding var value: String
    var label: String? = nil
    var placeholder: String? = nil
    var helperText: String? = nil
    var errorMessage: String? = nil
    var leadingSystemImage: String? = nil
    var showClearButton: Bool = true
    var trailingSystemImage: String? = nil
    var onTrailingIconTap: (() -> Void)? = nil
    var isEnabled: Bool = true
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .done
    var onSubmit: (() -> Void)? = nil

    @FocusState private var isFocused: Bool

    private var isError: Bool { errorMessage != nil }

    // Glass background
    private let containerColor = VitaColors.glassBg

    private var borderColor: Color {
        if isError { return VitaColors.dataRed }
        if isFocused { return VitaColors.accent }
        return VitaColors.glassBorder
    }

    private var labelColor: Color {
        isError ? VitaColors.dataRed : VitaColors.textSecondary
    }

    private var bottomText: String? { errorMessage ?? helperText }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Label
            if let label {
                Text(label)
                    .font(VitaTypography.labelMedium)
                    .foregroundColor(labelColor)
                    .padding(.bottom, 6)
            }

            // Field
            HStack(spacing: 8) {
                if let icon = leadingSystemImage {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(VitaColors.textSecondary)
                        .frame(width: 20)
                }

                Group {
                    if isSecure {
                        SecureField(placeholder ?? "", text: $value)
                    } else {
                        TextField(placeholder ?? "", text: $value)
                            .keyboardType(keyboardType)
                    }
                }
                .font(VitaTypography.bodyLarge)
                .foregroundColor(isEnabled ? VitaColors.textPrimary : VitaColors.textTertiary)
                .submitLabel(submitLabel)
                .onSubmit { onSubmit?() }
                .focused($isFocused)
                .disabled(!isEnabled)
                .tint(VitaColors.accent)

                // Trailing area
                if let customIcon = trailingSystemImage {
                    Button {
                        onTrailingIconTap?()
                    } label: {
                        Image(systemName: customIcon)
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(VitaColors.textSecondary)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                } else if showClearButton && !value.isEmpty && isEnabled {
                    Button {
                        value = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(VitaColors.textTertiary)
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
            .background(isEnabled ? containerColor : containerColor.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor, lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.15), value: isFocused)
            .animation(.easeInOut(duration: 0.15), value: isError)

            // Helper / Error text
            if let text = bottomText {
                Text(text)
                    .font(VitaTypography.bodySmall)
                    .foregroundColor(isError ? VitaColors.dataRed : VitaColors.textTertiary)
                    .padding(.top, 4)
                    .padding(.leading, 4)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("VitaInput states") {
    ScrollView {
        VStack(spacing: 20) {
            VitaInput(
                value: .constant(""),
                label: "E-mail",
                placeholder: "seu@email.com",
                leadingSystemImage: "envelope"
            )

            VitaInput(
                value: .constant("Rafael"),
                label: "Nome",
                placeholder: "Seu nome",
                leadingSystemImage: "person",
                showClearButton: true
            )

            VitaInput(
                value: .constant(""),
                label: "Senha",
                placeholder: "Mínimo 8 caracteres",
                leadingSystemImage: "lock",
                isSecure: true
            )

            VitaInput(
                value: .constant("valor inválido"),
                label: "Campo com erro",
                placeholder: "Placeholder",
                errorMessage: "Este campo é obrigatório."
            )

            VitaInput(
                value: .constant(""),
                label: "Desabilitado",
                placeholder: "Não editável",
                isEnabled: false
            )
        }
        .padding(24)
    }
    .background(VitaColors.surface)
}
#endif
