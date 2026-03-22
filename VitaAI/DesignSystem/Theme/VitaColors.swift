import SwiftUI

// MARK: - VitaAI Gold Ambient Glass Design System
// DO NOT hardcode Color(hex:) here — all values must come from VitaTokens.
// Source of truth: packages/design-tokens/tokens.json → node generate.mjs

enum VitaColors {
    // Accent: Gold (ONLY accent color)
    static let accent        = VitaTokens.DarkColors.accent          // gold-400 primary
    static let accentDark    = VitaTokens.DarkColors.accentHover     // gold-500
    static let accentLight   = VitaTokens.PrimitiveColors.gold300    // gold-300
    static let accentSubtle  = VitaTokens.DarkColors.bgSubtle        // deep accent-tinted bg

    // Ambient light colors (for background radial gradients)
    static let ambientPrimary   = VitaTokens.DarkColors.accent          // gold-400
    static let ambientSecondary = VitaTokens.DarkColors.accentHover     // gold-500
    static let ambientTertiary  = VitaTokens.PrimitiveColors.gold600    // gold-600

    // Glow animation colors
    static let glowA = VitaTokens.DarkColors.accent                  // gold-400
    static let glowB = VitaTokens.PrimitiveColors.glowB              // warm gold glow
    static let glowC = VitaTokens.PrimitiveColors.glowC              // lighter gold glow

    // Surfaces — near-black with warm tint
    static let black           = VitaTokens.PrimitiveColors.black
    static let surface         = VitaTokens.DarkColors.bg
    static let surfaceElevated = VitaTokens.DarkColors.bgElevated
    static let surfaceCard     = VitaTokens.DarkColors.bgCard
    static let surfaceBorder   = VitaTokens.DarkColors.borderSurface  // warm-tinted border

    // Glass (fine-tuned opacities — no exact token, intentional)
    static let glassBg        = Color.white.opacity(0.025)
    static let glassBorder    = Color.white.opacity(0.04)
    static let glassHighlight = Color.white.opacity(0.06)

    // Text
    static let white         = VitaTokens.PrimitiveColors.white
    static let textPrimary   = VitaTokens.DarkColors.text
    static let textSecondary = VitaTokens.DarkColors.textSecondary
    static let textTertiary  = VitaTokens.DarkColors.textMuted

    // Semantic data colors
    static let dataGreen  = VitaTokens.PrimitiveColors.green500     // #22c55e
    static let dataRed    = VitaTokens.PrimitiveColors.red500       // #ef4444
    static let dataAmber  = VitaTokens.PrimitiveColors.amber500     // #f59e0b
    static let dataBlue   = VitaTokens.PrimitiveColors.blue400      // #60a5fa
    static let dataIndigo = VitaTokens.PrimitiveColors.indigo400    // #a78bfa (card back accent)

    // Gold (achievements & text)
    static let goldText = Color(red: 255/255, green: 240/255, blue: 214/255)  // #FFF0D6
    static let goldBarGradient = LinearGradient(
        colors: [
            Color(red: 200/255, green: 160/255, blue: 80/255).opacity(0.85),   // #C8A050
            Color(red: 176/255, green: 138/255, blue: 58/255).opacity(0.65)    // #B08A3A
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}
