import SwiftUI

// MARK: - OrbMascot
//
// Generic orb-style mascot used by every ONE agent. Same orb design from the
// Vita iOS LoginScreen, parameterized by a `MascotPalette` so we can ship
// Vita (gold + Asclepius staff with green snake) and Pixio (green/teal, no
// staff) without duplicating animation code.
//
// Pixio palette is a literal port of `_OrbPainter` in
// pixio/apps/mobile_flutter/lib/screens/welcome_screen.dart on monstro —
// teal #2DD4BF + the deep emerald gradient stack. Rafael called it out as
// canonical: same Vita orb, just green.

struct MascotPalette: Equatable {
    let primary: Color        // main brand color (was `teal`)
    let bright: Color         // highlight (was `tealBright`)
    let dim: Color            // shadow (was `tealDim`)
    let sphereInner: Color    // orb body inner (lit cap)
    let sphereMid: Color      // body mid-stop (chromatic identity)
    let sphereOuter: Color    // body outer (terminator side)

    // Vita — warm gold orb. Body has a deep gold-brown chromatic cast so even
    // the unlit side reads "Vita" instead of pure black. Updated 2026-04-18.
    static let vita = MascotPalette(
        primary:     Color(red: 0.784, green: 0.627, blue: 0.314), // gold
        bright:      Color(red: 1.000, green: 0.784, blue: 0.471),
        dim:         Color(red: 0.549, green: 0.392, blue: 0.196),
        sphereInner: Color(red: 0.16,  green: 0.13,  blue: 0.09),  // warm dark
        sphereMid:   Color(red: 0.10,  green: 0.08,  blue: 0.05),  // deep brown
        sphereOuter: Color(red: 0.04,  green: 0.03,  blue: 0.02)   // near-black, gold-tinted
    )

    // Pixio — emerald orb. Body carries a deep emerald cast so the unlit side
    // reads as "Pixio" green instead of pure black. From Flutter `_OrbPainter`
    // base palette but pushed slightly more saturated for chromatic identity.
    static let pixio = MascotPalette(
        primary:     Color(red: 0.176, green: 0.831, blue: 0.749), // #2DD4BF
        bright:      Color(red: 0.369, green: 0.918, blue: 0.831), // #5EEAD4
        dim:         Color(red: 0.059, green: 0.420, blue: 0.376), // #0F6B60
        sphereInner: Color(red: 0.102, green: 0.361, blue: 0.322), // #1A5C52
        sphereMid:   Color(red: 0.058, green: 0.239, blue: 0.218), // #0F3D38
        sphereOuter: Color(red: 0.016, green: 0.071, blue: 0.063)  // #041210
    )
}

struct OrbMascot: View {
    var palette: MascotPalette = .vita
    var state: VitaMascotState = .awake
    var size: CGFloat = 120
    // Staff/snake removed entirely on 2026-04-18 — Rafael called it ugly and
    // wanted the orb to stand on its own. Param kept for source compat (no-op).
    var showStaff: Bool = false
    // When false, the orb's periodic "bounce" is suppressed. Useful for
    // screens where the bounce competes with the user's task — e.g. the
    // Transcrição recorder where the orb needs to look focused, not excited.
    var bounceEnabled: Bool = true

    @State private var floatY: CGFloat = 0
    @State private var glowIntensity: Double = 0.3
    @State private var blinking = false
    @State private var sparklePhase: Double = 0
    @State private var breathScale: CGFloat = 1.0
    @State private var eyeLookX: CGFloat = 0
    @State private var ringRotation: Double = 0
    @State private var bounceY: CGFloat = 0
    @State private var squishY: CGFloat = 1.0
    @State private var squishX: CGFloat = 1.0
    @State private var auraHue: Double = 0
    @State private var eyeAngle: Double = 0
    @State private var loopTask: Task<Void, Never>? = nil
    // New behavior states (gold-standard pass)
    @State private var headTilt: Double = 0       // -8..8 degrees, micro head movement
    @State private var idleDriftX: CGFloat = 0    // tiny horizontal sway
    @State private var pulseBoost: Double = 0     // 0..1 magical pulse on the ring/aura
    @State private var slowBlink: Bool = false    // longer half-close (drowsy)
    @State private var happyEyes: Bool = false    // ^_^ closed-arc smile eyes

