import SwiftUI
import UniformTypeIdentifiers

// MARK: - ExportDataScreen
// Shell §5.2.8: Exportar meus dados (LGPD art. 18 V — portabilidade).
// SLA legal pequeno porte: 30 dias. Backend já gera tudo em /api/user/export.
// Esta tela só dispara, salva no temp e oferece ShareSheet pro usuário escolher
// onde guardar (Files, Mail, AirDrop).

struct ExportDataScreen: View {
    var onBack: (() -> Void)?

    @Environment(\.appContainer) private var container

    @State private var isExporting = false
    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                headerBar
                    .padding(.top, 8)

                introSection
                    .padding(.horizontal, 14)
                    .padding(.top, 16)

                whatYouGetCard
                    .padding(.horizontal, 14)
                    .padding(.top, 8)

                actionButton
                    .padding(.horizontal, 14)
                    .padding(.top, 24)

                if let errorMessage {
                    errorBanner(errorMessage)
                        .padding(.horizontal, 14)
                        .padding(.top, 4)
                }

                lgpdFooter
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                Spacer().frame(height: 120)
            }
        }
        .background(Color.clear)
        .trackScreen("ExportData")
        // vita-modals-ignore: ShareSheet wrappa UIActivityViewController nativo iOS
        // (Files/Mail/AirDrop) — não pode viver dentro de VitaSheet (é tela de sistema).
        .sheet(isPresented: $showShareSheet) {
            if let url = exportedFileURL {
                ShareSheet(items: [url])
                    .ignoresSafeArea()
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
                .accessibilityIdentifier("backButton")

                Text("Exportar meus dados")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
            }
            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Intro

    private var introSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Direito à portabilidade")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.92))
            Text("LGPD art. 18 V garante que você pode baixar tudo que produziu no VitaAI a qualquer momento. Geramos um arquivo JSON estruturado e você decide onde guardar.")
                .font(.system(size: 12))
                .foregroundStyle(VitaColors.textWarm.opacity(0.55))
                .lineSpacing(2)
        }
    }

    // MARK: - O que vem

    private var whatYouGetCard: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("O que vem no arquivo")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VitaColors.sectionLabel)
                    .textCase(.uppercase)
                    .kerning(0.5)

                ForEach(Self.contents, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.70))
                            .padding(.top, 1)
                        Text(item)
                            .font(.system(size: 12))
                            .foregroundStyle(VitaColors.textPrimary.opacity(0.85))
                            .lineSpacing(1)
                    }
                }
            }
            .padding(14)
        }
    }

    private static let contents: [String] = [
        "Perfil, conexões de portal e preferências",
        "Disciplinas, notas, frequência, calendário e horários",
        "Documentos (metadados — bytes referenciados)",
        "Flashcards, decks, revisões e estatísticas",
        "Sessões de QBank com respostas e simulados completos",
        "Notas, transcrições, conversas com o coach IA",
        "Conquistas, XP, streak e atividade"
    ]

    // MARK: - Action

    private var actionButton: some View {
        Button(action: { Task { await runExport() } }) {
            HStack(spacing: 10) {
                if isExporting {
                    ProgressView().controlSize(.small).tint(VitaColors.accentLight)
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(isExporting ? "Preparando arquivo..." : "Baixar meus dados")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(VitaColors.accentLight.opacity(0.95))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(VitaColors.accent.opacity(0.20))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(VitaColors.accentHover.opacity(0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isExporting)
        .opacity(isExporting ? 0.6 : 1.0)
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

    // MARK: - Footer

    private var lgpdFooter: some View {
        Text("VitaAI cumpre LGPD (Lei 13.709/2018). DPO: privacy@vitaai.app · SLA legal de portabilidade: 30 dias.")
            .font(.system(size: 10))
            .foregroundStyle(VitaColors.textWarm.opacity(0.30))
            .multilineTextAlignment(.center)
    }

    // MARK: - Logic

    private func runExport() async {
        guard !isExporting else { return }
        isExporting = true
        errorMessage = nil
        defer { isExporting = false }

        do {
            let data = try await container.api.exportUserData()
            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
            let filename = "vitaai-export-\(timestamp).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            exportedFileURL = url
            showShareSheet = true
        } catch {
            errorMessage = "Não foi possível gerar o arquivo agora. Tente novamente em instantes."
        }
    }
}

// MARK: - ShareSheet bridge

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
