import SwiftUI

// MARK: - VitaGlassCard
// Gold glassmorphism card — matches mockup .glass class:
//   background: rgba(255,255,255,0.04)
//   backdrop-filter: blur(50px) saturate(1.4)
//   border: 1px solid rgba(255,255,255,0.07)
//   box-shadow: 0 16px 48px rgba(0,0,0,0.2), inset 0 1px 0 rgba(255,255,255,0.07)

struct VitaGlassCard<Content: View>: View {
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
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
            .overlay(alignment: .top) {
                // Top-edge highlight — inset 0 1px 0 rgba(255,255,255,0.07)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.clear, VitaColors.glassHighlight, .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                    .padding(.horizontal, 24)
            }
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
            }
            .shadow(color: VitaColors.accent.opacity(0.08), radius: 16, x: 0, y: 8)
            .shadow(color: .black.opacity(0.20), radius: 20, x: 0, y: 10)
    }
}
