import SwiftUI

// MARK: - VitaAI Frosted Gold Glass Design System
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

    // Glow animation colors (warm gold tones)
    static let glowA = VitaTokens.DarkColors.accent                  // gold-400
    static let glowB = VitaTokens.PrimitiveColors.gold300             // gold-300
    static let glowC = VitaTokens.PrimitiveColors.gold500             // gold-500

    // Surfaces — warm brown-black
    static let black           = VitaTokens.PrimitiveColors.black
    static let surface         = VitaTokens.DarkColors.bg
    static let surfaceElevated = VitaTokens.DarkColors.bgElevated
    static let surfaceCard     = VitaTokens.DarkColors.bgCard
    static let surfaceBorder   = VitaTokens.DarkColors.borderSurface

    // Glass (token-driven opacities from Components.GlassCard)
    static let glassBg        = Color.white.opacity(VitaTokens.Components.GlassCard.bgAlpha)       // 0.05
    static let glassBorder    = Color.white.opacity(VitaTokens.Components.GlassCard.borderAlpha)    // 0.07
    static let glassHighlight = Color.white.opacity(0.06)

    // Text
    static let white         = VitaTokens.PrimitiveColors.white
    static let textPrimary   = VitaTokens.DarkColors.text            // white 70%
    static let textSecondary = VitaTokens.DarkColors.textSecondary   // white 25%
    static let textTertiary  = VitaTokens.DarkColors.textMuted       // white 15%

    // Semantic data colors
    static let dataGreen  = VitaTokens.PrimitiveColors.green500     // #22c55e
    static let dataRed    = VitaTokens.PrimitiveColors.red500       // #ef4444
    static let dataAmber  = VitaTokens.PrimitiveColors.amber500     // #f59e0b
    static let dataBlue   = VitaTokens.PrimitiveColors.blue400      // #60a5fa
    static let dataIndigo = VitaTokens.PrimitiveColors.indigo400    // #a78bfa (card back accent)
}
