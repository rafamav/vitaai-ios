import SwiftUI

// MARK: - EstudosScreen

struct EstudosScreen: View {
    @Environment(\.appContainer) private var container

    // Navigation callbacks — injected by AppRouter/MainTabView
    var onNavigateToCanvasConnect:    (() -> Void)?
    var onNavigateToNotebooks:         (() -> Void)?
    var onNavigateToMindMaps:          (() -> Void)?
    var onNavigateToFlashcardSession:  ((String) -> Void)?
    var onNavigateToFlashcardStats:    (() -> Void)?
    var onNavigateToPdfViewer:         ((URL) -> Void)?
    var onNavigateToSimulados:         (() -> Void)?

    @State private var viewModel: EstudosViewModel?

    var body: some View {
        Group {
            if let viewModel {
                EstudosContent(
                    viewModel: viewModel,
                    onNavigateToCanvasConnect:   onNavigateToCanvasConnect,
                    onNavigateToNotebooks:        onNavigateToNotebooks,
                    onNavigateToMindMaps:         onNavigateToMindMaps,
                    onNavigateToFlashcardSession: onNavigateToFlashcardSession,
                    onNavigateToFlashcardStats:   onNavigateToFlashcardStats,
                    onNavigateToPdfViewer:        onNavigateToPdfViewer,
                    onNavigateToSimulados:        onNavigateToSimulados
                )
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = EstudosViewModel(api: container.api)
                Task { await viewModel?.load() }
            }
        }
    }
}

// MARK: - Content

private struct EstudosContent: View {
    @Bindable var viewModel: EstudosViewModel
    let onNavigateToCanvasConnect:    (() -> Void)?
    let onNavigateToNotebooks:         (() -> Void)?
    let onNavigateToMindMaps:          (() -> Void)?
    let onNavigateToFlashcardSession:  ((String) -> Void)?
    let onNavigateToFlashcardStats:    (() -> Void)?
    let onNavigateToPdfViewer:         ((URL) -> Void)?
    let onNavigateToSimulados:         (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Canvas Connect Banner — matches Android CanvasConnectBanner
            if !viewModel.isLoading && !viewModel.canvasConnected {
                CanvasConnectBanner(onConnect: onNavigateToCanvasConnect)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // 4-tab bar (Disciplinas | Notebooks | Flashcards | PDFs)
            EstudosTabBar(selectedTab: $viewModel.selectedTab)

            // Body
            if let err = viewModel.error,
               viewModel.courses.isEmpty && viewModel.flashcardDisplayDecks.isEmpty {
                EstudosErrorView(message: err) {
                    Task { await viewModel.load() }
                }
            } else if viewModel.isLoading && viewModel.courses.isEmpty {
                EstudosSkeleton(tab: viewModel.selectedTab)
            } else {
                tabContent
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.canvasConnected)
    }
}

private extension EstudosContent {
    @ViewBuilder
    var tabContent: some View {
        switch viewModel.selectedTab {
        case .disciplinas:
            DisciplinasTab(
                viewModel: viewModel,
                onCourseClick: { courseId in viewModel.selectCourse(courseId) },
                onNavigateToSimulados: onNavigateToSimulados,
                onRefresh: { await viewModel.load() }
            )

        case .notebooks:
            NotebooksTab(
                onNavigate: onNavigateToNotebooks ?? {}
            )

        case .mindMaps:
            MindMapsTab(
                onNavigate: onNavigateToMindMaps ?? {}
            )

        case .flashcards:
            FlashcardsTab(
                decks: viewModel.flashcardDisplayDecks,
                isLoading: viewModel.isLoading,
                onDeckClick: { deckId in onNavigateToFlashcardSession?(deckId) },
                onStatsClick: onNavigateToFlashcardStats,
                onRefresh: { await viewModel.load() }
            )

        case .pdfs:
            PdfsTab(
                files: viewModel.files,
                isLoading: viewModel.isLoading,
                selectedCourseId: viewModel.selectedCourseId,
                downloadingFileId: viewModel.downloadingFileId,
                onFileClick: { file in
                    Task {
                        if let url = await viewModel.downloadFile(
                            fileId: file.id,
                            fileName: file.displayName
                        ) {
                            onNavigateToPdfViewer?(url)
                        }
                    }
                },
                onClearFilter: { viewModel.clearCourseFilter() },
                onRefresh: { await viewModel.load() }
            )
        }
    }
}

// MARK: - Tab Bar

private struct EstudosTabBar: View {
    @Binding var selectedTab: EstudosTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(EstudosTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.title)
                            .font(VitaTypography.labelMedium)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)
                            .foregroundStyle(
                                selectedTab == tab
                                    ? VitaColors.accent
                                    : VitaColors.textSecondary
                            )

