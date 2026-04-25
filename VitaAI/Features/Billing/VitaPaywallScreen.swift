import SwiftUI
import StoreKit
import SafariServices
import Sentry

// MARK: - VitaPaywallScreen
//
// Rewritten from scratch (Apr 2026): full D4 shell — VitaAmbientBackground,
// VitaTypography, VitaGlassCard wrapper, VitaColors. Same content as v6
// (3 plan tiers + 10 features + StoreKit/Stripe CTA + legal links).

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
    @State private var isLoadingStripe = false
    @State private var stripeError: String? = nil
    @State private var showSuccess = false
    @State private var selectedFeature: PaywallFeature? = nil

    var body: some View {
        VitaAmbientBackground {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 20) {
                    headerCard

                    // 3 plan rows soltos, sem wrapper, cada um com seu próprio D4
                    ForEach(PlanTier.allCases) { tier in
                        PlanRow(
                            tier: tier,
                            isSelected: selectedTier == tier,
                            product: product(for: tier),
                            onTap: { select(tier) }
                        )
                    }

                    featuresList

                    if let err = storeKit.purchaseError ?? stripeError {
                        Text(err)
                            .font(VitaTypography.bodySmall)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }
                    ctaButton
                    legalLinks
                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .preferredColorScheme(.dark)
        .navigationTitle("Assinatura")
        .navigationBarTitleDisplayMode(.inline)
        .task { await storeKit.loadProducts() }
        .onAppear {
            VitaPostHogConfig.capture(event: "paywall_shown", properties: ["screen": "VitaPaywall"])
            SentrySDK.reportFullyDisplayed()
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
        .sheet(item: $selectedFeature) { feat in
            FeatureDetailSheet(feature: feat) { selectedFeature = nil }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.ultraThinMaterial)
        }
    }

    // MARK: - Header card (D4)

    private var headerCard: some View {
        VStack(spacing: 6) {
            Text("Escolha seu plano")
                .font(VitaTypography.headlineLarge)
                .foregroundStyle(VitaColors.textPrimary)
            Text("7 dias grátis · cancele quando quiser")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .background(d4CardBackground(cornerRadius: 18))
    }

    // MARK: - Features list (D4 background, items dentro)

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(VitaColors.accent.opacity(0.80))
                Text("INCLUÍDO NO \(selectedTier.displayName.uppercased())")
                    .font(VitaTypography.labelSmall)
                    .tracking(1.2)
                    .foregroundStyle(VitaColors.accent.opacity(0.85))
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 4)

            ForEach(Array(featuresIncluded(in: selectedTier).enumerated()), id: \.element.id) { idx, feat in
                if idx > 0 {
                    Rectangle()
                        .fill(VitaColors.glassBorder.opacity(0.5))
                        .frame(height: 0.5)
                }
                Button { selectedFeature = feat } label: {
                    HStack(spacing: 12) {
                        Image(systemName: feat.icon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VitaColors.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feat.label)
                                .font(VitaTypography.titleSmall)
                                .foregroundStyle(VitaColors.textPrimary)
                            Text(feat.sub)
                                .font(VitaTypography.bodySmall)
                                .foregroundStyle(VitaColors.textSecondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(d4CardBackground(cornerRadius: 18))
    }

    // MARK: - D4 background (simple version — Layer 1 gradient + border + shadow,
    // sem Canvas radial glows que conflitam com VStack interno)

    @ViewBuilder
    private func d4CardBackground(cornerRadius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 30/255, green: 22/255, blue: 15/255).opacity(0.92),
                            Color(red: 14/255, green: 10/255, blue: 7/255).opacity(0.92)
                        ],
                        startPoint: UnitPoint(x: 0.46, y: 0.0),
                        endPoint: UnitPoint(x: 0.54, y: 1.0)
                    )
                )
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    Color(red: 200/255, green: 160/255, blue: 80/255).opacity(0.22),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.50), radius: 16, x: 0, y: 6)
        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 1)
    }

    // MARK: - CTA

    private var ctaButton: some View {
        Button(action: { handleSubscribe(selectedTier) }) {
            HStack(spacing: 8) {
                if storeKit.isPurchasing || isLoadingStripe {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: VitaColors.accent))
                        .scaleEffect(0.85)
                }
                Text(ctaLabel)
                    .font(VitaTypography.titleMedium)
            }
            .foregroundStyle(VitaColors.surface)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(VitaColors.accent)
            )
        }
        .buttonStyle(.plain)
        .disabled(storeKit.isPurchasing || isLoadingStripe)
    }

    private var legalLinks: some View {
        HStack(spacing: 10) {
            Link("Termos", destination: URL(string: "https://vita-ai.cloud/terms")!)
            Text("·").foregroundStyle(VitaColors.textTertiary)
            Link("Privacidade", destination: URL(string: "https://vita-ai.cloud/privacy")!)
            Text("·").foregroundStyle(VitaColors.textTertiary)
            Button("Restaurar") { Task { await storeKit.restorePurchases() } }
        }
        .font(VitaTypography.bodySmall)
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
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
            selectedTier = tier
        }
    }

    private func product(for tier: PlanTier) -> Product? {
        guard let id = tier.productID else { return nil }
        return storeKit.products.first { $0.id == id }
    }

    private func handleSubscribe(_ tier: PlanTier) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard tier != .free else { onDismiss(); return }
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
}