    private var primary: Color { palette.primary }
    private var bright: Color  { palette.bright }
    private var dim: Color     { palette.dim }

    var body: some View {
        ZStack {
            auraView
            orbView
        }
        .scaleEffect(x: breathScale * squishX, y: breathScale * squishY)
        .offset(x: idleDriftX, y: bounceY)
        .onAppear { startAnimations() }
        .onDisappear {
            loopTask?.cancel()
            loopTask = nil
            floatY = 0; glowIntensity = 0.3; sparklePhase = 0; breathScale = 1.0
            ringRotation = 0; auraHue = 0
            eyeAngle = 0; bounceY = 0; squishY = 1.0; squishX = 1.0
            eyeLookX = 0; blinking = false
            headTilt = 0; idleDriftX = 0; pulseBoost = 0; slowBlink = false
            happyEyes = false
        }
        .onChange(of: state) { newState in
            if newState == .happy { triggerBounce() }
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.7), value: state)
    }

    // MARK: - Aura
    private var auraView: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(hue: auraHue.truncatingRemainder(dividingBy: 1.0), saturation: 0.6, brightness: 0.9).opacity(0.08),
                        Color(hue: (auraHue + 0.3).truncatingRemainder(dividingBy: 1.0), saturation: 0.5, brightness: 0.8).opacity(0.04),
                        .clear,
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
        ZStack { orbGlow; orbSparkles; orbRing; orbBody }
            .offset(y: floatY)
    }

    private var orbGlow: some View {
        Circle()
            .fill(RadialGradient(
                colors: [primary.opacity(glowIntensity * 0.7), primary.opacity(glowIntensity * 0.15), .clear],
                center: .center, startRadius: size * 0.2, endRadius: size * 1.3
            ))
            .frame(width: size * 2.6, height: size * 2.6)
            .blur(radius: 22)
    }

    private var orbSparkles: some View {
        ForEach(0..<8, id: \.self) { i in
            Circle()
                .fill(bright.opacity(0.3 + sin(sparklePhase + Double(i) * 0.8) * 0.25))
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
            .stroke(primary.opacity(0.12), lineWidth: 10)
            .frame(width: size * 1.45, height: size * 0.36)
            .blur(radius: 8)

        let ringMain = Ellipse()
            .stroke(
                AngularGradient(
                    colors: [primary.opacity(0.8), bright.opacity(0.5), primary.opacity(0.6), bright.opacity(0.12), primary.opacity(0.7)],
                    center: .center
                ),
                lineWidth: 1.8
            )
            .frame(width: size * 1.45, height: size * 0.36)
            .shadow(color: primary.opacity(0.5), radius: 10)

        return ZStack { ringGlow; ringMain }
            .rotationEffect(.degrees(-12 + sin(ringRotation * 0.3) * 2))
            .opacity(state == .sleeping ? 0.3 : (0.9 + pulseBoost * 0.1))
            .scaleEffect(1.0 + pulseBoost * 0.04)
            .shadow(color: primary.opacity(pulseBoost * 0.6), radius: 18 * pulseBoost)
    }

    // MARK: - Orb body — 3D sphere stack
    //
    // Layered like a render shader:
    //   1. base       — multi-stop radial body, deep terminator
    //   2. subsurface — palette-tinted inner glow on the lit side
    //   3. ambientFill— cool palette bounce on the bottom-back (atmospheric)
    //   4. terminator — extra darkening on the unlit side (occlusion)
    //   5. fresnelRim — bright crescent stroke on lit silhouette
    //   6. edgeGlow   — angular outer ring (the chrome/iris feel)
    //   7. specKey    — primary specular highlight (key light)
    //   8. specSecond — small wet sub-spec for that "polished glass" pop
    //   9. eyes
    private var orbBody: some View {
        ZStack {
            // ROTATES with the head — body parts and eyes are "attached"
            ZStack {
                orbBase
                orbSubsurface
                orbAmbientFill
                orbNebula
                orbTerminator
                orbEyes
            }
            .rotationEffect(.degrees(headTilt))

            // STAYS FIXED — light source is environmental, doesn't rotate
            // with the orb. This is what reads as "real glass" instead of
            // "rotating sticker".
            orbFresnelRim
            orbEdgeGlow
            orbSpecKey
            orbSpecStreak
            orbSpecCaustic
        }
        .shadow(color: primary.opacity(state == .sleeping ? 0.08 : 0.30), radius: size * 0.22)
        .shadow(color: .black.opacity(0.6), radius: size * 0.12, y: size * 0.05)
    }

    private var orbBase: some View {
        // 4-stop radial: lit cap (palette tinted dark) → mid → terminator
        // → near-black palette-tinted edge. The body is now *made of* the
        // agent's color, not just lit by it.
        Circle()
            .fill(RadialGradient(
                gradient: Gradient(stops: [
                    .init(color: palette.sphereInner,  location: 0.00),
                    .init(color: palette.sphereInner,  location: 0.30),
                    .init(color: palette.sphereMid,    location: 0.65),
                    .init(color: palette.sphereOuter,  location: 0.95),
                    .init(color: Color.black,          location: 1.00),
                ]),
                center: UnitPoint(x: 0.36, y: 0.30),
                startRadius: 0,
                endRadius: size * 0.62
            ))
            .frame(width: size, height: size)
    }

    private var orbSubsurface: some View {
        // Palette tint that "breathes" through the body on the lit cap —
        // gives the orb its chromatic identity (gold for Vita, teal for Pixio).
        Circle()
            .fill(RadialGradient(
                colors: [primary.opacity(state == .sleeping ? 0.05 : 0.22), .clear],
                center: UnitPoint(x: 0.36, y: 0.30),
                startRadius: 0,
                endRadius: size * 0.42
            ))
            .frame(width: size, height: size)
            .blendMode(.screen)
    }

    private var orbAmbientFill: some View {
        // Cool/colored bounce light from the bottom-back. Sells the volume.
        Circle()
            .fill(RadialGradient(
                colors: [primary.opacity(state == .sleeping ? 0.04 : 0.14), .clear],
                center: UnitPoint(x: 0.78, y: 0.86),
                startRadius: 0,
                endRadius: size * 0.55
            ))
            .frame(width: size, height: size)
            .blendMode(.screen)
    }

    private var orbTerminator: some View {
        // Extra darkening on the unlit side — strengthens 3D perception.
        // Stronger on the bottom-right than before so the silhouette pops.
        Circle()
            .fill(RadialGradient(
                colors: [
                    Color.black.opacity(0.85),
                    Color.black.opacity(0.55),
                    .clear,
                ],
                center: UnitPoint(x: 0.92, y: 0.82),
                startRadius: 0,
                endRadius: size * 0.55
            ))
            .frame(width: size, height: size)
            .blendMode(.multiply)
    }

    /// Clean fresnel rim — bright crescent on the lit silhouette. Stays
    /// FIXED relative to the world (light source doesn't rotate with the
    /// head), so it's rendered outside the headTilt rotation.
    private var orbFresnelRim: some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    colors: [bright.opacity(0.85), primary.opacity(0.5), .clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                lineWidth: size * 0.018
            )
            .frame(width: size, height: size)
            .blur(radius: 0.5)
            .opacity(state == .sleeping ? 0.3 : 0.95)
    }

    private var orbEdgeGlow: some View {
        Circle()
            .stroke(
                AngularGradient(
                    colors: [primary.opacity(0.6), bright.opacity(0.25), primary.opacity(0.45), dim.opacity(0.08), primary.opacity(0.55)],
                    center: .center
                ),
                lineWidth: 2.0
            )
            .frame(width: size, height: size)
            .shadow(color: primary.opacity(0.4), radius: 14)
    }

    private var orbSpecKey: some View {
        // Primary specular highlight — soft, large, the "key light" hot spot.
        Ellipse()
            .fill(RadialGradient(
                colors: [
                    Color.white.opacity(state == .sleeping ? 0.08 : 0.55),
                    Color.white.opacity(state == .sleeping ? 0.02 : 0.18),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: size * 0.18
            ))
            .frame(width: size * 0.34, height: size * 0.22)
            .rotationEffect(.degrees(-22))
            .offset(x: -size * 0.20, y: -size * 0.26)
            .blur(radius: 1.2)
    }

    /// Vertical streak — what a *real* glass marble looks like under a window.
    /// Tall, soft-edged, slightly off-axis. NOT a dot. Reads as glass, not skin.
    private var orbSpecStreak: some View {
        ZStack {
            // Halo behind the streak
            Capsule()
                .fill(Color.white.opacity(state == .sleeping ? 0.05 : 0.30))
                .frame(width: size * 0.09, height: size * 0.34)
                .blur(radius: size * 0.04)
            // Bright core
            Capsule()
                .fill(LinearGradient(
                    colors: [
                        Color.white.opacity(0.0),
                        Color.white.opacity(state == .sleeping ? 0.20 : 0.85),
                        Color.white.opacity(state == .sleeping ? 0.30 : 0.98),
                        Color.white.opacity(state == .sleeping ? 0.10 : 0.55),
                        Color.white.opacity(0.0),
                    ],
                    startPoint: .top, endPoint: .bottom
                ))
                .frame(width: size * 0.045, height: size * 0.30)
                .blur(radius: 0.6)
            // Tiny sparkle pinpoint at the brightest spot
            Circle()
                .fill(Color.white.opacity(state == .sleeping ? 0.30 : 0.95))
                .frame(width: size * 0.022, height: size * 0.022)
                .offset(y: -size * 0.04)
                .blur(radius: 0.3)
        }
        .rotationEffect(.degrees(-12))
        .offset(x: -size * 0.21, y: -size * 0.18)
    }

    /// Caustic refraction spot — light entering the top exits as a bright
    /// crescent on the opposite (bottom-back) side. Tiny but it's the detail
    /// that says "thick glass" instead of "painted ball".
    private var orbSpecCaustic: some View {
        Ellipse()
            .fill(RadialGradient(
                colors: [
                    bright.opacity(state == .sleeping ? 0.08 : 0.55),
                    primary.opacity(state == .sleeping ? 0.04 : 0.20),
                    .clear,
                ],
                center: .center,
                startRadius: 0,
                endRadius: size * 0.10
            ))
            .frame(width: size * 0.20, height: size * 0.10)
            .rotationEffect(.degrees(20))
            .offset(x: size * 0.18, y: size * 0.26)
            .blur(radius: 1.0)
    }

    /// Internal "nebula" — tiny particles drifting INSIDE the orb at a
    /// different velocity than the outer sparkles. Parallax = depth perception.
    /// Clipped to the orb circle so they look submerged in the body.
    private var orbNebula: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let baseAngle = Double(i) * (.pi * 2 / 6)
                let phase = sparklePhase * 0.4 + Double(i) * 0.5
                let r = size * (0.12 + 0.18 * Double((i % 3 + 1)) / 3)
                let alpha = 0.20 + 0.35 * (0.5 + 0.5 * sin(phase * 1.3 + Double(i)))
                let dotSize = size * (0.012 + 0.008 * Double(i % 3))
                Circle()
                    .fill(bright.opacity(state == .sleeping ? alpha * 0.2 : alpha))
                    .frame(width: dotSize, height: dotSize)
                    .offset(
                        x: cos(baseAngle + phase) * r,
                        y: sin(baseAngle + phase) * r * 0.85
                    )
                    .blur(radius: 0.4)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .blendMode(.screen)
    }

    private var orbEyes: some View {
        HStack(spacing: size * 0.17) {
            eyeView.rotationEffect(.degrees(eyeAngle))
            eyeView.rotationEffect(.degrees(-eyeAngle))
        }
        .offset(x: eyeLookX, y: -size * 0.02)
    }

    private var eyeView: some View {
        // slowBlink = drowsy half-close (~40% of normal height for ~400ms)
        let baseH = slowBlink ? eyeHeight * 0.30 : eyeHeight
        let h = blinking ? size * 0.025 : baseH
        let w = blinking ? eyeWidth * 1.3 : eyeWidth
        return Group {
            if happyEyes && !blinking && state != .sleeping {
                // ^_^ — closed-arc smile eye. Triggered occasionally during
                // bounces. Reads as a burst of joy.
                HappyEyeArc()
                    .stroke(Color.white,
                            style: StrokeStyle(lineWidth: max(2.0, size * 0.022),
                                               lineCap: .round))
                    .frame(width: eyeWidth * 1.5, height: eyeHeight * 0.55)
                    .shadow(color: Color.white.opacity(0.6), radius: 8)
                    .shadow(color: Color.white.opacity(0.35), radius: 14)
            } else {
                // Plain white eyes — 3 halos + crisp white capsule.
                ZStack {
                    Capsule().fill(Color.white.opacity(state == .sleeping ? 0.04 : 0.20))
                        .frame(width: w + 8, height: h + 8).blur(radius: 8)
                    Capsule().fill(Color.white.opacity(state == .sleeping ? 0.08 : 0.40))
                        .frame(width: w + 4, height: h + 4).blur(radius: 4)
                    Capsule().fill(Color.white.opacity(state == .sleeping ? 0.40 : 0.95))
                        .frame(width: w, height: h)
                    if !blinking && state != .sleeping && h > size * 0.08 {
                        Capsule().fill(Color.white)
                            .frame(width: w * 0.5, height: h * 0.15)
                            .offset(y: -h * 0.3).opacity(0.4)
                    }
                }
                .shadow(color: Color.white.opacity(0.35), radius: 12)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: happyEyes)
        .animation(.easeInOut(duration: 0.08), value: blinking)
    }

    private var eyeWidth: CGFloat {
        switch state {
        case .sleeping: return size * 0.11
        case .waking:   return size * 0.075
        case .awake:    return size * 0.075
        case .thinking: return size * 0.07
        case .happy:    return size * 0.085
        }
    }

    private var eyeHeight: CGFloat {
        switch state {
        case .sleeping: return size * 0.025
        case .waking:   return size * 0.13
        case .awake:    return size * 0.22
        case .thinking: return size * 0.16
        case .happy:    return size * 0.18
        }
    }

    // MARK: - Animations
    private func startAnimations() {
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) { floatY = -8 }
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
            glowIntensity = state == .sleeping ? 0.2 : 0.55
        }
        withAnimation(.linear(duration: 12).repeatForever(autoreverses: false)) { sparklePhase = .pi * 2 }
        withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) { breathScale = 1.025 }
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) { ringRotation = .pi * 2 }
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) { auraHue = 1.0 }
        withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) { eyeAngle = 5 }

        loopTask?.cancel()
        loopTask = Task { @MainActor in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.eyeLookLoop() }
                group.addTask { await self.blinkLoop() }
                if self.bounceEnabled {
                    group.addTask { await self.bounceLoop() }
                }
                group.addTask { await self.headTiltLoop() }
                group.addTask { await self.idleDriftLoop() }
                group.addTask { await self.magicPulseLoop() }
                group.addTask { await self.slowBlinkLoop() }
            }
        }
    }

    // MARK: - New behavior loops

    /// Curious head tilt — orb rotates a few degrees, holds, returns. Sometimes
    /// pairs with the eye look so it really feels like it's *looking* at
    /// something off-screen.
    @MainActor
    private func headTiltLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 3500...7000)))
            guard !Task.isCancelled else { break }
            let tilt = Double.random(in: 4...8) * (Bool.random() ? 1 : -1)
            withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
                headTilt = tilt
                eyeLookX = CGFloat(tilt > 0 ? -1 : 1) * size * 0.035
            }
            try? await Task.sleep(for: .milliseconds(Int.random(in: 900...1800)))
            guard !Task.isCancelled else { break }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                headTilt = 0
                eyeLookX = 0
            }
        }
    }

    /// Idle micro-drift so the orb is never *perfectly* still — sells "alive".
    @MainActor
    private func idleDriftLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 2200...4500)))
            guard !Task.isCancelled else { break }
            withAnimation(.easeInOut(duration: 1.6)) {
                idleDriftX = CGFloat.random(in: -size * 0.025...size * 0.025)
            }
        }
    }

    /// Magic pulse — every 6-12s the ring brightens and a spark wave goes out.
    /// Visualizes the orb "thinking of something". Hookable for chat states.
    @MainActor
    private func magicPulseLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 6000...12000)))
            guard !Task.isCancelled else { break }
            withAnimation(.easeOut(duration: 0.5)) { pulseBoost = 1.0 }
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { break }
            withAnimation(.easeIn(duration: 1.2)) { pulseBoost = 0.0 }
        }
    }

    /// Sleepy slow-blink — occasional drowsy half-close that lingers.
    /// Different rhythm than the regular blink so it reads as a separate "mood"
    /// rather than just a long blink.
    @MainActor
    private func slowBlinkLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(Int.random(in: 9000...18000)))
            guard !Task.isCancelled else { break }
            withAnimation(.easeInOut(duration: 0.25)) { slowBlink = true }
            try? await Task.sleep(for: .milliseconds(420))
            guard !Task.isCancelled else { break }
            withAnimation(.easeInOut(duration: 0.30)) { slowBlink = false }
        }
    }

    private func triggerBounce() {
        // ~40% of bounces also trigger happy ^_^ eyes for the duration of
        // the hop. Random so it doesn't feel mechanical.
        let goHappy = Double.random(in: 0...1) < 0.40
        Task { @MainActor in
            withAnimation(.easeIn(duration: 0.1)) { squishY = 0.85; squishX = 1.12 }
            if goHappy { happyEyes = true }
            try? await Task.sleep(for: .milliseconds(100))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                bounceY = -25; squishY = 1.1; squishX = 0.92
            }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                bounceY = 0; squishY = 0.9; squishX = 1.08
            }
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                squishY = 1.0; squishX = 1.0
            }
            // Hold the happy face a beat after landing, then drop it
            if goHappy {
                try? await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                happyEyes = false
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

// MARK: - State (shared with legacy VitaMascot callsites)

enum VitaMascotState: Equatable {
    case sleeping, waking, awake, thinking, happy
}

// MARK: - Backwards-compat alias
//
// Older callsites still pass `VitaMascot(state:size:)`. Routes to OrbMascot
// with the gold palette. (showStaff arg accepted but ignored — staff was
// retired 2026-04-18.)

struct VitaMascot: View {
    var state: VitaMascotState = .awake
    var size: CGFloat = 120
    var showStaff: Bool = false

    var body: some View {
        OrbMascot(palette: .vita, state: state, size: size)
    }
}

// MARK: - Shapes

/// ^_^ — closed-arc happy eye. Upward-curving smile-eye, like anime joy.
private struct HappyEyeArc: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.5)
            )
        }
    }
}