                        Rectangle()
                            .fill(selectedTab == tab ? VitaColors.accent : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .animation(.easeInOut(duration: 0.2), value: selectedTab)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VitaColors.glassBorder)
                .frame(height: 1)
        }
    }
}

// MARK: - Canvas Connect Banner

private struct CanvasConnectBanner: View {
    let onConnect: (() -> Void)?

    var body: some View {
        VitaGlassCard {
            HStack(spacing: 12) {
                Image(systemName: "building.columns")
                    .font(.system(size: 22))
                    .foregroundStyle(VitaColors.accent.opacity(0.8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Conecte o Canvas LMS")
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("Sincronize disciplinas, PDFs e tarefas")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }

                Spacer()

                if let onConnect {
                    Button("Conectar") { onConnect() }
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(VitaColors.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Skeleton

private struct EstudosSkeleton: View {
    let tab: EstudosTab

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                switch tab {
                case .disciplinas, .flashcards:
                    ForEach(0..<5, id: \.self) { _ in
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(VitaColors.surfaceElevated)
                                .frame(width: 44, height: 44)
                                .shimmer()
                            VStack(alignment: .leading, spacing: 6) {
                                ShimmerText(width: 180, height: 16)
                                ShimmerText(width: 120, height: 12)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }

                case .pdfs:
                    ForEach(0..<2, id: \.self) { groupIdx in
                        VStack(alignment: .leading, spacing: 8) {
                            ShimmerText(width: 140, height: 14)
                                .padding(.horizontal, 16)
                            ForEach(0..<3, id: \.self) { _ in
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(VitaColors.surfaceElevated)
                                        .frame(width: 22, height: 22)
                                        .shimmer()
                                    VStack(alignment: .leading, spacing: 4) {
                                        ShimmerText(width: 200, height: 14)
                                        ShimmerText(width: 140, height: 12)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        if groupIdx == 0 { Spacer().frame(height: 8) }
                    }

                case .notebooks, .mindMaps:
                    ForEach(0..<5, id: \.self) { _ in
                        ShimmerBox(height: 76, cornerRadius: 14)
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 100)
        }
    }
}

// MARK: - Error View

private struct EstudosErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(VitaColors.dataAmber)
            Text("Erro ao carregar")
                .font(VitaTypography.titleMedium)
                .foregroundStyle(VitaColors.textPrimary)
            Text(message)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button("Tentar Novamente", action: onRetry)
                .font(VitaTypography.labelMedium)
                .fontWeight(.semibold)
                .foregroundStyle(VitaColors.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(VitaColors.accent)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Spacer()
        }
    }
}

// MARK: - Disciplinas Tab

private struct DisciplinasTab: View {
    @Bindable var viewModel: EstudosViewModel
    let onCourseClick: (String) -> Void
    var onNavigateToSimulados: (() -> Void)?
    var onRefresh: (() async -> Void)?

    @State private var isGridView = false

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        if !viewModel.isLoading && viewModel.courses.isEmpty {
            VitaEmptyState(
                title: "Nenhuma disciplina",
                message: "Conecte o Canvas para sincronizar suas disciplinas.",
                actionText: nil,
                onAction: nil
            ) {
                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(VitaColors.accent)
            }
        } else {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Toolbar: sort menu + grid/list toggle
                    DisciplinasToolbar(
                        sortOption: $viewModel.sortOption,
                        isGridView: $isGridView
                    )

                    // Simulados entry card
                    if let onSimulados = onNavigateToSimulados {
                        SimuladosEntryCard(onTap: onSimulados)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                    }

                    if isGridView {
                        // Grid layout
                        LazyVGrid(columns: gridColumns, spacing: 12) {
                            ForEach(
                                Array(viewModel.sortedCourses.enumerated()),
                                id: \.element.id
                            ) { index, course in
                                CourseGridCell(
                                    course: course,
                                    colorIndex: index,
                                    isFavorite: viewModel.isFavorite(course.id),
                                    onFavoriteToggle: { viewModel.toggleFavorite(course.id) },
                                    onClick: { onCourseClick(course.id) }
                                )
                                .transition(.opacity.combined(with: .scale))
                                .animation(
                                    .easeOut(duration: 0.3).delay(Double(index) * 0.04),
                                    value: viewModel.sortedCourses.count
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    } else {
                        // List layout
                        LazyVStack(spacing: 12) {
                            ForEach(
                                Array(viewModel.sortedCourses.enumerated()),
                                id: \.element.id
                            ) { index, course in
                                CourseRow(
                                    course: course,
                                    colorIndex: index,
                                    isFavorite: viewModel.isFavorite(course.id),
                                    onFavoriteToggle: { viewModel.toggleFavorite(course.id) },
                                    onClick: { onCourseClick(course.id) }
                                )
                                .transition(.opacity.combined(with: .move(edge: .bottom)))
                                .animation(
                                    .easeOut(duration: 0.3).delay(Double(index) * 0.06),
                                    value: viewModel.sortedCourses.count
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 100)
                    }
                }
            }
            .refreshable {
                await onRefresh?()
            }
            .animation(.easeInOut(duration: 0.25), value: isGridView)
        }
    }
}

// MARK: - Simulados Entry Card

private struct SimuladosEntryCard: View {
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VitaGlassCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VitaColors.accent.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "text.badge.checkmark")
                            .font(.system(size: 20))
                            .foregroundStyle(VitaColors.accent)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Simulados")
                            .font(VitaTypography.bodyLarge)
                            .fontWeight(.semibold)
                            .foregroundStyle(VitaColors.textPrimary)
                        Text("Pratique com questões de múltipla escolha")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Disciplinas Toolbar (Sort + Grid/List Toggle)

private struct DisciplinasToolbar: View {
    @Binding var sortOption: CourseSortOption
    @Binding var isGridView: Bool

    var body: some View {
        HStack {
            // Sort menu
            Menu {
                ForEach(CourseSortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sortOption = option
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Label(option.label, systemImage: option.iconName)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 12, weight: .medium))
                    Text(sortOption.label)
                        .font(VitaTypography.labelSmall)
                        .fontWeight(.medium)
                }
                .foregroundStyle(VitaColors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(VitaColors.glassBg)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(VitaColors.glassBorder, lineWidth: 1)
                )
            }

            Spacer()

            // Grid / List toggle
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isGridView.toggle()
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: isGridView ? "list.bullet" : "square.grid.2x2")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(VitaColors.glassBg)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }
}

// MARK: - Course Row (List Mode)

private struct CourseRow: View {
    let course: Course
    let colorIndex: Int
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    let onClick: () -> Void

    private var folderColor: Color {
        FolderPalette.color(forIndex: colorIndex)
    }

    var body: some View {
        Button(action: onClick) {
            VitaGlassCard {
                HStack(spacing: 14) {
                    // Colorful folder icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(folderColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "folder.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(folderColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(course.name)
                            .font(VitaTypography.bodyLarge)
                            .fontWeight(.medium)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(2)
                        Text("\(course.filesCount) arquivo\(course.filesCount == 1 ? "" : "s") · \(course.assignmentsCount) tarefa\(course.assignmentsCount == 1 ? "" : "s")")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }

                    Spacer()

                    // Star/Favorite button
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            onFavoriteToggle()
                        }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: isFavorite ? "star.fill" : "star")
                            .font(.system(size: 16))
                            .foregroundStyle(
                                isFavorite ? VitaColors.dataAmber : VitaColors.textTertiary
                            )
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Course Grid Cell (Grid Mode)

private struct CourseGridCell: View {
    let course: Course
    let colorIndex: Int
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    let onClick: () -> Void

    private var folderColor: Color {
        FolderPalette.color(forIndex: colorIndex)
    }

    var body: some View {
        Button(action: onClick) {
            VitaGlassCard {
                VStack(spacing: 10) {
                    // Top row: folder icon + star
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                onFavoriteToggle()
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Image(systemName: isFavorite ? "star.fill" : "star")
                                .font(.system(size: 14))
                                .foregroundStyle(
                                    isFavorite ? VitaColors.dataAmber : VitaColors.textTertiary
                                )
                                .contentTransition(.symbolEffect(.replace))
                        }
                        .buttonStyle(.plain)
                    }

                    // Centered folder icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(folderColor.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: "folder.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(folderColor)
                    }

                    // Course name
                    Text(course.name)
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.medium)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: 30)

                    // File count
                    Text("\(course.filesCount) arquivo\(course.filesCount == 1 ? "" : "s")")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notebooks Tab

private struct NotebooksTab: View {
    let onNavigate: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(VitaColors.accent.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(VitaColors.accent)
                }

                Text("Meus Notebooks")
                    .font(VitaTypography.titleMedium)
                    .fontWeight(.medium)
                    .foregroundStyle(VitaColors.textPrimary)

                Text("Toque para abrir seus notebooks de estudo")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button(action: onNavigate) {
                    Text("Abrir Notebooks")
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(VitaColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 100)
        .contentShape(Rectangle())
        .onTapGesture { onNavigate() }
    }
}

// MARK: - MindMaps Tab

private struct MindMapsTab: View {
    let onNavigate: () -> Void

    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(VitaColors.accent.opacity(0.1))
                        .frame(width: 80, height: 80)
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 36))
                        .foregroundStyle(VitaColors.accent)
                }

                Text("Mapas Mentais")
                    .font(VitaTypography.titleMedium)
                    .fontWeight(.medium)
                    .foregroundStyle(VitaColors.textPrimary)

                Text("Organize ideias e conceitos visualmente")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button(action: onNavigate) {
                    Text("Abrir Mapas Mentais")
                        .font(VitaTypography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(VitaColors.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 100)
        .contentShape(Rectangle())
        .onTapGesture { onNavigate() }
    }
}

// MARK: - Flashcards Tab

private struct FlashcardsTab: View {
    let decks: [FlashcardDeckDisplayEntry]
    var isLoading: Bool = false
    let onDeckClick: (String) -> Void
    var onStatsClick: (() -> Void)?
    var onRefresh: (() async -> Void)?

    var body: some View {
        if !isLoading && decks.isEmpty {
            VitaEmptyState(
                title: "Nenhum flashcard",
                message: "Crie decks de flashcards para começar a revisar.",
                actionText: nil,
                onAction: nil
            ) {
                Image(systemName: "rectangle.on.rectangle.angled")
                    .font(.system(size: 44))
                    .foregroundStyle(VitaColors.accent)
            }
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    // Stats entry button — mirrors Android header pattern
                    if let onStats = onStatsClick {
                        Button(action: onStats) {
                            HStack(spacing: 10) {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(VitaColors.accent)

                                Text("Ver Estatísticas")
                                    .font(VitaTypography.labelLarge)
                                    .foregroundStyle(VitaColors.accent)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundStyle(VitaColors.textTertiary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(VitaColors.accent.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(VitaColors.accent.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    ForEach(Array(decks.enumerated()), id: \.element.id) { index, deck in
                        FlashcardRow(deck: deck, onClick: { onDeckClick(deck.id) })
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                            .animation(
                                .easeOut(duration: 0.3).delay(Double(index) * 0.06),
                                value: decks.count
                            )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
            .refreshable {
                await onRefresh?()
            }
        }
    }
}

private struct FlashcardRow: View {
    let deck: FlashcardDeckDisplayEntry
    let onClick: () -> Void

    var body: some View {
        Button(action: onClick) {
            VitaGlassCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(VitaColors.accent.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "rectangle.on.rectangle.angled")
                            .font(.system(size: 18))
                            .foregroundStyle(VitaColors.accent)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(deck.name)
                            .font(VitaTypography.bodyLarge)
                            .fontWeight(.medium)
                            .foregroundStyle(VitaColors.textPrimary)

                        if !deck.courseName.isEmpty {
                            Text(deck.courseName)
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textSecondary)
                        }

                        // Progress bar — mirrors Android LinearProgressIndicator
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(VitaColors.surfaceElevated)
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(VitaColors.accent)
                                    .frame(
                                        width: geo.size.width * CGFloat(deck.progress),
                                        height: 4
                                    )
                                    .animation(.easeOut(duration: 0.4), value: deck.progress)
                            }
                        }
                        .frame(height: 4)

                        Text("\(deck.masteredCount)/\(deck.cardCount) dominados")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PDFs Tab

private struct PdfsTab: View {
    let files: [CanvasFile]
    var isLoading: Bool = false
    var selectedCourseId: String?
    let downloadingFileId: String?
    let onFileClick: (CanvasFile) -> Void
    let onClearFilter: () -> Void
    var onRefresh: (() async -> Void)?

    private var pdfs: [CanvasFile] {
        files.filter {
            $0.contentType?.contains("pdf") == true || $0.displayName.hasSuffix(".pdf")
        }
    }

    // Returns ordered groups preserving encounter order (preserves course sort)
    private var grouped: [(key: String, files: [CanvasFile])] {
        var dict: [(key: String, files: [CanvasFile])] = []
        var seen: [String: Int] = [:]
        for file in pdfs {
            let key = file.courseName ?? "Outros"
            if let idx = seen[key] {
                dict[idx].files.append(file)
            } else {
                seen[key] = dict.count
                dict.append((key: key, files: [file]))
            }
        }
        return dict
    }

    var body: some View {
        if !isLoading && pdfs.isEmpty {
            VitaEmptyState(
                title: "Nenhum PDF",
                message: "Conecte o Canvas para sincronizar seus materiais em PDF.",
                actionText: nil,
                onAction: nil
            ) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(VitaColors.accent)
            }
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    // Active filter pill
                    if selectedCourseId != nil {
                        Button(action: onClearFilter) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                Text("Limpar filtro de disciplina")
                                    .font(VitaTypography.labelSmall)
                            }
                            .foregroundStyle(VitaColors.accent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(VitaColors.accent.opacity(0.1))
                            .clipShape(Capsule())
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                    }

                    PdfsGroupedList(
                        grouped: grouped,
                        downloadingFileId: downloadingFileId,
                        onFileClick: onFileClick
                    )
                }
                .padding(.bottom, 100)
            }
            .refreshable {
                await onRefresh?()
            }
        }
    }
}

// Extracted into its own view to compute stagger indexes cleanly.
private struct PdfsGroupedList: View {
    let grouped: [(key: String, files: [CanvasFile])]
    let downloadingFileId: String?
    let onFileClick: (CanvasFile) -> Void

    // Pre-flatten groups into a typed list to avoid mutable state in @ViewBuilder.
    private var flatItems: [PdfListItem] {
        var result: [PdfListItem] = []
        var fileIndex = 0
        for group in grouped {
            result.append(.header(group.key))
            for file in group.files {
                result.append(.file(file, staggerIndex: fileIndex))
                fileIndex += 1
            }
        }
        return result
    }

    var body: some View {
        ForEach(Array(flatItems.enumerated()), id: \.offset) { _, item in
            switch item {
            case .header(let title):
                Text(title)
                    .font(VitaTypography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.accent)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 4)

            case .file(let file, let idx):
                FileRow(
                    file: file,
                    isDownloading: file.id == downloadingFileId,
                    onClick: { onFileClick(file) }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .animation(
                    .easeOut(duration: 0.3).delay(Double(idx) * 0.05),
                    value: grouped.count
                )
            }
        }
    }

    private enum PdfListItem {
        case header(String)
        case file(CanvasFile, staggerIndex: Int)
    }
}

private struct FileRow: View {
    let file: CanvasFile
    var isDownloading: Bool = false
    let onClick: () -> Void

    private var isPdf: Bool {
        file.contentType?.contains("pdf") == true || file.displayName.hasSuffix(".pdf")
    }

    var body: some View {
        Button(action: { if !isDownloading { onClick() } }) {
            VitaGlassCard {
                HStack(spacing: 12) {
                    if isDownloading {
                        ProgressView()
                            .tint(VitaColors.accent)
                            .frame(width: 22, height: 22)
                    } else {
                        Image(systemName: isPdf ? "doc.fill" : "doc.text.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(
                                isPdf ? VitaColors.textSecondary : VitaColors.dataBlue
                            )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.displayName)
                            .font(VitaTypography.bodyMedium)
                            .fontWeight(.medium)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        if let module = file.moduleName {
                            Text(module)
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if !isDownloading {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 16))
                            .foregroundStyle(VitaColors.accent.opacity(0.6))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .buttonStyle(.plain)
        .opacity(isDownloading ? 0.7 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isDownloading)
    }
}
