import SwiftUI
import Sentry

// MARK: - AssinaturaScreen
// Matches assinatura-mobile-v1.html mockup.
// Sections: Current Plan badge, Plan Cards (horizontal scroll: Free/Premium/Pro), Comparison Table.

struct AssinaturaScreen: View {
    @Environment(\.subscriptionStatus) private var subStatus
    @State private var showPaywall = false

    var onBack: (() -> Void)?

    // Mockup colors
    private let goldText = VitaColors.accentLight       // → VitaColors.accentLight
    private let goldBorder = VitaColors.accentHover     // → VitaColors.accentHover
    private let subtleText = VitaColors.textWarm
    private let purpleAccent = VitaColors.dataIndigo                         // #a78bfa (indigo400)
    private let purpleLight = VitaColors.dataIndigo.opacity(0.85)           // lighter indigo for Pro tier

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: - Header
                headerBar
                    .padding(.top, 8)

                // MARK: - Current Plan
                currentPlanCard
                    .padding(.horizontal, 14)
                    .padding(.top, 4)

                // MARK: - Plan Cards
                sectionLabel("Escolha seu plano")
                    .padding(.top, 18)
                planCardsScroll
                    .padding(.leading, 14)

                // MARK: - Comparison Table
                sectionLabel("Comparativo")
                    .padding(.top, 22)
                comparisonTable
                    .padding(.horizontal, 14)

