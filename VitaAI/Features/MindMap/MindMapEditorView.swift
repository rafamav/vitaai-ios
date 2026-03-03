import SwiftUI

// MARK: - MindMapEditorView
// Full mind map editor with canvas, toolbar, and dialogs.
// Mirrors MindMapEditorScreen.kt (Android).

struct MindMapEditorView: View {
    let mindMapId: String
    let onBack: () -> Void

    @State private var viewModel: MindMapEditorViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(
        mindMapId: String,
        store: MindMapStore,
        onBack: @escaping () -> Void
    ) {
        self.mindMapId = mindMapId
        self.onBack = onBack
        _viewModel = State(initialValue: MindMapEditorViewModel(mindMapId: mindMapId, store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VitaColors.surface.ignoresSafeArea()

                if viewModel.isLoading {
                    ProgressView()
                        .tint(VitaColors.accent)
                } else {
                    VStack(spacing: 0) {
                        // Canvas
                        MindMapCanvasView(
                            nodes: viewModel.nodes,
                            selectedNodeId: viewModel.selectedNodeId,
                            scale: viewModel.scale,
                            offsetX: viewModel.offsetX,
                            offsetY: viewModel.offsetY,
                            onSelectNode: { id in
                                viewModel.selectNode(id: id)
                            },
                            onMoveNode: { id, x, y in
                                viewModel.moveNode(id: id, x: x, y: y)
                            },
                            onDoubleTapNode: { _ in
                                viewModel.showEditText()
                            },
                            onTransformChanged: { scale, offsetX, offsetY in
                                viewModel.updateTransform(scale: scale, offsetX: offsetX, offsetY: offsetY)
                            }
                        )

                        // Toolbar
                        toolbar
                    }
                }
            }
            .navigationTitle(viewModel.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await viewModel.onDisappear()
                            onBack()
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(VitaColors.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showEditTextDialog) {
                editTextDialog
            }
            .sheet(isPresented: $viewModel.showColorPickerDialog) {
                colorPickerDialog
            }
            .task {
                await viewModel.onAppear()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .background {
                    Task { await viewModel.save() }
                }
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 20) {
            // Add node button
            Button {
                viewModel.addNode()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                    Text("Adicionar")
                        .font(.system(size: 11))
                }
                .foregroundStyle(viewModel.selectedNodeId != nil ? VitaColors.accent : VitaColors.textTertiary)
            }
            .disabled(viewModel.selectedNodeId == nil)

            // Edit text button
            Button {
                viewModel.showEditText()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                    Text("Editar")
                        .font(.system(size: 11))
                }
                .foregroundStyle(viewModel.selectedNodeId != nil ? VitaColors.accent : VitaColors.textTertiary)
            }
            .disabled(viewModel.selectedNodeId == nil)

            // Color picker button
            Button {
                viewModel.showColorPicker()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 24))
                    Text("Cor")
                        .font(.system(size: 11))
                }
                .foregroundStyle(viewModel.selectedNodeId != nil ? VitaColors.accent : VitaColors.textTertiary)
            }
            .disabled(viewModel.selectedNodeId == nil)

            // Delete node button
            Button {
                viewModel.deleteSelectedNode()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 24))
                    Text("Deletar")
                        .font(.system(size: 11))
                }
                .foregroundStyle(viewModel.selectedNodeId != nil ? Color.red : VitaColors.textTertiary)
            }
            .disabled(viewModel.selectedNodeId == nil)

            Spacer()

            // Zoom controls
            VStack(spacing: 4) {
                HStack(spacing: 12) {
                    Button {
                        let newScale = max(0.3, viewModel.scale - 0.2)
                        viewModel.updateTransform(scale: newScale, offsetX: viewModel.offsetX, offsetY: viewModel.offsetY)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 20))
                    }

                    Text("\(Int(viewModel.scale * 100))%")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 50)

                    Button {
                        let newScale = min(3.0, viewModel.scale + 0.2)
                        viewModel.updateTransform(scale: newScale, offsetX: viewModel.offsetX, offsetY: viewModel.offsetY)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 20))
                    }
                }
                .foregroundStyle(VitaColors.textSecondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(VitaColors.surfaceElevated)
        .overlay(
            Rectangle()
                .fill(VitaColors.surfaceBorder)
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Edit Text Dialog

    private var editTextDialog: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TextField("Texto do nó", text: $viewModel.editingText)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                Spacer()
            }
            .navigationTitle("Editar Texto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        viewModel.cancelEditText()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        viewModel.saveEditedText()
                    }
                    .disabled(viewModel.editingText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }

    // MARK: - Color Picker Dialog

    private var colorPickerDialog: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Escolha uma cor")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(VitaColors.textPrimary)
                    .padding(.top, 24)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                ], spacing: 16) {
                    ForEach(mindMapNodeColors, id: \.self) { color in
                        Button {
                            viewModel.selectColor(color)
                        } label: {
                            Circle()
                                .fill(colorFromARGB(color))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                )
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("Escolher Cor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        viewModel.cancelColorPicker()
                    }
                }
            }
        }
        .presentationDetents([.height(350)])
    }

    // MARK: - Helpers

    private func colorFromARGB(_ argb: UInt64) -> Color {
        let a = Double((argb >> 24) & 0xFF) / 255.0
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >> 8) & 0xFF) / 255.0
        let b = Double(argb & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
