import SwiftUI

// MARK: - VitaModals — UM padrão pra TODO overlay/popout do app
//
// Rafael (2026-04-25): "a gente tem 3-4 jeitos diferentes pra mesma coisa,
// isso cria estranhamento. unifica via design tokens, um jeito clean."
//
// Antes: 38× .sheet, 5× .fullScreenCover, 7× .alert, 1× .popover, 16×
// Color.black.opacity custom + 15 sheets-screens próprias (RenameSubject,
// EmailAuth, FlashcardSettings, ConnectorStatus, etc) — cada uma com
// background, animação, scrim, scrim-tap-to-dismiss diferente.
//
// Agora: 3 sabores canônicos com tokens compartilhados.
//
//   • VitaSheet  — bottom sheet pra lista, formulário, picker, detalhe longo.
//                  Substitui .sheet + Color.black.opacity custom + sheets
//                  próprias dispersas. Glass D4, drag handle, detents.
//
//   • VitaBubble — popover bubble com seta, animação iCloud (escala+fade
//                  do ponto de origem). Pra menu rápido, picker pequeno,
//                  info contextual sem perder o lugar. Substitui .popover
//                  + ZStack overlays manuais.
//
//   • VitaAlert  — modal centro pra confirmação destrutiva (excluir, sair).
//                  Blur fundo, 2 botões (cancela / destrutivo vermelho).
//                  Substitui .alert custom e .confirmationDialog.
//
// Tokens compartilhados (todos 3 herdam):
//   - Background:    .ultraThinMaterial + warm gold tint 6%
//   - Border:        gold 22% — mesmo VitaGlassCard
//   - Shadow:        black 50% radius 24 y 8
//   - Animation:     .spring(response: 0.35, dampingFraction: 0.78)
//   - Haptic:        .soft ao abrir
//
// Regra: NÃO criar .sheet/.popover/Color.black.opacity overlay direto em
// nova feature. Use sempre um destes 3. Hook de pre-commit bloqueia drift.
// Ver `~/.claude/shell.md` seção Modals.

// MARK: - Shared tokens

enum VitaModalTokens {
    static let cornerRadius: CGFloat = 20
    static let goldTint = Color(red: 1.0, green: 0.824, blue: 0.549).opacity(0.06)
    static let borderColor = Color(red: 200/255, green: 160/255, blue: 80/255).opacity(0.22)
    static let shadowColor = Color.black.opacity(0.50)
    static let shadowRadius: CGFloat = 24
    static let shadowY: CGFloat = 8
    static let openSpring = Animation.spring(response: 0.35, dampingFraction: 0.78)

    @ViewBuilder
    static func glassBackground(cornerRadius: CGFloat = 20) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(goldTint)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        }
    }
}

// MARK: - VitaSheet (bottom sheet padrão)

/// Bottom sheet glass D4 pra lista, formulário, picker, detalhe longo.
/// Use SEMPRE com `.sheet(item:)` ou `.sheet(isPresented:)`.
///
/// Exemplo:
/// ```swift
/// .sheet(item: $selectedItem) { item in
///     VitaSheet(title: "Detalhes") {
///         // conteúdo
///     }
/// }
/// ```
struct VitaSheet<Content: View>: View {
    var title: String? = nil
    var detents: Set<PresentationDetent> = [.medium, .large]
    @ViewBuilder var content: Content

    init(
        title: String? = nil,
        detents: Set<PresentationDetent> = [.medium, .large],
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detents = detents
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .font(VitaTypography.headlineSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Top edge glow — linha de luz simulando "vidro premium" no topo do sheet.
        // Sutil (gold 30% → 0%) e curta (90px) pra não invadir o conteúdo.
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [
                    VitaColors.accent.opacity(0.32),
                    VitaColors.accent.opacity(0.08),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 90)
            .allowsHitTesting(false)
            .ignoresSafeArea(edges: .top)
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        // Background custom: ultraThinMaterial + gold tint warm 6% — D4 vidro
        // dourado, mais quente e menos austero que ultraThinMaterial puro.
        .presentationBackground {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Rectangle().fill(VitaModalTokens.goldTint)
            }
            .ignoresSafeArea()
        }
        .presentationCornerRadius(28)
        .onAppear { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    }
}

// MARK: - VitaBubble (popover bubble — estilo iCloud)

/// Popover com seta apontando pra origem, anima escala+fade do ponto
/// de tap. Pra menu rápido / picker pequeno / info contextual.
///
/// Exemplo:
/// ```swift
/// .vitaBubble(isPresented: $showLanguagePicker, arrowEdge: .top) {
///     VStack { ... }
/// }
/// ```
struct VitaBubbleModifier<BubbleContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let arrowEdge: Edge
    @ViewBuilder var bubbleContent: () -> BubbleContent

