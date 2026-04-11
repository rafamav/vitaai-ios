import SwiftUI
import StoreKit
import SafariServices

// MARK: - VitaPaywallScreen
// Rebuild 2026-04-11: starry background, VitaMascot watching from bottom,
// 3 tiers (Free/Premium/Pro) in vertical stack. Large, reliable tap targets
// (no horizontal carousel — old version had broken hit-testing).
//
// Feature placement is tier-based and CONTROLLED VIA `tierFeatures` below —
// move features between tiers by editing that single array. UI reads from it.
//
// Payment: StoreKit 2 primary. Stripe web-checkout fallback if products fail to load.

// MARK: - Plan tier model

enum PlanTier: String, CaseIterable, Identifiable {
    case free, premium, pro
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .free:    return "Free"
        case .premium: return "Premium"
        case .pro:     return "Pro"
        }
    }

    var monthlyPriceLabel: String {
        switch self {
        case .free:    return "R$ 0"
        case .premium: return "R$ 24,90"
        case .pro:     return "R$ 49,90"
        }
    }

    var tagline: String {
        switch self {
        case .free:    return "Comece sem pagar"
        case .premium: return "Destrava a IA do Vita"
        case .pro:     return "Tudo que temos, sem limite"
        }
    }

    /// Associated StoreKit product ID (nil = free).
    var productID: String? {
        switch self {
        case .free:    return nil
        case .premium: return StoreKitManager.premiumProductID
        case .pro:     return StoreKitManager.proProductID
        }
    }
}

// MARK: - Feature catalog
// Source of truth for which features belong to which tier.
// Moving a feature between tiers = change `tier` field. UI auto-updates.

private struct TierFeature: Identifiable {
    let id: String
    let label: String
    let tier: PlanTier   // minimum tier required
    let icon: String     // SF Symbol
}

private let tierFeatures: [TierFeature] = [
    // Free tier
    .init(id: "flashcards",  label: "Flashcards ilimitados",          tier: .free,    icon: "rectangle.stack.fill"),
    .init(id: "qbank",       label: "QBank de questões ilimitado",    tier: .free,    icon: "questionmark.circle.fill"),
    .init(id: "simulados",   label: "Simulados completos",            tier: .free,    icon: "doc.text.fill"),
    .init(id: "conectores",  label: "Conectores ULBRA / Mannesoft",   tier: .free,    icon: "link.circle.fill"),
    .init(id: "notas",       label: "Notas e caderno digital",        tier: .free,    icon: "note.text"),

    // Premium tier
    .init(id: "chat_ia",     label: "Vita Chat IA ilimitado",         tier: .premium, icon: "sparkles"),
    .init(id: "osce",        label: "OSCE clínico interativo",        tier: .premium, icon: "stethoscope"),
    .init(id: "atlas_3d",    label: "Atlas 3D de anatomia",           tier: .premium, icon: "brain.head.profile"),
    .init(id: "upload_pdf",  label: "Upload e análise de PDFs",       tier: .premium, icon: "doc.badge.arrow.up"),

    // Pro tier
    .init(id: "transcricao", label: "Transcrição de aulas",           tier: .pro,     icon: "waveform"),
    .init(id: "voz",         label: "Modo voz com o Vita",            tier: .pro,     icon: "mic.fill"),
    .init(id: "vita_game",   label: "VITA GAME (em breve)",           tier: .pro,     icon: "gamecontroller.fill"),
    .init(id: "early",       label: "Acesso antecipado a features",   tier: .pro,     icon: "star.fill"),
    .init(id: "priority",    label: "Atendimento prioritário",        tier: .pro,     icon: "bolt.fill")
]

private func features(for tier: PlanTier) -> [TierFeature] {
    tierFeatures.filter { $0.tier == tier }
}

/// Returns a feature list that represents EVERYTHING unlocked at the given tier
/// (accumulates lower tiers — Pro includes Premium + Free).
private func cumulativeFeatures(upTo tier: PlanTier) -> [TierFeature] {
    switch tier {
    case .free:    return features(for: .free)
    case .premium: return features(for: .free) + features(for: .premium)
    case .pro:     return features(for: .free) + features(for: .premium) + features(for: .pro)
    }
}

// MARK: - Screen

struct VitaPaywallScreen: View {
    @Environment(\.appContainer) private var container
    @State private var storeKit = StoreKitManager()

    let onDismiss: () -> Void

    @State private var selectedTier: PlanTier = .premium
    @State private var mascotState: MascotState = .awake
    @State private var headerVisible = false
    @State private var cardsVisible = false
    @State private var isLoadingStripe = false
    @State private var stripeError: String? = nil
    @State private var showSuccess = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                starryBackground(w: w, h: h)

