import SwiftUI

// MARK: - VitaAI Cyan Ambient Glass Design System
// DO NOT hardcode Color(hex:) here — all values must come from VitaTokens.
// Source of truth: packages/design-tokens/tokens.json → node generate.mjs

enum VitaColors {
    // Accent: Cyan (ONLY accent color)
    static let accent        = VitaTokens.DarkColors.accent          // cyan-400 primary
    static let accentDark    = VitaTokens.DarkColors.accentHover     // cyan-500
    static let accentLight   = VitaTokens.PrimitiveColors.cyan300    // cyan-300
    static let accentSubtle  = VitaTokens.DarkColors.bgSubtle        // deep accent-tinted bg

    // Ambient light colors (for background radial gradients)
    static let ambientPrimary   = VitaTokens.DarkColors.accent          // cyan-400
    static let ambientSecondary = VitaTokens.DarkColors.accentHover     // cyan-500
    static let ambientTertiary  = VitaTokens.PrimitiveColors.cyan600    // cyan-600

    // Glow animation colors
    static let glowA = VitaTokens.DarkColors.accent                  // cyan-400
    static let glowB = VitaTokens.PrimitiveColors.glowB              // #00e5ff
    static let glowC = VitaTokens.PrimitiveColors.glowC              // #40c4ff

    // Surfaces — near-black with cool tint
    static let black           = VitaTokens.PrimitiveColors.black
    static let surface         = VitaTokens.DarkColors.bg
    static let surfaceElevated = VitaTokens.DarkColors.bgElevated
    static let surfaceCard     = VitaTokens.DarkColors.bgCard
    static let surfaceBorder   = VitaTokens.DarkColors.borderSurface  // #1A2028

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
}
