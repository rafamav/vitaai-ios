import SwiftUI

// MARK: - Card accent colors (mirroring Android/web)
// Gold theme: front uses gold accent, back uses indigo for visual contrast

private let goldBorder   = VitaColors.accent.opacity(0.12)   // front side border
private let goldGlow     = VitaColors.accent.opacity(0.06)   // front top glow
private let goldPillBg   = VitaColors.accent.opacity(0.08)

// Legacy aliases for existing usage below (no functional change needed)
private let cyanBorder   = goldBorder
private let cyanGlow     = goldGlow
private let cyanPillBg   = goldPillBg

private let indigoAccent  = Color(hex: 0xA78BFA)              // indigo-400 for back side
private let indigoBorder  = Color(hex: 0xA78BFA, opacity: 0.12)
private let indigoGlow    = Color(hex: 0xA78BFA, opacity: 0.06)
private let indigoPillBg  = Color(hex: 0xA78BFA, opacity: 0.08)

private let cardBg = Color(hex: 0x11111A, opacity: 0.92)

// MARK: - FlashcardCardView

/// Animated flip card with gold (front) and indigo (back) themes.
/// Uses `rotation3DEffect` for the Y-axis flip, mirroring the back with negative rotation.
struct FlashcardCardView: View {

    let front: String
    let back: String
    let deckTitle: String
    let isFlipped: Bool
    var onFlip: () -> Void

    @State private var rotationDegrees: Double = 0

    var body: some View {
        ZStack {
            // Both faces are always in the tree; only the correct one is visible
            // based on the rotation angle. This avoids a layout jump mid-animation.
            frontFace
                .opacity(rotationDegrees < 90 ? 1 : 0)
                // Un-mirror the front (it gets mirrored naturally when angle > 180)
                .rotation3DEffect(.degrees(rotationDegrees), axis: (0, 1, 0), perspective: 0.4)

            backFace
                .opacity(rotationDegrees >= 90 ? 1 : 0)
                // The back starts pre-mirrored so it reads correctly after the flip
                .rotation3DEffect(.degrees(rotationDegrees - 180), axis: (0, 1, 0), perspective: 0.4)
        }
        .contentShape(Rectangle())
        .onTapGesture { onFlip() }
        .accessibilityLabel(isFlipped
            ? "Resposta: \(back). Toque para ver a pergunta."
            : "Flashcard: \(front). Toque para revelar a resposta."
        )
        .onChange(of: isFlipped) { _, flipped in
            withAnimation(.easeInOut(duration: 0.5)) {
                rotationDegrees = flipped ? 180 : 0
            }
        }
    }

    // MARK: Front face (cyan theme)

    private var frontFace: some View {
        cardShell(borderColor: cyanBorder, glowColor: cyanGlow) {
            VStack(spacing: 0) {
                // Deck label pill
                pillLabel(text: deckTitle.uppercased(), textColor: VitaColors.accent,
                          bgColor: cyanPillBg, borderColor: cyanBorder)

                Spacer().frame(height: 20)

                // Question
                Text(front)
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity)

                Spacer()

                // "Tap to reveal" hint
                pillLabel(text: "TOQUE PARA REVELAR",
                          textColor: VitaColors.accent.opacity(0.6),
                          bgColor: cyanPillBg,
                          borderColor: .clear,
                          fontSize: 9)
            }
        }
    }

    // MARK: Back face (indigo theme)

    private var backFace: some View {
        cardShell(borderColor: indigoBorder, glowColor: indigoGlow) {
            VStack(spacing: 0) {
                // "RESPOSTA" pill
                pillLabel(text: "RESPOSTA", textColor: indigoAccent,
                          bgColor: indigoPillBg, borderColor: indigoBorder)

                Spacer().frame(height: 20)

                // Answer text
                Text(back)
                    .font(VitaTypography.bodyLarge)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
        }
    }

    // MARK: Card shell

    @ViewBuilder
    private func cardShell<Content: View>(
        borderColor: Color,
        glowColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .top) {
            // Base card
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(borderColor, lineWidth: 1)
                )
                // Top glow gradient overlay
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [glowColor, .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .frame(height: 120)
                }

            // Content
            VStack {
                content()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Pill label

    @ViewBuilder
    private func pillLabel(
        text: String,
        textColor: Color,
        bgColor: Color,
        borderColor: Color,
        fontSize: CGFloat = 10
    ) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .kerning(0.8)
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(bgColor)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(borderColor, lineWidth: 1))
    }
}
