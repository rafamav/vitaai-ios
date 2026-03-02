import SwiftUI

// MARK: - VitaErrorState

/// Error state placeholder for failed screen loads or operations.
///
/// Similar to VitaEmptyState but specifically for error scenarios:
/// - Error icon (defaults to exclamationmark.triangle, customizable via systemImage)
/// - Title and error description
/// - Optional retry button using VitaButton (.danger variant)
/// - Gentle fade-in animation
///
/// Usage:
/// ```swift
/// VitaErrorState(
///     title: "Falha ao carregar",
///     message: error.localizedDescription,
///     onRetry: { viewModel.reload() }
/// )
/// ```
struct VitaErrorState: View {
    let title: String
    let message: String
    var systemImage: String = "exclamationmark.triangle"
    var retryText: String = "Tentar novamente"
    var onRetry: (() -> Void)? = nil

    @State private var visible = false

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: systemImage)
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(VitaColors.dataRed)

            Spacer().frame(height: 24)

            Text(title)
                .font(VitaTypography.titleMedium)
                .foregroundColor(VitaColors.textPrimary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 8)

            Text(message)
                .font(VitaTypography.bodyMedium)
                .foregroundColor(VitaColors.textSecondary)
                .multilineTextAlignment(.center)

            if let retry = onRetry {
                Spacer().frame(height: 24)
                VitaButton(text: retryText, action: retry, variant: .danger, size: .md)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 48)
        .opacity(visible ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                visible = true
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("VitaErrorState") {
    ZStack {
        VitaColors.surface.ignoresSafeArea()
        VitaErrorState(
            title: "Erro ao carregar dados",
            message: "Não foi possível conectar ao servidor. Verifique sua conexão e tente novamente.",
            onRetry: {}
        )
    }
}

#Preview("VitaErrorState — no retry") {
    ZStack {
        VitaColors.surface.ignoresSafeArea()
        VitaErrorState(
            title: "Sem permissão",
            message: "Você não tem acesso a este recurso.",
            systemImage: "lock.fill"
        )
    }
}
#endif
