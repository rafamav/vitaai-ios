import SwiftUI

// MARK: - VitaToastType

enum VitaToastType {
    case success
    case error
    case warning
    case info

    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error:   return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success: return VitaColors.dataGreen
        case .error:   return VitaColors.dataRed
        case .warning: return VitaColors.dataAmber
        case .info:    return VitaColors.accent
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .success: return "Sucesso"
        case .error:   return "Erro"
        case .warning: return "Aviso"
        case .info:    return "Informação"
        }
    }
}

// MARK: - VitaToastData

struct VitaToastData: Identifiable {
    let id = UUID()
    let message: String
    let type: VitaToastType
    let actionText: String?
    let onAction: (() -> Void)?
    let duration: Double

    init(
        message: String,
        type: VitaToastType = .info,
        actionText: String? = nil,
        onAction: (() -> Void)? = nil,
        duration: Double = 3.0
    ) {
        self.message = message
        self.type = type
        self.actionText = actionText
        self.onAction = onAction
        self.duration = duration
    }
}

// MARK: - VitaToastState (@Observable, iOS 17+)

/// Toast state manager — create once per screen, pass down via environment or prop.
///
/// Usage:
/// ```swift
/// @State private var toastState = VitaToastState()
///
/// // In view hierarchy:
/// .vitaToastHost(toastState)
///
/// // To show:
/// toastState.show("Salvo com sucesso!", type: .success)
/// ```
@Observable
final class VitaToastState {
    var current: VitaToastData? = nil

    func show(
        _ message: String,
        type: VitaToastType = .info,
        actionText: String? = nil,
        onAction: (() -> Void)? = nil,
        duration: Double = 3.0
    ) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            current = VitaToastData(
                message: message,
                type: type,
                actionText: actionText,
                onAction: onAction,
                duration: duration
            )
        }
    }

    func dismiss() {
        withAnimation(.easeOut(duration: 0.25)) {
            current = nil
        }
    }
}

// MARK: - vitaToastHost View Extension

extension View {
    /// Attaches a toast host overlay to any view.
    func vitaToastHost(_ state: VitaToastState) -> some View {
        overlay(alignment: .bottom) {
            _VitaToastHostView(state: state)
        }
    }
}

// MARK: - _VitaToastHostView

private struct _VitaToastHostView: View {
    var state: VitaToastState

    var body: some View {
        ZStack {
            if let toast = state.current {
                _VitaToastBar(data: toast, onDismiss: { state.dismiss() })
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        )
                    )
                    // Auto-dismiss: task is cancelled + restarted each time toast.id changes
                    .task(id: toast.id) {
                        do {
                            try await Task.sleep(for: .seconds(toast.duration))
                            state.dismiss()
                        } catch {
                            // Task cancelled — new toast appeared or dismissed manually
                        }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.current?.id)
    }
}

// MARK: - _VitaToastBar

private struct _VitaToastBar: View {
    let data: VitaToastData
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: data.type.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(data.type.color)
                .accessibilityLabel(data.type.accessibilityLabel)

            // Message
            Text(data.message)
                .font(VitaTypography.bodyMedium)
                .foregroundColor(VitaColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.updatesFrequently)

            // Optional action button
            if let actionText = data.actionText, let onAction = data.onAction {
                Button {
                    onAction()
                    onDismiss()
                } label: {
                    Text(actionText)
                        .font(VitaTypography.labelLarge)
                        .foregroundColor(data.type.color)
                }
                .frame(minWidth: 44, minHeight: 44)
            }

            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(VitaColors.textTertiary)
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Fechar")
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(VitaColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(data.type.color.opacity(0.2), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("VitaToast types") {
    @Previewable @State var toastState = VitaToastState()

    ZStack {
        VitaColors.surface.ignoresSafeArea()

        VStack(spacing: 12) {
            VitaButton(text: "Sucesso", action: {
                toastState.show("Dados salvos com sucesso!", type: .success)
            }, variant: .primary)

            VitaButton(text: "Erro", action: {
                toastState.show("Erro ao conectar ao servidor.", type: .error)
            }, variant: .danger)

            VitaButton(text: "Aviso", action: {
                toastState.show("Sua sessão vai expirar em 5 min.", type: .warning)
            }, variant: .secondary)

            VitaButton(text: "Info", action: {
                toastState.show("Sincronização concluída.", type: .info)
            }, variant: .ghost)

            VitaButton(text: "Com ação", action: {
                toastState.show(
                    "Item excluído.",
                    type: .info,
                    actionText: "Desfazer",
                    onAction: { print("Undo!") }
                )
            }, variant: .secondary)
        }
        .padding()
    }
    .vitaToastHost(toastState)
}
#endif
