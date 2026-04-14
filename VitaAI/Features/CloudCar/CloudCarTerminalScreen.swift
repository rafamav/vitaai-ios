import SwiftUI

// MARK: - CloudCarTerminalScreen
//
// In-app surface for CloudCar. Two responsibilities:
// 1. Configure the gateway URL + bearer token (so the user can point the app
//    at their own CloudCode tunnel without rebuilding).
// 2. Show a live transcript / debug terminal — useful before the driver gets
//    in the car, and as a fallback when CarPlay isn't connected.
//
// The screen subscribes to the shared CloudCarController so it sees the same
// state the CarPlay scene sees.

struct CloudCarTerminalScreen: View {

    @StateObject private var controller = CloudCarController.shared
    @State private var gatewayURL: String = CloudCarConfig.gatewayURL
    @State private var authToken: String = CloudCarConfig.authToken ?? ""
    @State private var autoConnect: Bool = CloudCarConfig.autoConnect
    @State private var preferLocalTTS: Bool = CloudCarConfig.preferLocalTTS
    @State private var commandDraft: String = ""
    @State private var showSettings: Bool = false

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                statusStrip
                transcriptView
                composer
            }
        }
        .navigationBarHidden(true)
        .onAppear { controller.start() }
        .sheet(isPresented: $showSettings) {
            settingsSheet
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("CloudCar")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(VitaColors.textPrimary)
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(VitaColors.textSecondary)
                    .padding(10)
                    .background(VitaColors.glassBg)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Status

    private var statusStrip: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 10, height: 10)
            Text(controller.linkState.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VitaColors.textSecondary)
            Spacer()
            Text(listeningLabel)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(VitaColors.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(VitaColors.glassBg)
        .overlay(
            Rectangle()
                .fill(VitaColors.glassBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var statusDotColor: Color {
        switch controller.linkState {
        case .online:                  return VitaColors.dataGreen
        case .connecting,
             .reconnecting:            return VitaColors.dataAmber
        case .error:                   return VitaColors.dataRed
        case .offline:                 return VitaColors.textTertiary
        }
    }

    private var listeningLabel: String {
        switch controller.listening {
        case .idle:      return "Pronto"
        case .listening: return "Ouvindo..."
        case .thinking:  return "Pensando..."
        case .speaking:  return "Respondendo..."
        }
    }

    // MARK: - Transcript

    private var transcriptView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    if controller.transcript.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    }
                    ForEach(controller.transcript) { turn in
                        turnRow(turn)
                            .id(turn.id)
                    }
                    if !controller.partialTranscript.isEmpty {
                        partialRow
                            .id("partial")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .onChange(of: controller.transcript.count) { _ in
                if let last = controller.transcript.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.system(size: 38, weight: .light))
                .foregroundColor(VitaColors.accent.opacity(0.6))
            Text("Conecte ao CarPlay ou toque em Falar para começar")
                .multilineTextAlignment(.center)
                .font(.system(size: 14))
                .foregroundColor(VitaColors.textSecondary)
                .padding(.horizontal, 40)
        }
    }

    private func turnRow(_ turn: CloudCarController.Turn) -> some View {
        HStack(alignment: .top, spacing: 10) {
            roleBadge(turn.role)
            Text(turn.text)
                .font(.system(size: 14))
                .foregroundColor(VitaColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(VitaColors.glassBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(VitaColors.glassBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var partialRow: some View {
        HStack(alignment: .top, spacing: 10) {
            roleBadge(.user)
            Text(controller.partialTranscript)
                .font(.system(size: 14, weight: .light))
                .italic()
                .foregroundColor(VitaColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(VitaColors.glassBg.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func roleBadge(_ role: CloudCarController.Turn.Role) -> some View {
        let (label, color): (String, Color) = {
            switch role {
            case .user:   return ("VC", VitaColors.accent)
            case .agent:  return ("AI", VitaColors.dataBlue)
            case .system: return ("SYS", VitaColors.textTertiary)
            }
        }()
        return Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(VitaColors.surface)
            .frame(width: 32, height: 32)
            .background(color)
            .clipShape(Circle())
    }

    // MARK: - Composer

    private var composer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("Comando ou digite para o agente", text: $commandDraft)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(VitaColors.glassBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .foregroundColor(VitaColors.textPrimary)
                    .submitLabel(.send)
                    .onSubmit(sendDraft)

                Button(action: sendDraft) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VitaColors.surface)
                        .frame(width: 44, height: 44)
                        .background(VitaColors.accent)
                        .clipShape(Circle())
                }
                .disabled(commandDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(commandDraft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
            }

            HStack(spacing: 12) {
                Button(action: micButtonTapped) {
                    HStack(spacing: 8) {
                        Image(systemName: micButtonIcon)
                        Text(micButtonLabel)
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(VitaColors.surface)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(controller.listening == .listening ? VitaColors.dataRed : VitaColors.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                }

                Button {
                    controller.interrupt()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(VitaColors.textPrimary)
                        .frame(width: 50, height: 50)
                        .background(VitaColors.glassBg)
                        .overlay(
                            Circle().stroke(VitaColors.glassBorder, lineWidth: 1)
                        )
                        .clipShape(Circle())
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(VitaColors.surface)
        .overlay(
            Rectangle()
                .fill(VitaColors.glassBorder)
                .frame(height: 1),
            alignment: .top
        )
    }

    private var micButtonIcon: String {
        controller.listening == .listening ? "mic.fill" : "mic"
    }

    private var micButtonLabel: String {
        switch controller.listening {
        case .listening: return "Parar"
        case .thinking:  return "Pensando..."
        case .speaking:  return "Tocando..."
        case .idle:      return "Falar"
        }
    }

    private func micButtonTapped() {
        if controller.listening == .speaking {
            controller.interrupt()
        } else {
            controller.togglePushToTalk()
        }
    }

    private func sendDraft() {
        let text = commandDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        controller.sendCommand(text)
        commandDraft = ""
    }

    // MARK: - Settings sheet

    private var settingsSheet: some View {
        NavigationView {
            Form {
                Section(header: Text("Gateway")) {
                    TextField("wss://...", text: $gatewayURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("Bearer token (opcional)", text: $authToken)
                }
                Section(header: Text("Comportamento")) {
                    Toggle("Conectar automaticamente", isOn: $autoConnect)
                    Toggle("Síntese de voz local (TTS no iPhone)", isOn: $preferLocalTTS)
                }
                Section {
                    Button("Salvar e reconectar") { saveAndReconnect() }
                    Button(role: .destructive) {
                        controller.clearTranscript()
                    } label: {
                        Text("Limpar histórico")
                    }
                }
                Section(header: Text("Sobre")) {
                    Text("CloudCar transmite o microfone do iPhone (ou do carro via CarPlay) para um agente remoto via WebSocket. O cérebro roda no seu PC.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Configurações")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") { showSettings = false }
                }
            }
        }
    }

    private func saveAndReconnect() {
        CloudCarConfig.gatewayURL = gatewayURL
        CloudCarConfig.authToken = authToken.isEmpty ? nil : authToken
        CloudCarConfig.autoConnect = autoConnect
        CloudCarConfig.preferLocalTTS = preferLocalTTS
        controller.disconnect()
        controller.connect()
        showSettings = false
    }
}

#if DEBUG
struct CloudCarTerminalScreen_Previews: PreviewProvider {
    static var previews: some View {
        CloudCarTerminalScreen()
            .preferredColorScheme(.dark)
    }
}
#endif