    func body(content: Content) -> some View {
        content.popover(isPresented: $isPresented, arrowEdge: arrowEdge) {
            bubbleContent()
                .padding(14)
                .background(VitaModalTokens.glassBackground(cornerRadius: 14))
                .presentationCompactAdaptation(.popover)
                .presentationBackground(.ultraThinMaterial)
                .onAppear { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        }
    }
}

extension View {
    /// Popover bubble glass D4 (estilo iCloud). Use pra menus rápidos /
    /// pickers pequenos / info contextual que não merece sheet inteira.
    func vitaBubble<Bubble: View>(
        isPresented: Binding<Bool>,
        arrowEdge: Edge = .top,
        @ViewBuilder content: @escaping () -> Bubble
    ) -> some View {
        modifier(VitaBubbleModifier(isPresented: isPresented, arrowEdge: arrowEdge, bubbleContent: content))
    }
}

// MARK: - VitaAlert (modal centro destrutivo)

/// Modal centro glass D4 pra confirmação destrutiva (excluir, sair).
/// Blur fundo, 2 botões (cancela / destrutivo vermelho).
///
/// Exemplo:
/// ```swift
/// .vitaAlert(
///     isPresented: $confirmDelete,
///     title: "Excluir nota?",
///     message: "Essa ação não pode ser desfeita.",
///     destructiveLabel: "Excluir",
///     onConfirm: { delete() }
/// )
/// ```
struct VitaAlertModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let destructiveLabel: String
    let cancelLabel: String
    let onConfirm: () -> Void

    /// Usa `.fullScreenCover` (UIKit por baixo) em vez de `.overlay` —
    /// garante que alert fica em janela acima de tudo, independente
    /// de onde o modificador é chamado (sub-button, ScrollView, etc).
    /// Background `.clear` faz a fullScreenCover virar transparente, e
    /// a transition scale+opacity simula alert pop nativo.
    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $isPresented) {
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented = false
                    }

                VStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text(title)
                            .font(VitaTypography.titleLarge)
                            .foregroundStyle(VitaColors.textPrimary)
                            .multilineTextAlignment(.center)
                        if let message {
                            Text(message)
                                .font(VitaTypography.bodyMedium)
                                .foregroundStyle(VitaColors.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            isPresented = false
                        } label: {
                            Text(cancelLabel)
                                .font(VitaTypography.titleSmall)
                                .foregroundStyle(VitaColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            isPresented = false
                            onConfirm()
                        } label: {
                            Text(destructiveLabel)
                                .font(VitaTypography.titleSmall)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.red.opacity(0.85))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                .background(VitaModalTokens.glassBackground())
                .shadow(color: VitaModalTokens.shadowColor, radius: VitaModalTokens.shadowRadius, y: VitaModalTokens.shadowY)
                .padding(.horizontal, 32)
            }
            .presentationBackground(.clear)
            .onAppear { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
        }
        .transaction { $0.disablesAnimations = true }
    }
}

extension View {
    /// Modal centro glass D4 pra confirmação destrutiva.
    func vitaAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        destructiveLabel: String = "Excluir",
        cancelLabel: String = "Cancelar",
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(VitaAlertModifier(
            isPresented: isPresented,
            title: title,
            message: message,
            destructiveLabel: destructiveLabel,
            cancelLabel: cancelLabel,
            onConfirm: onConfirm
        ))
    }
}
