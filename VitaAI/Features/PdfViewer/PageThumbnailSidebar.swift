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

    @State private var filterBookmarks: Bool = false

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
                                            onTap: { onPageSelected(index) }
                                        )
                                        .id(index)
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
                            isCurrentPage ? VitaColors.accent : VitaColors.surfaceBorder,
                            lineWidth: isCurrentPage ? 2 : 1
                        )
                )

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
