import SwiftUI

// MARK: - VitaGlassCard
// Gold glassmorphism card — matches mockup .glass class:
//   background: rgba(255,255,255,0.04) + ultraThinMaterial blur
//   backdrop-filter: blur(50px) saturate(1.4)
//   border: 1px solid rgba(255,255,255,0.07)
//   border-radius: 24px (mockup spec)
//   box-shadow: 0 16px 48px rgba(0,0,0,0.25), inset 0 1px 0 rgba(255,255,255,0.07)

struct VitaGlassCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            // Correct order: tint above material (matches mockup .glass rgba(255,255,255,0.04))
            // SwiftUI stacks: .background(A).background(B) → rendering bottom to top: B, A, content
            // So: tint=A (above material), material=B (deepest, blurs ambient bg)
            .background(Color.white.opacity(0.04))
            // ultraThinMaterial applies iOS blur (~50px equivalent) + saturation boost
            .background(.ultraThinMaterial)
            // border-radius: 24px from mockup .glass spec
            .clipShape(RoundedRectangle(cornerRadius: 24))
            // Border: rgba(255,255,255,0.07) from mockup
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
            // Inset top highlight: inset 0 1px 0 rgba(255,255,255,0.07)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.08), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.top, 0.5)
            }
            // box-shadow: 0 16px 48px rgba(0,0,0,0.20) from mockup .glass
            .shadow(color: .black.opacity(0.20), radius: 24, x: 0, y: 12)
    }
}

// MARK: - VitaGoldCard
// Gold-accented variant — for selected/featured items.
// Matches mockup active states: border rgba(200,160,80,0.15-0.22)

struct VitaGoldCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            // Correct order: tint above material
            .background(VitaColors.glassBg)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(VitaColors.goldBorder, lineWidth: 1.5)
            )
            .overlay(alignment: .top) {
                // Gold top-edge shimmer
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, VitaColors.accentLight.opacity(0.10), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.top, 0.5)
            }
            .shadow(color: VitaColors.accent.opacity(0.10), radius: 20, x: 0, y: 10)
            .shadow(color: .black.opacity(0.20), radius: 24, x: 0, y: 12)
    }
}
