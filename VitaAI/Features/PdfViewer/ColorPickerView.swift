import SwiftUI

private let presetColors: [Color] = [
    Color(hex: 0xC8A050),  // gold accent
    Color(hex: 0xEF4444),  // red
    Color(hex: 0x22C55E),  // green
    Color(hex: 0x3B82F6),  // blue
    Color(hex: 0xF59E0B),  // amber
    Color(hex: 0xEC4899),  // pink
    Color(hex: 0xA855F7),  // purple
    Color(hex: 0xF97316),  // orange
    Color(hex: 0xFFFFFF),  // white
    Color(hex: 0x000000),  // black
]

/// Full HSB color picker: 2D saturation/value + hue bar + presets.
struct ColorPickerView: View {
    let selectedColor: Color
    let onColorSelected: (Color) -> Void
    let onDismiss: () -> Void

    @State private var hue: Double
    @State private var saturation: Double
    @State private var brightness: Double

    init(selectedColor: Color, onColorSelected: @escaping (Color) -> Void, onDismiss: @escaping () -> Void) {
        self.selectedColor = selectedColor
        self.onColorSelected = onColorSelected
        self.onDismiss = onDismiss
        // Decompose initial color into HSB
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(selectedColor).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        self._hue = State(initialValue: Double(h))
        self._saturation = State(initialValue: Double(s))
        self._brightness = State(initialValue: Double(b))
    }

    private var currentColor: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    var body: some View {
        VStack(spacing: 12) {
            // 2D SV picker
            SaturationBrightnessPicker(hue: hue, saturation: saturation, brightness: brightness) { s, b in
                saturation = s; brightness = b
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1.4, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Hue rainbow bar
            HueBarView(hue: hue) { h in hue = h }
                .frame(maxWidth: .infinity, minHeight: 28, maxHeight: 28)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            // Preview + Select
            HStack(spacing: 12) {
                Circle()
                    .fill(currentColor)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 2))

                Button {
                    onColorSelected(currentColor)
                } label: {
                    Text("Selecionar")
                        .font(VitaTypography.labelLarge)
                        .foregroundStyle(VitaColors.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(VitaColors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Preset colors
            HStack(spacing: 0) {
                ForEach(presetColors, id: \.vitaHex) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.2), lineWidth: color.vitaHex == 0x000000 ? 1 : 0)
                        )
                        .frame(maxWidth: .infinity)
                        .onTapGesture { onColorSelected(color) }
                }
            }
        }
        .padding(16)
        .background(
            Color(hex: 0x0A0E14).opacity(0.97)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.5), radius: 20)
    }
}

// MARK: - Saturation/Brightness 2D Picker

private struct SaturationBrightnessPicker: View {
    let hue: Double
    let saturation: Double
    let brightness: Double
    let onChange: (Double, Double) -> Void

    private var pureHueColor: Color { Color(hue: hue, saturation: 1, brightness: 1) }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // White → pure hue (horizontal)
                LinearGradient(colors: [.white, pureHueColor], startPoint: .leading, endPoint: .trailing)
                // Transparent → black (vertical)
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)

                // Selection indicator
                Circle()
                    .stroke(Color.white, lineWidth: 2.5)
                    .frame(width: 20, height: 20)
                    .shadow(radius: 2)
                    .position(
                        x: saturation * geo.size.width,
                        y: (1 - brightness) * geo.size.height
                    )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        let s = (value.location.x / geo.size.width).clamped(to: 0...1)
                        let b = 1 - (value.location.y / geo.size.height).clamped(to: 0...1)
                        onChange(s, b)
                    }
            )
        }
    }
}

// MARK: - Hue Bar

private struct HueBarView: View {
    let hue: Double
    let onChange: (Double) -> Void

    private let hueColors: [Color] = stride(from: 0, through: 1, by: 1.0/12).map {
        Color(hue: $0, saturation: 1, brightness: 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(colors: hueColors, startPoint: .leading, endPoint: .trailing)
                // Thumb
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: geo.size.height, height: geo.size.height)
                    .shadow(radius: 2)
                    .position(x: hue * geo.size.width, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .local)
                    .onChanged { value in
                        onChange((value.location.x / geo.size.width).clamped(to: 0...1))
                    }
            )
        }
    }
}

// MARK: - Helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
