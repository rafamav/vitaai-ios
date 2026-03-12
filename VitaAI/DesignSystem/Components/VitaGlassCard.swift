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
            // ultraThinMaterial applies iOS blur (~50px equivalent) + saturation boost
            .background(.ultraThinMaterial)
            // Tint layer: rgba(255,255,255,0.04) from mockup .glass
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            // Border: rgba(255,255,255,0.07) from mockup
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            )
            // Inset top highlight: inset 0 1px 0 rgba(255,255,255,0.07)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.clear)
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
            }
            // box-shadow: 0 16px 48px rgba(0,0,0,0.25)
            .shadow(color: .black.opacity(0.25), radius: 28, x: 0, y: 14)
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
            .background(.ultraThinMaterial)
            .background(VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
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
            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
    }
}
