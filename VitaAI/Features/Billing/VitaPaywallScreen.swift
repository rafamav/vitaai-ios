import SwiftUI
import StoreKit
import SafariServices
import Sentry

// MARK: - VitaPaywallScreen
// v6 — compact plan rows + detailed features + detail sheets.
// Structure from working v4 (GeometryReader, starryBackground, nav integration).
// Content from v5 (PaywallFeature catalog, PlanRow radio cards, FeatureRow + detail sheet).
// No mascot.

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

    var priceLabel: String {
        switch self {
        case .free:    return "Grátis"
        case .premium: return "R$ 24,90"
        case .pro:     return "R$ 49,90"
        }
    }

    var period: String {
        switch self {
        case .free:    return "para sempre"
        case .premium: return "/ mês"
        case .pro:     return "/ mês"
        }
    }

    var tagline: String {
        switch self {
        case .free:    return "Pra começar"
        case .premium: return "Destrava a IA do Vita"
        case .pro:     return "Tudo, sem limite"
        }
    }

    var productID: String? {
        switch self {
        case .free:    return nil
        case .premium: return StoreKitManager.premiumProductID
        case .pro:     return StoreKitManager.proProductID
        }
    }
}

// MARK: - Feature catalog

private struct PaywallFeature: Identifiable {
    let id: String
    let label: String
    let sub: String
    let icon: String
    let minTier: PlanTier
    let detail: String
    let highlights: [String]
}

private let allFeatures: [PaywallFeature] = [
    .init(id: "qbank",
          label: "QBank de questões",
          sub: "121.440 questões · 1.622 tópicos",
          icon: "questionmark.circle.fill",
          minTier: .free,
          detail: "O maior banco de questões de medicina do Brasil. Questões de todas as faculdades, organizadas por matéria e tópico, com correção e explicação detalhada.",
          highlights: ["121.440 questões atualizadas", "1.622 tópicos organizados", "Filtros por matéria, dificuldade e fonte", "Correção com explicação detalhada", "Estatísticas de desempenho"]),
    .init(id: "flashcards",
          label: "Flashcards ilimitados",
          sub: "Spaced repetition · decks públicos",
          icon: "rectangle.stack.fill",
          minTier: .free,
          detail: "Sistema de flashcards com repetição espaçada que se adapta ao seu ritmo. Crie seus próprios cards ou use decks prontos da comunidade.",
          highlights: ["Algoritmo de repetição espaçada", "Crie cards de texto e imagem", "Decks públicos da comunidade", "Previsão de revisão diária", "Sincroniza entre dispositivos"]),
    .init(id: "simulados",
          label: "Simulados completos",
          sub: "Provas cronometradas com correção IA",
          icon: "doc.text.fill",
          minTier: .free,
          detail: "Simule provas reais de residência e faculdade com cronômetro, correção automática e análise de desempenho por área.",
          highlights: ["Provas com cronômetro real", "Correção com IA por questão", "Ranking entre estudantes", "Análise por área de conhecimento", "Histórico completo de tentativas"]),
    .init(id: "faculdades",
          label: "355 faculdades suportadas",
          sub: "FMUSP, Unifesp, UFRJ, Afya, Estácio...",
          icon: "graduationcap.fill",
          minTier: .free,
          detail: "Conecte seu portal acadêmico e tenha notas, horários e materiais automaticamente sincronizados. Suporte a Canvas, Mannesoft/WebAluno e mais.",
          highlights: ["Sync automático de notas e faltas", "Horários sempre atualizados", "Materiais do portal no app", "Canvas e WebAluno suportados", "355+ faculdades brasileiras"]),
    .init(id: "notas",
          label: "Notas e caderno digital",
          sub: "Markdown, rich text, por matéria",
          icon: "note.text",
          minTier: .free,
          detail: "Caderno digital organizado por matéria com suporte a Markdown, imagens e formatação rica. Suas anotações sempre acessíveis.",
          highlights: ["Markdown e rich text", "Organização por matéria", "Busca em todas as notas", "Sincroniza na nuvem"]),
    .init(id: "chat",
          label: "Vita Coach IA ilimitado",
          sub: "Seu coach de medicina 24/7",
          icon: "sparkles",
          minTier: .premium,
          detail: "Converse com o Vita a qualquer hora. Ele conhece sua faculdade, suas notas, seu plano de estudos e te ajuda de forma personalizada.",
          highlights: ["Respostas contextualizadas à sua faculdade", "Acesso às suas notas e provas", "Tira dúvidas de qualquer matéria", "Ajuda a montar plano de estudos", "Disponível 24/7"]),
    .init(id: "osce",
          label: "OSCE clínico interativo",
          sub: "Simulação de atendimento com IA",
          icon: "stethoscope",
          minTier: .premium,
          detail: "Pratique habilidades clínicas com pacientes simulados por IA. Anamnese, exame físico e raciocínio clínico com feedback em tempo real.",
          highlights: ["Casos clínicos realistas", "Anamnese guiada por IA", "Feedback de habilidades clínicas", "Múltiplas especialidades"]),
    .init(id: "atlas",
          label: "Atlas 3D de anatomia",
          sub: "Modelos interativos de todos os sistemas",
          icon: "brain.head.profile",
          minTier: .premium,
          detail: "Explore modelos 3D interativos do corpo humano. Rotacione, amplie e estude cada estrutura com descrições detalhadas.",
          highlights: ["Modelos 3D de todos os sistemas", "Rotação e zoom livre", "Descrições anatômicas detalhadas", "Ideal pra provas práticas"]),
    .init(id: "transcricao",
          label: "Transcrição de aulas",
          sub: "Grava aula → resumo + flashcards",
          icon: "waveform",
          minTier: .pro,
          detail: "Grave suas aulas e o Vita transcreve, gera resumo estruturado e cria flashcards automaticamente do conteúdo.",
          highlights: ["Transcrição automática em português", "Resumo estruturado por tópicos", "Flashcards gerados da aula", "Histórico de gravações"]),
    .init(id: "voz",
          label: "Modo voz com o Vita",
          sub: "Converse como se fosse um monitor",
          icon: "mic.fill",
          minTier: .pro,
          detail: "Converse por voz com o Vita como se estivesse falando com um monitor ou colega. Tire dúvidas, revise matéria e estude de forma natural.",
          highlights: ["Conversa natural por voz", "Respostas em áudio", "Estude sem precisar digitar", "Ideal pra revisão rápida"]),
]

