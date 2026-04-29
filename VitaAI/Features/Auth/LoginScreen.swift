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
    @State private var hintBounce: CGFloat = 0

    private enum LoadingProvider { case google, apple, none }

    // Asymmetric snap: easier to commit to revealed (0.4 going up) but ALSO
    // easier to dismiss back (0.55 going down). Velocity also pulls toward the
    // intended end so a flick reverts even with small distance.
    private let snapThreshold = 0.5

    var body: some View {
        let w = UIScreen.main.bounds.width
        let h = UIScreen.main.bounds.height
        let p = progress

        // Vita: starts HUGE peeking from below the screen edge (~25% of head visible,
        // eyes hidden, no idle motion — looks like it's sleeping). As user drags up,
        // it shrinks, rises to center, eyes fade in and progressively widen.
        let mascotSize: CGFloat = 620 - 510 * p
        let mascotY = h * (1.18 - 0.78 * p)

        // State: sleeping -> waking -> awake, tap = happy.
        // Lower waking threshold so eyes start opening AS SOON AS the drag begins.
        let mascotState: VitaMascotState = {
            if vitaTapped { return .happy }
            if p > 0.55 { return .awake }
            if p > 0.04 { return .waking }
            return .sleeping
        }()
        // Freeze idle motion + hide eyes while sleeping (peeking under the screen).
        let mascotIdle = mascotState != .sleeping

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
            VitaMascot(state: mascotState, size: mascotSize, showStaff: false, idleEnabled: mascotIdle)
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

            // Intro text — espelha pattern do Pixio (Rafael 2026-04-28)
            if p < 0.3 {
                Text("O futuro dos seus estudos\ncome\u{00E7}a aqui.")
                    .font(.system(size: 34, weight: .light, design: .serif))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .position(x: w / 2, y: h * 0.32)
                    .opacity(1.0 - p / 0.25)
            }

            // Swipe hint — sits right above Vita's head, double chevron with
            // staggered upward bounce so it reads as motion guidance.
            if p < 0.2 {
                VStack(spacing: 6) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white.opacity(0.55))
                        .offset(y: hintBounce)
                    Image(systemName: "chevron.up")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                        .offset(y: hintBounce * 0.5)
                    Text("ARRASTE PARA CIMA")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(3.0)
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.top, 4)
                }
                .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 4)
                // Anchor right above Vita's visible head — top of mascot minus a small gap.
                .position(x: w / 2, y: max(h * 0.55, mascotY - mascotSize / 2 - 70))
                .opacity(1.0 - p / 0.18)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                        hintBounce = -8
                    }
                }
            }

            // Reveal headline — espelha pattern do Pixio (Rafael 2026-04-28)
            if p > 0.6 {
                VStack(spacing: 8) {
                    Text("Conhe\u{00E7}a Vita")
                        .font(.system(size: 38, weight: .light, design: .serif))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("Seu agente de estudos pessoal")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .position(x: w / 2, y: h * 0.60)
                .opacity(min(1, (p - 0.6) / 0.25))
            }

            // Buttons — staggered entrance (BYMAV shell canon: each CTA appears
            // ~0.05 progress units after the previous one, riding up from y+20).
            // Drives the "wave" feel without timers; pure progress-bound.
            if p > 0.85 {
                let googleAppear = min(1, max(0, (p - 0.85) / 0.10))
                let appleAppear  = min(1, max(0, (p - 0.90) / 0.10))
                let legalAppear  = min(1, max(0, (p - 0.95) / 0.05))

                VStack(spacing: 0) {
                    Spacer()

                    if authManager.isLoading {
                        ProgressView()
                            .tint(VitaColors.accent)
                            .scaleEffect(1.2)
                        Spacer().frame(height: 40)
                    } else {
                        // Google first (Rafael preference — favored login path).
                        // Apple HIG 4.8 requires Sign-in-with-Apple to *exist* when
                        // 3rd-party providers are present, not to be at the top.
                        SocialAuthButton(
                            provider: .google,
                            label: "Continuar com Google",
                            isLoading: loadingProvider == .google
                        ) {
                            loadingProvider = .google
                            authManager.signInWithGoogle()
                        }
                        .padding(.horizontal, 36)
                        .opacity(googleAppear)
                        .offset(y: (1 - googleAppear) * 20)

                        Spacer().frame(height: 12)

                        SocialAuthButton(
                            provider: .apple,
                            label: "Continuar com Apple",
                            isLoading: loadingProvider == .apple
                        ) {
                            loadingProvider = .apple
                            authManager.signInWithApple()
                        }
                        .padding(.horizontal, 36)
                        .opacity(appleAppear)
                        .offset(y: (1 - appleAppear) * 20)
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

                    // Legal links — Link opens Safari externally (App Store gold standard
                    // for Terms/Privacy). HStack avoids tap propagation to background drag
                    // gesture that was logging the user in by accident.
                    VStack(spacing: 4) {
                        Text("Ao continuar voc\u{00EA} concorda com os")
                            .foregroundColor(VitaColors.textTertiary)
                        HStack(spacing: 4) {
                            // Use canonical PT-BR URLs directly (the en /terms /privacy
                            // routes are kept for Google Play submission only — they 307 here).
                            Link(destination: URL(string: "https://vita-ai.cloud/termos")!) {
                                Text("Termos de Uso")
                                    .foregroundColor(VitaColors.textSecondary)
                                    .underline()
                            }
                            Text("e")
                                .foregroundColor(VitaColors.textTertiary)
                            Link(destination: URL(string: "https://vita-ai.cloud/privacidade")!) {
                                Text("Pol\u{00ED}tica de Privacidade")
                                    .foregroundColor(VitaColors.textSecondary)
                                    .underline()
                            }
                        }
                    }
                    .font(VitaTypography.labelSmall)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 48)
                    .opacity(legalAppear)
                    .offset(y: (1 - legalAppear) * 12)

                    // Extra breathing room above the home indicator.
                    Spacer().frame(height: 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        // Bidirectional drag — pull up to reveal, pull down to put Vita back
        // to sleep. simultaneousGesture coexists with Button/Link taps (the
        // higher minimumDistance still gives them priority for short touches).
        // Velocity is folded into the snap decision so a flick down reverts
        // even if the user only moved the finger ~10% of the screen.
        .simultaneousGesture(
            DragGesture(minimumDistance: 18)
                .onChanged { value in
                    let base: Double = revealed ? 1.0 : 0.0
                    let delta = -Double(value.translation.height) / Double(UIScreen.main.bounds.height * 0.45)
                    withAnimation(.interactiveSpring()) {
                        progress = max(0, min(1, base + delta))
                    }
                }
                .onEnded { value in
                    // Velocity-aware snap: predicted end translation tells us where the
                    // finger is "heading", so a quick downward flick reverts even with
                    // small distance. predicted.y > 0 means finger is moving DOWN.
                    let predictedY = value.predictedEndTranslation.height
                    let projectedProgress: Double = {
                        if revealed && predictedY > 200 { return 0 }   // strong flick down → revert
                        if !revealed && predictedY < -200 { return 1 } // strong flick up → reveal
                        return progress > snapThreshold ? 1 : 0
                    }()
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                        progress = projectedProgress
                        revealed = projectedProgress > 0.5
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

