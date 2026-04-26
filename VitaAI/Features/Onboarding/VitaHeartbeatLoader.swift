import SwiftUI

/// Loading state com a personalidade do Vita: só o mascote (orb) flutuando.
/// Antes havia um coração dourado pulsando "dentro" do orb em ritmo lub-dub,
/// removido por feedback Rafael 2026-04-25 ("ficou estranho, deixa apenas o
/// mascote mesmo"). Wrapper mantido (em vez de chamar OrbMascot direto) pra
/// preservar API atual de orbSize e o ponto único de mudança no futuro.
struct VitaHeartbeatLoader: View {
    var orbSize: CGFloat = 96

    var body: some View {
        OrbMascot(palette: .vita, state: .awake, size: orbSize, bounceEnabled: false)
    }
}

#Preview {
    ZStack {
        VitaColors.surface.ignoresSafeArea()
        VitaHeartbeatLoader()
    }
}
