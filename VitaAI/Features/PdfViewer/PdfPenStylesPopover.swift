import SwiftUI
import PencilKit

// MARK: - PdfPenStylesPopover
//
// Goodnotes/Notability-style picker for pen tool style.
// Opens via long-press on the pen toolbar button (handled in PdfToolbar via
// `onPenLongPress`). User customizes:
//   • Tipo (esferográfica / marcador / pincel)
//   • Espessura (1pt → 20pt)
//   • Cor (8 fixas + ColorPicker custom)
//
// Persistence: UserDefaults keys `pdf.pen.{style|width|color}` so the next
// open of any PDF re-applies the user's preference.
//
// Output: callback `onApply(PKInkingTool)` so the screen can push the new
// tool into the active PKCanvasView (and the PKToolPicker for next pages).

enum PdfPenStyle: String, CaseIterable, Identifiable {
    case ballpoint  // PKInk.InkType.pen
    case marker     // PKInk.InkType.marker
    case fountain   // PKInk.InkType.fountainPen (iOS 17+)

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ballpoint: return "Esferográfica"
        case .marker:    return "Marcador"
        case .fountain:  return "Pincel"
        }
    }

    var icon: String {
        switch self {
        case .ballpoint: return "pencil.tip"
        case .marker:    return "highlighter"
        case .fountain:  return "paintbrush.pointed"
        }
    }

    var inkType: PKInk.InkType {
        switch self {
        case .ballpoint: return .pen
        case .marker:    return .marker
        case .fountain:
            if #available(iOS 17.0, *) { return .fountainPen }
            return .pen
        }
    }
}

struct PdfPenStylesPopover: View {
    // 8 cores canônicas — gold accent + neutros + 5 destaques de anotação.
    private static let palette: [Color] = [
        VitaColors.accent,       // gold (default)
        Color(white: 0.1),       // preto
        Color(white: 0.95),      // branco
        Color(red: 0.95, green: 0.30, blue: 0.30), // vermelho
        Color(red: 0.30, green: 0.65, blue: 0.95), // azul
        Color(red: 0.40, green: 0.80, blue: 0.50), // verde
        Color(red: 0.95, green: 0.65, blue: 0.30), // laranja
        Color(red: 0.75, green: 0.45, blue: 0.95)  // roxo
    ]

    @AppStorage("pdf.pen.style") private var styleRaw: String = PdfPenStyle.ballpoint.rawValue
    @AppStorage("pdf.pen.width") private var widthValue: Double = 3.0
    @AppStorage("pdf.pen.colorHex") private var colorHex: String = "#F0B742"

    let onApply: (PKInkingTool) -> Void

    private var currentStyle: PdfPenStyle {
        PdfPenStyle(rawValue: styleRaw) ?? .ballpoint
    }

    private var currentColor: Color {
        Color(hex: colorHex) ?? VitaColors.accent
    }

