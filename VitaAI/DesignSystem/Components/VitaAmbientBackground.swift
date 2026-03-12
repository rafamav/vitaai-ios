import SwiftUI

// MARK: - VitaAmbientBackground
// Gold glassmorphism ambient light system.
// Background: #0A0A0F (deep near-black) with three gold radial glows.
// Matches mockup vita-app.html: bg #0a080e + gold ambient pulses.

struct VitaAmbientBackground<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Deep near-black base (#0A0A0F — from mockup)
            VitaColors.surface
                .ignoresSafeArea()

            Canvas { context, size in
                // Light 1: top-left, primary gold glow
                // Matches mockup radial gradient warm gold, opacity ~0.11
                let center1 = CGPoint(x: size.width * 0.12, y: size.height * 0.10)
                let gradient1 = Gradient(colors: [
                    VitaColors.ambientPrimary.opacity(0.10),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center1.x - size.width * 0.65,
                            y: center1.y - size.width * 0.65,
                            width: size.width * 1.30,
                            height: size.width * 1.30
                        )),
                        with: .radialGradient(
                            gradient1,
                            center: center1,
                            startRadius: 0,
                            endRadius: size.width * 0.65
                        )
                    )
                }

                // Light 2: bottom-right, warm amber-gold
                // Matches mockup bottom ambient, slightly warmer
                let center2 = CGPoint(x: size.width * 0.88, y: size.height * 0.80)
                let gradient2 = Gradient(colors: [
                    VitaColors.ambientSecondary.opacity(0.07),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center2.x - size.width * 0.55,
                            y: center2.y - size.width * 0.55,
                            width: size.width * 1.10,
                            height: size.width * 1.10
                        )),
                        with: .radialGradient(
                            gradient2,
                            center: center2,
                            startRadius: 0,
                            endRadius: size.width * 0.55
                        )
                    )
                }

                // Light 3: center, deep gold fill (very subtle)
                let center3 = CGPoint(x: size.width * 0.50, y: size.height * 0.38)
                let gradient3 = Gradient(colors: [
                    VitaColors.ambientTertiary.opacity(0.04),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center3.x - size.width * 0.70,
                            y: center3.y - size.width * 0.70,
                            width: size.width * 1.40,
                            height: size.width * 1.40
                        )),
                        with: .radialGradient(
                            gradient3,
                            center: center3,
                            startRadius: 0,
                            endRadius: size.width * 0.70
                        )
                    )
                }
            }
            .ignoresSafeArea()

            content
        }
    }
}
