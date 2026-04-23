import SwiftUI

/// Slim WhatsApp-link flow used by the onboarding `ExtrasStep`. Calls the
/// same backend contract (`/api/whatsapp/link` + `/api/whatsapp/verify`) as
/// the Connections screen, but keeps the sheet self-contained so the onboarding
/// doesn't depend on ConnectorsViewModel.
struct OnboardingWhatsAppLinkSheet: View {
    @Binding var phone: String
    @Binding var code: String
    @Binding var stepIndex: Int
    @Binding var sending: Bool
    @Binding var error: String?
    let onSendCode: () -> Void
    let onVerify: () -> Void
    let onClose: () -> Void

    private var green: Color { Color(red: 0.15, green: 0.68, blue: 0.38) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer().frame(height: 10)
                Image(systemName: stepIndex == 2 ? "checkmark.circle.fill" : "message.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(stepIndex == 2 ? .green : green)

                switch stepIndex {
                case 0: phoneEntry
                case 1: codeEntry
                default: connectedState
                }

                Spacer()
            }
            .padding(.top, 20)
            .background(Color(red: 0.08, green: 0.08, blue: 0.10))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar", action: onClose).foregroundStyle(.gray)
                }
            }
        }
    }

    @ViewBuilder private var phoneEntry: some View {
        Text("Conectar WhatsApp").font(.title2.bold()).foregroundStyle(.white)
        Text("Receba notificações e converse com a VITA pelo WhatsApp")
            .font(.subheadline).foregroundStyle(.gray)
            .multilineTextAlignment(.center).padding(.horizontal)
        TextField("51989484243", text: $phone)
            .keyboardType(.phonePad).textContentType(.telephoneNumber)
            .padding().background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24).foregroundStyle(.white)
        if let err = error { Text(err).font(.caption).foregroundStyle(.red) }
        Button(action: onSendCode) {
            HStack {
                if sending { ProgressView().tint(.black) }
                Text("Enviar código").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(green).foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(phone.count < 8 || sending).padding(.horizontal, 24)
    }

    @ViewBuilder private var codeEntry: some View {
        Text("Digite o código").font(.title2.bold()).foregroundStyle(.white)
        Text("Enviamos um código de 6 dígitos para seu WhatsApp")
            .font(.subheadline).foregroundStyle(.gray)
            .multilineTextAlignment(.center).padding(.horizontal)
        TextField("000000", text: $code)
            .keyboardType(.numberPad).textContentType(.oneTimeCode)
            .multilineTextAlignment(.center)
            .font(.system(size: 32, weight: .bold, design: .monospaced))
            .padding().background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 60).foregroundStyle(.white)
        if let err = error { Text(err).font(.caption).foregroundStyle(.red) }
        Button(action: onVerify) {
            HStack {
                if sending { ProgressView().tint(.black) }
                Text("Verificar").fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(green).foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(code.count < 6 || sending).padding(.horizontal, 24)
        Button("Reenviar código", action: onSendCode)
            .font(.caption).foregroundStyle(.white.opacity(0.4))
    }

    @ViewBuilder private var connectedState: some View {
        Text("WhatsApp conectado!").font(.title2.bold()).foregroundStyle(.white)
        Text("Vita vai te mandar uma mensagem de boas-vindas")
            .font(.subheadline).foregroundStyle(.gray)
    }
}
