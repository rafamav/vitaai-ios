import SwiftUI

/// Floating annotation toolbar shown at the bottom of the PDF viewer.
/// When not in draw mode: shows a single "Anotar" button.
/// When in draw mode: expands to show all tools, colors, widths, undo/redo.
struct AnnotationToolbar: View {
    let isDrawMode: Bool
    let selectedTool: AnnotationTool
    let selectedColor: Color
    let strokeWidth: CGFloat
    let canUndo: Bool
    let canRedo: Bool
    let onToggleDrawMode: () -> Void
    let onSelectTool: (AnnotationTool) -> Void
    let onSelectColor: (Color) -> Void
    let onStrokeWidthChange: (CGFloat) -> Void
    let onUndo: () -> Void
    let onRedo: () -> Void
    let onShapeMode: (AnnotationTool) -> Void

    @State private var showColorPicker: Bool = false
    @State private var showShapeMenu: Bool = false

    private let surfaceBg = Color(hex: 0x1A1A2E).opacity(0.97)
    private let borderColor = Color.white.opacity(0.08)

    var body: some View {
        ZStack(alignment: .bottom) {
            // Color picker popup above toolbar
            if showColorPicker {
                ColorPickerView(
                    selectedColor: selectedColor,
                    onColorSelected: { color in
                        onSelectColor(color)
                        showColorPicker = false
                    },
                    onDismiss: { showColorPicker = false }
                )
                .frame(maxWidth: 320)
                .offset(y: -80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Main toolbar row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    if !isDrawMode {
                        // Collapsed: just the annotate button
                        ToolButton(
                            systemImage: "pencil.tip",
                            label: "Anotar",
                            isSelected: false,
                            accentColor: VitaColors.accent,
                            action: onToggleDrawMode
                        )
                    } else {
                        // Expanded toolbar
                        Group {
                            // Drawing tools
                            ToolButton(systemImage: "pencil", label: "Caneta",
                                       isSelected: selectedTool == .pen) { onSelectTool(.pen) }
                            ToolButton(systemImage: "highlighter", label: "Marca-texto",
                                       isSelected: selectedTool == .highlighter) { onSelectTool(.highlighter) }
                            ToolButton(systemImage: "eraser", label: "Borracha",
                                       isSelected: selectedTool == .eraser) { onSelectTool(.eraser) }

                            ToolbarDivider()

                            // Text tool
                            ToolButton(systemImage: "textformat", label: "Texto",
                                       isSelected: selectedTool == .text) { onSelectTool(.text) }

                            // Shape tool with menu
                            Menu {
                                Button { onShapeMode(.shapeLine) }   label: { Label("Linha",       systemImage: "line.diagonal") }
                                Button { onShapeMode(.shapeArrow) }  label: { Label("Seta",        systemImage: "arrow.up.right") }
                                Button { onShapeMode(.shapeRect) }   label: { Label("Retângulo",   systemImage: "rectangle") }
                                Button { onShapeMode(.shapeCircle) } label: { Label("Círculo",     systemImage: "circle") }
                            } label: {
                                ToolButtonLabel(
                                    systemImage: shapeSystemImage,
                                    label: "Forma",
                                    isSelected: selectedTool.isShapeTool
                                )
                            }

                            ToolbarDivider()

                            // Color swatch
                            Button {
                                withAnimation(.spring(duration: 0.25)) { showColorPicker.toggle() }
                            } label: {
                                VStack(spacing: 2) {
                                    Circle()
                                        .fill(selectedColor)
                                        .frame(width: 22, height: 22)
                                        .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 2))
                                    Text("Cor")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.white.opacity(0.7))
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }

                            ToolbarDivider()

                            // Stroke widths
                            StrokeWidthButton(label: "Fino",  value: 2,  current: strokeWidth, onChange: onStrokeWidthChange)
                            StrokeWidthButton(label: "Médio", value: 4,  current: strokeWidth, onChange: onStrokeWidthChange)
                            StrokeWidthButton(label: "Grosso", value: 8, current: strokeWidth, onChange: onStrokeWidthChange)

                            ToolbarDivider()

                            // Undo/Redo
                            ToolButton(systemImage: "arrow.uturn.backward", label: "Desfazer",
                                       isSelected: false, enabled: canUndo, action: onUndo)
                            ToolButton(systemImage: "arrow.uturn.forward", label: "Refazer",
                                       isSelected: false, enabled: canRedo, action: onRedo)

                            ToolbarDivider()

                            // Close draw mode
                            ToolButton(systemImage: "xmark", label: "Fechar",
                                       isSelected: false) {
                                showColorPicker = false
                                onToggleDrawMode()
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            .background(surfaceBg)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(borderColor, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.4), radius: 12)
            .animation(.spring(duration: 0.25), value: isDrawMode)
        }
    }

    private var shapeSystemImage: String {
        switch selectedTool {
        case .shapeLine:   return "line.diagonal"
        case .shapeArrow:  return "arrow.up.right"
        case .shapeCircle: return "circle"
        default:           return "rectangle"
        }
    }
}

// MARK: - Tool Button

private struct ToolButton: View {
    let systemImage: String
    let label: String
    let isSelected: Bool
    var accentColor: Color = VitaColors.accent
    var enabled: Bool = true
    let action: () -> Void

    var tint: Color {
        if !enabled { return VitaColors.textTertiary }
        return isSelected ? accentColor : .white
    }

    var body: some View {
        Button(action: action) {
            ToolButtonLabel(systemImage: systemImage, label: label, isSelected: isSelected,
                            accentColor: accentColor, enabled: enabled)
        }
        .disabled(!enabled)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isSelected)
    }
}

private struct ToolButtonLabel: View {
    let systemImage: String
    let label: String
    let isSelected: Bool
    var accentColor: Color = VitaColors.accent
    var enabled: Bool = true

    var tint: Color {
        if !enabled { return VitaColors.textTertiary }
        return isSelected ? accentColor : .white
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
            Text(label)
                .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                .foregroundStyle(tint.opacity(0.85))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isSelected ? accentColor.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct StrokeWidthButton: View {
    let label: String
    let value: CGFloat
    let current: CGFloat
    let onChange: (CGFloat) -> Void

    private var isSelected: Bool { current == value }
    private var dotSize: CGFloat { value == 2 ? 6 : value == 4 ? 10 : 14 }

    var body: some View {
        Button { onChange(value) } label: {
            VStack(spacing: 2) {
                Circle()
                    .fill(isSelected ? VitaColors.accent : Color.white.opacity(0.7))
                    .frame(width: dotSize, height: dotSize)
                    .frame(width: 22, height: 22)
                Text(label)
                    .font(.system(size: 9, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? VitaColors.accent : Color.white.opacity(0.7))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? VitaColors.accent.opacity(0.2) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isSelected)
    }
}

private struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 28)
            .padding(.horizontal, 4)
    }
}
