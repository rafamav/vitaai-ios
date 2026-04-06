import SwiftUI

// MARK: - NotebookListScreen
// Grid of notebooks — mirrors NotebookListScreen.kt (Android).
// Two-column grid with staggered entrance animation, pull-to-refresh,
// create dialog with color picker, delete via swipe.

@available(iOS 17, *)
struct NotebookListScreen: View {

    let onBack: () -> Void
    let onOpenNotebook: (UUID) -> Void

    @State private var viewModel: NotebookListViewModel
    @State private var appeared: Bool = false   // drives stagger animation

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    init(
        store: NotebookStore,
        onBack: @escaping () -> Void,
        onOpenNotebook: @escaping (UUID) -> Void
    ) {
        self.onBack = onBack
        self.onOpenNotebook = onOpenNotebook
        _viewModel = State(initialValue: NotebookListViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Group {
                    if viewModel.isLoading && viewModel.notebooks.isEmpty {
                        // Skeleton grid
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in
                                SkeletonCard()
                            }
                        }
                        .padding(16)

                    } else if viewModel.notebooks.isEmpty {
                        // Empty state
                        emptyState

                    } else {
                        // Notebook grid with pull-to-refresh
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(Array(viewModel.notebooks.enumerated()), id: \.element.id) { index, notebook in
                                    NotebookCard(
                                        notebook: notebook,
                                        onTap: { onOpenNotebook(notebook.id) },
                                        onDelete: {
                                            Task { await viewModel.deleteNotebook(id: notebook.id) }
                                        }
                                    )
                                    .opacity(appeared ? 1 : 0)
                                    .offset(y: appeared ? 0 : 20)
                                    .animation(
                                        .spring(response: 0.4, dampingFraction: 0.8)
                                            .delay(Double(index) * 0.06),
                                        value: appeared
                                    )
                                }
                            }
                            .padding(16)
                        }
                        .refreshable {
                            await viewModel.refresh()
                        }
                    }
                }

                // FAB — create notebook
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            viewModel.showCreate()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(VitaColors.surface)
                                .frame(width: 56, height: 56)
                                .background(VitaColors.accent, in: Circle())
                                .shadow(color: VitaColors.accent.opacity(0.4), radius: 12, x: 0, y: 4)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 32)
                        .accessibilityLabel("Criar notebook")
                        // sensoryFeedback removed (iOS 17+)
                    }
                }
            }
            .navigationTitle("Notebooks")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundColor(VitaColors.textPrimary)
                    }
                    .accessibilityLabel("Voltar")
                }
            }
            .task {
                await viewModel.onAppear()
                withAnimation { appeared = true }
            }
            .sheet(isPresented: $viewModel.showCreateDialog) {
                CreateNotebookSheet(
                    onDismiss: viewModel.hideCreate,
                    onCreate: { title, color in
                        Task { await viewModel.createNotebook(title: title, coverColor: color) }
                    }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed")
                .font(.system(size: 64))
                .foregroundColor(VitaColors.textTertiary)

            VStack(spacing: 8) {
                Text("Nenhum caderno criado")
                    .font(VitaTypography.titleMedium)
                    .foregroundColor(VitaColors.textPrimary)

                Text("Crie seu primeiro notebook para\ncomeçar a anotar.")
                    .font(VitaTypography.bodyMedium)
                    .foregroundColor(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                viewModel.showCreate()
            } label: {
                Text("Criar notebook")
                    .font(VitaTypography.labelLarge)
                    .foregroundColor(VitaColors.surface)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(VitaColors.accent, in: Capsule())
            }
        }
        .padding(32)
    }
}

// MARK: - NotebookCard

