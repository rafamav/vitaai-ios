import SwiftUI
import PDFKit

// MARK: - PdfSettingsSheet
//
// Ajustes globais do PDF Viewer. Persistem em UserDefaults com prefix
// `pdf.settings.*` e algumas se aplicam VIVO no PDFView atual via
// `NativePdfView.pdfViewRef`.
//
// Settings:
//   - Auto-save annotations (toggle, default ON)
//   - Page transition: continuous scroll vs page-by-page
//   - Two-page spread (paisagem) — só faz sentido em iPad/landscape
//   - Brilho (overlay opacity 0.0-0.5 sobre PDFView)
//   - Modo noturno (invert colors via PDFView.appearance)
//   - Tamanho default da fonte freeText (12-32pt)
//   - Reset annotations (botão destrutivo + confirm alert)

struct PdfSettingsSheet: View {
    let onResetAnnotations: () -> Void

    @AppStorage("pdf.settings.autoSave")        private var autoSave: Bool = true
    @AppStorage("pdf.settings.pageByPage")      private var pageByPage: Bool = false
    @AppStorage("pdf.settings.twoPageSpread")   private var twoPageSpread: Bool = false
    @AppStorage("pdf.settings.darkMode")        private var darkMode: Bool = false
    @AppStorage("pdf.settings.brightness")      private var brightness: Double = 1.0
    @AppStorage("pdf.settings.freeTextSize")    private var freeTextSize: Double = 16.0
    // Shape snap reactivated 2026-04-28 — default OFF (segurança até confirmar
    // em uso real que guards anti-letra estão calibrados). Usuário liga aqui.
    @AppStorage("pdf.shapeSnap.enabled")        private var shapeSnapEnabled: Bool = false
    @AppStorage("pdf.handwriting.autoConvert")  private var autoConvertHandwriting: Bool = false

    @State private var showResetConfirm: Bool = false

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        VitaSheet(title: "Ajustes do PDF") {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("Comportamento") {
                        toggleRow(
                            title: "Auto-save de anotações",
                            subtitle: "Salva traços e marcações automaticamente",
                            isOn: $autoSave
                        )
                        .onChange(of: autoSave) { _, _ in applyLive() }

                        toggleRow(
                            title: "Modo página por página",
                            subtitle: "Em vez de rolagem contínua",
                            isOn: $pageByPage
                        )
                        .onChange(of: pageByPage) { _, _ in applyLive() }

                        toggleRow(
                            title: "Página dupla (paisagem)",
                            subtitle: isPad ? "Mostra duas páginas lado a lado em landscape" : "Disponível apenas em iPad",
                            isOn: $twoPageSpread,
                            disabled: !isPad
                        )
                        .onChange(of: twoPageSpread) { _, _ in applyLive() }

                        toggleRow(
                            title: "Snap de formas",
                            subtitle: "Linha torta vira reta, círculo torto vira perfeito (estilo Goodnotes)",
                            isOn: $shapeSnapEnabled
                        )

                        toggleRow(
                            title: "Auto-converter escrita em texto",
                            subtitle: "Quando você para de escrever, vira digitado sozinho (estilo Apple Notes)",
                            isOn: $autoConvertHandwriting
                        )
                    }

                    section("Aparência") {
                        toggleRow(
                            title: "Modo noturno do PDF",
                            subtitle: "Inverte cores (útil pra leitura à noite)",
                            isOn: $darkMode
                        )
                        .onChange(of: darkMode) { _, _ in applyLive() }

                        sliderRow(
                            title: "Brilho",
                            value: $brightness,
                            range: 0.5...1.5,
                            step: 0.05,
                            valueText: String(format: "%.0f%%", brightness * 100)
                        )
                        .onChange(of: brightness) { _, _ in applyLive() }

                        sliderRow(
                            title: "Tamanho default da fonte (caixa de texto)",
                            value: $freeTextSize,
                            range: 12...32,
                            step: 1,
                            valueText: "\(Int(freeTextSize))pt"
                        )
                    }

                    section("Anotações") {
                        Button {
                            showResetConfirm = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "trash")
                                    .font(.system(size: 14, weight: .medium))
                                Text("Limpar todas as anotações deste PDF")
                                    .font(VitaTypography.bodyMedium)
                                Spacer()
                            }
                            .foregroundStyle(VitaColors.dataRed)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(VitaColors.dataRed.opacity(0.10))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(VitaColors.dataRed.opacity(0.35), lineWidth: 0.6)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
        }
        .vitaAlert(
            isPresented: $showResetConfirm,
            title: "Limpar anotações?",
            message: "Todos os traços, marca-textos e caixas de texto deste PDF serão apagados. Não dá pra desfazer.",
            destructiveLabel: "Limpar",
            onConfirm: { onResetAnnotations() }
        )
    }

    // MARK: Helpers

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
                .padding(.bottom, 2)
            content()
        }
    }

    private func toggleRow(
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>,
        disabled: Bool = false
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(disabled ? VitaColors.textTertiary : VitaColors.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(VitaColors.accent)
                .disabled(disabled)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(VitaColors.surfaceCard.opacity(0.5))
        )
    }

    private func sliderRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                Text(valueText)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .monospacedDigit()
            }
            Slider(value: value, in: range, step: step)
                .tint(VitaColors.accent)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(VitaColors.surfaceCard.opacity(0.5))
        )
    }

    /// Aplica as settings vivas no PDFView atual. Chamado on toggle.
    private func applyLive() {
        // PdfSettingsLive lives in PdfViewerScreen.swift — bridge that
        // reaches into NativePdfView.pdfViewRef and applies displayMode/
        // displaysAsBook/inverted overlay, etc.
        PdfSettingsLive.apply(
            pageByPage: pageByPage,
            twoPageSpread: twoPageSpread,
            darkMode: darkMode,
            brightness: brightness
        )
    }
}

// MARK: - PdfSettingsLive
//
// Bridge pra aplicar settings dinâmicas no PDFView ativo. Lê
// `NativePdfView.pdfViewRef` (weak) e mexe nas props necessárias.
// Settings que NÃO precisam de PDFView ref (autoSave, freeTextSize)
// só lêem UserDefaults onde forem usadas.

enum PdfSettingsLive {
    static func apply(
        pageByPage: Bool,
        twoPageSpread: Bool,
        darkMode: Bool,
        brightness: Double
    ) {
        // PdfViewerScreen subscreve via Notification e aplica no PDFView.
        NotificationCenter.default.post(
            name: .pdfSettingsChanged,
            object: nil,
            userInfo: [
                "pageByPage": pageByPage,
                "twoPageSpread": twoPageSpread,
                "darkMode": darkMode,
                "brightness": brightness,
            ]
        )
    }
}

extension Notification.Name {
    static let pdfSettingsChanged = Notification.Name("pdfSettingsChanged")
}
