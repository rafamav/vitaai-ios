import SwiftUI

// MARK: - PdfToolbar — Goodnotes-inspired 2-row top bar in VitaAI palette
//
// Row 1 (navigation + title):
//   [home]  Title...                              [page counter]
//
// Row 2 (tools | shell):
//   [sidebar] [pen] [highlighter] [text] [lasso]  │  [⌄ more] [⤢] [⋯]
//
// Visual: black glass (ultraThinMaterial) + VitaColors.accent tint 4% + fine
// gold border. Divider between tool group and shell group.
// Each button long-press → tooltip via SwiftUI .help() modifier.
//
// AI is NOT inside this toolbar — Vita mascot is a separate FAB (parity with
// Flexcil and Goodnotes that keep AI outside the pen toolbar).

struct PdfToolbar: View {
    let fileName: String
    let currentPage: Int
    let pageCount: Int
    let isSaving: Bool
    let isAnnotating: Bool
    let isHighlightMode: Bool
    let isTextMode: Bool
    let isSearching: Bool
    let isBookmarked: Bool
    let hasInkOnCurrentPage: Bool
    let isRecognizing: Bool
    let isLassoMode: Bool
    let showMascot: Bool
    let showThumbnailToggle: Bool

    // ZONE-A — Pen Styles (owned by Agent A pen-styles)
    var isEraserMode: Bool = false
    var isPointerMode: Bool = false
    var canUndo: Bool = false
    var canRedo: Bool = false

    // ZONE-C — Study Mode (owned by Agent C study-mode)
    var isMaskingMode: Bool = false
    var isStudyMode: Bool = false

    let onBack: () -> Void
    let onToggleThumbnails: () -> Void
    let onToggleAnnotating: () -> Void
    let onToggleHighlight: () -> Void
    let onToggleText: () -> Void
    let onToggleLasso: () -> Void
    let onToggleSearch: () -> Void
    let onToggleBookmark: () -> Void
    let onToggleFullscreen: () -> Void
    let onToggleMascot: () -> Void
    let onExport: () -> Void
    let onTranscribe: () -> Void

    // ZONE-A callbacks (Agent A pen-styles)
    var onToggleEraser: (() -> Void)? = nil
    var onTogglePointer: (() -> Void)? = nil
    var onUndo: (() -> Void)? = nil
    var onRedo: (() -> Void)? = nil
    var onPenLongPress: (() -> Void)? = nil       // abre popover estilos
    var onHighlightLongPress: (() -> Void)? = nil // abre popover cor

    // ZONE-B callbacks (Agent B header-sheets)
    var onShowBookmarksList: (() -> Void)? = nil
    var onShowOutline: (() -> Void)? = nil
    var onShowSettings: (() -> Void)? = nil

    // ZONE-C callbacks (Agent C study-mode)
    var onToggleMasking: (() -> Void)? = nil
    var onToggleStudyMode: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            navigationRow
            // Subtle gold divider between rows
            LinearGradient(
                colors: [
                    VitaColors.glassBorder.opacity(0.0),
                    VitaColors.accent.opacity(0.25),
                    VitaColors.glassBorder.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
            toolsRow
        }
        .background(glassBackground)
        .overlay(alignment: .top) {
            // Inner top highlight — gives the "lit from above" liquid glass feel
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 8)
            .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
            // Gold gradient bottom border — the iOS 26 liquid glass signature
            LinearGradient(
                colors: [
                    VitaColors.glassBorder.opacity(0.1),
                    VitaColors.accent.opacity(0.35),
                    VitaColors.glassBorder.opacity(0.1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.8)
        }
        .shadow(color: Color.black.opacity(0.25), radius: 12, y: 4)
    }

    // MARK: Row 1 — navigation / title / page counter

    private var navigationRow: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "house.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 36, height: 36)
            }
            .help("Voltar pra Documentos")

