import SwiftUI
import StoreKit
import SafariServices

// MARK: - Billing Strategy
// iOS uses StoreKit 2 as primary payment channel (App Store requirement).
// When StoreKit products fail to load (sandbox/region issues, App Store Connect misconfiguration),
// a Stripe web-checkout fallback is offered so the user is never blocked.
// Fallback: POST billing/checkout → open SafariViewController with checkout URL.

// MARK: - Feature List (mirrors Android proFeatures)

private let proFeatures: [(icon: String, text: String)] = [
    ("mic.fill",           "Voice Tutor — converse com a Vita por voz"),
    ("stethoscope",        "OSCE — simulações de exame clínico"),
    ("waveform",           "Transcrição de aulas em tempo real"),
    ("photo.fill",         "Análise de imagens médicas"),
    ("clock.fill",         "Histórico ilimitado de conversas"),
    ("brain.head.profile", "Plano de estudos personalizado com IA"),
]

// MARK: - VitaPaywallScreen

struct VitaPaywallScreen: View {

    /// Called when the user dismisses / navigates back.
    var onDismiss: (() -> Void)?
    /// API used for Stripe checkout fallback. Injected so paywall stays testable.
    var api: VitaAPI? = nil

    @State private var storeKit = StoreKitManager()
    @State private var selectedProductID = StoreKitManager.annualProductID

    // Stripe fallback state
    @State private var isLoadingStripe = false
    @State private var stripeError: String? = nil

    // Staggered entrance animation gates
    @State private var heroVisible     = false
    @State private var plansVisible    = false
    @State private var featuresVisible = false
    @State private var ctaVisible      = false

    // MARK: - Computed

    private var selectedProduct: Product? {
        storeKit.products.first { $0.id == selectedProductID }
    }

    private var annualSavingsBadge: String? {
        guard let annual = storeKit.annualProduct,
              let monthly = storeKit.monthlyProduct else { return nil }
        let annualMonthly = annual.price / Decimal(12)
        let saving = monthly.price - annualMonthly
        let pct = (saving / monthly.price * 100) as NSDecimalNumber
        let intPct = pct.intValue
        guard intPct > 0 else { return nil }
        return "Economize \(intPct)%"
    }

    private func annualMonthlyNote(for product: Product) -> String? {
        let monthly = product.price / Decimal(12)
        let nf = NumberFormatter()
        nf.numberStyle = .currency
        nf.locale = Locale.current
        guard let formatted = nf.string(from: monthly as NSDecimalNumber) else { return nil }
        return "\(formatted)/mês"
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            // Ambient gold glow at top — matches gold glassmorphism aesthetic
            RadialGradient(
                colors: [VitaColors.accent.opacity(0.14), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 380
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                    heroSection
                    planSelector
                    featuresList
                    ctaSection
                    Spacer().frame(height: 80)
                }
            }
        }
        .task { await runEntranceSequence() }
        .navigationBarHidden(true)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Spacer()
            if let dismiss = onDismiss {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VitaColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(VitaColors.glassBg)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(VitaColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: 16) {
            // Glowing diamond badge
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [VitaColors.accent.opacity(0.28), VitaColors.accent.opacity(0.04)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 52
                    ))
                    .frame(width: 96, height: 96)

                Image(systemName: "diamond.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(LinearGradient(
                        colors: [VitaColors.accentLight, VitaColors.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
            }

            VStack(spacing: 8) {
                Text("VitaAI Pro")
                    .font(VitaTypography.headlineLarge)
                    .foregroundStyle(VitaColors.white)

                Text("Estude mais rápido com IA avançada")
                    .font(VitaTypography.bodyLarge)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 28)
        .padding(.horizontal, 20)
        .opacity(heroVisible ? 1 : 0)
        .offset(y: heroVisible ? 0 : 24)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: heroVisible)
    }

    // MARK: - Plan Selector

    private var planSelector: some View {
        HStack(spacing: 12) {
            PaywallPlanCard(
                label: "Anual",
                badge: annualSavingsBadge,
                price: storeKit.annualProduct?.displayPrice,
                priceNote: storeKit.annualProduct.flatMap { annualMonthlyNote(for: $0) },
                priceSuffix: "/ano",
                isSelected: selectedProductID == StoreKitManager.annualProductID,
                isLoading: storeKit.isLoadingProducts
            ) {
                selectedProductID = StoreKitManager.annualProductID
                haptic(.light)
            }

            PaywallPlanCard(
                label: "Mensal",
                badge: nil,
                price: storeKit.monthlyProduct?.displayPrice,
                priceNote: "cobrado mensalmente",
                priceSuffix: "/mês",
                isSelected: selectedProductID == StoreKitManager.monthlyProductID,
                isLoading: storeKit.isLoadingProducts
            ) {
                selectedProductID = StoreKitManager.monthlyProductID
                haptic(.light)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 32)
        .opacity(plansVisible ? 1 : 0)
        .offset(y: plansVisible ? 0 : 20)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: plansVisible)
    }

    // MARK: - Features List