private struct NotebookCard: View {
    let notebook: Notebook
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Cover thumbnail area
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(notebook.swiftUIColor.opacity(0.15))
                        .overlay(
                            Image(systemName: "book.closed")
                                .font(.system(size: 36))
                                .foregroundColor(notebook.swiftUIColor.opacity(0.6))
                        )
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.0, contentMode: .fill)

                    // Delete button
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(VitaColors.textSecondary)
                            .frame(width: 28, height: 28)
                            .background(VitaColors.surfaceCard, in: Circle())
                    }
                    .padding(6)
                    .accessibilityLabel("Excluir \(notebook.title)")
                }

                // Title
                Text(notebook.title)
                    .font(VitaTypography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(VitaColors.textPrimary)
                    .lineLimit(2)

                // Meta
                Text("\(notebook.pageCount) pg · \(notebook.formattedDate)")
                    .font(VitaTypography.labelSmall)
                    .foregroundColor(VitaColors.textSecondary)
            }
            .padding(12)
            .background(VitaColors.surfaceCard, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(VitaColors.surfaceBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(notebook.title), \(notebook.pageCount) páginas")
        // sensoryFeedback removed (iOS 17+)
    }
}

// MARK: - SkeletonCard

private struct SkeletonCard: View {
    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                LinearGradient(
                    colors: [
                        VitaColors.surfaceCard,
                        VitaColors.surfaceElevated,
                        VitaColors.surfaceCard,
                    ],
                    startPoint: shimmer ? .leading : .trailing,
                    endPoint: shimmer ? .trailing : .leading
                )
            )
            .aspectRatio(0.75, contentMode: .fit)
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    shimmer = true
                }
            }
    }
}

// MARK: - CreateNotebookSheet

private struct CreateNotebookSheet: View {
    let onDismiss: () -> Void
    let onCreate: (String, UInt64) -> Void

    @State private var title: String = ""
    @State private var selectedColor: UInt64 = notebookCoverColors[0]
    @FocusState private var titleFocused: Bool

    private let colorColumns = [
        GridItem(.adaptive(minimum: 36), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                // Title field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nome")
                        .font(VitaTypography.labelMedium)
                        .foregroundColor(VitaColors.textSecondary)

                    TextField("Ex: Anatomia, Farmacologia…", text: $title)
                        .font(VitaTypography.bodyLarge)
                        .foregroundColor(VitaColors.textPrimary)
                        .autocorrectionDisabled()
                        .focused($titleFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            if !title.trimmingCharacters(in: .whitespaces).isEmpty {
                                onCreate(title.trimmingCharacters(in: .whitespaces), selectedColor)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(VitaColors.surfaceCard, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(VitaColors.accent, lineWidth: 1)
                        )
                }

                // Color picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cor do caderno")
                        .font(VitaTypography.labelMedium)
                        .foregroundColor(VitaColors.textSecondary)

                    LazyVGrid(columns: colorColumns, spacing: 10) {
                        ForEach(notebookCoverColors, id: \.self) { color in
                            let isSelected = color == selectedColor
                            Circle()
                                .fill(colorFromUInt64(color))
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            isSelected ? Color.white : Color.clear,
                                            lineWidth: 3
                                        )
                                )
                                .scaleEffect(isSelected ? 1.15 : 1.0)
                                .animation(.spring(response: 0.2), value: isSelected)
                                .onTapGesture { selectedColor = color }
                                // sensoryFeedback removed (iOS 17+)
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
            .background(VitaColors.surfaceElevated.ignoresSafeArea())
            .navigationTitle("Novo Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { onDismiss() }
                        .foregroundColor(VitaColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Criar") {
                        let t = title.trimmingCharacters(in: .whitespaces)
                        if !t.isEmpty { onCreate(t, selectedColor) }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(title.trimmingCharacters(in: .whitespaces).isEmpty
                        ? VitaColors.textTertiary
                        : VitaColors.accent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { titleFocused = true }
    }

    private func colorFromUInt64(_ value: UInt64) -> Color {
        Color(
            red:   Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue:  Double(value & 0xFF) / 255.0,
            opacity: Double((value >> 24) & 0xFF) / 255.0
        )
    }
}
