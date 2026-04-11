import SwiftUI

// MARK: - Vita Mascot — Based on MASCOTEVITA.png + Zed reference
// Dark orb, neon teal glow, expressive round eyes (Zed-like),
// Asclepius staff perpendicular as if held, green snake wrapped around it

struct VitaMascot: View {
    var state: MascotState = .sleeping
    var size: CGFloat = 120
    var showStaff: Bool = true

    @State private var floatY: CGFloat = 0
    @State private var glowIntensity: Double = 0.3
    @State private var blinking = false
    @State private var sparklePhase: Double = 0
    @State private var breathScale: CGFloat = 1.0
    @State private var eyeLookX: CGFloat = 0
    @State private var snakePhase: Double = 0
    @State private var ringRotation: Double = 0
    @State private var crystalGlow: Double = 0.8
    @State private var bounceY: CGFloat = 0        // bounce/jump animation
    @State private var squishY: CGFloat = 1.0      // vertical squish during bounce
    @State private var squishX: CGFloat = 1.0      // horizontal squish
    @State private var auraHue: Double = 0         // rotating hue for aura
    @State private var eyeAngle: Double = 0        // slight tilt to eyes
    @State private var loopTask: Task<Void, Never>? = nil

    private let teal = Color(red: 0.784, green: 0.627, blue: 0.314)
    private let tealBright = Color(red: 1.0, green: 0.784, blue: 0.471)
    private let tealDim = Color(red: 0.549, green: 0.392, blue: 0.196)
    // Snake is a distinct green — different from teal staff
    private let snakeGreen = Color(red: 0.2, green: 0.9, blue: 0.45)
    private let snakeGreenBright = Color(red: 0.4, green: 1.0, blue: 0.6)

