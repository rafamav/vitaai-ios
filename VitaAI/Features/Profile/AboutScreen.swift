import SwiftUI

struct AboutScreen: View {
    @Environment(\.dismiss) private var dismiss

    // Entrance animation phases
    @State private var logoOpacity: Double = 0
    @State private var logoScale: Double = 0.85
    @State private var changelogOffset: Double = 20
    @State private var changelogOpacity: Double = 0
    @State private var legalOffset: Double = 20
    @State private var legalOpacity: Double = 0

    private let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }()

    private let changelogFeatures = [
        "Dashboard com resumo de estudos",
        "Chat com VitaAI (IA assistente)",
        "Integrações Canvas LMS e WebAluno",
        "Flashcards com revisão espaçada",
        "Cadernos e anotações",
        "Agenda de provas e atividades",
        "Insights de desempenho",
        "Notificações push via APNs",
        "Tema claro e escuro",
        "Onboarding personalizado",
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Logo + version block
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(VitaColors.accent.opacity(0.12))
                            .frame(width: 120, height: 120)
                        Image(systemName: "sparkles")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(VitaColors.accent)
                    }

                    Text("VitaAI")
                        .font(VitaTypography.headlineLarge)
                        .foregroundStyle(VitaColors.white)

                    Text("v\(appVersion)")
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textSecondary)

                    Text("Feito com amor pela BYMAV")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .opacity(logoOpacity)
                .scaleEffect(logoScale)
                .padding(.top, 32)
                .padding(.bottom, 32)

                // Changelog card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Changelog")
                        .font(VitaTypography.titleLarge)
                        .foregroundStyle(VitaColors.white)
                        .padding(.horizontal, 20)

                    VitaGlassCard {
                        VStack(alignment: .leading, spacing: 0) {
                            // Version badge
                            HStack {
                                Text("v0.1.0")
                                    .font(VitaTypography.labelLarge)
                                    .foregroundStyle(VitaColors.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(VitaColors.accent.opacity(0.12))
                                    .clipShape(Capsule())
                                Spacer()
                            }
                            .padding(16)

                            Divider()
                                .background(VitaColors.glassBorder)

                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(changelogFeatures, id: \.self) { feature in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(VitaColors.accent.opacity(0.7))
                                            .padding(.top, 1)
                                        Text(feature)
                                            .font(VitaTypography.bodyMedium)
                                            .foregroundStyle(VitaColors.textSecondary)
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .opacity(changelogOpacity)
                .offset(y: changelogOffset)
                .padding(.bottom, 24)

                // Legal card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Legal")
                        .font(VitaTypography.titleLarge)
                        .foregroundStyle(VitaColors.white)
                        .padding(.horizontal, 20)

                    VitaGlassCard {
                        VStack(spacing: 0) {
                            LegalRow(
                                label: "Termos de Uso",
                                url: URL(string: "https://vita-ai.cloud/terms")!
                            )
                            Divider().background(VitaColors.glassBorder)
                            LegalRow(
                                label: "Política de Privacidade",
                                url: URL(string: "https://vita-ai.cloud/privacy")!
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .opacity(legalOpacity)
                .offset(y: legalOffset)

                Spacer().frame(height: 100)
            }
        }
        .background(VitaColors.surface.ignoresSafeArea())
        .navigationTitle("Sobre")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VitaColors.accent)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                logoOpacity = 1
                logoScale = 1
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.18)) {
                changelogOpacity = 1
                changelogOffset = 0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                legalOpacity = 1
                legalOffset = 0
            }
        }
    }
}

// MARK: - LegalRow

private struct LegalRow: View {
    let label: String
    let url: URL

    @State private var pressed = false

    var body: some View {
        Button(action: { UIApplication.shared.open(url) }) {
            HStack {
                Text(label)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        AboutScreen()
    }
    .preferredColorScheme(.dark)
}
