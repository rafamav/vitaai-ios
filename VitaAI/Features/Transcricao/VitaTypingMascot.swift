import SwiftUI

/// Mascote do Vita na área de gravação da transcrição.
///
/// Filosofia: o Vita dorme até você tocar pra gravar, aí ele acorda e um
/// teclado "voa" do nada pra frente dele — a transcrição é um ato do próprio
/// Vita, não uma UI genérica. Inspirado no SleepStep do onboarding
/// ("toque para acordar").
///
/// Estados:
/// - `isRecording == false` → `OrbMascot(.sleeping)` — orb fechado, aura
///   discreta, sem teclado.
/// - `isRecording == true`  → `OrbMascot(.thinking)` — olhos focados, aura
///   ativa. Teclado voa de baixo com spring, pousa logo abaixo do orb,
///   fica flutuando (±4pt) e teclas pulsam simulando digitação.
///
/// O orb usa `bounceEnabled: false` durante gravação pra não pular —
/// Rafael pediu: "tem que parecer focado, não excitado".
///
/// Entrada/saída do teclado:
/// - Entrada: offset y = +size*0.55 (fora da view), rotate 30°, scale 0.5,
///   opacity 0 → pousa em y = -size*0.04, rotate 0°, scale 1, opacity 1
///   via spring 0.55s.
/// - Saída: sobe, rotate -15°, scale 0.8, opacity 0 em 0.35s easeIn.
///
/// Respeita `accessibilityReduceMotion`: animações de flutuação/tecla
/// desligam. OrbMascot respeita internamente.
struct VitaTypingMascot: View {
    let isRecording: Bool
    let size: CGFloat

    @State private var keyboardFloatY: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Orb fills about 62% of the reserved width — leaves room for aura glow
    // and the keyboard below without clipping.
    private var orbSize: CGFloat { size * 0.62 }

    var body: some View {
        ZStack(alignment: .bottom) {
            OrbMascot(
                palette: .vita,
                state: isRecording ? .thinking : .sleeping,
                size: orbSize,
                bounceEnabled: false
            )
            .frame(width: size, height: size)
            .animation(.easeInOut(duration: 0.5), value: isRecording)

            if isRecording {
                VitaMiniKeyboard(size: size * 0.55, reduceMotion: reduceMotion)
                    .offset(y: -size * 0.02 + keyboardFloatY)
                    .transition(
                        .asymmetric(
                            insertion: .modifier(
                                active: KeyboardEntryModifier(progress: 0, size: size),
                                identity: KeyboardEntryModifier(progress: 1, size: size)
                            ),
                            removal: .opacity
                                .combined(with: .scale(scale: 0.8))
                                .combined(with: .offset(y: -size * 0.3))
                        )
                    )
            }
        }
        .frame(width: size, height: size)
        .onAppear { startFloat() }
        .onChange(of: isRecording) { _, recording in
            if recording { startFloat() }
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.72), value: isRecording)
    }

    private func startFloat() {
        guard isRecording, !reduceMotion else {
            keyboardFloatY = 0
            return
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            keyboardFloatY = -4
        }
    }
}

/// Custom mini-keyboard drawn in SwiftUI. No SF Symbol — rendered in the
/// Vita universe (gold gradient, glass base, inner glow). One key "press"
/// animation cycles randomly through the keys while recording to sell
/// "Vita digitando".
private struct VitaMiniKeyboard: View {
    let size: CGFloat
    let reduceMotion: Bool

    // 3 rows of keys. Row 3 has a wider spacebar at the end.
    private let row1 = 8
    private let row2 = 7
    private let row3 = 5  // 4 normal + spacebar

    @State private var activeKey: KeyID? = nil

    private var padding: CGFloat { size * 0.065 }
    private var keySpacing: CGFloat { size * 0.022 }
    private var keyRadius: CGFloat { size * 0.035 }
    private var rowHeight: CGFloat { size * 0.16 }

    var body: some View {
        VStack(spacing: keySpacing) {
            row(count: row1, rowIndex: 0)
            row(count: row2, rowIndex: 1)
            row3View
        }
        .padding(.horizontal, padding)
        .padding(.vertical, padding * 0.9)
        .background(keyboardBase)
        .onAppear { if !reduceMotion { startTypingLoop() } }
    }

    // MARK: - Rows

