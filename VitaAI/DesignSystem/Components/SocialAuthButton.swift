import SwiftUI

// MARK: - SocialAuthButton
//
// Pill-shaped sign-in button for social providers (Apple, Google).
// White-with-black for Apple (HIG-compliant Sign in with Apple branding),
// dark-glass for Google (with the OFFICIAL 4-color G logo asset, not SF Symbols).
//
// Both variants get the **vitaSoftGlow** halo modifier — a translucent
// white outer light that "transcends" the button edge. Inspired by Emergent's
// login screen — Rafael called it out as the gold-standard detail to adopt
// across the BYMAV app shell (Vita, Pixio, AURA, etc).
//
// The glow modifier is separate (`.vitaSoftGlow()`) so any other call-to-action
// surface (paywall CTAs, primary onboarding buttons) can opt into the same look.

enum SocialAuthProvider {
    case apple
    case google
}

struct SocialAuthButton: View {
    let provider: SocialAuthProvider
    let label: String
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView()
                        .tint(provider == .apple ? .black : .white)
                } else {
                    HStack(spacing: 12) {
                        icon
                        Text(label)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(textColor)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(strokeColor, lineWidth: 0.5)
            )
        }
        .disabled(isLoading)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.easeInOut(duration: 0.12), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        // Both providers now wear the strong halo — Google is the favored
        // primary path; equalizing keeps the pair balanced.
        .vitaSoftGlow(intensity: .strong)
    }

    @ViewBuilder
    private var icon: some View {
        switch provider {
        case .apple:
            Image(systemName: "apple.logo")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.black)
        case .google:
            Image("google-g")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 22)
        }
    }

    private var backgroundColor: Color {
        switch provider {
        case .apple: return .white
        case .google: return Color(red: 0.13, green: 0.13, blue: 0.15)
        }
    }

    private var textColor: Color {
        switch provider {
        case .apple: return .black
        case .google: return .white
        }
    }

    private var strokeColor: Color {
        switch provider {
        case .apple: return .clear
        case .google: return .white.opacity(0.08)
        }
    }
}

// MARK: - vitaSoftGlow modifier
//
// Translucent white halo around a CTA — the "Apple button glow" Rafael
// flagged as gold-standard. Two stacked shadows: a tight bright halo + a
// wider soft falloff. Designed to transcend the button silhouette.
//
// SHELL CANON 2026-04-26: every primary auth/CTA button across BYMAV apps
// (Vita iOS, Vita Android, Pixio iOS, Pixio Web, AURA) should adopt this
// halo for visual continuity. Android equivalent = `Modifier.softGlow()`.

enum VitaGlowIntensity {
    case medium
    case strong
}

private struct VitaSoftGlow: ViewModifier {
    let intensity: VitaGlowIntensity

    private var inner: (color: Color, radius: CGFloat) {
        switch intensity {
        case .strong: return (.white.opacity(0.45), 14)
        case .medium: return (.white.opacity(0.25), 12)
        }
    }

    private var outer: (color: Color, radius: CGFloat) {
        switch intensity {
        case .strong: return (.white.opacity(0.30), 36)
        case .medium: return (.white.opacity(0.18), 28)
        }
    }

    func body(content: Content) -> some View {
        content
            .shadow(color: inner.color, radius: inner.radius, x: 0, y: 0)
            .shadow(color: outer.color, radius: outer.radius, x: 0, y: 0)
    }
}

extension View {
    /// White translucent halo that transcends the view's silhouette.
    /// Use on primary CTAs (sign-in buttons, paywall confirm, etc.).
    func vitaSoftGlow(intensity: VitaGlowIntensity = .medium) -> some View {
        modifier(VitaSoftGlow(intensity: intensity))
    }
}
