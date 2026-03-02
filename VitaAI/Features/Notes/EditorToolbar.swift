import SwiftUI

// MARK: - EditorToolbar
// GoodNotes-style floating pill toolbar.
// Mirrors EditorToolbar.kt (Android).

struct EditorToolbar: View {

    // MARK: Bindings
    var currentBrush: BrushType
    var currentColor: UInt64
    var currentSize: Float
    var canUndo: Bool
    var canRedo: Bool

    var onBrushChange: (BrushType) -> Void
    var onColorChange: (UInt64) -> Void
    var onSizeChange: (Float) -> Void
    var onUndo: () -> Void
    var onRedo: () -> Void

    // MARK: Local state
    @State private var showSizeSlider = false

    // MARK: Toolbar palette colors (mirrors Android DrawingCanvas.kt)
    // Intentionally not from VitaColors — this is a dark floating UI surface
    private let pillBg      = Color(red: 0.165, green: 0.165, blue: 0.235)   // 0xFF2A2A3C
    private let pillBorder  = Color(red: 0.227, green: 0.227, blue: 0.298)   // 0xFF3A3A4C
    private let selectedBg  = Color(red: 0.251, green: 0.251, blue: 0.345)   // 0xFF404058

    var body: some View {
        VStack(spacing: 8) {
            // Size slider panel (shown above main toolbar)
            if showSizeSlider {
                sizeSliderPill
            }

            // Main toolbar pill
            mainPill
        }
    }

    // MARK: - Size slider

    private var sizeSliderPill: some View {
        HStack(spacing: 12) {
            // Preview dot sized to current brush size
            Circle()
                .fill(colorFromUInt64(currentColor))
                .frame(
                    width: CGFloat(currentSize.clamped(to: 2...20)),
                    height: CGFloat(currentSize.clamped(to: 2...20))
                )

            Slider(value: Binding(
                get: { Double(currentSize) },
                set: { onSizeChange(Float($0)) }
            ), in: 1...24)
            .tint(Color(red: 0.388, green: 0.400, blue: 0.945)) // indigo-500
            .frame(width: 160)

            Text("\(Int(currentSize))")
                .font(VitaTypography.labelSmall)
                .foregroundColor(Color.white.opacity(0.55))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(pillBg, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(pillBorder, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
    }

    // MARK: - Main pill

    private var mainPill: some View {
        HStack(spacing: 2) {
            // Pen
            ToolButton(
                selected: currentBrush == .pen,
                selectedBg: selectedBg,
                accessibilityLabel: "Caneta",
                action: { onBrushChange(.pen) }
            ) {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundColor(currentBrush == .pen ? .white : Color.white.opacity(0.55))
            }

            // Marker / Highlighter
            ToolButton(
                selected: currentBrush == .marker,
                selectedBg: selectedBg,
                accessibilityLabel: "Marcador",
                action: { onBrushChange(.marker) }
            ) {
                Image(systemName: "highlighter")
                    .font(.system(size: 16))
                    .foregroundColor(currentBrush == .marker ? .white : Color.white.opacity(0.55))
            }

            // Eraser
            ToolButton(
                selected: currentBrush == .eraser,
                selectedBg: selectedBg,
                accessibilityLabel: "Borracha",
                action: { onBrushChange(.eraser) }
            ) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(currentBrush == .eraser ? Color.white : Color.white.opacity(0.55))
                    .frame(width: 14, height: 14)
            }

            divider

            // Size button (shows current size as a dot)
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showSizeSlider.toggle()
                }
            } label: {
                Circle()
                    .fill(colorFromUInt64(currentColor))
                    .frame(
                        width: CGFloat(currentSize.clamped(to: 3...16)),
                        height: CGFloat(currentSize.clamped(to: 3...16))
                    )
                    .frame(width: 36, height: 36) // hit target
            }
            .background(showSizeSlider ? selectedBg : Color.clear, in: Circle())
            .accessibilityLabel("Tamanho do pincel: \(Int(currentSize))")

            divider

            // Color palette
            ForEach(Array(presetInkColors.enumerated()), id: \.offset) { index, color in
                let isSelected = color == currentColor
                Button {
                    onColorChange(color)
                } label: {
                    Circle()
                        .fill(colorFromUInt64(color))
                        .frame(width: isSelected ? 26 : 22, height: isSelected ? 26 : 22)
                        .overlay(
                            Circle()
                                .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: 2)
                        )
                        .animation(.spring(response: 0.2), value: isSelected)
                }
                .accessibilityLabel(presetInkColorNames[index] + (isSelected ? ", selecionado" : ""))
            }

            divider

            // Undo
            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16))
                    .foregroundColor(canUndo ? .white : Color.white.opacity(0.15))
            }
            .frame(width: 36, height: 36)
            .disabled(!canUndo)
            .accessibilityLabel("Desfazer")

            // Redo
            Button(action: onRedo) {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 16))
                    .foregroundColor(canRedo ? .white : Color.white.opacity(0.15))
            }
            .frame(width: 36, height: 36)
            .disabled(!canRedo)
            .accessibilityLabel("Refazer")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(pillBg, in: RoundedRectangle(cornerRadius: 28))
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .strokeBorder(pillBorder, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(pillBorder)
            .frame(width: 1, height: 24)
    }

    // MARK: - Helpers

    private func colorFromUInt64(_ value: UInt64) -> Color {
        Color(
            red:   Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue:  Double(value & 0xFF) / 255.0,
            opacity: Double((value >> 24) & 0xFF) / 255.0
        )
    }
}

// MARK: - ToolButton

private struct ToolButton<Label: View>: View {
    let selected: Bool
    let selectedBg: Color
    let accessibilityLabel: String
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .frame(width: 36, height: 36)
        }
        .background(selected ? selectedBg : Color.clear, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel(accessibilityLabel)
        .sensoryFeedback(.selection, trigger: selected)
    }
}

// MARK: - Comparable clamp helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
