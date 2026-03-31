import SwiftUI
import StoreKit
import SafariServices

// MARK: - Billing Strategy
// iOS uses StoreKit 2 as primary payment channel (App Store requirement).
// When StoreKit products fail to load (sandbox/region issues, App Store Connect misconfiguration),
// a Stripe web-checkout fallback is offered so the user is never blocked.
// Fallback: POST billing/checkout -> open SafariViewController with checkout URL.
//
// Visual layout matches assinatura-mobile-v1.html mockup:
// - Current plan badge
// - Horizontal scroll with Free / Premium / Pro plan cards
// - Premium card has conic gradient border (3-layer glass)
// - Pro card has purple accent
// - Comparison table below

// MARK: - Plan feature data

private struct PlanFeature {
    let text: String
    let enabled: Bool
}

private let freePlanFeatures: [PlanFeature] = [
    .init(text: "5 mensagens/dia com Vita", enabled: true),
    .init(text: "50 questoes/mes", enabled: true),
    .init(text: "Flashcards basicos", enabled: true),
    .init(text: "Entrada por voz", enabled: false),
    .init(text: "Upload de PDFs", enabled: false),
]

private let premiumPlanFeatures: [PlanFeature] = [
    .init(text: "Mensagens ilimitadas", enabled: true),
    .init(text: "Questoes ilimitadas", enabled: true),
    .init(text: "Entrada por voz", enabled: true),
    .init(text: "Upload de PDFs", enabled: true),
    .init(text: "Simulados OSCE", enabled: false),
]

private let proPlanFeatures: [PlanFeature] = [
    .init(text: "Tudo do Premium", enabled: true),
    .init(text: "Simulados OSCE", enabled: true),
    .init(text: "Atendimento prioritario", enabled: true),
    .init(text: "Atlas 3D completo", enabled: true),
    .init(text: "Acesso antecipado", enabled: true),
]

// Comparison table
private struct CompareRow {
    let feature: String
    let free: String     // text or "check" / "cross"
    let premium: String
    let pro: String
}

private let compareData: [CompareRow] = [
    .init(feature: "Mensagens IA", free: "5/dia", premium: "check", pro: "check"),
    .init(feature: "Questoes", free: "50/mes", premium: "check", pro: "check"),
    .init(feature: "Voz", free: "cross", premium: "check", pro: "check"),
    .init(feature: "PDFs", free: "cross", premium: "check", pro: "check"),
    .init(feature: "OSCE", free: "cross", premium: "cross", pro: "check"),
    .init(feature: "Prioridade", free: "cross", premium: "cross", pro: "check"),
]

// MARK: - VitaPaywallScreen

struct VitaPaywallScreen: View {

    /// Called when the user dismisses / navigates back.
    var onDismiss: (() -> Void)?
    /// API used for Stripe checkout fallback. Injected so paywall stays testable.
    var api: VitaAPI? = nil

    @State private var storeKit = StoreKitManager()
    @State private var selectedPlan: PlanTier = .premium

    // Stripe fallback state
    @State private var isLoadingStripe = false
    @State private var stripeError: String? = nil

    // Staggered entrance animation
    @State private var headerVisible = false
    @State private var cardsVisible  = false
    @State private var tableVisible  = false

    // Purple accent for Pro tier
    private let purpleAccent = Color(red: 0.545, green: 0.361, blue: 0.965)  // rgba(139,92,246)
    private let purpleLight  = Color(red: 0.753, green: 0.518, blue: 0.988)  // rgba(192,132,252)

    enum PlanTier: String, CaseIterable {
        case free, premium, pro
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()

