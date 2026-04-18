import SwiftUI

/// Color palette shared across a StudySuite screen (hero, CTA, chips, recents).
///
/// Each of the four tools on the dashboard has a signature colour:
///   Questões   → laranja/âmbar (cérebro dourado)
///   Flashcards → roxo/magenta (coração anatómico)
///   Simulados  → azul elétrico (silhueta + escudo)
///   Transcrição → teal ciano (microfone + onda)
///
/// The shell screens reuse the same silhouette (hero + CTA + chips + recent
/// sessions) but take on the theme colour so the four pages feel connected
/// to their dashboard entry point rather than looking like identical gold
/// clones.
struct StudyShellTheme {
    /// Dominant hue used for the big headline number, chip selection, CTA
    /// gradient, and session card accents.
    let primary: Color
    /// Lighter tint (highlights, inner glows, eyebrow text).
    let primaryLight: Color
    /// Muted tint (borders, dividers, low-opacity motif).
    let primaryMuted: Color
    /// Top of the hero surface gradient (slight warm/cool lift).
    let surfaceTop: Color
    /// Bottom of the hero surface gradient (near-black, same hue family).
    let surfaceBottom: Color
    /// Colour of the radial accent glow in the top-right of the hero.
    let glow: Color
    /// SF Symbol used as the decorative motif in the hero top-right.
    let motifSymbol: String
    /// Short label for the tab (used by the hero eyebrow).
    let eyebrow: String

    // MARK: - Factory per tool

    static let questoes = StudyShellTheme(
        primary: Color(red: 1.00, green: 0.54, blue: 0.24),
        primaryLight: Color(red: 1.00, green: 0.73, blue: 0.48),
        primaryMuted: Color(red: 1.00, green: 0.48, blue: 0.20).opacity(0.35),
        surfaceTop: Color(red: 0.14, green: 0.09, blue: 0.035),
        surfaceBottom: Color(red: 0.055, green: 0.035, blue: 0.015),
        glow: Color(red: 1.00, green: 0.58, blue: 0.28),
        motifSymbol: "brain.head.profile",
        eyebrow: "Quest\u{f5}es"
    )

    static let flashcards = StudyShellTheme(
        primary: Color(red: 0.71, green: 0.42, blue: 1.00),
        primaryLight: Color(red: 0.84, green: 0.63, blue: 1.00),
        primaryMuted: Color(red: 0.71, green: 0.42, blue: 1.00).opacity(0.35),
        surfaceTop: Color(red: 0.10, green: 0.06, blue: 0.18),
        surfaceBottom: Color(red: 0.045, green: 0.025, blue: 0.085),
        glow: Color(red: 0.80, green: 0.48, blue: 1.00),
        motifSymbol: "rectangle.on.rectangle",
        eyebrow: "Flashcards"
    )

    static let simulados = StudyShellTheme(
        primary: Color(red: 0.26, green: 0.64, blue: 1.00),
        primaryLight: Color(red: 0.50, green: 0.77, blue: 1.00),
        primaryMuted: Color(red: 0.26, green: 0.64, blue: 1.00).opacity(0.35),
        surfaceTop: Color(red: 0.03, green: 0.10, blue: 0.22),
        surfaceBottom: Color(red: 0.015, green: 0.045, blue: 0.115),
        glow: Color(red: 0.42, green: 0.76, blue: 1.00),
        motifSymbol: "doc.text.magnifyingglass",
        eyebrow: "Simulados"
    )

    static let transcricao = StudyShellTheme(
        primary: Color(red: 0.25, green: 0.85, blue: 0.76),
        primaryLight: Color(red: 0.50, green: 0.92, blue: 0.85),
        primaryMuted: Color(red: 0.25, green: 0.85, blue: 0.76).opacity(0.35),
        surfaceTop: Color(red: 0.025, green: 0.14, blue: 0.13),
        surfaceBottom: Color(red: 0.01, green: 0.065, blue: 0.06),
        glow: Color(red: 0.38, green: 0.92, blue: 0.82),
        motifSymbol: "waveform",
        eyebrow: "Transcri\u{e7}\u{e3}o"
    )
}

// MARK: - Shared CTA button applying the theme gradient + inner highlight

struct StudyShellCTA: View {
    let title: String
    let theme: StudyShellTheme
    let action: () -> Void
    var systemImage: String? = nil

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.1)
            }
            .foregroundStyle(theme.primaryLight.opacity(0.98))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                ZStack {
                    // 1. Glass base — real translucency
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.ultraThinMaterial)
                    // 2. Subtle theme tint on top (low opacity so it reads as a hue wash, not a solid fill)
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.primary.opacity(0.32),
                                    theme.primary.opacity(0.18),
                                    theme.primary.opacity(0.10),
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(alignment: .top) {
                // Top inner highlight — overhead light simulation
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.18), .clear],
                            startPoint: .top, endPoint: .init(x: 0.5, y: 0.20)
                        )
                    )
                    .frame(height: 10)
                    .padding(.horizontal, 1)
                    .allowsHitTesting(false)
            }
            .overlay(
                // Thin gradient stroke — liquid-glass rim, low contrast
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                theme.primaryLight.opacity(0.45),
                                theme.primary.opacity(0.08),
                                theme.primaryLight.opacity(0.22),
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.75
                    )
            )
            .shadow(color: theme.primary.opacity(0.18), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }
}
