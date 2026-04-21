import SwiftUI
import Sentry

// MARK: - Login Screen
// Drag interaction: Vita starts BIG at bottom (close to camera),
// user drags up -> Vita shrinks and moves to center (pushed far away).
// Tap on Vita = happy reaction. Small drag on Vita = wiggle.

struct LoginScreen: View {
    let authManager: AuthManager

    // 0 = intro (Vita big/close at bottom), 1 = revealed (Vita small/far at center)
    @State private var progress: Double = 0
    @State private var revealed = false
    @State private var loadingProvider: LoadingProvider = .none
    @State private var vitaTapped = false
    @State private var vitaDragX: CGFloat = 0

    private enum LoadingProvider { case google, apple, none }

    private let snapThreshold = 0.4

    var body: some View {
        let w = UIScreen.main.bounds.width
        let h = UIScreen.main.bounds.height
        let p = progress

        // Vita: starts huge at very bottom (barely visible head), shrinks and rises to center
        let mascotSize: CGFloat = 340 - 230 * p
        let mascotY = h * (0.98 - 0.58 * p)

        // State: sleeping -> waking -> awake, tap = happy
        let mascotState: MascotState = {
            if vitaTapped { return .happy }
            if p > 0.5 { return .awake }
            if p > 0.1 { return .waking }
            return .sleeping
        }()

        ZStack {
            // Dark starry background
            Color(red: 0.03, green: 0.02, blue: 0.04).ignoresSafeArea()

            Image("fundo-dashboard")
                .resizable()
                .scaledToFill()
                .frame(width: w, height: h)
                .clipped()
                .opacity(0.25 + 0.15 * p)
                .ignoresSafeArea()

            // Mascot
            VitaMascot(state: mascotState, size: mascotSize, showStaff: false)
                .offset(x: vitaDragX)
                .position(x: w / 2, y: mascotY)
                .onTapGesture {
                    guard revealed else { return }
                    vitaTapped = true
                    // Reset after bounce animation
                    Task {
                        try? await Task.sleep(for: .seconds(1.2))
                        withAnimation(.easeOut(duration: 0.3)) { vitaTapped = false }
                    }
                }
                .gesture(
                    revealed ?
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            withAnimation(.interactiveSpring()) {
                                vitaDragX = value.translation.width * 0.4
                            }
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                                vitaDragX = 0
                            }
                            // Trigger happy on release
                            vitaTapped = true
                            Task {
                                try? await Task.sleep(for: .seconds(1.0))
                                withAnimation(.easeOut(duration: 0.3)) { vitaTapped = false }
                            }
                        }
                    : nil
                )

            // Intro text
            if p < 0.3 {
                Text("Uma nova era de\nestudos est\u{00E1} aqui.")
                    .font(.system(size: 34, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .position(x: w / 2, y: h * 0.32)
                    .opacity(1.0 - p / 0.25)
            }

            // Swipe hint
            if p < 0.2 {
                VStack(spacing: 8) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.white.opacity(0.4))
                    Text("ARRASTE PARA CIMA")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(2.4)
                        .foregroundStyle(.white.opacity(0.35))
                }
                .position(x: w / 2, y: h * 0.68)
                .opacity(1.0 - p / 0.15)
            }

            // Reveal headline
            if p > 0.6 {
                VStack(spacing: 8) {
                    Text("Conhe\u{00E7}a o Vita.")
                        .font(.system(size: 38, weight: .light, design: .serif))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("O futuro dos seus estudos\ncome\u{00E7}a agora.")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .position(x: w / 2, y: h * 0.60)
                .opacity(min(1, (p - 0.6) / 0.25))
            }

            // Buttons
            if p > 0.85 {
                VStack(spacing: 0) {
                    Spacer()

                    if authManager.isLoading {
                        ProgressView()
                            .tint(VitaColors.accent)
                            .scaleEffect(1.2)
                        Spacer().frame(height: 40)
                    } else {
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

                        Spacer().frame(height: 12)

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
                    }

                    if let error = authManager.error {
                        Text(error)
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                            .padding(.horizontal, 36)
                    }

                    Spacer().frame(height: 16)

                    (Text("Ao continuar voc\u{00EA} concorda com os ")
                        .foregroundColor(VitaColors.textTertiary) +
                    Text("Termos de Uso")
                        .foregroundColor(VitaColors.textSecondary)
                        .underline() +
                    Text(" e ")
                        .foregroundColor(VitaColors.textTertiary) +
                    Text("Pol\u{00ED}tica de Privacidade")
                        .foregroundColor(VitaColors.textSecondary)
                        .underline())
                    .font(VitaTypography.labelSmall)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 48)

                    Spacer().frame(height: 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity.combined(with: .offset(y: 20)))
                .opacity(min(1, (p - 0.85) / 0.15))
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !revealed {
                        let drag = -value.translation.height / (UIScreen.main.bounds.height * 0.45)
                        withAnimation(.interactiveSpring()) {
                            progress = max(0, min(1, drag))
                        }
                    }
                }
                .onEnded { _ in
                    if !revealed {
                        if progress > snapThreshold {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                progress = 1.0
                                revealed = true
                            }
                        } else {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                progress = 0
                            }
                        }
                    }
                }
        )
        .onChange(of: authManager.isLoading) { _, newValue in
            if !newValue { loadingProvider = .none }
        }
        .onAppear { SentrySDK.reportFullyDisplayed() }
        .trackScreen("Login")
    }
}

// MARK: - Google icon

private struct GoogleIcon: View {
    var body: some View {
        Image(systemName: "g.circle.fill")
            .font(.system(size: 20))
            .foregroundStyle(Color.white)
    }
}
