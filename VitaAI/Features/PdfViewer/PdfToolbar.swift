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
    let showThumbnailToggle: Bool

    // ZONE-A — Pen Styles (owned by Agent A pen-styles)
    var isEraserMode: Bool = false
    var isPointerMode: Bool = false
    var canUndo: Bool = false
    var canRedo: Bool = false

    // ZONE-C — Estudo Ativo (Rafael 2026-04-28 redesign):
    // Botão único do olho liga `isStudyActiveMode` que abre painel flutuante
    // inline dentro do PDF com 2 ações (Criar máscaras / Revisar). isMaskingMode
    // e isStudyMode são sub-modos visuais usados pra tint do botão (eye.fill
    // quando algum sub-modo ativo, glow extra, etc).
    var isMaskingMode: Bool = false
    var isStudyMode: Bool = false
    var isStudyActiveMode: Bool = false

    let onBack: () -> Void
    let onToggleThumbnails: () -> Void
    let onToggleAnnotating: () -> Void
    let onToggleHighlight: () -> Void
    let onToggleText: () -> Void
    let onToggleLasso: () -> Void
    let onToggleSearch: () -> Void
    let onToggleBookmark: () -> Void
    let onToggleFullscreen: () -> Void
    let onAskVita: () -> Void
    let onExport: () -> Void
    let onTranscribe: () -> Void
    var onScanDocument: (() -> Void)? = nil

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
    var onShowStudyStats: (() -> Void)? = nil
    /// Toggle do painel inline "Estudo Ativo" (Rafael 2026-04-28). Substitui
    /// o Menu nativo SwiftUI antigo que fazia popover overlap no próprio botão.
    var onToggleStudyActive: (() -> Void)? = nil

    // Audio sync (Notability-style) — gravação + replay sincronizado com
    // anotações. Estado true = mic vermelho pulsante (gravando).
    var isAudioRecording: Bool = false
    var hasAudioRecorded: Bool = false
    var onToggleAudioRecording: (() -> Void)? = nil
    var onTogglePlaybackOverlay: (() -> Void)? = nil

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
            // Sub-toolbar — só aparece em modos que têm ferramentas extras
            // (Desenho hoje; futuramente pode aparecer pra outros). Mantém a
            // toolbar principal limpa e sinaliza "estou em outra camada".
            if isAnnotating {
                drawSubToolbar
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isAnnotating)
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
                    .font(VitaTypography.titleMedium.weight(.semibold))
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

            // Eraser/Pointer/Lasso/Undo/Redo/Transcribe migraram pra
            // `drawSubToolbar` — mostrada abaixo só quando isAnnotating ON
            // (Rafael 2026-04-28). Isso evita encher a toolbar principal e
            // sinaliza que o user entrou em outra camada de ferramentas.

            // ZONE-C — Estudo Ativo (fundiu Marcador opaco + Study Mode num
            // único botão menu, Rafael 2026-04-28). Pro user é UMA feature
            // de active recall: cobrir conteúdo pra testar memória depois.
            studyActiveMenuButton

            // Audio sync (Notability-style) — gravação de aula sincronizada
            // com anotações. Tap durante .idle → começa gravar. Tap durante
            // .recording → para. Long-press / re-tap quando .loaded → abre
            // overlay player. Mic muda visual: vermelho pulsante quando ON.
            audioRecordButton

            // Pergunte ao Vita — substitui o FAB flutuante. Mesmo asset do
            // mascote, menorzinha, na toolbar. Tap = scan area + chat.
            Button(action: onAskVita) {
                Image("vita-btn-active")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .frame(width: 36, height: 36)
            .help("Pergunte ao Vita")
            .accessibilityLabel("Pergunte ao Vita")

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
                // Document tools (search, bookmark, TOC, settings) — moved here
                // from the left chevron per Rafael 2026-04-28: settings belong
                // grouped on the right side of the toolbar.
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
                if let onShowOutline {
                    Button(action: onShowOutline) {
                        Label("Sumário (TOC)", systemImage: "list.bullet.indent")
                    }
                }
                if let onShowSettings {
                    Button(action: onShowSettings) {
                        Label("Ajustes do PDF", systemImage: "slider.horizontal.3")
                    }
                }
                Divider()
                if let onScanDocument {
                    Button(action: onScanDocument) {
                        Label("Escanear documento", systemImage: "doc.viewfinder")
                    }
                }
                Button(action: onExport) {
                    Label("Exportar / Compartilhar", systemImage: "square.and.arrow.up")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle((isSearching || isBookmarked) ? VitaColors.accent : VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
            }
            .help("Mais opções")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Estudo Ativo — botão olho (Rafael 2026-04-28 redesign v2)
    //
    // Substitui o Menu nativo SwiftUI antigo (que fazia popover overlap no
    // próprio botão e ficou ruim). Agora é toggle direto: tap = liga/desliga
    // painel flutuante inline DENTRO do PDF com 2 ações (Criar máscaras /
    // Revisar). Painel fica posicionado canto inferior direito.
    //
    // Visual sempre dourado (gold accent) com glow + RadialGradient, mais brilho
    // quando o painel está aberto OU algum sub-modo ativo. Asset `vita-btn-active`
    // (mascote) flutuando ao lado dá o toque "vivo" Vita-style pedido.

    private var isStudyActive: Bool { isMaskingMode || isStudyMode || isStudyActiveMode }

    private var studyEyeIcon: String {
        // Olho fechado quando inativo, aberto quando algum sub-modo ON
        return isStudyActive ? "eye.fill" : "eye"
    }

    @ViewBuilder
    private var studyActiveMenuButton: some View {
        Button {
            onToggleStudyActive?()
        } label: {
            studyActiveLabelView
        }
        .buttonStyle(.plain)
        .help("Estudo Ativo (cobrir + revisar)")
        .accessibilityLabel("Estudo Ativo")
    }

    private var studyActiveLabelView: some View {
        ZStack {
            // Halo radial dourado — sempre visível pra dar o toque "premium / vivo".
            // Mais intenso quando ativo.
            RadialGradient(
                colors: [
                    VitaColors.accent.opacity(isStudyActive ? 0.55 : 0.25),
                    VitaColors.accent.opacity(0.0)
                ],
                center: .center,
                startRadius: 2,
                endRadius: isStudyActive ? 26 : 18
            )
            .frame(width: 50, height: 50)
            .blur(radius: isStudyActive ? 4 : 2)

            // Active state — cápsula gradient gold (mantém parity com toolButton prominent)
            if isStudyActive {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                VitaColors.accent.opacity(0.42),
                                VitaColors.accent.opacity(0.22)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 38, height: 38)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(VitaColors.accent.opacity(0.95), lineWidth: 1.1)
                    .frame(width: 38, height: 38)
            }

            // Olho — sempre dourado (Rafael "ícone do olho com gold + brilho")
            Image(systemName: studyEyeIcon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(VitaColors.accent)
                .shadow(color: VitaColors.accent.opacity(isStudyActive ? 0.7 : 0.4), radius: isStudyActive ? 6 : 3)
                .frame(width: 38, height: 38)

            // Mascote Vita pequenininho no canto top-trailing — sinaliza "feature
            // Vita ativa". Asset reaproveitado do botão Pergunte ao Vita.
            Image("vita-btn-active")
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 14, height: 14)
                .offset(x: 13, y: -13)
                .shadow(color: VitaColors.accent.opacity(0.6), radius: 4)
                .opacity(isStudyActive ? 1.0 : 0.85)
        }
        .frame(width: 44, height: 44)
        .shadow(color: isStudyActive ? VitaColors.accent.opacity(0.5) : .clear, radius: 10, y: 1)
    }

    // MARK: - Audio record button (Notability-style)
    //
    // 3 estados visuais:
    //   · .idle (sem gravação) → mic, cinza
    //   · .recording           → mic.fill vermelho com pulse
    //   · .loaded/playing      → waveform dourado (áudio existe, abre overlay)

    @ViewBuilder
    private var audioRecordButton: some View {
        if isAudioRecording {
            Button {
                onToggleAudioRecording?()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(VitaTypography.titleLarge.weight(.semibold))
                    .foregroundStyle(VitaColors.recording)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(VitaColors.recording.opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(VitaColors.recording.opacity(0.7), lineWidth: 1.0)
                    )
                    .shadow(color: VitaColors.recording.opacity(0.5), radius: 10, y: 1)
                    .symbolEffect(.pulse.byLayer, options: .repeating)
            }
            .buttonStyle(.plain)
            .help("Parar gravação")
            .accessibilityLabel("Parar gravação de áudio")
        } else if hasAudioRecorded {
            Button {
                onTogglePlaybackOverlay?()
            } label: {
                Image(systemName: "waveform.circle.fill")
                    .font(VitaTypography.titleLarge.weight(.semibold))
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(VitaColors.accent.opacity(0.18))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(VitaColors.accent.opacity(0.7), lineWidth: 1.0)
                    )
            }
            .buttonStyle(.plain)
            .help("Reproduzir aula gravada")
            .accessibilityLabel("Reproduzir aula gravada")
        } else {
            Button {
                onToggleAudioRecording?()
            } label: {
                Image(systemName: "mic")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.plain)
            .help("Gravar aula (sincroniza com anotações)")
            .accessibilityLabel("Gravar aula")
        }
    }

    // MARK: Row 3 — Draw sub-toolbar (só visível em isAnnotating)
    //
    // Mostrada abaixo da `toolsRow` quando o modo Desenho está ativo. Carrega
    // ferramentas específicas do desenho (borracha, apontador, lasso, undo/redo,
    // transcribe). Idéia: toolbar principal fica enxuta, sub-toolbar sinaliza
    // visualmente "você entrou na camada de desenho".
    private var drawSubToolbar: some View {
        HStack(spacing: 2) {
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

            Spacer(minLength: 4)

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

            if hasInkOnCurrentPage {
                toolButton(
                    icon: isRecognizing ? "ellipsis.circle" : "text.viewfinder",
                    active: false,
                    tint: VitaColors.accent,
                    label: "Reconhecer escrita",
                    action: onTranscribe,
                    disabled: isRecognizing
                )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            Rectangle()
                .fill(VitaColors.accent.opacity(0.06))
        )
        .overlay(alignment: .top) {
            // Indicador visual de "subcamada"
            LinearGradient(
                colors: [
                    VitaColors.glassBorder.opacity(0.0),
                    VitaColors.accent.opacity(0.4),
                    VitaColors.glassBorder.opacity(0.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.5)
        }
    }

// MARK: - Reusable tool button

    private func toolButton(
        icon: String,
        active: Bool,
        tint: Color,
        label: String,
        action: @escaping () -> Void,
        disabled: Bool = false,
        prominent: Bool = false
    ) -> some View {
        let fillTop: Double = prominent ? 0.36 : 0.22
        let fillBottom: Double = prominent ? 0.18 : 0.10
        let strokeAlpha: Double = prominent ? 0.85 : 0.5
        let strokeWidth: CGFloat = prominent ? 1.0 : 0.6
        let shadowAlpha: Double = prominent ? 0.45 : 0.3
        let shadowRadius: CGFloat = prominent ? 10 : 6
        return Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? tint : VitaColors.textSecondary)
                .frame(width: 38, height: 38)
                .background(
                    ZStack {
                        if active {
                            // Active state: liquid glass chip with gold gradient fill + glow.
                            // `prominent` boosts saturation+stroke pra modos de estudo
                            // (Mask + Study Mode) — sinaliza camada premium.
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            tint.opacity(fillTop),
                                            tint.opacity(fillBottom)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(tint.opacity(strokeAlpha), lineWidth: strokeWidth)
                        }
                    }
                )
                .shadow(color: active ? tint.opacity(shadowAlpha) : .clear, radius: shadowRadius, y: 1)
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
