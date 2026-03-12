import SwiftUI

// MARK: - WelcomeStep
// Matches mockup onboarding step 1:
// - Mascot caduceu dourado centralizado com glow ring pulsante
// - "VITA" label em gold uppercase
// - Texto conversacional "Olá, [nome]"
// - Campo nome com glass effect + focus gold border
// - Energia do mascot aumenta conforme usuário preenche (ob-e20 → ob-e100)

struct WelcomeStep: View {
    @Bindable var viewModel: OnboardingViewModel
    @FocusState private var nameFocused: Bool

    @State private var iconVisible = false
    @State private var titleVisible = false
    @State private var subtitleVisible = false
    @State private var fieldVisible = false
    @State private var glowPulse = false

    // Mascot energy level based on name fill — matches mockup ob-e20..ob-e100
    private var energyLevel: Double {
        let name = viewModel.nickname.trimmingCharacters(in: .whitespaces)
        if name.isEmpty { return 0.20 }
        if name.count < 2 { return 0.50 }
        if name.count < 4 { return 0.80 }
        return 1.00
    }

    private var mascotGlowOpacity: Double { energyLevel * 0.25 }
    private var mascotRingOpacity: Double { energyLevel * 0.60 }
    private var mascotIconBrightness: Double { 0.50 + energyLevel * 0.50 }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Spacer().frame(height: 40)

                // Hero: caduceu gold com glow pulsante
                ZStack {
                    // Outer ambient glow (ob-mascot-glow)
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    VitaColors.accent.opacity(mascotGlowOpacity),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 56
                            )
                        )
                        .frame(width: 112, height: 112)
                        .scaleEffect(glowPulse ? 1.05 : 0.95)
                        .opacity(iconVisible ? 1.0 : 0.0)

                    // Ring border (ob-mascot-ring)
                    Circle()
                        .stroke(
                            VitaColors.accent.opacity(mascotRingOpacity),
                            lineWidth: energyLevel >= 1.0 ? 1.5 : 1.0
                        )
                        .frame(width: 108, height: 108)
                        .scaleEffect(iconVisible ? 1.0 : 0.5)
                        .opacity(iconVisible ? 1.0 : 0.0)
                        .animation(.spring(response: 0.6, dampingFraction: 0.65), value: iconVisible)
                        .animation(.easeInOut(duration: 0.5), value: energyLevel)

                    // Inner circle background (ob-mascot-inner)
                    Circle()
                        .fill(VitaColors.accent.opacity(0.06 + energyLevel * 0.14))
                        .frame(width: 80, height: 80)
                        .scaleEffect(iconVisible ? 1.0 : 0.5)
                        .opacity(iconVisible ? 1.0 : 0.0)
                        .animation(.spring(response: 0.5, dampingFraction: 0.6), value: iconVisible)
                        .animation(.easeInOut(duration: 0.5), value: energyLevel)

                    // Caduceu icon — gold, brightness matches energy
                    Image(systemName: "staroflife.fill")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [VitaColors.accentLight, VitaColors.accent],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .brightness(mascotIconBrightness - 1.0)
                        .shadow(color: VitaColors.accent.opacity(0.6), radius: 8, x: 0, y: 2)
                        .scaleEffect(iconVisible ? (energyLevel >= 1.0 ? 1.03 : 1.0) : 0.3)
                        .opacity(iconVisible ? 1.0 : 0.0)
                        .animation(.spring(response: 0.55, dampingFraction: 0.6).delay(0.05), value: iconVisible)
                        .animation(.easeInOut(duration: 0.5), value: energyLevel)
                }
                .animation(
                    energyLevel >= 1.0
                        ? .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
                        : .default,
                    value: glowPulse
                )

                Spacer().frame(height: 24)

                // VITA label em gold (ob-label)
                Text("VITA")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VitaColors.accent.opacity(0.50))
                    .tracking(1.5)
                    .opacity(titleVisible ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.3).delay(0.10), value: titleVisible)

                Spacer().frame(height: 8)

                // Texto conversacional — "Olá, [nome]" (ob-text com highlight)
                Group {
                    let name = viewModel.nickname.trimmingCharacters(in: .whitespaces)
                    if name.isEmpty {
                        Text("Sou seu assistente de estudos.\nComo posso te chamar?")
                            .font(VitaTypography.bodyLarge)
                            .foregroundStyle(VitaColors.textPrimary.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    } else {
                        // ob-text .hl = gold highlight
                        (Text("Olá, ")
                            .foregroundStyle(VitaColors.textPrimary.opacity(0.85))
                         + Text(name)
                            .foregroundStyle(VitaColors.goldText)
                            .fontWeight(.medium)
                         + Text("!\nPronto pra dominar a medicina?")
                            .foregroundStyle(VitaColors.textPrimary.opacity(0.85))
                        )
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                    }
                }
                .font(VitaTypography.bodyLarge)
                .multilineTextAlignment(.center)
                .offset(y: titleVisible ? 0 : 16)
                .opacity(titleVisible ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.4).delay(0.15), value: titleVisible)
                .animation(.easeInOut(duration: 0.3), value: viewModel.nickname)

                Spacer().frame(height: 40)

                // Campo nome com glass effect (ob-input)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Seu nome")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(VitaColors.textTertiary)
                        .tracking(1.0)
                        .textCase(.uppercase)

                    HStack(spacing: 12) {
                        Image(systemName: "person")
                            .foregroundStyle(
                                nameFocused
                                    ? VitaColors.accent.opacity(0.70)
                                    : VitaColors.textTertiary
                            )
                            .frame(width: 20)
                            .animation(.easeInOut(duration: 0.15), value: nameFocused)

                        TextField("Como quer ser chamado?", text: $viewModel.nickname)
                            .foregroundStyle(VitaColors.textPrimary)
                            .font(VitaTypography.bodyLarge)
                            .tint(VitaColors.accent)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit { nameFocused = false }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                    .background(
                        nameFocused
                            ? VitaColors.accent.opacity(0.05)
                            : Color.white.opacity(0.03)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                nameFocused
                                    ? VitaColors.accent.opacity(0.30)
                                    : VitaColors.glassBorder,
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: nameFocused ? VitaColors.accent.opacity(0.06) : .clear,
                        radius: 12, x: 0, y: 2
                    )
                    .animation(.easeInOut(duration: 0.20), value: nameFocused)
                }
                .offset(y: fieldVisible ? 0 : 16)
                .opacity(fieldVisible ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.4).delay(0.30), value: fieldVisible)

                Spacer().frame(height: 32)
            }
            .padding(.horizontal, 28)
        }
        .scrollDismissesKeyboard(.interactively)
        .onTapGesture { nameFocused = false }
        .onAppear {
            iconVisible   = true
            titleVisible  = true
            subtitleVisible = true
            fieldVisible  = true
            // Start glow pulse when energy is max
            if energyLevel >= 1.0 { glowPulse = true }
        }
        .onChange(of: energyLevel) { _, newVal in
            if newVal >= 1.0 {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    glowPulse = true
                }
            } else {
                glowPulse = false
            }
        }
    }
}