    var body: some View {
        ZStack {
            // Color-shifting aura behind everything
            auraView

            orbView

            if showStaff && state != .sleeping {
                staffWithSnake
                    .offset(x: -size * 0.72, y: size * 0.05)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .scaleEffect(x: breathScale * squishX, y: breathScale * squishY)
        .offset(y: bounceY)
        .onAppear {
            startAnimations()
        }
        .onDisappear {
            // Cancel all Task-based loops — they check Task.isCancelled
            loopTask?.cancel()
            loopTask = nil
            // Reset animated state so repeat-forever animations
            // can restart properly if the view reappears
            floatY = 0
            glowIntensity = 0.3
            sparklePhase = 0
            breathScale = 1.0
            snakePhase = 0
            ringRotation = 0
            crystalGlow = 0.8
            auraHue = 0
            eyeAngle = 0
            bounceY = 0
            squishY = 1.0
            squishX = 1.0
            eyeLookX = 0
            blinking = false
        }
        .onChange(of: state) { newState in
            if newState == .happy { triggerBounce() }
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.7), value: state)
    }

    // MARK: - Aura (color-shifting glow like Zed)

    private var auraView: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hue: auraHue.truncatingRemainder(dividingBy: 1.0), saturation: 0.6, brightness: 0.9).opacity(0.08),
                        Color(hue: (auraHue + 0.3).truncatingRemainder(dividingBy: 1.0), saturation: 0.5, brightness: 0.8).opacity(0.04),
                        .clear
                    ],
                    center: .center, startRadius: size * 0.3, endRadius: size * 1.0
                )
            )
            .frame(width: size * 2.2, height: size * 2.2)
            .blur(radius: 20)
            .opacity(state == .sleeping ? 0.3 : 0.7)
    }

    // MARK: - Orb

    private var orbView: some View {
        ZStack {
            orbGlow
            orbSparkles
            orbRing
            orbBody
        }
        .offset(y: floatY)
    }

    private var orbGlow: some View {
        Circle()
            .fill(RadialGradient(
                colors: [teal.opacity(glowIntensity * 0.7), teal.opacity(glowIntensity * 0.15), .clear],
                center: .center, startRadius: size * 0.2, endRadius: size * 1.3
            ))
            .frame(width: size * 2.6, height: size * 2.6)
            .blur(radius: 22)
    }

    private var orbSparkles: some View {
        ForEach(0..<8, id: \.self) { i in
            Circle()
                .fill(tealBright.opacity(0.3 + sin(sparklePhase + Double(i) * 0.8) * 0.25))
                .frame(width: 1.5 + CGFloat(i % 3), height: 1.5 + CGFloat(i % 3))
                .offset(
                    x: cos(Double(i) * 0.7 + sparklePhase * 0.25) * size * 0.7,
                    y: sin(Double(i) * 0.5 + sparklePhase * 0.3) * size * 0.6
                )
                .blur(radius: 0.5)
        }
    }

    private var orbRing: some View {
        let ringGlow = Ellipse()
            .stroke(teal.opacity(0.12), lineWidth: 10)
            .frame(width: size * 1.45, height: size * 0.36)
            .blur(radius: 8)

        let ringMain = Ellipse()
            .stroke(
                AngularGradient(
                    colors: [teal.opacity(0.8), tealBright.opacity(0.5), teal.opacity(0.6), tealBright.opacity(0.12), teal.opacity(0.7)],
                    center: .center
                ),
                lineWidth: 1.8
            )
            .frame(width: size * 1.45, height: size * 0.36)
            .shadow(color: teal.opacity(0.5), radius: 10)

        return ZStack {
            ringGlow
            ringMain
        }
        .rotationEffect(.degrees(-12 + sin(ringRotation * 0.3) * 2))
        .opacity(state == .sleeping ? 0.3 : 0.9)
    }

    private var orbBody: some View {
        ZStack {
            orbSphere
            orbEdgeGlow
            orbReflection
            orbEyes
        }
        .shadow(color: teal.opacity(state == .sleeping ? 0.08 : 0.25), radius: size * 0.18)
        .shadow(color: .black.opacity(0.5), radius: size * 0.1, y: size * 0.04)
    }

    private var orbSphere: some View {
        Circle()
            .fill(RadialGradient(
                colors: [
                    Color(red: 0.10, green: 0.13, blue: 0.15),
                    Color(red: 0.04, green: 0.05, blue: 0.06)
                ],
                center: UnitPoint(x: 0.4, y: 0.35),
                startRadius: 0, endRadius: size * 0.55
            ))
            .frame(width: size, height: size)
    }

    private var orbEdgeGlow: some View {
        Circle()
            .stroke(
                AngularGradient(
                    colors: [teal.opacity(0.5), tealBright.opacity(0.2), teal.opacity(0.4), tealDim.opacity(0.1), teal.opacity(0.45)],
                    center: .center
                ),
                lineWidth: 2.5
            )
            .frame(width: size, height: size)
            .shadow(color: teal.opacity(0.35), radius: 12)
    }

    private var orbReflection: some View {
        Ellipse()
            .fill(RadialGradient(
                colors: [Color.white.opacity(0.06), .clear],
                center: .center, startRadius: 0, endRadius: size * 0.1
            ))
            .frame(width: size * 0.16, height: size * 0.10)
            .offset(x: -size * 0.18, y: -size * 0.24)
    }

    private var orbEyes: some View {
        HStack(spacing: size * 0.17) {
            eyeView
                .rotationEffect(.degrees(eyeAngle))      // slight inward tilt left eye
            eyeView
                .rotationEffect(.degrees(-eyeAngle))     // slight inward tilt right eye
        }
        .offset(x: eyeLookX, y: -size * 0.02)
    }

    // MARK: - Eye (Zed-like — round, expressive, alive)

    private var eyeView: some View {
        let h = blinking ? size * 0.025 : eyeHeight
        let w = blinking ? eyeWidth * 1.3 : eyeWidth
        return ZStack {
            // Outer neon halo
            Capsule()
                .fill(Color.white.opacity(state == .sleeping ? 0.04 : 0.2))
                .frame(width: w + 8, height: h + 8)
                .blur(radius: 8)

            // Mid glow
            Capsule()
                .fill(Color.white.opacity(state == .sleeping ? 0.08 : 0.4))
                .frame(width: w + 4, height: h + 4)
                .blur(radius: 4)

            // Core eye — bright white capsule
            Capsule()
                .fill(Color.white.opacity(state == .sleeping ? 0.4 : 0.95))
                .frame(width: w, height: h)

            // Light catch (top highlight — gives life)
            if !blinking && state != .sleeping && h > size * 0.08 {
                Capsule()
                    .fill(Color.white)
                    .frame(width: w * 0.5, height: h * 0.15)
                    .offset(y: -h * 0.3)
                    .opacity(0.4)
            }
        }
        .shadow(color: Color.white.opacity(0.35), radius: 12)
        .animation(.easeInOut(duration: 0.08), value: blinking)
    }

    private var eyeWidth: CGFloat {
        switch state {
        case .sleeping: return size * 0.14
        case .waking: return size * 0.10
        case .awake: return size * 0.10       // NARROW — makes vertical pop
        case .thinking: return size * 0.09
        case .happy: return size * 0.11       // slightly wider but still vertical
        }
    }

    private var eyeHeight: CGFloat {
        switch state {
        case .sleeping: return size * 0.03    // thin line
        case .waking: return size * 0.16      // opening
        case .awake: return size * 0.32       // VERY TALL vertical — like reference
        case .thinking: return size * 0.20    // squinted but still vertical
        case .happy: return size * 0.26       // slightly shorter but STILL vertical
        }
    }

    // MARK: - Staff + Snake (perpendicular, as if held)

    private var staffWithSnake: some View {
        let h = size * 1.15
        return ZStack(alignment: .top) {
            staffRodView(height: h)
            staffCrystalView
            snakeWrappedView(staffHeight: h)
        }
        .offset(y: floatY * 0.5)
    }

    private func staffRodView(height h: CGFloat) -> some View {
        ZStack {
            // Rod glow
            RoundedRectangle(cornerRadius: 2)
                .fill(teal.opacity(0.12))
                .frame(width: 5, height: h)
                .blur(radius: 3)

            // Rod
            RoundedRectangle(cornerRadius: 1.5)
                .fill(LinearGradient(
                    colors: [tealBright.opacity(0.45), teal.opacity(0.4), tealDim.opacity(0.25)],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 2.5, height: h)
                .shadow(color: teal.opacity(0.3), radius: 4)
        }
    }

    private var staffCrystalView: some View {
        ZStack {
            // Large glow
            Diamond()
                .fill(tealBright.opacity(0.15 * crystalGlow))
                .frame(width: 24, height: 30)
                .blur(radius: 12)

            // Mid glow
            Diamond()
                .fill(tealBright.opacity(0.2 * crystalGlow))
                .frame(width: 16, height: 20)
                .blur(radius: 5)

            // Crystal
            Diamond()
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.9), tealBright, teal],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: 10, height: 15)
                .shadow(color: tealBright, radius: 10)
                .shadow(color: tealBright, radius: 5)
        }
        .offset(y: -5)
    }

    // MARK: - Snake (GREEN, wrapped around staff, expressive)

    private func snakeWrappedView(staffHeight h: CGFloat) -> some View {
        let snakeH = h * 0.65
        let amp: CGFloat = 14 + CGFloat(sin(snakePhase * 0.5)) * 2.5

        return ZStack(alignment: .top) {
            snakeBodyLayer(snakeH: snakeH, amp: amp)
            snakeHeadLayer(amp: amp)
        }
        .offset(y: h * 0.12)
    }

    private func snakeBodyLayer(snakeH: CGFloat, amp: CGFloat) -> some View {
        ZStack {
            // Body glow (green)
            SnakeCurve(height: snakeH, amplitude: amp)
                .stroke(snakeGreen.opacity(0.15), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .frame(width: 36, height: snakeH)
                .blur(radius: 4)

            // Body (green — distinct from teal staff)
            SnakeCurve(height: snakeH, amplitude: amp)
                .stroke(
                    LinearGradient(
                        colors: [snakeGreenBright.opacity(0.9), snakeGreen.opacity(0.75), snakeGreenBright.opacity(0.65), snakeGreen.opacity(0.8)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .frame(width: 36, height: snakeH)
                .shadow(color: snakeGreen.opacity(0.4), radius: 5)
        }
    }

    private func snakeHeadLayer(amp: CGFloat) -> some View {
        ZStack {
            // Head glow
            Ellipse()
                .fill(snakeGreenBright.opacity(0.2))
                .frame(width: 22, height: 16)
                .blur(radius: 6)

            // Head shape — triangular snake head
            snakeHeadShape
                .frame(width: 14, height: 10)
                .shadow(color: snakeGreenBright, radius: 5)

            // Snake eyes — TWO visible bright dots
            snakeEyesView

            // Forked tongue — flicking out
            snakeTongueView
        }
        .offset(x: amp * 0.35 + 4, y: -3)
        .rotationEffect(.degrees(-12))
    }

    private var snakeHeadShape: some View {
        SnakeHeadShape()
            .fill(
                LinearGradient(
                    colors: [snakeGreenBright.opacity(0.9), snakeGreen.opacity(0.75)],
                    startPoint: .top, endPoint: .bottom
                )
            )
    }

    private var snakeEyesView: some View {
        HStack(spacing: 5) {
            ZStack {
                Circle().fill(Color.white.opacity(0.95)).frame(width: 3, height: 3)
                Circle().fill(Color.black.opacity(0.7)).frame(width: 1.5, height: 1.5)
            }
            ZStack {
                Circle().fill(Color.white.opacity(0.95)).frame(width: 3, height: 3)
                Circle().fill(Color.black.opacity(0.7)).frame(width: 1.5, height: 1.5)
            }
        }
        .offset(x: 1, y: -1)
    }

    private var snakeTongueView: some View {
        Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: 5, y: -2))
            p.move(to: CGPoint(x: 0, y: 0))
            p.addLine(to: CGPoint(x: 5, y: 2))
        }
        .stroke(Color.red.opacity(0.7), lineWidth: 0.8)
        .frame(width: 6, height: 5)
        .offset(x: 10, y: 0)
    }

    // MARK: - Animations

    private func startAnimations() {
        // Float up/down
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            floatY = -8
        }
        // Glow pulse
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            glowIntensity = state == .sleeping ? 0.2 : 0.55
        }
        // Sparkle orbit
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) {
            sparklePhase = .pi * 2
        }
        // Breathing
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
            breathScale = 1.025
        }
        // Snake sway
        withAnimation(.linear(duration: 6).repeatForever(autoreverses: false)) {
            snakePhase = .pi * 2
        }
        // Ring wobble
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            ringRotation = .pi * 2
        }
        // Crystal pulse
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            crystalGlow = 1.2
        }
        // Aura color shift — slow hue rotation
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            auraHue = 1.0
        }
        // Eye angle — gentle sway
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            eyeAngle = 5
        }
        // Start all cancellable loops in a single parent Task
        loopTask?.cancel()
        loopTask = Task { @MainActor in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.eyeLookLoop() }
                group.addTask { await self.blinkLoop() }
                group.addTask { await self.bounceLoop() }
            }
        }
    }

    // MARK: - Bounce (Zed-like jumps)

    private func triggerBounce() {
        Task { @MainActor in
            // Squish down
            withAnimation(.easeIn(duration: 0.1)) {
                squishY = 0.85
                squishX = 1.12
            }
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            // Jump up
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                bounceY = -25
                squishY = 1.1
                squishX = 0.92
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            // Land
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                bounceY = 0
                squishY = 0.9
                squishX = 1.08
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            // Settle
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                squishY = 1.0
                squishX = 1.0
            }
        }
    }

    @MainActor
    private func bounceLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 4000...8000)))
            guard !Task.isCancelled else { break }
            triggerBounce()
        }
    }

    @MainActor
    private func eyeLookLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 1500...3500)))
            guard !Task.isCancelled else { break }
            withAnimation(.easeInOut(duration: 0.5)) {
                eyeLookX = CGFloat.random(in: -size * 0.04...size * 0.04)
            }

            try? await Task.sleep(for: .milliseconds(Int.random(in: 800...2000)))
            guard !Task.isCancelled else { break }
            withAnimation(.easeInOut(duration: 0.4)) { eyeLookX = 0 }
        }
    }

    @MainActor
    private func blinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 2500...5000)))
            guard !Task.isCancelled else { break }
            blinking = true
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { break }
            blinking = false
        }
    }
}

