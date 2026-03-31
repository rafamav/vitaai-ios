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

    // Layer 1 base
    private let baseStart = Color(red: 12/255, green: 9/255, blue: 7/255).opacity(0.94)
    private let baseEnd   = Color(red: 14/255, green: 11/255, blue: 8/255).opacity(0.90)

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

                    // ── Layer 2b: Inset top highlight (simulates inset 0 1px 0 rgba(255,255,255,0.04)) ──
                    VStack(spacing: 0) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, Color.white.opacity(0.04), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 1)
                            .padding(.horizontal, 20)
                            .padding(.top, 1)
                        Spacer()
                        // Inset bottom shadow (simulates inset 0 -1px 0 rgba(0,0,0,0.15))
                        Capsule()
                            .fill(Color.black.opacity(0.15))
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
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: conicGold120.opacity(0.14), location: 0.0),    // 0%
                                .init(color: conicGold100.opacity(0.04), location: 0.25),   // 25%
                                .init(color: conicGold120.opacity(0.08), location: 0.40),   // 40%
                                .init(color: conicGold100.opacity(0.02), location: 0.60),   // 60%
                                .init(color: conicGold120.opacity(0.10), location: 0.80),   // 80%
                                .init(color: conicGold120.opacity(0.14), location: 1.0),    // 100%
                            ]),
                            center: .center,
                            startAngle: .degrees(200),
                            endAngle: .degrees(200 + 360)
                        ),
                        lineWidth: 1
                    )
            )
            // ── Shadows ──
            // CSS: box-shadow: 0 20px 50px rgba(0,0,0,0.50), 0 6px 16px rgba(0,0,0,0.35)
            .shadow(color: .black.opacity(0.50), radius: 25, x: 0, y: 20)
            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 6)
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

    /// Lightweight glass background (base + border only, no Canvas overhead)
    func glassCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 12/255, green: 9/255, blue: 7/255).opacity(0.94),
                                Color(red: 14/255, green: 11/255, blue: 8/255).opacity(0.90)
                            ],
                            startPoint: UnitPoint(x: 0.46, y: 0.0),
                            endPoint: UnitPoint(x: 0.54, y: 1.0)
                        )
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(stops: [
                                .init(color: Color(red: 1.0, green: 200/255, blue: 120/255).opacity(0.14), location: 0.0),
                                .init(color: Color(red: 1.0, green: 180/255, blue: 100/255).opacity(0.04), location: 0.25),
                                .init(color: Color(red: 1.0, green: 200/255, blue: 120/255).opacity(0.08), location: 0.40),
                                .init(color: Color(red: 1.0, green: 180/255, blue: 100/255).opacity(0.02), location: 0.60),
                                .init(color: Color(red: 1.0, green: 200/255, blue: 120/255).opacity(0.10), location: 0.80),
                                .init(color: Color(red: 1.0, green: 200/255, blue: 120/255).opacity(0.14), location: 1.0),
                            ]),
                            center: .center,
                            startAngle: .degrees(200),
                            endAngle: .degrees(200 + 360)
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.50), radius: 25, x: 0, y: 20)
            .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 6)
    }
}
