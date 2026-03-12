import SwiftUI

// MARK: - VitaAI Gold Glassmorphism Design System
// Theme: Gold — #C8A050 primary accent, #0A0A0F deep background
// DO NOT hardcode Color(hex:) here — all values must come from VitaTokens.
// Source of truth: packages/design-tokens/tokens.json → node generate.mjs
// Updated: 2026-03-11 — migrated from cyan to gold per mockup vita-app.html

enum VitaColors {
    // MARK: - Accent: Gold (primary brand color)
    static let accent        = VitaTokens.DarkColors.accent          // gold-400 #C8A050
    static let accentDark    = VitaTokens.DarkColors.accentHover     // gold-500 #B88600
    static let accentLight   = VitaTokens.PrimitiveColors.gold300    // gold-300 #DCBC74
    static let accentSubtle  = VitaTokens.DarkColors.bgSubtle        // gold-tinted subtle bg

    // MARK: - Ambient glow (radial background lights)
    static let ambientPrimary   = VitaTokens.DarkColors.accent          // gold-400
    static let ambientSecondary = VitaTokens.PrimitiveColors.goldWarm   // warm gold-orange
    static let ambientTertiary  = VitaTokens.DarkColors.accentHover     // gold-500 deep

    // MARK: - Glow animation colors
    static let glowA = VitaTokens.DarkColors.accent               // gold-400
    static let glowB = VitaTokens.PrimitiveColors.glowB           // warm gold glow
    static let glowC = VitaTokens.PrimitiveColors.glowC           // amber-gold glow

    // MARK: - Surfaces — deep near-black (#0A0A0F), slightly warm
    static let black           = VitaTokens.PrimitiveColors.black
    static let surface         = VitaTokens.DarkColors.bg
    static let surfaceElevated = VitaTokens.DarkColors.bgElevated
    static let surfaceCard     = VitaTokens.DarkColors.bgCard
    static let surfaceBorder   = VitaTokens.DarkColors.borderSurface

    // MARK: - Glass (ultraThinMaterial + manual fallback)
    // glassBg: rgba(255,255,255,0.04) from mockup .glass class
    static let glassBg        = Color.white.opacity(0.04)
    // glassBorder: rgba(255,255,255,0.07) from mockup
    static let glassBorder    = Color.white.opacity(0.07)
    // glassHighlight: inset top-edge shimmer
    static let glassHighlight = Color.white.opacity(0.07)
    // goldBorder: gold-tinted border for active/selected elements
    static let goldBorder     = VitaTokens.DarkColors.accent.opacity(0.18)
    // goldBorderActive: stronger gold border
    static let goldBorderActive = VitaTokens.DarkColors.accent.opacity(0.30)

    // MARK: - Text
    static let white         = VitaTokens.PrimitiveColors.white
    static let textPrimary   = VitaTokens.DarkColors.text
    static let textSecondary = VitaTokens.DarkColors.textSecondary
    static let textTertiary  = VitaTokens.DarkColors.textMuted
    // goldText: rgba(255,220,160,0.9) from mockup ob-cta/ob-stat-num
    static let goldText      = VitaTokens.PrimitiveColors.goldLight.opacity(0.90)

    // MARK: - Semantic data colors (unchanged — pure data viz)
    static let dataGreen  = VitaTokens.PrimitiveColors.green500     // #22c55e
    static let dataRed    = VitaTokens.PrimitiveColors.red500       // #ef4444
    static let dataAmber  = VitaTokens.PrimitiveColors.amber500     // #f59e0b
    static let dataBlue   = VitaTokens.PrimitiveColors.blue400      // #60a5fa
    static let dataIndigo = VitaTokens.PrimitiveColors.indigo400    // #a78bfa (card back accent)

    // MARK: - Gold gradient helpers (for buttons, bars, active states)
    /// Gradient matching mockup .ob-cta / .continue-cta
    static let goldGradient = LinearGradient(
        colors: [
            VitaTokens.DarkColors.accent.opacity(0.85),
            VitaTokens.PrimitiveColors.goldWarm.opacity(0.75)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Subtle gold gradient for progress bars / fill indicators
    static let goldBarGradient = LinearGradient(
        colors: [
            VitaTokens.DarkColors.accent.opacity(0.55),
            VitaTokens.PrimitiveColors.goldWarm.opacity(0.40)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}