            Text(fileName)
                .font(VitaTypography.titleSmall)
                .foregroundStyle(VitaColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isSaving {
                Text("Salvando…")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }

            if pageCount > 0 {
                Text("\(currentPage) / \(pageCount)")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(VitaColors.surfaceCard.opacity(0.6))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: Row 2 — tools (5) | shell overflow | fullscreen | doc overflow

    private var toolsRow: some View {
        HStack(spacing: 2) {
            // --- Tools group ---
            if showThumbnailToggle {
                toolButton(
                    icon: "sidebar.left",
                    active: false,
                    tint: VitaColors.textSecondary,
                    label: "Miniaturas",
                    action: onToggleThumbnails
                )
            }

            toolButton(
                icon: isAnnotating ? "scribble.variable" : "scribble",
                active: isAnnotating,
                tint: VitaColors.accent,
                label: "Desenhar (segura: estilo)",
                action: onToggleAnnotating
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in onPenLongPress?() }
            )

            toolButton(
                icon: "highlighter",
                active: isHighlightMode,
                tint: VitaColors.accent,
                label: "Marca-texto (segura: cor)",
                action: onToggleHighlight
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.45)
                    .onEnded { _ in onHighlightLongPress?() }
            )

            toolButton(
                icon: "character.textbox",
                active: isTextMode,
                tint: VitaColors.accent,
                label: "Caixa de texto",
                action: onToggleText
            )

            if isAnnotating {
                toolButton(
                    icon: "eraser",
                    active: isEraserMode,
                    tint: VitaColors.accent,
                    label: "Borracha",
                    action: { onToggleEraser?() }
                )

                toolButton(
                    icon: "cursorarrow",
                    active: isPointerMode,
                    tint: VitaColors.accent,
                    label: "Apontador",
                    action: { onTogglePointer?() }
                )

                toolButton(
                    icon: "lasso",
                    active: isLassoMode,
                    tint: VitaColors.accentHover,
                    label: "Selecionar traços",
                    action: onToggleLasso
                )

                toolButton(
                    icon: "arrow.uturn.backward",
                    active: false,
                    tint: VitaColors.textSecondary,
                    label: "Desfazer",
                    action: { onUndo?() },
                    disabled: !canUndo
                )

                toolButton(
                    icon: "arrow.uturn.forward",
                    active: false,
                    tint: VitaColors.textSecondary,
                    label: "Refazer",
                    action: { onRedo?() },
                    disabled: !canRedo
                )
            }

            if isAnnotating && hasInkOnCurrentPage {
                toolButton(
                    icon: isRecognizing ? "ellipsis.circle" : "text.viewfinder",
                    active: false,
                    tint: VitaColors.accent,
                    label: "Reconhecer escrita",
                    action: onTranscribe,
                    disabled: isRecognizing
                )
            }

            // --- Secondary tools overflow (search, bookmark) ---
            Menu {
                Button(action: onToggleSearch) {
                    Label("Buscar no PDF", systemImage: "magnifyingglass")
                }
                Button(action: onToggleBookmark) {
                    Label(
                        isBookmarked ? "Remover marcador" : "Marcar página",
                        systemImage: isBookmarked ? "bookmark.fill" : "bookmark"
                    )
                }
                if let onShowBookmarksList {
                    Button(action: onShowBookmarksList) {
                        Label("Marcações salvas", systemImage: "bookmark.circle")
                    }
                }
            } label: {
                Image(systemName: "chevron.down.circle")
                    .font(.system(size: 16))
                    .foregroundStyle((isSearching || isBookmarked) ? VitaColors.accent : VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .help("Mais ferramentas")

            // Flex spacer pushes the shell group to the right
            Spacer(minLength: 0)

            Divider()
                .frame(height: 20)
                .background(VitaColors.glassBorder.opacity(0.6))
                .padding(.horizontal, 4)

            // --- Shell group ---
            toolButton(
                icon: "arrow.up.left.and.arrow.down.right",
                active: false,
                tint: VitaColors.textSecondary,
                label: "Tela cheia",
                action: onToggleFullscreen
            )

            Menu {
                Button(action: onExport) {
                    Label("Exportar / Compartilhar", systemImage: "square.and.arrow.up")
                }
                Button(action: onToggleMascot) {
                    Label(
                        showMascot ? "Esconder Vita" : "Mostrar Vita",
                        systemImage: showMascot ? "questionmark.bubble.fill" : "questionmark.bubble"
                    )
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .help("Mais opções")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Reusable tool button

    private func toolButton(
        icon: String,
        active: Bool,
        tint: Color,
        label: String,
        action: @escaping () -> Void,
        disabled: Bool = false
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? tint : VitaColors.textSecondary)
                .frame(width: 38, height: 38)
                .background(
                    ZStack {
                        if active {
                            // Active state: liquid glass chip with gold gradient fill + glow
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            tint.opacity(0.22),
                                            tint.opacity(0.10)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(tint.opacity(0.5), lineWidth: 0.6)
                        }
                    }
                )
                .shadow(color: active ? tint.opacity(0.3) : .clear, radius: 6, y: 1)
        }
        .disabled(disabled)
        .help(label)
    }

    // MARK: - Glassmorphism background (VitaAI liquid glass)
    //
    // Layered effect (bottom → top):
    //   1. Blurred content underneath via .ultraThinMaterial (dark tinted)
    //   2. Radial accent tint — warmer near the center, darker at edges
    //   3. Subtle noise/shimmer (gradient) for depth
    //   4. Top gold glint (rendered as overlay by parent)

    private var glassBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)

            // Warm gold center tint
            RadialGradient(
                colors: [
                    VitaColors.accent.opacity(0.10),
                    VitaColors.accent.opacity(0.03),
                    Color.black.opacity(0.05)
                ],
                center: .top,
                startRadius: 20,
                endRadius: 320
            )

            // Vertical gradient adds "glass thickness"
            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.clear,
                    Color.black.opacity(0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