                ScrollView {
                    VStack(spacing: 20) {
                        topBar
                            .padding(.top, 8)
                            .opacity(headerVisible ? 1 : 0)
                            .offset(y: headerVisible ? 0 : -12)

                        header
                            .opacity(headerVisible ? 1 : 0)
                            .offset(y: headerVisible ? 0 : -8)

                        VStack(spacing: 14) {
                            ForEach(PlanTier.allCases) { tier in
                                PlanCard(
                                    tier: tier,
                                    isSelected: selectedTier == tier,
                                    product: product(for: tier),
                                    onTap: { select(tier) },
                                    onSubscribe: { handleSubscribe(tier) },
                                    isPurchasing: storeKit.isPurchasing && selectedTier == tier
                                )
                                .opacity(cardsVisible ? 1 : 0)
                                .offset(y: cardsVisible ? 0 : 20)
                                .animation(
                                    .spring(response: 0.5, dampingFraction: 0.8)
                                        .delay(Double(PlanTier.allCases.firstIndex(of: tier) ?? 0) * 0.08),
                                    value: cardsVisible
                                )
                            }
                        }
                        .padding(.horizontal, 16)

                        errorBanner

                        legalLinks
                            .padding(.top, 8)

                        // Leave room at bottom so mascot doesn't overlap last card
                        Spacer().frame(height: 160)
                    }
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)

                // Vita mascot watching from below — anchored to bottom-right corner
                VitaMascot(state: mascotState, size: 110, showStaff: true)
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, -10)
                    .padding(.bottom, -20)
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .ignoresSafeArea(.container, edges: .bottom)
        .task {
            await storeKit.loadProducts()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { headerVisible = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) { cardsVisible = true }
        }
        .onChange(of: storeKit.isSubscribed) { _, newValue in
            if newValue {
                mascotState = .happy
                showSuccess = true
                Task {
                    try? await Task.sleep(for: .seconds(1.8))
                    onDismiss()
                }
            }
        }
        .onChange(of: storeKit.purchaseError) { _, newValue in
            if newValue != nil {
                mascotState = .awake
            }
        }
        .overlay(alignment: .top) {
            if showSuccess {
                SuccessToast()
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Subviews

    private func starryBackground(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            Color(red: 0.03, green: 0.02, blue: 0.04).ignoresSafeArea()
            Image("fundo-dashboard")
                .resizable()
                .scaledToFill()
                .frame(width: w, height: h)
                .clipped()
                .opacity(0.35)
                .ignoresSafeArea()
            // Subtle gold glow from center-top
            RadialGradient(
                colors: [VitaColors.accent.opacity(0.12), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 500
            )
            .ignoresSafeArea()
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                haptic(.light)
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(.ultraThinMaterial))
            }
            Spacer()
            Button("Restaurar") {
                haptic(.light)
                Task { await storeKit.restorePurchases() }
            }
            .font(VitaTypography.bodySmall.weight(.semibold))
            .foregroundStyle(VitaColors.textSecondary)
        }
        .padding(.horizontal, 20)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Escolha seu plano")
                .font(VitaTypography.titleLarge)
                .foregroundStyle(VitaColors.textPrimary)
            Text("7 dias grátis nos planos pagos")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let err = storeKit.purchaseError ?? stripeError {
            Text(err)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var legalLinks: some View {
        HStack(spacing: 8) {
            Button("Restaurar") {
                Task { await storeKit.restorePurchases() }
            }
            .font(VitaTypography.bodySmall)
            .foregroundStyle(VitaColors.textTertiary)

            Text("\u{00B7}")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textTertiary)

            // swiftlint:disable:next force_unwrapping
            Link("Termos", destination: URL(string: "https://vita-ai.cloud/terms")!)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textTertiary)

            Text("\u{00B7}")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textTertiary)

            // swiftlint:disable:next force_unwrapping
            Link("Privacidade", destination: URL(string: "https://vita-ai.cloud/privacy")!)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textTertiary)
        }
    }

    // MARK: - Actions

    private func select(_ tier: PlanTier) {
        guard selectedTier != tier else { return }
        haptic(.light)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedTier = tier
        }
        // Happy mascot reaction on paid selection
        if tier != .free {
            mascotState = .happy
            Task {
                try? await Task.sleep(for: .seconds(1.0))
                if !storeKit.isPurchasing { mascotState = .awake }
            }
        }
    }

    private func product(for tier: PlanTier) -> Product? {
        guard let id = tier.productID else { return nil }
        return storeKit.products.first { $0.id == id }
    }

    private func handleSubscribe(_ tier: PlanTier) {
        haptic(.medium)
        guard tier != .free else {
            onDismiss()
            return
        }
        mascotState = .thinking

        if let product = product(for: tier) {
            storeKit.clearError()
            Task { await storeKit.purchase(product) }
        } else {
            // Fallback to Stripe web checkout
            Task { await openStripeCheckout(plan: tier.rawValue) }
        }
    }

    private func openStripeCheckout(plan: String) async {
        isLoadingStripe = true
        stripeError = nil
        defer { isLoadingStripe = false }
        do {
            let response = try await container.api.getCheckoutUrl(plan: plan)
            guard let urlStr = response.url, let url = URL(string: urlStr) else {
                stripeError = "URL de checkout inválida."
                return
            }
            guard
                let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                let root  = scene.windows.first?.rootViewController
            else { return }
            let safari = SFSafariViewController(url: url)
            safari.preferredControlTintColor = UIColor(VitaColors.accent)
            safari.dismissButtonStyle = .close
            root.present(safari, animated: true)
        } catch {
            stripeError = "Não foi possível abrir o checkout. Tente novamente."
        }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}