    var body: some View {
        VitaGlassCard(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Estilo da caneta")
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)

                // Type chips
                HStack(spacing: 8) {
                    ForEach(PdfPenStyle.allCases) { style in
                        styleChip(style)
                    }
                }

                // Width slider
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Espessura")
                            .font(VitaTypography.labelMedium)
                            .foregroundStyle(VitaColors.textSecondary)
                        Spacer()
                        Text("\(Int(widthValue)) pt")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                            .monospacedDigit()
                    }
                    Slider(value: $widthValue, in: 1...20, step: 1)
                        .tint(VitaColors.accent)
                        .onChange(of: widthValue) { _, _ in apply() }
                    // Live preview line
                    Capsule()
                        .fill(currentColor)
                        .frame(height: max(1, CGFloat(widthValue)))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }

                // Color palette
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cor")
                        .font(VitaTypography.labelMedium)
                        .foregroundStyle(VitaColors.textSecondary)
                    HStack(spacing: 10) {
                        ForEach(Self.palette.indices, id: \.self) { idx in
                            colorDot(Self.palette[idx])
                        }
                        // Custom color picker
                        ColorPicker("", selection: Binding(
                            get: { currentColor },
                            set: { newColor in
                                colorHex = newColor.toHex() ?? colorHex
                                apply()
                            }
                        ), supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 28, height: 28)
                    }
                }
            }
            .padding(18)
        }
        .frame(width: 320)
        .onAppear { apply() }
    }

    // MARK: - Subviews

    @ViewBuilder
    private func styleChip(_ style: PdfPenStyle) -> some View {
        let active = (style == currentStyle)
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeInOut(duration: 0.18)) {
                styleRaw = style.rawValue
            }
            apply()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: style.icon)
                    .font(.system(size: 18, weight: .regular))
                Text(style.label)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(active ? VitaColors.accent.opacity(0.18) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(active ? VitaColors.accent.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 0.8)
            )
            .foregroundStyle(active ? VitaColors.accent : VitaColors.textSecondary)
            .scaleEffect(active ? 1.03 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: active)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func colorDot(_ color: Color) -> some View {
        let hex = color.toHex() ?? ""
        let active = hex.lowercased() == colorHex.lowercased()
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            colorHex = hex
            apply()
        } label: {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 28, height: 28)
                Circle()
                    .stroke(active ? VitaColors.accent : Color.white.opacity(0.18),
                            lineWidth: active ? 2.5 : 0.8)
                    .frame(width: 28, height: 28)
            }
            .scaleEffect(active ? 1.15 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: active)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Apply

    private func apply() {
        let uiColor = UIColor(currentColor)
        let tool = PKInkingTool(currentStyle.inkType, color: uiColor, width: CGFloat(widthValue))
        onApply(tool)
    }
}

// MARK: - PdfHighlightColorPopover (apenas cor)
//
// Highlighter sempre usa marker mode com 40% opacity. User só escolhe cor.

struct PdfHighlightColorPopover: View {
    private static let palette: [Color] = [
        Color(red: 1.0, green: 0.85, blue: 0.30),  // amarelo (default)
        Color(red: 0.55, green: 0.92, blue: 0.55), // verde
        Color(red: 0.98, green: 0.62, blue: 0.78), // rosa
        Color(red: 0.55, green: 0.78, blue: 1.0)   // azul
    ]

    @AppStorage("pdf.highlight.colorHex") private var colorHex: String = "#FFD84D"

    let onApply: (UIColor) -> Void

    var body: some View {
        VitaGlassCard(cornerRadius: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cor do marca-texto")
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)

                HStack(spacing: 12) {
                    ForEach(Self.palette.indices, id: \.self) { idx in
                        colorChip(Self.palette[idx])
                    }
                }

                Text("Opacidade fixa em 40%")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(18)
        }
        .frame(width: 280)
        .onAppear { applyCurrent() }
    }

    @ViewBuilder
    private func colorChip(_ color: Color) -> some View {
        let hex = color.toHex() ?? ""
        let active = hex.lowercased() == colorHex.lowercased()
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            colorHex = hex
            applyCurrent()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.4))
                    .frame(width: 48, height: 36)
                RoundedRectangle(cornerRadius: 10)
                    .stroke(active ? VitaColors.accent : Color.white.opacity(0.2),
                            lineWidth: active ? 2.5 : 0.8)
                    .frame(width: 48, height: 36)
            }
            .scaleEffect(active ? 1.08 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: active)
        }
        .buttonStyle(.plain)
    }

    private func applyCurrent() {
        let base = Color(hex: colorHex) ?? Color.yellow
        onApply(UIColor(base).withAlphaComponent(0.4))
    }
}

// MARK: - Color hex helpers (local — minimal)

private extension Color {
    init?(hex: String) {
        let trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard trimmed.count == 6, let v = UInt32(trimmed, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let R = Int(round(r * 255)), G = Int(round(g * 255)), B = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", R, G, B)
    }
}