// MARK: - Shapes

private struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.closeSubpath()
        }
    }
}

private struct SnakeHeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.midY - rect.height * 0.45))
            p.addCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control1: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.05),
                control2: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.midY - rect.height * 0.1)
            )
            p.addCurve(
                to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.45),
                control1: CGPoint(x: rect.maxX - rect.width * 0.15, y: rect.midY + rect.height * 0.1),
                control2: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.05)
            )
            p.closeSubpath()
        }
    }
}

private struct SnakeCurve: Shape {
    let height: CGFloat
    let amplitude: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { p in
            let mid = rect.midX
            let seg = rect.height / 4.0
            p.move(to: CGPoint(x: mid + amplitude * 0.35, y: 0))
            p.addCurve(
                to: CGPoint(x: mid - amplitude * 0.25, y: seg),
                control1: CGPoint(x: mid + amplitude * 0.9, y: seg * 0.3),
                control2: CGPoint(x: mid - amplitude * 0.7, y: seg * 0.7)
            )
            p.addCurve(
                to: CGPoint(x: mid + amplitude * 0.25, y: seg * 2),
                control1: CGPoint(x: mid + amplitude * 0.4, y: seg * 1.3),
                control2: CGPoint(x: mid + amplitude * 0.85, y: seg * 1.7)
            )
            p.addCurve(
                to: CGPoint(x: mid - amplitude * 0.15, y: seg * 3),
                control1: CGPoint(x: mid - amplitude * 0.4, y: seg * 2.3),
                control2: CGPoint(x: mid - amplitude * 0.6, y: seg * 2.7)
            )
            p.addQuadCurve(
                to: CGPoint(x: mid, y: rect.height),
                control: CGPoint(x: mid + amplitude * 0.25, y: seg * 3.5)
            )
        }
    }
}

// MARK: - States

enum MascotState: Equatable {
    case sleeping
    case waking
    case awake
    case thinking
    case happy
}

// MARK: - Preview

struct VitaMascotOnboardingDemo: View {
    @State private var mascotState: MascotState = .sleeping

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.02, blue: 0.03).ignoresSafeArea()
            VStack(spacing: 40) {
                VitaMascot(state: mascotState, size: 120)
                HStack(spacing: 8) {
                    ForEach(["sleep", "wake", "awake", "think", "happy"], id: \.self) { s in
                        Button(s) {
                            withAnimation(.spring(response: 0.5)) {
                                mascotState = MascotState(rawValue: s)
                            }
                        }
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

private extension MascotState {
    init(rawValue: String) {
        switch rawValue {
        case "sleep": self = .sleeping
        case "wake": self = .waking
        case "awake": self = .awake
        case "think": self = .thinking
        case "happy": self = .happy
        default: self = .sleeping
        }
    }
}

#Preview { VitaMascotOnboardingDemo() }
