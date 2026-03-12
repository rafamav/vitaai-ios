import SwiftUI

// MARK: - VitaAmbientBackground
// Gold glassmorphism ambient light system.
// Background: #08060A (deep warm near-black) with rich gold radial glows.
// Uses background image if available (vita-background), otherwise falls back to pure gradient.
// Matches mockup vita-app.html: bg #08060a + background image + gold ambient overlays.

struct VitaAmbientBackground<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            // Deep near-black base (#0A0A0F — matches mockup: Color(0x0A0A0F))
            Color(red: 0.039, green: 0.039, blue: 0.059) // #0A0A0F
                .ignoresSafeArea()

            // Background image (vita-background.png — same as mockup img/00_5de63ca93fec.jpg)
            // This is the KEY layer that makes glassmorphism visible and premium.
            // Without it, glass cards look plain grey in dark mode.
            if UIImage(named: "vita-background") != nil {
                Image("vita-background")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.55) // Blend at 55% so gold glows layer on top
            }

            // Gold radial glow overlays on top of the background image
            Canvas { context, size in
                // ── Light 1: TOP-LEFT dominant gold glow — THE HERO LIGHT ──
                // Bold and visible so glass cards "float" over it.
                let center1 = CGPoint(x: size.width * 0.08, y: size.height * 0.12)
                let gradient1 = Gradient(colors: [
                    VitaColors.ambientPrimary.opacity(0.38),  // stronger core
                    VitaColors.ambientPrimary.opacity(0.22),  // mid spread
                    VitaColors.ambientPrimary.opacity(0.08),  // fade
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center1.x - size.width * 0.85,
                            y: center1.y - size.width * 0.85,
                            width: size.width * 1.70,
                            height: size.width * 1.70
                        )),
                        with: .radialGradient(
                            gradient1,
                            center: center1,
                            startRadius: 0,
                            endRadius: size.width * 0.85
                        )
                    )
                }

                // ── Light 2: BOTTOM-RIGHT warm amber-gold counter-light ──
                let center2 = CGPoint(x: size.width * 0.90, y: size.height * 0.78)
                let gradient2 = Gradient(colors: [
                    VitaColors.ambientSecondary.opacity(0.28),
                    VitaColors.ambientSecondary.opacity(0.14),
                    VitaColors.ambientSecondary.opacity(0.04),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center2.x - size.width * 0.70,
                            y: center2.y - size.width * 0.70,
                            width: size.width * 1.40,
                            height: size.width * 1.40
                        )),
                        with: .radialGradient(
                            gradient2,
                            center: center2,
                            startRadius: 0,
                            endRadius: size.width * 0.70
                        )
                    )
                }

                // ── Light 3: TOP-CENTER header halo — makes TopBar area feel premium ──
                let center3 = CGPoint(x: size.width * 0.50, y: size.height * 0.00)
                let gradient3 = Gradient(colors: [
                    VitaColors.ambientPrimary.opacity(0.25),
                    VitaColors.ambientSecondary.opacity(0.12),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center3.x - size.width * 0.70,
                            y: center3.y - size.width * 0.20,
                            width: size.width * 1.40,
                            height: size.width * 0.90
                        )),
                        with: .radialGradient(
                            gradient3,
                            center: center3,
                            startRadius: 0,
                            endRadius: size.width * 0.70
                        )
                    )
                }

                // ── Light 4: MID-LEFT gold wash — fills the content area ──
                let center4 = CGPoint(x: size.width * 0.20, y: size.height * 0.50)
                let gradient4 = Gradient(colors: [
                    VitaColors.ambientPrimary.opacity(0.18),
                    VitaColors.ambientPrimary.opacity(0.06),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center4.x - size.width * 0.85,
                            y: center4.y - size.width * 0.85,
                            width: size.width * 1.70,
                            height: size.width * 1.70
                        )),
                        with: .radialGradient(
                            gradient4,
                            center: center4,
                            startRadius: 0,
                            endRadius: size.width * 0.85
                        )
                    )
                }

                // ── Light 5: BOTTOM-CENTER deep warmth — base glow for bottom scroll ──
                let center5 = CGPoint(x: size.width * 0.50, y: size.height * 0.95)
                let gradient5 = Gradient(colors: [
                    VitaColors.ambientSecondary.opacity(0.16),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center5.x - size.width * 0.60,
                            y: center5.y - size.width * 0.60,
                            width: size.width * 1.20,
                            height: size.width * 1.20
                        )),
                        with: .radialGradient(
                            gradient5,
                            center: center5,
                            startRadius: 0,
                            endRadius: size.width * 0.60
                        )
                    )
                }

                // ── Light 6: UPPER-RIGHT INDIGO/PURPLE — adds rich blue-purple depth ──
                // This is the "rico azul/roxo/indigo" accent the mockup dark bg radiates.
                let center6 = CGPoint(x: size.width * 0.78, y: size.height * 0.18)
                let gradient6 = Gradient(colors: [
                    Color(red: 0.28, green: 0.14, blue: 0.58).opacity(0.18),
                    Color(red: 0.22, green: 0.11, blue: 0.46).opacity(0.09),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center6.x - size.width * 0.65,
                            y: center6.y - size.width * 0.65,
                            width: size.width * 1.30,
                            height: size.width * 1.30
                        )),
                        with: .radialGradient(
                            gradient6,
                            center: center6,
                            startRadius: 0,
                            endRadius: size.width * 0.65
                        )
                    )
                }

                // ── Light 7: MID-RIGHT DEEP BLUE — cool indigo complement to warm gold ──
                let center7 = CGPoint(x: size.width * 0.85, y: size.height * 0.50)
                let gradient7 = Gradient(colors: [
                    Color(red: 0.10, green: 0.18, blue: 0.55).opacity(0.12),
                    Color(red: 0.08, green: 0.14, blue: 0.42).opacity(0.05),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center7.x - size.width * 0.55,
                            y: center7.y - size.width * 0.55,
                            width: size.width * 1.10,
                            height: size.width * 1.10
                        )),
                        with: .radialGradient(
                            gradient7,
                            center: center7,
                            startRadius: 0,
                            endRadius: size.width * 0.55
                        )
                    )
                }

                // ── Light 8: BOTTOM-LEFT PURPLE-VIOLET — rounds out the color story ──
                let center8 = CGPoint(x: size.width * 0.05, y: size.height * 0.72)
                let gradient8 = Gradient(colors: [
                    Color(red: 0.35, green: 0.12, blue: 0.50).opacity(0.10),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center8.x - size.width * 0.50,
                            y: center8.y - size.width * 0.50,
                            width: size.width * 1.00,
                            height: size.width * 1.00
                        )),
                        with: .radialGradient(
                            gradient8,
                            center: center8,
                            startRadius: 0,
                            endRadius: size.width * 0.50
                        )
                    )
                }
            }
            .ignoresSafeArea()

            content
        }
    }
}
