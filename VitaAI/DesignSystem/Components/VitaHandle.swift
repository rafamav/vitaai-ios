import SwiftUI

// MARK: - VitaHandle

/// Draggable semicircle handle for bottom sheet / panel interactions.
///
/// Features a pulsing ambient glow using VitaColors.accent and a
/// dome highlight gradient — mirrors the Android VitaHandle component.
///
/// Usage:
/// ```swift
/// VitaHandle(onDrag: { delta in ... }, onDragEnd: { ... }, onTap: { ... })
/// ```
struct VitaHandle: View {
    var onDrag: (CGFloat) -> Void = { _ in }
    var onDragEnd: () -> Void = {}
    var onTap: () -> Void = {}

    // Custom warm dark palette — intentionally local.
    // TODO: promote to design-tokens once agreed (see Android VitaHandle.kt TODOs).
    private static let bgDark   = Color(hex: 0x1A1412)
    private static let bgMid    = Color(hex: 0x1E1814)
    private static let bgLight  = Color(hex: 0x2A2620)

    @State private var glowOpacity: Double = 0.08
    @GestureState private var dragOffset: CGFloat = 0

    private let handleWidth: CGFloat  = 76
    private let handleHeight: CGFloat = 38

    var body: some View {
        ZStack {
            // Ambient glow behind handle
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            VitaColors.accent.opacity(glowOpacity),
                            .clear,
                        ],
                        center: .init(x: 0.5, y: 1.0),
                        startRadius: 0,
                        endRadius: handleWidth * 0.7
                    )
                )
                .frame(width: handleWidth * 1.2, height: handleHeight * 1.5)
                .offset(y: handleHeight * 0.1)

            // Handle pill — semicircle (top rounded)
            HandleShape()
                .fill(
                    LinearGradient(
                        colors: [Self.bgLight, Self.bgMid, Self.bgDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    // Dome highlight
                    HandleShape()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.05),
                                    .clear,
                                ],
                                center: .init(x: 0.4, y: 0.15),
                                startRadius: 0,
                                endRadius: handleWidth * 0.35
                            )
                        )
                )
                .overlay(
                    // Bottom vignette
                    HandleShape()
                        .fill(
                            LinearGradient(
                                colors: [.clear, VitaColors.black.opacity(0.25)],
                                startPoint: .init(x: 0.5, y: 0.5),
                                endPoint: .bottom
                            )
                        )
                )
                // Vita logo mark
                .overlay(
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(VitaColors.accent)
                        .offset(y: 1)
                )
                .frame(width: handleWidth, height: handleHeight)
        }
        .frame(width: handleWidth, height: handleHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.height
                    onDrag(value.translation.height)
                }
                .onEnded { _ in onDragEnd() }
        )
        .onTapGesture { onTap() }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 3.0).repeatForever(autoreverses: true)
            ) {
                glowOpacity = 0.18
            }
        }
    }
}

// MARK: - HandleShape (top-rounded semicircle)

private struct HandleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.width / 2
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addArc(
            center: CGPoint(x: rect.midX, y: radius),
            radius: radius,
            startAngle: .degrees(180),
            endAngle: .degrees(0),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ZStack {
        VitaColors.surface
            .ignoresSafeArea()
        VStack {
            Spacer()
            VitaHandle(
                onDrag: { delta in print("drag: \(delta)") },
                onDragEnd: { print("drag ended") },
                onTap: { print("tapped") }
            )
        }
    }
}
#endif