// MARK: - Plan Card

private struct PlanCard: View {
    let tier: PlanTier
    let isSelected: Bool
    let product: Product?
    let onTap: () -> Void
    let onSubscribe: () -> Void
    let isPurchasing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: name + price
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(tier.displayName)
                            .font(VitaTypography.titleMedium.weight(.bold))
                            .foregroundStyle(VitaColors.textPrimary)
                        if tier == .premium {
                            Text("MAIS POPULAR")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(VitaColors.surface)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(VitaColors.accent)
                                )
                        }
                    }
                    Text(tier.tagline)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(product?.displayPrice ?? tier.monthlyPriceLabel)
                        .font(VitaTypography.titleMedium.weight(.bold))
                        .foregroundStyle(VitaColors.textPrimary)
                    if tier != .free {
                        Text("/mês")
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                }
            }

            if tier != .free {
                Label("7 dias grátis", systemImage: "gift.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VitaColors.accent)
            }

            Divider().overlay(VitaColors.textTertiary.opacity(0.3))

            // Feature list for this tier's highlights
            VStack(alignment: .leading, spacing: 10) {
                ForEach(cumulativeFeatures(upTo: tier)) { feat in
                    HStack(spacing: 10) {
                        Image(systemName: feat.icon)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(iconColor(for: feat.tier))
                            .frame(width: 20)
                        Text(feat.label)
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }

            // Primary CTA — HUGE button, no carousel hit-testing issue
            Button(action: onSubscribe) {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: VitaColors.surface))
                            .scaleEffect(0.8)
                    }
                    Text(ctaText)
                        .font(VitaTypography.bodyMedium.weight(.bold))
                }
                .foregroundStyle(ctaForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ctaBackground)
                )
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(tier == .premium
                              ? VitaColors.accent.opacity(0.08)
                              : Color.clear)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(borderColor, lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isSelected ? 1.01 : 1.0)
        .shadow(color: isSelected ? VitaColors.accent.opacity(0.25) : .clear, radius: 20, y: 6)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
    }

    // MARK: - Styling helpers

    private func iconColor(for tier: PlanTier) -> Color {
        switch tier {
        case .free:    return VitaColors.textSecondary
        case .premium: return VitaColors.accent
        case .pro:     return VitaColors.accent
        }
    }

    private var borderColor: Color {
        if isSelected { return VitaColors.accent }
        return VitaColors.textTertiary.opacity(0.3)
    }

    private var ctaText: String {
        switch tier {
        case .free:    return "Continuar grátis"
        case .premium: return "Assinar Premium"
        case .pro:     return "Assinar Pro"
        }
    }

    private var ctaBackground: Color {
        switch tier {
        case .free:    return VitaColors.textTertiary.opacity(0.15)
        case .premium: return VitaColors.accent
        case .pro:     return VitaColors.accent
        }
    }

    private var ctaForeground: Color {
        switch tier {
        case .free:    return VitaColors.textPrimary
        case .premium: return VitaColors.surface
        case .pro:     return VitaColors.surface
        }
    }
}

// MARK: - Success toast

private struct SuccessToast: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VitaColors.accent)
            Text("Assinatura ativada!")
                .font(VitaTypography.bodyMedium.weight(.semibold))
                .foregroundStyle(VitaColors.textPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(.ultraThinMaterial)
        )
        .overlay(
            Capsule().stroke(VitaColors.accent.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Paywall — Assinatura") {
    VitaPaywallScreen(onDismiss: {})
}
#endif
