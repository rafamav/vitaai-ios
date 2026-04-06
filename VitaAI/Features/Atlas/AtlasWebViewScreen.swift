import SwiftUI

// MARK: - Atlas 3D Screen (Native SwiftUI — no WebView)

struct AtlasWebViewScreen: View {
    var onBack: () -> Void

    private let stats: [(count: String, label: String)] = [
        ("1.037", "Ossos"),
        ("344", "Músculos"),
        ("419", "Vasos"),
        ("431", "Nervos"),
        ("271", "Órgãos"),
        ("236", "Artic."),
        ("165", "Linfático"),
        ("2.903", "Total"),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Hero icon
                Image("tool-atlas3d")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .padding(.top, 20)

                // Title
                Text("Atlas 3D")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(VitaColors.textPrimary)

                Text("A anatomia interativa precisa baixar os modelos 3D para funcionar.")
                    .font(.system(size: 14))
                    .foregroundColor(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                // Stats grid
                statsGrid
                    .padding(.horizontal, 16)

                // Download size
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 14))
                    Text("~7 MB")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(VitaColors.textSecondary)

                // Download button
                Button {
                    // TODO: trigger actual 3D model download
                } label: {
                    Text("Baixar Modelos")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [
                                    VitaColors.accent.opacity(0.8),
                                    VitaColors.accentDark.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 16)

                // Feature list
                VStack(alignment: .leading, spacing: 12) {
                    featureRow(icon: "rotate.3d", text: "Rotação 360° de todos os modelos")
                    featureRow(icon: "magnifyingglass", text: "Zoom e isolamento de estruturas")
                    featureRow(icon: "tag", text: "Nomes anatômicos em português")
                    featureRow(icon: "book.closed", text: "Integrado com suas disciplinas")
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer(minLength: 120)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()), GridItem(.flexible()),
            GridItem(.flexible()), GridItem(.flexible())
        ], spacing: 12) {
            ForEach(stats, id: \.label) { stat in
                VStack(spacing: 2) {
                    Text(stat.count)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(VitaColors.accentLight)
                    Text(stat.label)
                        .font(.system(size: 10))
                        .foregroundColor(VitaColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VitaColors.surface.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(VitaColors.accentLight.opacity(0.12), lineWidth: 0.5)
                        )
                )
            }
        }
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(VitaColors.accent)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(VitaColors.textSecondary)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Atlas 3D") {
    AtlasWebViewScreen(onBack: {})
        .preferredColorScheme(.dark)
}
#endif