// MARK: - PlanRow (single row inside plansCard, no own background)

private struct PlanRow: View {
    let tier: PlanTier
    let isSelected: Bool
    let product: Product?
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Radio indicator
            Circle()
                .stroke(isSelected ? VitaColors.accent : VitaColors.textTertiary, lineWidth: 1.5)
                .frame(width: 20, height: 20)
                .overlay {
                    if isSelected {
                        Circle().fill(VitaColors.accent).frame(width: 10, height: 10)
                    }
                }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(tier.displayName)
                        .font(VitaTypography.titleLarge)
                        .foregroundStyle(VitaColors.textPrimary)
                    if tier == .premium {
                        Text("MAIS POPULAR")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(VitaColors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(VitaColors.accent.opacity(0.4), lineWidth: 0.5)
                            )
                    }
                }
                Text(tier.tagline)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(product?.displayPrice ?? tier.priceLabel)
                    .font(tier == .free ? VitaTypography.titleSmall : VitaTypography.titleLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                    .monospacedDigit()
                Text(tier.period)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 30/255, green: 22/255, blue: 15/255).opacity(0.92),
                                Color(red: 14/255, green: 10/255, blue: 7/255).opacity(0.92)
                            ],
                            startPoint: UnitPoint(x: 0.46, y: 0.0),
                            endPoint: UnitPoint(x: 0.54, y: 1.0)
                        )
                    )
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(VitaColors.accent.opacity(0.06))
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isSelected
                        ? VitaColors.accent
                        : Color(red: 200/255, green: 160/255, blue: 80/255).opacity(0.22),
                    lineWidth: isSelected ? 1.5 : 1
                )
        )
        .shadow(color: .black.opacity(0.40), radius: 12, x: 0, y: 4)
        .shadow(color: .black.opacity(0.20), radius: 3, x: 0, y: 1)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .animation(.spring(response: 0.3, dampingFraction: 0.78), value: isSelected)
    }
}

// MARK: - Feature detail (sheet, D4 background via .ultraThinMaterial)

private struct FeatureDetailSheet: View {
    let feature: PaywallFeature
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(VitaColors.accent)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(VitaColors.accent.opacity(0.12))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.label)
                            .font(VitaTypography.headlineSmall)
                            .foregroundStyle(VitaColors.textPrimary)
                        tierBadge
                    }
                    Spacer()
                }

                Text(feature.detail)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("INCLUÍDO")
                        .font(VitaTypography.labelSmall)
                        .tracking(1.2)
                        .foregroundStyle(VitaColors.textSecondary)
                    ForEach(feature.highlights, id: \.self) { h in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(VitaColors.accent)
                                .padding(.top, 2)
                            Text(h)
                                .font(VitaTypography.bodyMedium)
                                .foregroundStyle(VitaColors.textPrimary.opacity(0.90))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private var tierBadge: some View {
        let label: String = {
            switch feature.minTier {
            case .free: return "Grátis"
            case .premium: return "Premium"
            case .pro: return "Pro"
            }
        }()
        let color: Color = feature.minTier == .free ? .green : VitaColors.accent
        return Text(label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .tracking(1)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.12)))
    }
}

// MARK: - Success toast

private struct SuccessToast: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(.green)
            Text("Bem-vindo ao Premium!")
                .font(VitaTypography.titleSmall)
                .foregroundStyle(VitaColors.textPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().stroke(VitaColors.glassBorder, lineWidth: 1))
        )
    }
}