    private var featuresList: some View {
        VitaGlassCard {
            VStack(spacing: 0) {
                Text("O que está incluído")
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 16)

                ForEach(Array(proFeatures.enumerated()), id: \.offset) { index, feature in
                    VStack(spacing: 0) {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(VitaColors.accent.opacity(0.12))
                                    .frame(width: 34, height: 34)
                                Image(systemName: feature.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(VitaColors.accent)
                            }
                            Text(feature.text)
                                .font(VitaTypography.bodyMedium)
                                .foregroundStyle(VitaColors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 13)

                        if index < proFeatures.count - 1 {
                            Divider()
                                .background(VitaColors.glassBorder)
                                .padding(.leading, 68)
                        }
                    }
                }

                Spacer().frame(height: 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .opacity(featuresVisible ? 1 : 0)
        .offset(y: featuresVisible ? 0 : 16)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: featuresVisible)
    }

    // MARK: - CTA Section

    private var ctaSection: some View {
        VStack(spacing: 16) {
            if storeKit.isSubscribed {
                subscribedBadge
            } else {
                purchaseButton

                // Stripe fallback: only shown when StoreKit products fail to load
                if storeKit.products.isEmpty && !storeKit.isLoadingProducts {
                    stripeWebButton
                }

                legalLinks
            }

            if let error = storeKit.purchaseError {
                Text(error)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.dataRed)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let error = stripeError {
                Text(error)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.dataRed)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .opacity(ctaVisible ? 1 : 0)
        .offset(y: ctaVisible ? 0 : 12)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: ctaVisible)
    }

    private var subscribedBadge: some View {
        VitaGlassCard {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(VitaColors.dataGreen)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Você já é Pro! ✨")
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(VitaColors.white)
                    Text("Aproveite todos os recursos premium")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer()
            }
            .padding(20)
        }
    }

    private var purchaseButton: some View {
        Button {
            guard let product = selectedProduct else { return }
            haptic(.medium)
            storeKit.clearError()
            Task { await storeKit.purchase(product) }
        } label: {
            HStack(spacing: 8) {
                if storeKit.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: VitaColors.black))
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Começar agora")
                        .font(VitaTypography.titleSmall)
                }
            }
            .foregroundStyle(VitaColors.black)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                (storeKit.isPurchasing || selectedProduct == nil)
                    ? VitaColors.accent.opacity(0.5)
                    : VitaColors.accent
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .disabled(storeKit.isPurchasing || selectedProduct == nil)
        .animation(.easeInOut(duration: 0.2), value: storeKit.isPurchasing)
    }

    /// Stripe web-checkout fallback — shown only when StoreKit products are unavailable.
    private var stripeWebButton: some View {
        Button {
            haptic(.light)
            Task { await openStripeCheckout() }
        } label: {
            HStack(spacing: 6) {
                if isLoadingStripe {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: VitaColors.textSecondary))
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 13, weight: .medium))
                }
                Text("Assinar pelo site")
                    .font(VitaTypography.bodySmall)
            }
            .foregroundStyle(VitaColors.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(VitaColors.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isLoadingStripe)
    }

    private var legalLinks: some View {
        HStack(spacing: 4) {
            Button {
                Task { await storeKit.restorePurchases() }
            } label: {
                Text("Restaurar compra")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .buttonStyle(.plain)

            Text("·")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textTertiary)

            // swiftlint:disable:next force_unwrapping
            Link("Termos", destination: URL(string: "https://vita-ai.cloud/terms")!)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textTertiary)

            Text("·")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textTertiary)

            // swiftlint:disable:next force_unwrapping
            Link("Privacidade", destination: URL(string: "https://vita-ai.cloud/privacy")!)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textTertiary)
        }
    }

    // MARK: - Helpers

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func runEntranceSequence() async {
        await storeKit.loadProducts()
        withAnimation { heroVisible = true }
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation { plansVisible = true }
        try? await Task.sleep(for: .milliseconds(100))
        withAnimation { featuresVisible = true }
        try? await Task.sleep(for: .milliseconds(80))
        withAnimation { ctaVisible = true }
    }

    /// Fetch Stripe checkout URL from backend and present via SFSafariViewController.
    /// Mirrors PaywallViewModel.startCheckout() — uses the same SFSafariViewController pattern.
    private func openStripeCheckout() async {
        guard let api else {
            stripeError = "Checkout via web não disponível."
            return
        }
        isLoadingStripe = true
        stripeError = nil
        defer { isLoadingStripe = false }
        do {
            let response = try await api.getCheckoutUrl(plan: "pro")
            guard let url = URL(string: response.url) else {
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
}

// MARK: - PaywallPlanCard

private struct PaywallPlanCard: View {
    let label: String
    let badge: String?
    let price: String?
    let priceNote: String?
    let priceSuffix: String
    let isSelected: Bool
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Label row + optional badge
                HStack(alignment: .top) {
                    Text(label)
                        .font(VitaTypography.titleSmall)
                        .foregroundStyle(isSelected ? VitaColors.white : VitaColors.textSecondary)
                    Spacer()
                    if let badge {
                        Text(badge)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.surface)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(VitaColors.accent)
                            .clipShape(Capsule())
                    }
                }

                // Price
                if isLoading {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(VitaColors.glassBg)
                        .frame(height: 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let price {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(price)
                            .font(VitaTypography.headlineSmall)
                            .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(priceSuffix)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                } else {
                    Text("—")
                        .font(VitaTypography.headlineSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }

                // Note (e.g. per-month equivalent for annual plan)
                if let note = priceNote {
                    Text(note)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 118)
            .background(isSelected ? VitaColors.accent.opacity(0.08) : VitaColors.glassBg)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? VitaColors.accent.opacity(0.6) : VitaColors.glassBorder,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Paywall — Dark") {
    VitaPaywallScreen(onDismiss: {})
}
#endif
