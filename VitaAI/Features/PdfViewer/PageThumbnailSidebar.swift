import SwiftUI
import PDFKit

/// Slide-in sidebar showing page thumbnails for quick PDF navigation.
struct PageThumbnailSidebar: View {
    let document: PDFDocument
    let pageCount: Int
    let currentPage: Int
    let isVisible: Bool
    let onPageSelected: (Int) -> Void

    var body: some View {
        Group {
            if isVisible {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            ForEach(0..<pageCount, id: \.self) { index in
                                ThumbnailItem(
                                    document: document,
                                    pageIndex: index,
                                    isCurrentPage: index == currentPage,
                                    onTap: { onPageSelected(index) }
                                )
                                .id(index)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(width: 110)
                    .background(VitaColors.surfaceCard.opacity(0.95))
                    .onChange(of: currentPage) { _, newPage in
                        withAnimation { proxy.scrollTo(newPage, anchor: .center) }
                    }
                }
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