            RadialGradient(
                colors: [VitaColors.accent.opacity(0.10), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 380
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    topBar
                    currentPlanBadge
                        .padding(.top, 4)

                    // Plan cards label
                    sectionLabel("Escolha seu plano")
                        .padding(.top, 18)

                    // Horizontal scroll plan cards
                    planCardsScroll
                        .padding(.top, 8)

                    // Comparison table
                    sectionLabel("Comparativo")
                        .padding(.top, 22)
                    comparisonTable
                        .padding(.horizontal, 14)
                        .padding(.top, 8)

                    // Legal links
                    legalLinks
                        .padding(.top, 20)

                    if let error = stripeError {
                        Text(error)
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(VitaColors.dataRed)
                            .multilineTextAlignment(.center)
                            .padding(.top, 12)
                    }

                    Spacer().frame(height: 120)
                }
            }
        }
        .task { await runEntranceSequence() }
        .navigationBarHidden(true)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            HStack(spacing: 10) {
                if let dismiss = onDismiss {
                    Button(action: dismiss) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.80))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("backButton")
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Assinatura")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("Gerencie seu plano")
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .opacity(headerVisible ? 1 : 0)
        .offset(y: headerVisible ? 0 : 16)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: headerVisible)
    }

    // MARK: - Current Plan Badge

    private var currentPlanBadge: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Plano atual")
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textTertiary)
                Text("Free")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(VitaColors.textPrimary)
            }
            Spacer()
            Text("GRATUITO")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(VitaColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(VitaColors.textWarm.opacity(0.08), lineWidth: 1)
                )
        }
        .padding(14)
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VitaColors.glassBorder, lineWidth: 1))
        .padding(.horizontal, 14)
        .opacity(headerVisible ? 1 : 0)
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(VitaColors.textTertiary)
                .kerning(0.4)
            Spacer()
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Plan Cards Horizontal Scroll

    private var planCardsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                freePlanCard
                premiumPlanCard
                proPlanCard
            }
            .padding(.horizontal, 14)
        }
        .opacity(cardsVisible ? 1 : 0)
        .offset(y: cardsVisible ? 0 : 20)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: cardsVisible)
    }

    // MARK: - Free Plan Card

    private var freePlanCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Free")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VitaColors.textPrimary)
                .kerning(-0.54)

            Text("R$ 0")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(VitaColors.textSecondary)
                .padding(.top, 6)

            featureList(freePlanFeatures, accentColor: VitaColors.accentLight)
                .padding(.top, 14)

            Button(action: {}) {
                Text("Plano atual")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(VitaColors.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(VitaColors.textWarm.opacity(0.06), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(true)
            .padding(.top, 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(width: 240)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 12/255, green: 9/255, blue: 7/255).opacity(0.92),
                    Color(red: 14/255, green: 11/255, blue: 8/255).opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(VitaColors.textWarm.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Premium Plan Card (3-layer glass, conic border)

    private var premiumPlanCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Premium")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .kerning(-0.54)

                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("R$ 24,90")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.90))
                        .kerning(-0.78)
                    Text("/mes")
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .padding(.top, 6)

                featureList(premiumPlanFeatures, accentColor: VitaColors.accentLight)
                    .padding(.top, 14)

                Button(action: { handleSubscribe(.premium) }) {
                    Text("Assinar Premium")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.92))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [
                                    VitaColors.glassInnerLight.opacity(0.30),
                                    VitaColors.glassInnerLight.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(VitaColors.accentHover.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: VitaColors.glassInnerLight.opacity(0.15), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)

            // POPULAR badge
            Text("POPULAR")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(VitaColors.accentLight.opacity(0.90))
                .tracking(0.5)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(VitaColors.glassInnerLight.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(VitaColors.accentHover.opacity(0.20), lineWidth: 1)
                )
                .padding(.top, 12)
                .padding(.trailing, 12)
        }
        .frame(width: 240)
        .background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 20/255, green: 14/255, blue: 8/255).opacity(0.95),
                        Color(red: 14/255, green: 11/255, blue: 8/255).opacity(0.90)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // Inner glow
                RadialGradient(
                    colors: [VitaColors.glassInnerLight.opacity(0.14), .clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: 180
                )
                RadialGradient(
                    colors: [VitaColors.glassInnerLight.opacity(0.08), .clear],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 140
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // Conic gradient border (matches mockup ::before)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(stops: [
                            .init(color: VitaColors.accentHover.opacity(0.40), location: 0.0),
                            .init(color: VitaColors.accentHover.opacity(0.20), location: 0.17),
                            .init(color: Color.white.opacity(0.03), location: 0.39),
                            .init(color: Color.white.opacity(0.02), location: 0.61),
                            .init(color: VitaColors.accentHover.opacity(0.16), location: 0.83),
                            .init(color: VitaColors.accentHover.opacity(0.40), location: 1.0),
                        ]),
                        center: UnitPoint(x: 0.40, y: 0.80),
                        startAngle: .degrees(200),
                        endAngle: .degrees(560)
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.40), radius: 20, y: 16)
        .shadow(color: VitaColors.glassInnerLight.opacity(0.08), radius: 12)
    }

    // MARK: - Pro Plan Card (purple accent)

    private var proPlanCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pro")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VitaColors.textPrimary)
                .kerning(-0.54)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("R$ 49,90")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(purpleLight.opacity(0.90))
                    .kerning(-0.78)
                Text("/mes")
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.top, 6)

            featureList(proPlanFeatures, accentColor: purpleLight)
                .padding(.top, 14)

            Button(action: { handleSubscribe(.pro) }) {
                Text("Assinar Pro")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(purpleLight.opacity(0.92))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [
                                purpleAccent.opacity(0.25),
                                purpleAccent.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(purpleAccent.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: purpleAccent.opacity(0.12), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(width: 240)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 15/255, green: 8/255, blue: 20/255).opacity(0.95),
                    Color(red: 14/255, green: 11/255, blue: 8/255).opacity(0.90)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(purpleAccent.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.40), radius: 20, y: 16)
        .shadow(color: purpleAccent.opacity(0.06), radius: 10)
    }

    // MARK: - Feature List Helper

    private func featureList(_ features: [PlanFeature], accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(features.indices, id: \.self) { i in
                let f = features[i]
                HStack(spacing: 8) {
                    if f.enabled {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(accentColor.opacity(0.65))
                            .frame(width: 14, height: 14)
                    } else {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.15))
                            .frame(width: 14, height: 14)
                    }
                    Text(f.text)
                        .font(.system(size: 11.5))
                        .foregroundStyle(f.enabled ? VitaColors.textWarm.opacity(0.55) : VitaColors.textWarm.opacity(0.20))
                }
            }
        }
    }

    // MARK: - Comparison Table

    private var comparisonTable: some View {
        VStack(spacing: 0) {
            // Header row
            HStack {
                Text("RECURSO")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("FREE")
                    .frame(width: 56)
                Text("PREM.")
                    .frame(width: 56)
                Text("PRO")
                    .frame(width: 56)
            }
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(VitaColors.textTertiary)
            .tracking(0.5)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.01))

            ForEach(compareData.indices, id: \.self) { i in
                let row = compareData[i]
                HStack {
                    Text(row.feature)
                        .font(.system(size: 11.5))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.50))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    compareCell(row.free, tier: .free)
                        .frame(width: 56)
                    compareCell(row.premium, tier: .premium)
                        .frame(width: 56)
                    compareCell(row.pro, tier: .pro)
                        .frame(width: 56)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

                if i < compareData.count - 1 {
                    Rectangle()
                        .fill(VitaColors.textWarm.opacity(0.03))
                        .frame(height: 1)
                }
            }
        }
        .background(VitaColors.glassBg)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VitaColors.glassBorder, lineWidth: 1))
        .opacity(tableVisible ? 1 : 0)
        .offset(y: tableVisible ? 0 : 16)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: tableVisible)
    }

    @ViewBuilder
    private func compareCell(_ value: String, tier: PlanTier) -> some View {
        if value == "check" {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(tier == .pro ? purpleLight.opacity(0.65) : VitaColors.accentLight.opacity(0.65))
        } else if value == "cross" {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(VitaColors.textWarm.opacity(0.15))
        } else {
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(VitaColors.textTertiary)
        }
    }

    // MARK: - Legal Links

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

    // MARK: - Helpers

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func runEntranceSequence() async {
        await storeKit.loadProducts()
        withAnimation { headerVisible = true }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation { cardsVisible = true }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation { tableVisible = true }
    }

    private func handleSubscribe(_ tier: PlanTier) {
        haptic(.medium)
        // Map tier to StoreKit product if available
        let productID: String
        switch tier {
        case .free: return
        case .premium: productID = StoreKitManager.monthlyProductID
        case .pro: productID = StoreKitManager.annualProductID
        }

        if let product = storeKit.products.first(where: { $0.id == productID }) {
            storeKit.clearError()
            Task { await storeKit.purchase(product) }
        } else {
            // Fallback to Stripe web checkout
            Task { await openStripeCheckout(plan: tier.rawValue) }
        }
    }

    /// Fetch Stripe checkout URL from backend and present via SFSafariViewController.
    private func openStripeCheckout(plan: String) async {
        guard let api else {
            stripeError = "Checkout via web nao disponivel."
            return
        }
        isLoadingStripe = true
        stripeError = nil
        defer { isLoadingStripe = false }
        do {
            let response = try await api.getCheckoutUrl(plan: plan)
            guard let url = URL(string: response.url) else {
                stripeError = "URL de checkout invalida."
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
            stripeError = "Nao foi possivel abrir o checkout. Tente novamente."
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Paywall — Assinatura") {
    VitaPaywallScreen(onDismiss: {})
}
#endif
