// Auto-generated from design-tokens.json — DO NOT EDIT
// Brand: vita-gold | Generated: 2026-04-30
// Source: agent-brain/design-tokens.json
// Regenerator: agent-brain/scripts/generate-tokens.mjs

import SwiftUI

// MARK: - Vita Design Tokens

enum VitaTokens {

    // MARK: Dark Colors (Gold Glassmorphism)
    enum DarkColors {
        static let bg = Color(red: 0.031, green: 0.024, blue: 0.039) // #08060a
        static let bgCard = Color(red: 0.047, green: 0.035, blue: 0.027) // #0c0907
        static let bgElevated = Color(red: 0.055, green: 0.043, blue: 0.031) // #0e0b08
        static let bgHover = Color(red: 0.071, green: 0.055, blue: 0.039) // #120e0a
        static let bgActive = Color(red: 0.094, green: 0.075, blue: 0.055) // #18130e
        static let bgSubtle = Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.08) // #c8a05014
        static let borderSurface = Color(red: 1.000, green: 0.941, blue: 0.839).opacity(0.04) // #fff0d60a
        static let text = Color(red: 1.000, green: 0.988, blue: 0.973).opacity(0.96) // #fffcf8f5
        static let textSecondary = Color(red: 1.000, green: 0.941, blue: 0.843).opacity(0.40) // #fff0d766
        static let textMuted = Color(red: 1.000, green: 0.941, blue: 0.843).opacity(0.25) // #fff0d740
        static let dataBlue = Color(red: 0.376, green: 0.647, blue: 0.980) // #60a5fa
        static let dataGreen = Color(red: 0.290, green: 0.871, blue: 0.502) // #4ade80
        static let dataAmber = Color(red: 0.984, green: 0.749, blue: 0.141) // #fbbf24
        static let dataRed = Color(red: 0.973, green: 0.443, blue: 0.443) // #f87171
        static let accent = Color(red: 0.784, green: 0.627, blue: 0.314) // #c8a050
        static let accentHover = Color(red: 1.000, green: 0.784, blue: 0.471) // #ffc878
        static let accentSubtle = Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.08) // #c8a05014
        static let border = Color(red: 1.000, green: 0.784, blue: 0.471).opacity(0.08) // #ffc87814
        static let borderHover = Color(red: 1.000, green: 0.784, blue: 0.471).opacity(0.14) // #ffc87824
        static let borderActive = Color(red: 1.000, green: 0.784, blue: 0.471).opacity(0.20) // #ffc87833
    }

    // MARK: Light Colors
    enum LightColors {
        static let bg = Color(red: 0.980, green: 0.976, blue: 0.965) // #faf9f6
        static let bgCard = Color(red: 1.000, green: 0.996, blue: 0.988) // #fffefc
        static let bgElevated = Color(red: 0.961, green: 0.953, blue: 0.941) // #f5f3f0
        static let bgHover = Color(red: 0.941, green: 0.933, blue: 0.918) // #f0eeea
        static let bgActive = Color(red: 0.910, green: 0.898, blue: 0.878) // #e8e5e0
        static let border = Color(red: 0.898, green: 0.878, blue: 0.843) // #e5e0d7
        static let borderHover = Color(red: 0.820, green: 0.796, blue: 0.753) // #d1cbc0
        static let borderActive = Color(red: 0.612, green: 0.588, blue: 0.545) // #9c968b
        static let text = Color(red: 0.122, green: 0.110, blue: 0.094) // #1f1c18
        static let textSecondary = Color(red: 0.420, green: 0.400, blue: 0.365) // #6b665d
        static let textMuted = Color(red: 0.612, green: 0.588, blue: 0.545) // #9c968b
        static let dataBlue = Color(red: 0.231, green: 0.510, blue: 0.965) // #3b82f6
        static let dataGreen = Color(red: 0.133, green: 0.773, blue: 0.369) // #22c55e
        static let dataAmber = Color(red: 0.961, green: 0.620, blue: 0.043) // #f59e0b
        static let dataRed = Color(red: 0.937, green: 0.267, blue: 0.267) // #ef4444
        static let accent = Color(red: 0.706, green: 0.549, blue: 0.235) // #b48c3c
        static let accentHover = Color(red: 0.627, green: 0.471, blue: 0.188) // #a07830
        static let accentSubtle = Color(red: 0.784, green: 0.627, blue: 0.314).opacity(0.06) // #c8a0500f
    }

    // MARK: Primitive Colors
    enum PrimitiveColors {
        static let gold300 = Color(red: 1.000, green: 0.863, blue: 0.627) // #ffdca0
        static let gold400 = Color(red: 0.784, green: 0.627, blue: 0.314) // #c8a050
        static let gold500 = Color(red: 1.000, green: 0.784, blue: 0.471) // #ffc878
        static let gold600 = Color(red: 0.549, green: 0.392, blue: 0.196) // #8c6432
        static let gold700 = Color(red: 0.784, green: 0.608, blue: 0.275) // #c89b46
        static let cyan300 = Color(red: 0.404, green: 0.910, blue: 0.976) // #67e8f9
        static let cyan400 = Color(red: 0.133, green: 0.827, blue: 0.933) // #22d3ee
        static let cyan500 = Color(red: 0.024, green: 0.714, blue: 0.831) // #06b6d4
        static let cyan600 = Color(red: 0.031, green: 0.569, blue: 0.698) // #0891b2
        static let orange400 = Color(red: 0.984, green: 0.573, blue: 0.235) // #fb923c
        static let orange500 = Color(red: 0.976, green: 0.451, blue: 0.086) // #f97316
        static let orange600 = Color(red: 0.918, green: 0.345, blue: 0.047) // #ea580c
        static let orange700 = Color(red: 0.761, green: 0.255, blue: 0.047) // #c2410c
        static let blue400 = Color(red: 0.376, green: 0.647, blue: 0.980) // #60a5fa
        static let blue500 = Color(red: 0.231, green: 0.510, blue: 0.965) // #3b82f6
        static let green400 = Color(red: 0.290, green: 0.871, blue: 0.502) // #4ade80
        static let green500 = Color(red: 0.133, green: 0.773, blue: 0.369) // #22c55e
        static let amber400 = Color(red: 0.984, green: 0.749, blue: 0.141) // #fbbf24
        static let amber500 = Color(red: 0.961, green: 0.620, blue: 0.043) // #f59e0b
        static let red400 = Color(red: 0.973, green: 0.443, blue: 0.443) // #f87171
        static let red500 = Color(red: 0.937, green: 0.267, blue: 0.267) // #ef4444
        static let indigo400 = Color(red: 0.655, green: 0.545, blue: 0.980) // #a78bfa
        static let teal400 = Color(red: 0.235, green: 0.706, blue: 0.667) // #3cb4aa
        static let glowA = Color(red: 1.000, green: 0.753, blue: 0.373) // #ffc05f
        static let glowB = Color(red: 1.000, green: 0.784, blue: 0.471) // #ffc878
        static let glowC = Color(red: 0.784, green: 0.627, blue: 0.314) // #c8a050
        static let white = Color(red: 1.000, green: 1.000, blue: 1.000) // #ffffff
        static let black = Color(red: 0.000, green: 0.000, blue: 0.000) // #000000
    }

    // MARK: Spacing (CGFloat in points)
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let _2xl: CGFloat = 24
        static let _3xl: CGFloat = 32
        static let _4xl: CGFloat = 48
    }

    // MARK: Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 9999
    }

    // MARK: Elevation (shadow radius)
    enum Elevation {
        static let none: CGFloat = 0
        static let xs: CGFloat = 1
        static let sm: CGFloat = 2
        static let md: CGFloat = 4
        static let lg: CGFloat = 8
        static let xl: CGFloat = 12
        static let _2xl: CGFloat = 24
    }

    // MARK: Typography
    enum Typography {
        static let fontSizeXs: CGFloat = 10
        static let fontSizeSm: CGFloat = 12
        static let fontSizeBase: CGFloat = 13
        static let fontSizeMd: CGFloat = 14
        static let fontSizeLg: CGFloat = 16
        static let fontSizeXl: CGFloat = 20
        static let fontSize2xl: CGFloat = 24
        static let fontSize3xl: CGFloat = 30
        static let fontWeightNormal: CGFloat = 400
        static let fontWeightMedium: CGFloat = 500
        static let fontWeightSemibold: CGFloat = 600
        static let fontWeightBold: CGFloat = 700
        static let letterSpacingTight: CGFloat = -0.4
        static let letterSpacingNormal: CGFloat = 0
        static let letterSpacingWide: CGFloat = 0.5
        static let fontFamilySans: String = "Space Grotesk"
        static let fontFamilyMono: String = "JetBrains Mono"
        static let fontFamilyIosBody: String = "SF Pro Text"
        static let fontFamilyIosDisplay: String = "SF Pro Display"
    }

    // MARK: Animation
    enum Animation {
        static let durationFast: Double = 0.15
        static let durationNormal: Double = 0.3
        static let durationSlow: Double = 0.5
        static let easeOut: String = "cubic-bezier(0.33, 1, 0.68, 1)"
    }

    // MARK: Components
    enum Components {
        enum RatingButton {
            static let minHeight: CGFloat = 56
            static let radius: CGFloat = 14
            static let fontSize: CGFloat = 12
            static let iconSize: CGFloat = 16
            static let bgAlpha: CGFloat = 0.08
            static let borderAlpha: CGFloat = 0.18
        }
        enum GlassCard {
            static let radius: CGFloat = 16
            static let bgAlpha: CGFloat = 0.92
            static let borderAlpha: CGFloat = 0.34
            static let innerLightAlpha: CGFloat = 0.16
        }
        enum ChatBubble {
            static let radius: CGFloat = 16
            static let maxWidth: String = "85%"
        }
        enum Flashcard {
            static let flipDuration: CGFloat = 0.5
            static let perspective: CGFloat = 1200
            static let frontBorderAlpha: CGFloat = 0.12
            static let backBorderAlpha: CGFloat = 0.12
            static let blur: CGFloat = 16
        }
        enum Chip {
            static let paddingV: CGFloat = 8
            static let paddingH: CGFloat = 14
            static let radius: CGFloat = 9999
            static let fontSize: CGFloat = 11
            static let fontWeight: CGFloat = 500
        }
        enum DeckPill {
            static let paddingV: CGFloat = 4
            static let paddingH: CGFloat = 12
            static let radius: CGFloat = 9999
            static let fontSize: CGFloat = 10
            static let fontWeight: CGFloat = 600
            static let letterSpacing: CGFloat = 0.8
        }
    }

}
