import SwiftUI

// MARK: - MindMapListView
// Grid of mind maps — mirrors MindMapListScreen.kt (Android).
// Two-column grid with staggered entrance animation, pull-to-refresh,
// create dialog, delete via swipe.

struct MindMapListView: View {

    let onBack: () -> Void
    let onOpenMindMap: (String) -> Void

    @State private var viewModel: MindMapListViewModel
    @State private var appeared: Bool = false   // drives stagger animation
    @State private var createTitle: String = ""

    let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    init(
        store: MindMapStore,
        onBack: @escaping () -> Void,
        onOpenMindMap: @escaping (String) -> Void
    ) {
        self.onBack = onBack
        self.onOpenMindMap = onOpenMindMap
        _viewModel = State(initialValue: MindMapListViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VitaColors.surface.ignoresSafeArea()

                Group {
                    if viewModel.isLoading && viewModel.mindMaps.isEmpty {
                        // Skeleton grid
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(0..<4, id: \.self) { _ in
                                SkeletonCard()
                            }
                        }
                        .padding(16)

                    } else if viewModel.mindMaps.isEmpty {
                        // Empty state
                        emptyState

                    } else {
                        // MindMap grid with pull-to-refresh
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(Array(viewModel.mindMaps.enumerated()), id: \.element.id) { index, mindMap in
                                    MindMapCard(
                                        mindMap: mindMap,
                                        onTap: { onOpenMindMap(mindMap.id) },
                                        onDelete: {
                                            Task { await viewModel.deleteMindMap(id: mindMap.id) }
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

                // FAB — create mind map
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button {
                            viewModel.showCreate()
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(VitaColors.accent)
                                .clipShape(Circle())
                                .shadow(color: VitaColors.accent.opacity(0.4), radius: 12, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Mapas Mentais")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        onBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(VitaColors.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showCreateDialog) {
                createDialog
            }
            .task {
                await viewModel.onAppear()
                appeared = true
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VitaEmptyState(
            title: "Nenhum mapa mental",
            message: "Crie mapas mentais para organizar ideias e conceitos visualmente",
            actionText: "Criar Mapa Mental",
            onAction: { viewModel.showCreate() }
        ) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(VitaColors.accent)
        }
    }

    // MARK: - Create Dialog

    private var createDialog: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TextField("Título do mapa mental", text: $createTitle)
                    .textFieldStyle(.roundedBorder)
                    .padding()

                Spacer()
            }
            .navigationTitle("Novo Mapa Mental")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        createTitle = ""
                        viewModel.hideCreate()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Criar") {
                        Task {
                            if let newId = await viewModel.createMindMap(title: createTitle) {
                                createTitle = ""
                                onOpenMindMap(newId)
                            }
                        }
                    }
                    .disabled(createTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}

// MARK: - MindMapCard

private struct MindMapCard: View {
    let mindMap: MindMap
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                // Color accent bar
                Rectangle()
                    .fill(mindMap.coverSwiftUIColor)
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Text(mindMap.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(2)

                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 12))
                            .foregroundStyle(VitaColors.textSecondary)
                        Text("\(mindMap.nodes.count) nós")
                            .font(.system(size: 12))
                            .foregroundStyle(VitaColors.textSecondary)
                    }

                    Text(mindMap.updatedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .padding(12)
            }
            .background(VitaColors.surfaceElevated)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(VitaColors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Deletar", systemImage: "trash")
            }
        }
    }
}

// MARK: - SkeletonCard

private struct SkeletonCard: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle()
                .fill(VitaColors.textTertiary.opacity(0.3))
                .frame(height: 4)

            VStack(alignment: .leading, spacing: 8) {
                Rectangle()
                    .fill(VitaColors.textTertiary.opacity(0.3))
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(VitaColors.textTertiary.opacity(0.3))
                    .frame(height: 12)
                    .frame(width: 80)

                Rectangle()
                    .fill(VitaColors.textTertiary.opacity(0.3))
                    .frame(height: 11)
                    .frame(width: 100)
            }
            .padding(12)
        }
        .background(
            LinearGradient(
                colors: [
                    VitaColors.surfaceElevated,
                    VitaColors.surfaceCard,
                    VitaColors.surfaceElevated,
                ],
                startPoint: shimmer ? .leading : .trailing,
                endPoint: shimmer ? .trailing : .leading
            )
        )
        .cornerRadius(12)
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                shimmer = true
            }
        }
    }
}
