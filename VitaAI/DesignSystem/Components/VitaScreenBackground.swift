import SwiftUI

// MARK: - VitaScreenBackground
// Warm dark background with subtle gold ambient radials.
// Apply to ALL screens via .vitaScreenBg() modifier.
// Matches mockup app-shell-frame CSS.

struct VitaScreenBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                VitaScreenBg()
            )
    }

    private func drawGlow(ctx: inout GraphicsContext, size: CGSize, cx: Double, cy: Double, r: Double, color: Color, alpha: Double) {
        let center = CGPoint(x: size.width * cx, y: size.height * cy)
        let radius = size.width * r
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(Gradient(colors: [color.opacity(alpha), .clear]), center: center, startRadius: 0, endRadius: radius)
        )
    }
}

extension View {
    func vitaScreenBg() -> some View {
        modifier(VitaScreenBackgroundModifier())
    }
}

// MARK: - VitaScreenBg view (for use inside ZStack as a child view)
// Use this instead of VitaColors.surface.ignoresSafeArea()

struct VitaScreenBg: View {
    var body: some View {
        ZStack {
            VitaColors.surface

            // Background image (same as main app shell)
            Image("fundo-dashboard")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .scaleEffect(1.32)
                .blur(radius: 4)
                .saturation(0.96)

            // Dark overlay — subtle to keep starry texture visible
            LinearGradient(
                colors: [
                    Color(red: 0.024, green: 0.016, blue: 0.016).opacity(0.28),
                    Color(red: 0.024, green: 0.016, blue: 0.016).opacity(0.50)
                ],
                startPoint: .top, endPoint: .bottom
            )

            // Gold ambient radials
            Canvas { context, size in
                let gold = Color(red: 1.0, green: 0.753, blue: 0.373)
                for (cx, cy, r, a) in [(0.08, 0.12, 0.45, 0.10), (0.92, 0.12, 0.45, 0.10), (0.5, 0.95, 0.5, 0.06)] as [(Double, Double, Double, Double)] {
                    let center = CGPoint(x: size.width * cx, y: size.height * cy)
                    let radius = size.width * r
                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                        with: .radialGradient(Gradient(colors: [gold.opacity(a), .clear]), center: center, startRadius: 0, endRadius: radius)
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}
