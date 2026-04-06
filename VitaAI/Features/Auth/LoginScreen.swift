import SwiftUI

struct LoginScreen: View {
    let authManager: AuthManager

    @State private var imageOpacity: Double = 0
    @State private var showGoogle = false
    @State private var showApple = false
    @State private var showEmail = false
    @State private var showFooter = false
    @State private var loadingProvider: LoadingProvider = .none
    @State private var glowStarted = false
    @State private var showEmailSheet = false

    private enum LoadingProvider {
        case google, apple, none
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Background logo image — fades smoothly into black via mask (no hard line)
            VStack {
                ZStack {
                    Image("login_bg")
                        .resizable()
                        .scaledToFill()  // fills edge-to-edge, no black bars
                        .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.82)
                        .clipped()
                        .opacity(imageOpacity)

                    // Organic glow overlay
                    if glowStarted {
                        OrganicGlowCanvas()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.height * 0.82)
                .mask(
                    // Fade image to transparent at bottom — no hard clip line
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.50),
                            .init(color: .black.opacity(0.3), location: 0.80),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Spacer()
            }

            // Buttons + footer — pinned to bottom third of screen
            VStack(spacing: 0) {
                Spacer(minLength: UIScreen.main.bounds.height * 0.72)  // buttons ~bottom 28%


                if authManager.isLoading {
                    ProgressView()
                        .tint(VitaColors.accent)
                        .scaleEffect(1.2)
                    Spacer().frame(height: 40)
                } else {
                    // Google
                    if showGoogle {
                        GlassAuthButton(
                            label: "Continuar com Google",
                            icon: AnyView(GoogleIcon()),
                            isPrimary: true,
                            isLoading: loadingProvider == .google
                        ) {
                            loadingProvider = .google
                            authManager.signInWithGoogle()
                        }
                        .padding(.horizontal, 36)
                        .transition(.opacity.combined(with: .offset(y: 14)))  // Android: slideInVertically { h/3 } = 14pt
                    }

                    Spacer().frame(height: 12)

                    // Apple
                    if showApple {
                        GlassAuthButton(
                            label: "Continuar com Apple",
                            icon: AnyView(
                                Image(systemName: "apple.logo")
                                    .font(.system(size: 18))
                                    .foregroundStyle(VitaColors.white)
                            ),
                            isLoading: loadingProvider == .apple
                        ) {
                            loadingProvider = .apple
                            authManager.signInWithApple()
                        }
                        .padding(.horizontal, 36)
                        .transition(.opacity.combined(with: .offset(y: 14)))  // Android: slideInVertically { h/3 } = 14pt
                    }

                    Spacer().frame(height: 12)

                    // Email
                    if showEmail {
                        GlassAuthButton(
                            label: "Continuar com Email",
                            icon: AnyView(
                                Image(systemName: "envelope")
                                    .font(.system(size: 16))
                                    .foregroundColor(VitaColors.textSecondary)
                            ),
                            isLoading: false
                        ) {
                            showEmailSheet = true
                        }
                        .padding(.horizontal, 36)
                        .transition(.opacity.combined(with: .offset(y: 14)))  // Android: slideInVertically { h/3 } = 14pt
                    }
                }

                // Error
                if let error = authManager.error {
                    Text(error)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                        .padding(.horizontal, 36)
                }

                Spacer().frame(height: 16)

                // Legal footer — frame(maxWidth) ensures text wraps within screen bounds
                if showFooter {
                    (Text("Ao continuar voce concorda com os ")
                        .foregroundColor(VitaColors.textTertiary) +
                    Text("Termos de Uso")
                        .foregroundColor(VitaColors.textSecondary)
                        .underline() +
                    Text(" e ")
                        .foregroundColor(VitaColors.textTertiary) +
                    Text("Politica de Privacidade")
                        .foregroundColor(VitaColors.textSecondary)
                        .underline())
                    .font(VitaTypography.labelSmall)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)   // forces wrapping within screen width
                    .padding(.horizontal, 48)     // matches Android: Column(h=36) + Text(h=12) = 48dp
                    .transition(.opacity)
                }

