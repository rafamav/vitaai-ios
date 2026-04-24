import SwiftUI

// MARK: - VitaGlassCard — 3-Layer Gold Glass System
// Matches mockup CSS .g3 / .gpanel exactly:
//   Layer 1: Dark warm base (linear-gradient 175deg)
//   Layer 2: Inner glow (4 radial-gradients at corners/center)
//   Layer 3: Conic border (angular-gradient masked to 1px stroke)
//   Shadow: 2 drop shadows + 2 inset-simulated highlights

struct VitaGlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    init(
        cornerRadius: CGFloat = 18,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    // MARK: - Mockup-exact colors (from CSS rgba values)

    // Layer 1 base — D4 "carved" gradient (obsidiana quente top → preto quente base)
    private let baseStart = Color(red: 30/255, green: 22/255, blue: 15/255).opacity(0.92)
    private let baseEnd   = Color(red: 14/255, green: 10/255, blue: 7/255).opacity(0.92)

    // Layer 2 inner glow
    private let glowGold120  = Color(red: 1.0, green: 200/255, blue: 120/255) // rgba(255,200,120)
    private let glowGold100  = Color(red: 1.0, green: 180/255, blue: 100/255) // rgba(255,180,100)
    private let glowWarm210  = Color(red: 1.0, green: 240/255, blue: 210/255) // rgba(255,240,210)

    // Layer 3 conic border
    private let conicGold120 = Color(red: 1.0, green: 200/255, blue: 120/255) // rgba(255,200,120)
    private let conicGold100 = Color(red: 1.0, green: 180/255, blue: 100/255) // rgba(255,180,100)

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    // ── Layer 1: Base dark warm gradient ──
                    // CSS: linear-gradient(175deg, rgba(12,9,7,0.94), rgba(14,11,8,0.90))
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [baseStart, baseEnd],
                                startPoint: UnitPoint(x: 0.46, y: 0.0),  // 175deg ≈ nearly vertical, slight left
                                endPoint: UnitPoint(x: 0.54, y: 1.0)
                            )
                        )

                    // ── Layer 2: Inner glow — 4 radial gradients ──
                    // CSS ::before with 4 radial-gradient layers
                    Canvas { context, size in
                        let rect = CGRect(origin: .zero, size: size)
                        let clip = Path(roundedRect: rect, cornerRadius: cornerRadius)
                        context.clip(to: clip)

                        // radial-gradient(circle at 15% 0%, rgba(255,200,120,0.08), transparent 50%)
                        drawRadial(
                            context: &context, size: size,
                            center: CGPoint(x: size.width * 0.15, y: 0),
                            radiusFraction: 0.50,
                            color: glowGold120, alpha: 0.08
                        )

                        // radial-gradient(circle at 85% 0%, rgba(255,200,120,0.05), transparent 40%)
                        drawRadial(
                            context: &context, size: size,
                            center: CGPoint(x: size.width * 0.85, y: 0),
                            radiusFraction: 0.40,
                            color: glowGold120, alpha: 0.05
                        )

                        // radial-gradient(circle at 50% 100%, rgba(255,180,100,0.04), transparent 35%)
                        drawRadial(
                            context: &context, size: size,
                            center: CGPoint(x: size.width * 0.50, y: size.height),
                            radiusFraction: 0.35,
                            color: glowGold100, alpha: 0.04
                        )

                        // radial-gradient(circle at 50% 50%, rgba(255,240,210,0.015), transparent 70%)
                        drawRadial(
                            context: &context, size: size,
                            center: CGPoint(x: size.width * 0.50, y: size.height * 0.50),
                            radiusFraction: 0.70,
                            color: glowWarm210, alpha: 0.015
                        )
                    }
                    .allowsHitTesting(false)

                    // ── Layer 2b: Inset top highlight (D4 bevel — gold 18%) ──
                    VStack(spacing: 0) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, Color(red: 255/255, green: 230/255, blue: 180/255).opacity(0.18), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.top, 1)
                        Spacer()
                        // Inset bottom shadow — dark bevel pra carved effect
                        Capsule()
                            .fill(Color.black.opacity(0.5))
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 1)
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            // ── Layer 3: Conic gold border (1px angular gradient stroke) ──
            // CSS: conic-gradient(from 200deg, ...)  mask-composite: exclude; padding: 1px
            // ── Layer 3: D4 border gold solid 22% (visível mas elegante) ──
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        Color(red: 200/255, green: 160/255, blue: 80/255).opacity(0.22),
                        lineWidth: 1
                    )
            )
            // ── Shadows D4 — card "sentado" na tela ──
            .shadow(color: .black.opacity(0.50), radius: 16, x: 0, y: 6)
            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 1)
    }

    // MARK: - Radial gradient helper (matches CSS radial-gradient circle)

    private func drawRadial(
        context: inout GraphicsContext,
        size: CGSize,
        center: CGPoint,
        radiusFraction: CGFloat,
        color: Color,
        alpha: Double
    ) {
        // CSS "circle" radial = radius based on max dimension
        let radius = max(size.width, size.height) * radiusFraction

        context.drawLayer { ctx in
            ctx.fill(
                Path(ellipseIn: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(alpha), .clear]),
                    center: center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
        }
    }
}

// MARK: - View modifier for inline glass styling (lightweight version)

extension View {
    /// Full 3-layer glass card wrapping content
    func vitaGlassCard(cornerRadius: CGFloat = 18) -> some View {
        VitaGlassCard(cornerRadius: cornerRadius) {
            self
        }
    }

    /// Lightweight glass card — matches mockup D4 "CARVED":
    ///   background: linear-gradient(180deg, rgba(30,22,15,0.92) → rgba(14,10,7,0.92))
    ///   border: 1px rgba(200,160,80,0.22)
    ///   box-shadow: inset top highlight rgba(255,230,180,0.18),
    ///               inset bottom shadow rgba(0,0,0,0.5),
    ///               drop 0 6px 16px rgba(0,0,0,0.5)
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 30/255, green: 22/255, blue: 15/255).opacity(0.92),
                                Color(red: 14/255, green: 10/255, blue: 7/255).opacity(0.92)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            // Inset top highlight — linha clara que simula luz de cima (bevel)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 255/255, green: 230/255, blue: 180/255).opacity(0.18),
                                Color(red: 255/255, green: 230/255, blue: 180/255).opacity(0.04),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.plusLighter)
            )
            // Border gold solid 22% — visível mas não gritante
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        Color(red: 200/255, green: 160/255, blue: 80/255).opacity(0.22),
                        lineWidth: 1
                    )
            )
            // Drop shadows — mais fortes pra card "sentar"
            .shadow(color: .black.opacity(0.50), radius: 16, x: 0, y: 6)
            .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 1)
    }
}
