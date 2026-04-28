import SwiftUI
import PDFKit

/// Slide-in sidebar showing page thumbnails for quick PDF navigation.
struct PageThumbnailSidebar: View {
    let document: PDFDocument
    let pageCount: Int
    let currentPage: Int
    let isVisible: Bool
    let bookmarkedPages: Set<Int>
    let onPageSelected: (Int) -> Void
    var onToggleBookmarkFor: ((Int) -> Void)? = nil
    var onRotatePage: ((Int, Int) -> Void)? = nil
    var onMovePage: ((Int, Int) -> Void)? = nil
    var onDeletePage: ((Int) -> Void)? = nil
    var onDuplicatePage: ((Int) -> Void)? = nil

    @State private var filterBookmarks: Bool = false
    @State private var draggingIndex: Int? = nil
    @State private var dropTargetIndex: Int? = nil
    @State private var pendingDeleteIndex: Int? = nil

    private var visibleIndices: [Int] {
        if filterBookmarks {
            return (0..<pageCount).filter { bookmarkedPages.contains($0) }
        }
        return Array(0..<pageCount)
    }

    var body: some View {
        Group {
            if isVisible {
                VStack(spacing: 0) {
                    // Sidebar header with bookmark filter toggle
                    HStack(spacing: 6) {
                        Text(filterBookmarks ? "Marcadas" : "Páginas")
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                filterBookmarks.toggle()
                            }
                        } label: {
                            Image(systemName: filterBookmarks ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 13))
                                .foregroundStyle(filterBookmarks ? VitaColors.accentHover : VitaColors.textTertiary)
                                .frame(width: 28, height: 28)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(VitaColors.surfaceCard)
                    .overlay(
                        Rectangle()
                            .frame(height: 1)
                            .foregroundStyle(VitaColors.surfaceBorder),
                        alignment: .bottom
                    )

                    if filterBookmarks && visibleIndices.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "bookmark.slash")
                                .font(.system(size: 22))
                                .foregroundStyle(VitaColors.textTertiary)
                            Text("Sem marcadores")
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                LazyVStack(spacing: 8) {
                                    ForEach(visibleIndices, id: \.self) { index in
                                        ThumbnailItem(
                                            document: document,
                                            pageIndex: index,
                                            isCurrentPage: index == currentPage,
                                            isBookmarked: bookmarkedPages.contains(index),
                                            isDropTarget: dropTargetIndex == index,
                                            isDragging: draggingIndex == index,
                                            onTap: { onPageSelected(index) }
                                        )
                                        .id(index)
                                        // Drag-to-reorder (iOS 16+ Transferable API).
                                        // We carry only the pageIndex as String; ViewModel.movePage swaps.
                                        .draggable("\(index)") {
                                            ThumbnailItem(
                                                document: document,
                                                pageIndex: index,
                                                isCurrentPage: false,
                                                isBookmarked: bookmarkedPages.contains(index),
                                                isDropTarget: false,
                                                isDragging: true,
                                                onTap: {}
                                            )
                                            .onAppear { draggingIndex = index }
                                        }
                                        .dropDestination(for: String.self) { items, _ in
                                            defer {
                                                draggingIndex = nil
                                                dropTargetIndex = nil
                                            }
                                            guard let str = items.first, let src = Int(str), src != index,
                                                  let move = onMovePage else { return false }
                                            move(src, index)
                                            return true
                                        } isTargeted: { hovering in
                                            if hovering { dropTargetIndex = index }
                                            else if dropTargetIndex == index { dropTargetIndex = nil }
                                        }
                                        .contextMenu {
                                            Button {
                                                onPageSelected(index)
                                            } label: {
                                                Label("Ir para página", systemImage: "arrow.right")
                                            }
                                            if let toggle = onToggleBookmarkFor {
                                                Button {
                                                    toggle(index)
                                                } label: {
                                                    Label(
                                                        bookmarkedPages.contains(index) ? "Remover marcador" : "Marcar página",
                                                        systemImage: bookmarkedPages.contains(index) ? "bookmark.slash" : "bookmark"
                                                    )
                                                }
                                            }
                                            if let rotate = onRotatePage {
                                                Menu {
                                                    Button {
                                                        rotate(index, 90)
                                                    } label: {
                                                        Label("Girar à direita (90°)", systemImage: "rotate.right")
                                                    }
                                                    Button {
                                                        rotate(index, -90)
                                                    } label: {
                                                        Label("Girar à esquerda (-90°)", systemImage: "rotate.left")
                                                    }
                                                    Button {
                                                        rotate(index, 180)
                                                    } label: {
                                                        Label("Girar 180°", systemImage: "arrow.triangle.2.circlepath")
                                                    }
                                                } label: {
                                                    Label("Rotacionar página", systemImage: "rotate.right")
                                                }
                                            }
                                            if let duplicate = onDuplicatePage {
                                                Button {
                                                    duplicate(index)
                                                } label: {
                                                    Label("Duplicar página", systemImage: "plus.square.on.square")
                                                }
                                            }
                                            if let _ = onDeletePage, pageCount > 1 {
                                                Divider()
                                                Button(role: .destructive) {
                                                    pendingDeleteIndex = index
                                                } label: {
                                                    Label("Excluir página", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .onChange(of: currentPage) { newPage in
                                if visibleIndices.contains(newPage) {
                                    withAnimation { proxy.scrollTo(newPage, anchor: .center) }
                                }
                            }
                        }
                    }
                }
                .frame(width: 110)
                .background(VitaColors.surfaceCard.opacity(0.95))
                .transition(.move(edge: .leading))
                .alert(
                    "Excluir página?",
                    isPresented: Binding(
                        get: { pendingDeleteIndex != nil },
                        set: { if !$0 { pendingDeleteIndex = nil } }
                    ),
                    presenting: pendingDeleteIndex
                ) { idx in
                    Button("Excluir", role: .destructive) {
                        onDeletePage?(idx)
                        pendingDeleteIndex = nil
                    }
                    Button("Cancelar", role: .cancel) {
                        pendingDeleteIndex = nil
                    }
                } message: { idx in
                    Text("A página \(idx + 1) e suas anotações serão removidas. Não dá pra desfazer.")
                }
            }
        }
        .animation(.spring(duration: 0.3), value: isVisible)
    }
}

// MARK: - Thumbnail Item

private struct ThumbnailItem: View {
    let document: PDFDocument
    let pageIndex: Int
    let isCurrentPage: Bool
    let isBookmarked: Bool
    var isDropTarget: Bool = false
    var isDragging: Bool = false
    let onTap: () -> Void

    @State private var thumbnail: UIImage? = nil

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                Group {
                    if let img = thumbnail {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Rectangle()
                            .fill(VitaColors.surfaceElevated)
                            .overlay(
                                ProgressView().tint(VitaColors.accent)
                            )
                    }
                }
                .frame(width: 94)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(
                            isDropTarget ? VitaColors.accentHover : (isCurrentPage ? VitaColors.accent : VitaColors.surfaceBorder),
                            lineWidth: isDropTarget ? 3 : (isCurrentPage ? 2 : 1)
                        )
                )
                .opacity(isDragging ? 0.4 : 1.0)
                .scaleEffect(isDropTarget ? 1.04 : 1.0)
                .animation(.easeInOut(duration: 0.18), value: isDropTarget)
                .animation(.easeInOut(duration: 0.12), value: isDragging)

                // Page number badge
                Text("\(pageIndex + 1)")
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(isCurrentPage ? VitaColors.accent : VitaColors.textSecondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(VitaColors.surfaceCard.opacity(0.8))
                    .clipShape(
                        UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4)
                    )
            }
            .frame(width: 94)
            .padding(.horizontal, 8)
            // Bookmark indicator in top-right corner
            .overlay(alignment: .topTrailing) {
                if isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.accentHover)
                        .padding(4)
                }
            }
        }
        .buttonStyle(.plain)
        .task(id: pageIndex) {
            guard thumbnail == nil else { return }
            thumbnail = await renderThumbnail()
        }
    }

    private func renderThumbnail() async -> UIImage? {
        await Task.detached(priority: .background) {
            guard let page = document.page(at: pageIndex) else { return nil }
            return page.thumbnail(of: CGSize(width: 200, height: 280), for: .cropBox)
        }.value
    }
}