                Spacer().frame(height: 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)  // fills ZStack so Spacer() pushes buttons to bottom
        }
        .ignoresSafeArea()  // full bleed — no black bars at top/bottom from safe area
        .sheet(isPresented: $showEmailSheet) {
            EmailAuthSheet(authManager: authManager)
        }
        .onChange(of: authManager.isLoading) { _, newValue in
            if !newValue {
                loadingProvider = .none
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5)) { imageOpacity = 1 }
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(.easeOut(duration: 0.8)) { showGoogle = true }
                try? await Task.sleep(for: .seconds(0.1))
                withAnimation(.easeOut(duration: 0.8)) { showApple = true }
                try? await Task.sleep(for: .seconds(0.1))
                withAnimation(.easeOut(duration: 0.8)) { showEmail = true }
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(.easeOut(duration: 0.6)) { showFooter = true }
                glowStarted = true
            }
        }
    }
}

// MARK: - Organic glow (matches Android BrandConfig glow system)

private struct OrganicGlowCanvas: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate

                // Co-prime durations = no visible loop
                let glowA = (sin(t * 0.886) + 1) / 2  // ~7.1s period
                let glowB = (sin(t * 1.461) + 1) / 2  // ~4.3s period
                let glowC = (sin(t * 2.166) + 1) / 2  // ~2.9s period
                let composite = glowA * 0.45 + glowB * 0.35 + glowC * 0.2

                let cx = size.width * 0.5
                let glowTop = size.height * 0.15
                let glowBottom = size.height * 0.65

                // 1. Core radial glow — organic breathing
                let baseAlpha = composite * 0.18
                let radius = size.width * (0.35 + composite * 0.08)
                let centerDriftX = cx + sin(glowA * .pi) * size.width * 0.02
                let centerDriftY = size.height * 0.38 + sin(glowB * .pi) * size.height * 0.01
                context.fill(
                    Path(ellipseIn: CGRect(x: centerDriftX - radius, y: centerDriftY - radius,
                                          width: radius * 2, height: radius * 2)),
                    with: .radialGradient(
                        Gradient(colors: [
                            VitaColors.accent.opacity(baseAlpha),
                            VitaColors.accent.opacity(baseAlpha * 0.25),
                            .clear
                        ]),
                        center: CGPoint(x: centerDriftX, y: centerDriftY),
                        startRadius: 0, endRadius: radius
                    )
                )

                // 2. Light sweep A — slow diagonal
                let sweepA = fmod(t / 8.3, 1.0)
                if sweepA > 0 && sweepA < 1 {
                    let sxA = size.width * sweepA
                    let intensity = 0.08 * (1 - 2 * abs(sweepA - 0.5))
                    context.fill(
                        Path(CGRect(x: 0, y: 0, width: size.width, height: size.height)),
                        with: .linearGradient(
                            Gradient(colors: [
                                .clear,
                                VitaColors.accent.opacity(intensity * 0.4),
                                Color.white.opacity(intensity),
                                VitaColors.accent.opacity(intensity * 0.4),
                                .clear
                            ]),
                            startPoint: CGPoint(x: sxA - size.width * 0.12, y: glowTop),
                            endPoint: CGPoint(x: sxA + size.width * 0.12, y: glowBottom)
                        )
                    )
                }

                // 3. Head highlight
                let headAlpha = (glowB * 0.6 + glowC * 0.4) * 0.10
                let headRadius = size.width * 0.13
                let headCenter = CGPoint(x: cx, y: glowTop + size.height * 0.04)
                context.fill(
                    Path(ellipseIn: CGRect(x: headCenter.x - headRadius, y: headCenter.y - headRadius,
                                          width: headRadius * 2, height: headRadius * 2)),
                    with: .radialGradient(
                        Gradient(colors: [VitaColors.accent.opacity(headAlpha), .clear]),
                        center: headCenter, startRadius: 0, endRadius: headRadius
                    )
                )
            }
        }
    }
}

// MARK: - Google icon

private struct GoogleIcon: View {
    var body: some View {
        // Real Google G SVG paths rendered as SwiftUI shapes
        ZStack {
            Image(systemName: "g.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.white)
        }
    }
}
