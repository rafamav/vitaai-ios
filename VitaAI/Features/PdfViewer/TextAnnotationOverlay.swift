import SwiftUI

/// Overlay that renders text annotations on a PDF page.
/// Tap in active mode → create new text at that position.
/// Tap existing text → edit. Drag existing text → reposition.
struct TextAnnotationOverlay: View {
    let annotations: [TextAnnotation]
    let selectedColor: Color
    let isActive: Bool
    let onAddText: (TextAnnotation) -> Void
    let onUpdateText: (TextAnnotation) -> Void
    let onRemoveText: (UUID) -> Void

    @State private var editingId: UUID? = nil

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Tap-to-create capture (only when active and no text is being edited)
            if isActive && editingId == nil {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        let hitExisting = annotations.contains { ann in
                            let dx = location.x - ann.x
                            let dy = location.y - ann.y
                            return dx >= 0 && dx <= 200 && dy >= -20 && dy <= 40
                        }
                        guard !hitExisting else { return }
                        let newAnn = TextAnnotation(x: location.x, y: location.y, color: selectedColor)
                        onAddText(newAnn)
                        editingId = newAnn.id
                    }
            }

            // Render each annotation
            ForEach(annotations) { ann in
                DraggableTextAnnotationView(
                    annotation: ann,
                    isEditing: editingId == ann.id,
                    isActive: isActive,
                    onStartEditing: { editingId = ann.id },
                    onStopEditing: {
                        editingId = nil
                        if ann.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onRemoveText(ann.id)
                        }
                    },
                    onUpdate: onUpdateText
                )
            }
        }
    }
}

// MARK: - Draggable Text Annotation

private struct DraggableTextAnnotationView: View {
    let annotation: TextAnnotation
    let isEditing: Bool
    let isActive: Bool
    let onStartEditing: () -> Void
    let onStopEditing: () -> Void
    let onUpdate: (TextAnnotation) -> Void

    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0
    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if isEditing {
                    TextField("", text: Binding(
                        get: { annotation.text },
                        set: { onUpdate(annotation.withText($0)) }
                    ), axis: .vertical)
                    .font(.system(size: annotation.fontSize))
                    .foregroundStyle(annotation.color)
                    .tint(annotation.color)
                    .lineLimit(1...10)
                    .focused($focused)
                    .frame(minWidth: 80, maxWidth: 250)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(annotation.color.opacity(0.4), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .onSubmit { onStopEditing() }
                } else if !annotation.text.isEmpty {
                    Text(annotation.text)
                        .font(.system(size: annotation.fontSize))
                        .foregroundStyle(annotation.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
        }
        .position(
            x: annotation.x + offsetX + 40,
            y: annotation.y + offsetY + 10
        )
        .gesture(
            isActive && !isEditing
            ? DragGesture()
                .onChanged { value in
                    offsetX = value.translation.width
                    offsetY = value.translation.height
                }
                .onEnded { value in
                    onUpdate(annotation.withPosition(
                        x: annotation.x + value.translation.width,
                        y: annotation.y + value.translation.height
                    ))
                    offsetX = 0; offsetY = 0
                }
            : nil
        )
        .onTapGesture {
            if isActive { onStartEditing() }
        }
        .onChange(of: isEditing) { _, editing in
            if editing { focused = true }
        }
    }
}

// MARK: - TextAnnotation Helpers

private extension TextAnnotation {
    func withText(_ newText: String) -> TextAnnotation {
        var copy = self; copy.text = newText; return copy
    }
    func withPosition(x: CGFloat, y: CGFloat) -> TextAnnotation {
        var copy = self; copy.x = x; copy.y = y; return copy
    }
}
