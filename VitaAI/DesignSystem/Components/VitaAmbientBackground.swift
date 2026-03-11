import SwiftUI

struct VitaAmbientBackground<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            VitaColors.surface
                .ignoresSafeArea()

            Canvas { context, size in
                // Light 1: top-left, primary gold glow
                let center1 = CGPoint(x: size.width * 0.08, y: size.height * 0.12)
                let gradient1 = Gradient(colors: [
                    VitaColors.ambientPrimary.opacity(0.11),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center1.x - size.width * 0.7,
                            y: center1.y - size.width * 0.7,
                            width: size.width * 1.4,
                            height: size.width * 1.4
                        )),
                        with: .radialGradient(
                            gradient1,
                            center: center1,
                            startRadius: 0,
                            endRadius: size.width * 0.7
                        )
                    )
                }

                // Light 2: bottom-right, secondary gold
                let center2 = CGPoint(x: size.width * 0.85, y: size.height * 0.78)
                let gradient2 = Gradient(colors: [
                    VitaColors.ambientSecondary.opacity(0.07),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center2.x - size.width * 0.6,
                            y: center2.y - size.width * 0.6,
                            width: size.width * 1.2,
                            height: size.width * 1.2
                        )),
                        with: .radialGradient(
                            gradient2,
                            center: center2,
                            startRadius: 0,
                            endRadius: size.width * 0.6
                        )
                    )
                }

                // Light 3: center, deep subtle gold fill
                let center3 = CGPoint(x: size.width * 0.50, y: size.height * 0.40)
                let gradient3 = Gradient(colors: [
                    VitaColors.ambientTertiary.opacity(0.05),
                    .clear
                ])
                context.drawLayer { ctx in
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: center3.x - size.width * 0.75,
                            y: center3.y - size.width * 0.75,
                            width: size.width * 1.5,
                            height: size.width * 1.5
                        )),
                        with: .radialGradient(
                            gradient3,
                            center: center3,
                            startRadius: 0,
                            endRadius: size.width * 0.75
                        )
                    )
                }
            }
            .ignoresSafeArea()

            content
        }
    }
}
