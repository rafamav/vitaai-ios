import SwiftUI

/// Renderiza um asset PNG do bundle (e.g. glassv2-exam-paper-nobg).
/// Se o asset não existir no bundle, exibe um SF Symbol como fallback.
/// Isso permite compilação limpa mesmo antes dos assets serem adicionados ao xcassets.
struct GlassAssetImage: View {
    let assetName: String
    let fallbackSymbol: String
    var size: CGFloat = 52
    var tint: Color = VitaColors.accent

    var body: some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.27)
                    .fill(tint.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.27)
                            .stroke(tint.opacity(0.18), lineWidth: 1)
                    )
                    .frame(width: size, height: size)

                Image(systemName: fallbackSymbol)
                    .font(.system(size: size * 0.42, weight: .medium))
                    .foregroundStyle(tint.opacity(0.80))
            }
        }
    }
}