                Spacer().frame(height: 120)
            }
        }
        .background(VitaColors.surface.ignoresSafeArea())
        .sheet(isPresented: $showPaywall) {
            VitaPaywallScreen(onDismiss: { showPaywall = false })
        }
        .onAppear { SentrySDK.reportFullyDisplayed() }
        .trackScreen("Assinatura")
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 10) {
            Button(action: { onBack?() }) {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18))
                    .foregroundStyle(subtleText.opacity(0.75))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Voltar")

            VStack(alignment: .leading, spacing: 1) {
                Text("Assinatura")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                Text("Gerencie seu plano")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Color.white.opacity(0.35))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Current Plan Card

    private var currentPlanCard: some View {
        VitaGlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plano atual")
                        .font(.system(size: 11))
                        .foregroundStyle(subtleText.opacity(0.35))
                    Text("Free")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.90))
                }
                Spacer()
                Text("GRATUITO")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(subtleText.opacity(0.45))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(subtleText.opacity(0.08), lineWidth: 1)
                    )
            }
            .padding(14)
        }
    }

    // MARK: - Plan Cards Scroll

    private var planCardsScroll: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                freePlanCard
                premiumPlanCard
                proPlanCard
            }
            .padding(.trailing, 14)
        }
    }

    // MARK: - Free Plan Card

    private var freePlanCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Free")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.96))
                .tracking(-0.5)

            Text("R$ 0")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(subtleText.opacity(0.45))
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 8) {
                featureRow(text: "5 mensagens/dia com Vita", enabled: true, color: goldText)
                featureRow(text: "50 questões/mês", enabled: true, color: goldText)
                featureRow(text: "Flashcards básicos", enabled: true, color: goldText)
                featureRow(text: "Entrada por voz", enabled: false, color: goldText)
                featureRow(text: "Upload de PDFs", enabled: false, color: goldText)
            }
            .padding(.top, 14)

            Text("Plano atual")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(subtleText.opacity(0.30))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .padding(.vertical, 11)
                .background(Color.white.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(subtleText.opacity(0.06), lineWidth: 1)
                )
                .accessibilityLabel("Plano atual — Free")
                .accessibilityAddTraits(.isStaticText)
                .accessibilityRemoveTraits(.isButton)
                .padding(.top, 16)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(minWidth: 240)
        .background(
            LinearGradient(
                colors: [
                    VitaColors.glassBg,
                    VitaColors.surfaceElevated.opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(subtleText.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Premium Plan Card

    private var premiumPlanCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Premium")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.96))
                    .tracking(-0.5)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("R$ 24,90")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(goldText.opacity(0.90))
                        .tracking(-0.5)
                    Text("/mês")
                        .font(.system(size: 11))
                        .foregroundStyle(subtleText.opacity(0.35))
                }
                .padding(.top, 6)

                VStack(alignment: .leading, spacing: 8) {
                    featureRow(text: "Mensagens ilimitadas", enabled: true, color: goldText)
                    featureRow(text: "Questões ilimitadas", enabled: true, color: goldText)
                    featureRow(text: "Entrada por voz", enabled: true, color: goldText)
                    featureRow(text: "Upload de PDFs", enabled: true, color: goldText)
                    featureRow(text: "Simulados OSCE", enabled: false, color: goldText)
                }
                .padding(.top, 14)

                Button(action: { showPaywall = true }) {
                    Text("Assinar Premium")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.92))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            LinearGradient(
                                colors: [
                                    VitaColors.accentHover.opacity(0.30),
                                    VitaColors.accentHover.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(goldBorder.opacity(0.25), lineWidth: 1)
                        )
                        .shadow(color: VitaColors.accentHover.opacity(0.15), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .frame(minWidth: 240)

            // "POPULAR" badge
            Text("POPULAR")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(goldText.opacity(0.90))
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(VitaColors.accentHover.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(goldBorder.opacity(0.20), lineWidth: 1)
                )
                .padding(.top, 12)
                .padding(.trailing, 12)
        }
        .background(
            LinearGradient(
                colors: [
                    VitaColors.surfaceElevated.opacity(0.95),
                    VitaColors.glassBg.opacity(0.90)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(goldBorder.opacity(0.20), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.40), radius: 20, y: 8)
        .shadow(color: VitaColors.accent.opacity(0.08), radius: 12)
    }

    // MARK: - Pro Plan Card

    private var proPlanCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Pro")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.96))
                .tracking(-0.5)

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("R$ 49,90")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(purpleLight.opacity(0.90))
                    .tracking(-0.5)
                Text("/mês")
                    .font(.system(size: 11))
                    .foregroundStyle(subtleText.opacity(0.35))
            }
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 8) {
                featureRow(text: "Tudo do Premium", enabled: true, color: purpleLight)
                featureRow(text: "Simulados OSCE", enabled: true, color: purpleLight)
                featureRow(text: "Atendimento prioritario", enabled: true, color: purpleLight)
                featureRow(text: "Atlas 3D completo", enabled: true, color: purpleLight)
                featureRow(text: "Acesso antecipado", enabled: true, color: purpleLight)
            }
            .padding(.top, 14)

            Button(action: { showPaywall = true }) {
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
        .frame(minWidth: 240)
        .background(
            LinearGradient(
                colors: [
                    VitaColors.surfaceCard.opacity(0.95),
                    VitaColors.glassBg.opacity(0.90)
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
        .shadow(color: .black.opacity(0.40), radius: 20, y: 8)
        .shadow(color: purpleAccent.opacity(0.06), radius: 10)
    }

    // MARK: - Feature Row

    private func featureRow(text: String, enabled: Bool, color: Color) -> some View {
        HStack(spacing: 8) {
            if enabled {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color.opacity(0.65))
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(subtleText.opacity(0.15))
                    .frame(width: 14, height: 14)
            }
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(enabled ? subtleText.opacity(0.55) : subtleText.opacity(0.20))
        }
    }

    // MARK: - Comparison Table

    private var comparisonTable: some View {
        VitaGlassCard {
            VStack(spacing: 0) {
                // Header
                compareRow(
                    feature: "Recurso",
                    free: "Free",
                    premium: "Prem.",
                    pro: "Pro",
                    isHeader: true
                )

                compareDataRow(feature: "Mensagens IA", free: "5/dia", premiumCheck: true, proCheck: true)
                compareDataRow(feature: "Questões", free: "50/mês", premiumCheck: true, proCheck: true)
                compareDataRow(feature: "Voz", free: nil, premiumCheck: true, proCheck: true)
                compareDataRow(feature: "PDFs", free: nil, premiumCheck: true, proCheck: true)
                compareDataRow(feature: "OSCE", free: nil, premiumCheck: false, proCheck: true)
                compareDataRow(feature: "Prioridade", free: nil, premiumCheck: false, proCheck: true)
            }
        }
    }

    private func compareRow(feature: String, free: String, premium: String, pro: String, isHeader: Bool) -> some View {
        HStack(spacing: 0) {
            Text(feature)
                .font(.system(size: isHeader ? 9 : 11.5, weight: isHeader ? .bold : .regular))
                .foregroundStyle(isHeader ? subtleText.opacity(0.25) : subtleText.opacity(0.50))
                .textCase(isHeader ? .uppercase : nil)
                .tracking(isHeader ? 0.5 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(free)
                .font(.system(size: isHeader ? 9 : 11, weight: isHeader ? .bold : .semibold))
                .foregroundStyle(subtleText.opacity(isHeader ? 0.25 : 0.30))
                .textCase(isHeader ? .uppercase : nil)
                .tracking(isHeader ? 0.5 : 0)
                .frame(width: 56, alignment: .center)

            Text(premium)
                .font(.system(size: isHeader ? 9 : 11, weight: isHeader ? .bold : .semibold))
                .foregroundStyle(subtleText.opacity(isHeader ? 0.25 : 0.30))
                .textCase(isHeader ? .uppercase : nil)
                .tracking(isHeader ? 0.5 : 0)
                .frame(width: 56, alignment: .center)

            Text(pro)
                .font(.system(size: isHeader ? 9 : 11, weight: isHeader ? .bold : .semibold))
                .foregroundStyle(subtleText.opacity(isHeader ? 0.25 : 0.30))
                .textCase(isHeader ? .uppercase : nil)
                .tracking(isHeader ? 0.5 : 0)
                .frame(width: 56, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(isHeader ? Color.white.opacity(0.06) : Color.clear)
        .overlay(alignment: .bottom) {
            Rectangle().fill(subtleText.opacity(0.03)).frame(height: 1)
        }
    }

    @ViewBuilder
    private func compareDataRow(feature: String, free: String?, premiumCheck: Bool, proCheck: Bool) -> some View {
        HStack(spacing: 0) {
            Text(feature)
                .font(.system(size: 11.5))
                .foregroundStyle(subtleText.opacity(0.50))
                .frame(maxWidth: .infinity, alignment: .leading)

            // Free column
            Group {
                if let freeText = free {
                    Text(freeText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(subtleText.opacity(0.30))
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundStyle(subtleText.opacity(0.15))
                }
            }
            .frame(width: 56, alignment: .center)

            // Premium column
            Group {
                if premiumCheck {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(goldText.opacity(0.65))
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundStyle(subtleText.opacity(0.15))
                }
            }
            .frame(width: 56, alignment: .center)

            // Pro column
            Group {
                if proCheck {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 14))
                        .foregroundStyle(purpleLight.opacity(0.65))
                } else {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                        .foregroundStyle(subtleText.opacity(0.15))
                }
            }
            .frame(width: 56, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(subtleText.opacity(0.03)).frame(height: 1)
        }
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(subtleText.opacity(0.35))
            .textCase(.uppercase)
            .tracking(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.bottom, 6)
    }
}
