import SwiftUI

// MARK: - Pro features list
// Mirrors Android VitaPaywallScreen.kt proFeatures list

private let proFeatures: [(icon: String, text: String)] = [
    ("mic.fill",           "Voice Tutor — converse com a Vita por voz"),
    ("stethoscope",        "OSCE — simulacoes de exame clinico"),
    ("waveform",           "Transcricao de aulas em tempo real"),
    ("photo.on.rectangle", "Analise de imagens medicas"),
    ("bubble.left.and.bubble.right.fill", "Historico ilimitado de conversas"),
    ("calendar.badge.clock", "Plano de estudos personalizado com IA"),
]

// MARK: - PaywallScreen
// Mirrors Android: VitaPaywallScreen.kt
// Entrance animations: hero (400ms) → features (+80ms delay, 400ms) → cta (+60ms delay, 350ms)

struct PaywallScreen: View {
    @Environment(\.appContainer) private var container
    @Environment(\.subscriptionStatus) private var subStatus
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PaywallViewModel?

    // Entrance animation states
    @State private var heroOpacity: Double = 0
    @State private var heroOffset: CGFloat = 30
    @State private var featuresOpacity: Double = 0
    @State private var featuresOffset: CGFloat = 24
    @State private var ctaOpacity: Double = 0
    @State private var ctaOffset: CGFloat = 16

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            if let vm = viewModel {
                mainContent(vm: vm)
            } else {
                ProgressView().tint(VitaColors.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = PaywallViewModel(api: container.api)
                viewModel = vm
                Task {
                    await vm.loadStatus()
                    runEntranceAnimations()
                }
            }
        }
        .onDisappear {
            // Refresh global subscription status when leaving paywall
            // (user may have completed Stripe checkout in Safari).
            Task { await subStatus.refresh() }
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func mainContent(vm: PaywallViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Top bar with back/close button
                topBar

                VStack(spacing: 0) {
                    // Hero section
                    heroSection
                        .opacity(heroOpacity)
                        .offset(y: heroOffset)

                    Spacer().frame(height: 32)

                    // Features card
                    featuresCard
                        .opacity(featuresOpacity)
                        .offset(y: featuresOffset)
                        .padding(.horizontal, 20)

                    Spacer().frame(height: 32)

                    // CTA section
                    ctaSection(vm: vm)
                        .opacity(ctaOpacity)
                        .offset(y: ctaOffset)
                        .padding(.horizontal, 20)

                    // Legal links
                    legalLinks
                        .opacity(ctaOpacity)

                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 0)
            }
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(VitaColors.glassBg)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Hero section

    private var heroSection: some View {
        VStack(spacing: 0) {
            // Diamond badge (radial gradient like Android)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                VitaColors.accent.opacity(0.9),
                                VitaColors.accent.opacity(0.35),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "diamond.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(VitaColors.black)
            }
            .padding(.bottom, 20)

            Text("VitaAI Pro")
                .font(VitaTypography.headlineLarge)
                .foregroundStyle(VitaColors.white)

            Spacer().frame(height: 8)

            Text("Estude mais rapido com IA avancada")
                .font(VitaTypography.bodyLarge)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)

            Spacer().frame(height: 24)

            // Price display — mirrors Android price tag layout
            priceTag
        }
        .padding(.horizontal, 20)
    }

    private var priceTag: some View {
        HStack(alignment: .bottom, spacing: 2) {
            Text("R$")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(VitaColors.accent)
                .padding(.bottom, 8)

            Spacer().frame(width: 2)

            Text("39")
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(VitaColors.accent)

            Text("/mes")
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textSecondary)
                .padding(.bottom, 10)
        }
    }

    // MARK: - Features card

    private var featuresCard: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 20) {
                Text("O que esta incluido")
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                VStack(spacing: 16) {
                    ForEach(proFeatures, id: \.text) { feature in
                        ProFeatureRow(icon: feature.icon, text: feature.text)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - CTA section

    @ViewBuilder
    private func ctaSection(vm: PaywallViewModel) -> some View {
        VStack(spacing: 12) {
            if vm.state.isPro {
                // Already subscribed
                alreadyProCard(periodEnd: vm.state.periodEnd)
            } else {
                // Subscribe CTA
                subscribeCTA(vm: vm)
            }

            if let error = vm.state.error {
                Text(error)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.dataRed)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func alreadyProCard(periodEnd: String?) -> some View {
        VitaGlassCard {
            VStack(spacing: 8) {
                Text("Voce ja e Pro!")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.accent)

                if let end = periodEnd {
                    Text("Valido ate \(end)")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
        }
    }

    @ViewBuilder
    private func subscribeCTA(vm: PaywallViewModel) -> some View {
        // Primary subscribe button
        Button(action: {
            Task { await vm.startCheckout() }
        }) {
            HStack(spacing: 8) {
                if vm.state.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: VitaColors.black))
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("Assinar Pro")
                        .font(VitaTypography.titleSmall)
                }
            }
            .foregroundStyle(vm.state.isLoading ? VitaColors.black.opacity(0.6) : VitaColors.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                vm.state.isLoading
                    ? VitaColors.accent.opacity(0.6)
                    : VitaColors.accent
            )
            .clipShape(RoundedRectangle(cornerRadius: VitaTokens.Radius.lg))
        }
        .buttonStyle(.plain)
        .disabled(vm.state.isLoading)
        .sensoryFeedback(.impact(weight: .heavy), trigger: vm.state.isLoading)
        .animation(.easeInOut(duration: VitaTokens.Animation.durationFast), value: vm.state.isLoading)

        // Restore purchase ghost button
        Button(action: {
            Task { await vm.restorePurchase() }
        }) {
            Text("Restaurar compra")
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
        }
        .buttonStyle(.plain)
        .disabled(vm.state.isLoading)
    }

    // MARK: - Legal links

    private var legalLinks: some View {
        HStack(spacing: 16) {
            Link(destination: URL(string: "https://vita-ai.cloud/terms")!) {
                Text("Termos de Uso")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }

            Text("•")
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)

            Link(destination: URL(string: "https://vita-ai.cloud/privacy")!) {
                Text("Privacidade")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    // MARK: - Entrance animations
    // Mirrors Android: heroAnim(400ms) → delay 80ms → featuresAnim(400ms) → delay 60ms → ctaAnim(350ms)

    private func runEntranceAnimations() {
        withAnimation(.easeOut(duration: 0.4)) {
            heroOpacity = 1
            heroOffset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.48) {
            withAnimation(.easeOut(duration: 0.4)) {
                featuresOpacity = 1
                featuresOffset = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.54) {
            withAnimation(.easeOut(duration: 0.35)) {
                ctaOpacity = 1
                ctaOffset = 0
            }
        }
    }
}

// MARK: - ProFeatureRow
// Mirrors Android: ProFeatureRow composable

private struct ProFeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(VitaColors.accent.opacity(0.15))
                    .frame(width: 28, height: 28)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VitaColors.accent)
            }

            Text(text)
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Paywall — Free user") {
    PaywallScreen()
        .environment(\.appContainer, AppContainer())
        .preferredColorScheme(.dark)
}
#endif