private func featuresIncluded(in tier: PlanTier) -> [PaywallFeature] {
    allFeatures.filter { feat in
        switch tier {
        case .free:    return feat.minTier == .free
        case .premium: return feat.minTier == .free || feat.minTier == .premium
        case .pro:     return true
        }
    }
}

// MARK: - Screen

struct VitaPaywallScreen: View {
    @Environment(\.appContainer) private var container
    @State private var storeKit = StoreKitManager()

    let onDismiss: () -> Void

    @State private var selectedTier: PlanTier = .premium
    @State private var headerVisible = false
    @State private var cardsVisible = false
    @State private var isLoadingStripe = false
    @State private var stripeError: String? = nil
    @State private var showSuccess = false
    @State private var selectedFeature: PaywallFeature? = nil

    var body: some View {
        // Use the canonical VitaAmbientBackground wrapper so the paywall
        // matches the rest of the app (4 layers: dark base + nebula image +
        // center warm glow + 3 corner gold glows). The hand-rolled background
        // here was missing layers 2 and 3 — that's the inconsistency Rafael saw.
        VitaAmbientBackground {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 12)
                        .opacity(headerVisible ? 1 : 0)
                        .offset(y: headerVisible ? 0 : -8)

                    VStack(spacing: 8) {
                        ForEach(PlanTier.allCases) { tier in
                            PlanRow(
                                tier: tier,
                                isSelected: selectedTier == tier,
                                product: product(for: tier),
                                onTap: { select(tier) }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .opacity(cardsVisible ? 1 : 0)
                    .offset(y: cardsVisible ? 0 : 14)

                    featuresSection
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    errorBanner

                    inlineCTA
                        .padding(.horizontal, 20)
                        .padding(.top, 24)

                    legalLinks
                        .padding(.top, 12)

                    Spacer().frame(height: 32)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Assinatura")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await storeKit.loadProducts()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { headerVisible = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.15)) { cardsVisible = true }
            VitaPostHogConfig.capture(event: "paywall_shown", properties: [
                "screen": "VitaPaywall",
            ])
        }
        .onChange(of: storeKit.isSubscribed) { _, newValue in
            if newValue {
                showSuccess = true
                Task {
                    try? await Task.sleep(for: .seconds(1.8))
                    onDismiss()
                }
            }
        }
        .overlay(alignment: .top) {
            if showSuccess {
                SuccessToast()
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if let feat = selectedFeature {
                FeaturePopout(feature: feat) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        selectedFeature = nil
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: selectedFeature?.id)
        .onAppear { SentrySDK.reportFullyDisplayed() }
        .trackScreen("VitaPaywall")
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(spacing: 6) {
            Text("Escolha seu plano")
                .font(.system(size: 27, weight: .semibold))
                .tracking(-0.9)
                .foregroundStyle(VitaColors.textPrimary)
            Text("7 dias grátis · cancele quando quiser")
                .font(.system(size: 12.5))
                .foregroundStyle(VitaColors.textSecondary)
        }
    }

    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Separator with tier label
            HStack(spacing: 10) {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Color.white.opacity(0.08), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                Text("INCLUÍDO NO ")
                    .foregroundStyle(VitaColors.textTertiary)
                + Text(selectedTier.displayName.uppercased())
                    .foregroundStyle(VitaColors.accentLight)
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Color.white.opacity(0.08), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
            }
            .font(.system(size: 9.5, weight: .semibold))
            .tracking(1.5)
            .frame(maxWidth: .infinity)

            VStack(spacing: 4) {
                ForEach(featuresIncluded(in: selectedTier)) { feat in
                    Button {
                        selectedFeature = feat
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: feat.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(red: 1, green: 0.82, blue: 0.45))
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feat.label)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                Text(feat.sub)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.55))
                                    .lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        // popout is handled as overlay on the main body
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let err = storeKit.purchaseError ?? stripeError {
            Text(err)
                .font(.system(size: 12))
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var inlineCTA: some View {
        Button(action: { handleSubscribe(selectedTier) }) {
            HStack(spacing: 8) {
                if storeKit.isPurchasing || isLoadingStripe {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: VitaColors.accentLight))
                        .scaleEffect(0.8)
                }
                Text(ctaLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(-0.2)
            }
            .foregroundStyle(VitaColors.accentLight)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(VitaColors.accentLight.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(storeKit.isPurchasing || isLoadingStripe)
    }

    private var legalLinks: some View {
        HStack(spacing: 10) {
            Link("Termos", destination: URL(string: "https://vita-ai.cloud/terms")!)
            Text("·")
            Link("Privacidade", destination: URL(string: "https://vita-ai.cloud/privacy")!)
            Text("·")
            Button("Restaurar") {
                Task { await storeKit.restorePurchases() }
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(VitaColors.textTertiary)
    }

    private var ctaLabel: String {
        switch selectedTier {
        case .free:    return "Continuar grátis"
        case .premium: return "Começar 7 dias grátis"
        case .pro:     return "Começar 7 dias grátis"
        }
    }

    // MARK: - Actions

    private func select(_ tier: PlanTier) {
        guard selectedTier != tier else { return }
        haptic(.light)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selectedTier = tier
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
        if let product = product(for: tier) {
            storeKit.clearError()
            Task { await storeKit.purchase(product) }
        } else {
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

// MARK: - Plan Row (compact radio card)

private struct PlanRow: View {
    let tier: PlanTier
    let isSelected: Bool
    let product: Product?
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Radio indicator
            Circle()
                .stroke(isSelected ? VitaColors.accent : Color.gray, lineWidth: 1.5)
                .frame(width: 20, height: 20)
                .overlay {
                    if isSelected {
                        Circle().fill(VitaColors.accent).frame(width: 12, height: 12)
                    }
                }

            // Plan info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(tier.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    if tier == .premium {
                        Text("MAIS POPULAR")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(Color(red: 1, green: 0.82, blue: 0.45))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(VitaColors.accent.opacity(0.4), lineWidth: 0.5)
                            )
                    }
                }
                Text(tier.tagline)
                    .font(.system(size: 11.5))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer(minLength: 4)

            // Price
            VStack(alignment: .trailing, spacing: 2) {
                Text(product?.displayPrice ?? tier.priceLabel)
                    .font(.system(size: tier == .free ? 13 : 17, weight: .semibold))
                    .foregroundColor(.white)
                    .monospacedDigit()
                Text(tier.period)
                    .font(.system(size: 10.5))
                    .foregroundColor(.white.opacity(0.45))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .vitaGlassCard(cornerRadius: 18)
        .overlay(
            // Selection highlight ring on top of D4 stroke (subtle when not selected).
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? VitaColors.accent : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isSelected)
    }
}

// MARK: - Feature popout (blur overlay)

private struct FeaturePopout: View {
    let feature: PaywallFeature
    let onClose: () -> Void

    private let gold = Color(red: 1, green: 0.82, blue: 0.45)

    var body: some View {
        ZStack {
            // Blurred backdrop — tap to dismiss
            Color.black.opacity(0.5)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // Card
            VStack(spacing: 16) {
                // Close
                HStack {
                    Spacer()
                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                // Icon + title
                Image(systemName: feature.icon)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(gold)

                Text(feature.label)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                tierBadge

                // Description
                Text(feature.detail)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)

                // Highlights
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(feature.highlights, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(gold)
                                .offset(y: 2)
                            Text(item)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
            }
            .padding(24)
            .glassCard(cornerRadius: 24)
            .padding(.horizontal, 24)
        }
    }

    private var tierBadge: some View {
        let tierLabel: String = {
            switch feature.minTier {
            case .free: return "Grátis"
            case .premium: return "Premium"
            case .pro: return "Pro"
            }
        }()
        let color = feature.minTier == .free ? Color.green : gold
        return Text(tierLabel.uppercased())
            .font(.system(size: 10, weight: .bold))
            .tracking(1)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.12)))
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().stroke(VitaColors.accent.opacity(0.5), lineWidth: 1))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Paywall v6") {
    NavigationStack {
        VitaPaywallScreen(onDismiss: {})
    }
}
#endif