    private func row(count: Int, rowIndex: Int) -> some View {
        HStack(spacing: keySpacing) {
            ForEach(0..<count, id: \.self) { col in
                keyCap(id: KeyID(row: rowIndex, col: col), isSpace: false)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: rowHeight)
    }

    private var row3View: some View {
        HStack(spacing: keySpacing) {
            keyCap(id: KeyID(row: 2, col: 0), isSpace: false).frame(width: rowHeight * 0.95)
            keyCap(id: KeyID(row: 2, col: 1), isSpace: false).frame(width: rowHeight * 0.95)
            keyCap(id: KeyID(row: 2, col: 2), isSpace: true).frame(maxWidth: .infinity)
            keyCap(id: KeyID(row: 2, col: 3), isSpace: false).frame(width: rowHeight * 0.95)
            keyCap(id: KeyID(row: 2, col: 4), isSpace: false).frame(width: rowHeight * 0.95)
        }
        .frame(height: rowHeight)
    }

    // MARK: - Key

    @ViewBuilder
    private func keyCap(id: KeyID, isSpace: Bool) -> some View {
        let active = activeKey == id
        RoundedRectangle(cornerRadius: keyRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: active
                        ? [VitaColors.accentLight.opacity(0.95), VitaColors.accent.opacity(0.65)]
                        : [VitaColors.accent.opacity(0.42), VitaColors.accentDark.opacity(0.30)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: keyRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: active
                                ? [VitaColors.accentLight.opacity(0.9), VitaColors.accent.opacity(0.4)]
                                : [VitaColors.accent.opacity(0.45), VitaColors.accentDark.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.6
                    )
            )
            // Tiny top highlight — sells the "cap" look
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: keyRadius, style: .continuous)
                    .fill(Color.white.opacity(active ? 0.45 : 0.18))
                    .frame(height: rowHeight * 0.18)
                    .padding(.horizontal, size * 0.008)
                    .padding(.top, size * 0.006)
                    .blur(radius: 0.4)
                    .mask(RoundedRectangle(cornerRadius: keyRadius, style: .continuous))
            }
            .scaleEffect(active ? 0.92 : 1.0)
            .shadow(color: active ? VitaColors.accent.opacity(0.55) : .clear, radius: 4)
            .animation(.easeInOut(duration: 0.18), value: active)
            .frame(height: rowHeight * (isSpace ? 0.80 : 1.0))
    }

    // MARK: - Base

    private var keyboardBase: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.06, blue: 0.035).opacity(0.85),
                            Color(red: 0.04, green: 0.03, blue: 0.02).opacity(0.92),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [VitaColors.accent.opacity(0.55), VitaColors.accent.opacity(0.15)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 0.8
                )
            // Inner top-edge glow (like a macbook keyboard underlit)
            RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                .blur(radius: 0.5)
                .offset(y: -0.5)
        }
        .shadow(color: VitaColors.accent.opacity(0.28), radius: 12)
        .shadow(color: .black.opacity(0.55), radius: 6, y: 3)
    }

    // MARK: - Typing loop

    private func startTypingLoop() {
        Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int.random(in: 90...220)))
                let rowCandidates = [row1, row2, row3]
                let row = Int.random(in: 0..<3)
                let col = Int.random(in: 0..<rowCandidates[row])
                activeKey = KeyID(row: row, col: col)
                try? await Task.sleep(for: .milliseconds(Int.random(in: 90...160)))
                activeKey = nil
            }
        }
    }

    struct KeyID: Equatable {
        let row: Int
        let col: Int
    }
}

/// Fly-in transition for the keyboard: rises from below, rotates into place,
/// and springs to full opacity. Drives everything off a single 0→1 progress
/// value so SwiftUI can animate it as a single transition.
private struct KeyboardEntryModifier: ViewModifier, Animatable {
    var progress: Double
    let size: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = max(0, min(1, progress))
        let offsetY = (1 - t) * size * 0.55
        let rotation = Angle.degrees((1 - t) * 30)
        let scale = 0.5 + 0.5 * t
        let opacity = t
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .rotationEffect(rotation)
            .offset(y: offsetY)
    }
}

#Preview("idle") {
    VitaTypingMascot(isRecording: false, size: 155)
        .padding(40)
        .background(Color.black)
}

#Preview("recording") {
    VitaTypingMascot(isRecording: true, size: 155)
        .padding(40)
        .background(Color.black)
}
