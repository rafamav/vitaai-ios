import SwiftUI
import PDFKit

// MARK: - PdfOutlineSheet
//
// Lê PDFDocument.outlineRoot (Apple PDFKit nativo) e renderiza o sumário
// (TOC) em árvore recursiva. Cada node é tappable → pula pra página de
// destino. Nodes com filhos são expansíveis (chevron rotaciona).
//
// Sem persistência: TOC é live do PDF, não muda.
//
// Empty state: livros médicos antigos / scans não têm outlineRoot — comum.

struct PdfOutlineSheet: View {
    let document: PDFDocument
    let onJumpToPage: (Int) -> Void

    private var rootNodes: [PDFOutline] {
        guard let root = document.outlineRoot else { return [] }
        return (0..<root.numberOfChildren).compactMap { root.child(at: $0) }
    }

    var body: some View {
        VitaSheet(title: "Sumário") {
            if rootNodes.isEmpty {
                emptyState
            } else {
                listContent
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "list.bullet.indent")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(VitaColors.textTertiary)
            Text("Esse PDF não tem sumário (TOC)")
                .font(VitaTypography.bodyMedium)
                .foregroundStyle(VitaColors.textSecondary)
            Text("Livros médicos modernos vêm com índice navegável; scans antigos não.")
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(0..<rootNodes.count, id: \.self) { idx in
                    OutlineNodeView(
                        node: rootNodes[idx],
                        document: document,
                        depth: 0,
                        onJumpToPage: onJumpToPage
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Recursive node row

private struct OutlineNodeView: View {
    let node: PDFOutline
    let document: PDFDocument
    let depth: Int
    let onJumpToPage: (Int) -> Void

    @State private var expanded: Bool = false

    private var hasChildren: Bool { node.numberOfChildren > 0 }
    private var children: [PDFOutline] {
        (0..<node.numberOfChildren).compactMap { node.child(at: $0) }
    }
    private var label: String { node.label ?? "(sem título)" }

    private var pageIndex: Int? {
        guard let dest = node.destination, let page = dest.page else { return nil }
        return document.index(for: page)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                // Indent visual por depth
                if depth > 0 {
                    Spacer().frame(width: CGFloat(depth) * 14)
                }

                // Chevron expand/collapse (só se tem filhos)
                if hasChildren {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            expanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VitaColors.textSecondary)
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                            .frame(width: 20, height: 28)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 20)
                }

                // Tap no label → pula pra página
                Button {
                    if let idx = pageIndex {
                        onJumpToPage(idx)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(label)
                            .font(depth == 0 ? VitaTypography.bodyMedium : VitaTypography.labelMedium)
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 8)

                        if let idx = pageIndex {
                            Text("\(idx + 1)")
                                .font(VitaTypography.labelSmall)
                                .foregroundStyle(VitaColors.textTertiary)
                                .monospacedDigit()
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)

            if expanded && hasChildren {
                ForEach(0..<children.count, id: \.self) { idx in
                    OutlineNodeView(
                        node: children[idx],
                        document: document,
                        depth: depth + 1,
                        onJumpToPage: onJumpToPage
                    )
                }
            }
        }
    }
}
