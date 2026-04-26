import SwiftUI
import CoreImage.CIFilterBuiltins

// MARK: - ReferralScreen
//
// Sistema de indicação Vita (Rafael 2026-04-26). Backend: vitaai-web commit
// c11ec19. Reward: 7 dias Pro pro convidante, 14 dias pro convidado.
// Trigger: convidado vincula portal + completa 1ª sessão.
//
// 4 blocos:
//   1. Hero card com código grande + share button
//   2. Stats (amigos convidados, qualificados, dias ganhos)
//   3. QR code expansível pra mostrar presencial em sala
//   4. Lista anonimizada de amigos (qualificados / pendentes)
//
// Customização: tap no código abre VitaSheet pra trocar (1x apenas).

struct ReferralScreen: View {
    var onBack: (() -> Void)?

    @Environment(\.appContainer) private var container

    @State private var data: MyReferralResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showQR = false
    @State private var showCustomize = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                headerBar.padding(.top, 8)

                if isLoading && data == nil {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let data {
                    heroCard(data)
                        .padding(.horizontal, 14)
                        .padding(.top, 16)

                    statsRow(data)
                        .padding(.horizontal, 14)
                        .padding(.top, 16)

                    Button(action: { showQR.toggle() }) {
                        HStack {
                            Image(systemName: "qrcode")
                                .font(.system(size: 14, weight: .medium))
                            Text(showQR ? "Esconder QR" : "Mostrar QR pra escanear")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Image(systemName: showQR ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(VitaColors.textPrimary.opacity(0.85))
                        .padding(14)
                        .background(VitaColors.glassInnerLight.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.top, 14)

                    if showQR {
                        qrCodeView(data)
                            .padding(.horizontal, 14)
                            .padding(.top, 12)
                    }

                    if !(data.qualifiedFriends ?? []).isEmpty || !(data.pendingFriends ?? []).isEmpty {
                        friendsList(data)
                            .padding(.top, 24)
                    }
                }

                if let errorMessage {
                    errorBanner(errorMessage)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                }

                Spacer().frame(height: 120)
            }
        }
        .background(Color.clear)
        .trackScreen("Referral")
        .task { await load() }
        // vita-modals-ignore: CustomizeCodeSheet já é um VitaSheet internamente.
        .sheet(isPresented: $showCustomize) {
            CustomizeCodeSheet(currentCode: data?.code ?? "") { newCode in
                Task { await load() }
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            HStack(spacing: 10) {
                Button(action: { onBack?() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.75))
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                Text("Convide amigos")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Hero card

    private func heroCard(_ data: MyReferralResponse) -> some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("SEU CÓDIGO")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                    .kerning(0.8)

                Button(action: {
                    showCustomize = true
                    HapticManager.shared.fire(.light)
                }) {
                    HStack(spacing: 8) {
                        Text(data.code)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.95))
                            .tracking(2)
                        if !data.isCustomized {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(data.isCustomized)
            }

            Text("Você ganha \(data.rewards.ownerDays ?? 7) dias Pro por amigo qualificado. Quem você convida ganha \(data.rewards.invitedDays ?? 14) dias.")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.horizontal, 12)

            ShareLink(
                item: URL(string: data.shareUrl)!,
                message: Text("Vem comigo no Vita — app de estudo de medicina. Use meu código pra ganhar \(data.rewards.invitedDays ?? 14) dias Pro grátis: \(data.code)"),
                preview: SharePreview("VitaAI — \(data.code)")
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Compartilhar")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(VitaColors.accentLight.opacity(0.95))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(VitaColors.accent.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(VitaColors.accentHover.opacity(0.30), lineWidth: 1)
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(VitaColors.glassInnerLight.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(VitaColors.accentHover.opacity(0.16), lineWidth: 1)
        )
    }

    // MARK: - Stats

    private func statsRow(_ data: MyReferralResponse) -> some View {
        HStack(spacing: 8) {
            statChip(icon: "person.fill", value: "\(data.totalInvited ?? 0)", label: "Convidados")
            statChip(icon: "checkmark.seal.fill", value: "\(data.totalQualified ?? 0)", label: "Qualificados")
            statChip(icon: "star.fill", value: "+\(data.totalDaysEarned ?? 0)d", label: "Pro grátis")
        }
    }

    private func statChip(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(VitaColors.accentLight.opacity(0.70))
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VitaColors.accentLight.opacity(0.95))
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                .textCase(.uppercase)
                .kerning(0.4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(VitaColors.glassInnerLight.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - QR code

    private func qrCodeView(_ data: MyReferralResponse) -> some View {
        VStack(spacing: 8) {
            if let qr = generateQR(from: data.shareUrl) {
                Image(uiImage: qr)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 220, height: 220)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text("Mostre o QR pra colega scanear com a câmera")
                .font(.system(size: 11))
                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(VitaColors.glassInnerLight.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func generateQR(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Friends list

    private func friendsList(_ data: MyReferralResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if !(data.qualifiedFriends ?? []).isEmpty {
                sectionLabel("Qualificados (você ganhou \(data.rewards.ownerDays ?? 7)d cada)")
                VitaGlassCard {
                    VStack(spacing: 0) {
                        ForEach(Array((data.qualifiedFriends ?? []).enumerated()), id: \.offset) { idx, friend in
                            friendRow(name: friend.name ?? "Anônimo", date: friend.qualifiedAt, qualified: true)
                            if idx < (data.qualifiedFriends ?? []).count - 1 { divider }
                        }
                    }
                }
                .padding(.horizontal, 14)
            }

            if !(data.pendingFriends ?? []).isEmpty {
                sectionLabel("Aguardando 1ª sessão de estudo")
                    .padding(.top, 16)
                VitaGlassCard {
                    VStack(spacing: 0) {
                        ForEach(Array((data.pendingFriends ?? []).enumerated()), id: \.offset) { idx, friend in
                            friendRow(name: friend.name ?? "Anônimo", date: friend.signedUpAt, qualified: false)
                            if idx < (data.pendingFriends ?? []).count - 1 { divider }
                        }
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }

    private func friendRow(name: String, date: Date?, qualified: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: qualified ? "checkmark.circle.fill" : "clock.fill")
                .font(.system(size: 14))
                .foregroundStyle(qualified
                    ? VitaColors.dataGreen.opacity(0.85)
                    : VitaColors.textWarm.opacity(0.45))

            Text(name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.85))

            Spacer()

            if let date {
                Text(formatDate(date))
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.40))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "d MMM"
        return f.string(from: date)
    }

    // MARK: - Common

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(VitaColors.textWarm.opacity(0.40))
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
    }

    private var divider: some View {
        Rectangle()
            .fill(VitaColors.textWarm.opacity(0.04))
            .frame(height: 1)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(VitaColors.dataRed.opacity(0.85))
            Text(msg)
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textPrimary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(VitaColors.dataRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Logic

    private func load() async {
        do {
            let result = try await container.api.getMyReferral()
            data = result
            errorMessage = nil
        } catch {
            errorMessage = "Não conseguimos carregar agora. Tenta puxar pra atualizar."
        }
        isLoading = false
    }
}

// MARK: - CustomizeCodeSheet

private struct CustomizeCodeSheet: View {
    let currentCode: String
    var onChanged: (String) -> Void

    @Environment(\.appContainer) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var input: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        VitaSheet(title: "Personalizar código", detents: [.medium]) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Você pode trocar seu código uma vez. Depois fica fixo. 4–12 caracteres, letras, números e hífen.")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                    .lineSpacing(2)

                VStack(alignment: .leading, spacing: 6) {
                    Text("NOVO CÓDIGO")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VitaColors.sectionLabel)
                        .kerning(0.5)
                    TextField(currentCode, text: $input)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 17, weight: .semibold, design: .monospaced))
                        .padding(14)
                        .background(VitaColors.glassInnerLight.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(VitaColors.accentHover.opacity(0.16), lineWidth: 1)
                        )
                        .foregroundStyle(VitaColors.textPrimary)
                        .onChange(of: input) { _, val in
                            input = val.uppercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
                        }
                }

                if let errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(VitaColors.dataRed.opacity(0.85))
                        Text(errorMessage)
                            .font(.system(size: 12))
                    }
                    .padding(12)
                    .background(VitaColors.dataRed.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Text("Cancelar")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(VitaColors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(VitaColors.glassInnerLight.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)

                    Button(action: { Task { await save() } }) {
                        Text(isSaving ? "Salvando..." : "Confirmar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.95))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(VitaColors.accent.opacity(0.20))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving || input.count < 4)
                    .opacity((isSaving || input.count < 4) ? 0.5 : 1)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
    }

    private func save() async {
        guard input.count >= 4, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let resp = try await container.api.customizeReferralCode(code: input)
            HapticManager.shared.fire(.success)
            onChanged(resp.code ?? input)
            dismiss()
        } catch {
            HapticManager.shared.fire(.error)
            let msg = (error as NSError).localizedDescription.lowercased()
            if msg.contains("taken") || msg.contains("409") {
                errorMessage = "Já tem alguém usando esse código."
            } else if msg.contains("reserved") {
                errorMessage = "Esse código é reservado, escolha outro."
            } else if msg.contains("already_customized") {
                errorMessage = "Você já personalizou seu código antes."
            } else {
                errorMessage = "Não foi possível salvar agora."
            }
        }
    }
}
