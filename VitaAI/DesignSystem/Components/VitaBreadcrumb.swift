import SwiftUI

// MARK: - VitaBreadcrumb
//
// Global breadcrumb bar rendered in the shell below VitaTopBar. Shows the
// user's current location in the hierarchy: "Home > Faculdade > Agenda".
// Each crumb is tappable and navigates to that level.
//
// Reads from @Environment(Router.self) so it updates automatically whenever
// selectedTab or the current tab's path changes.
//
// Visual rules:
//   - Current level: bold, accentHover gold
//   - Previous levels: regular weight, textWarm at 40% — tappable
//   - Chevrons between: tiny, 20% opacity
//   - Horizontal scroll if breadcrumb overflows
//
// Structure:
//   [Home] > [TabLabel (if not home)] > [path crumbs in order]
//
// Tap behavior:
//   - Home: switch to home tab + popToRoot
//   - TabLabel: popToRoot (stays on same tab)
//   - Pushed crumb: pop stack down to that level

struct VitaBreadcrumb: View {
    @Environment(Router.self) private var router

    var body: some View {
        // Hide breadcrumb on home root — user already knows they're home
        let isHomeRoot = router.selectedTab == .home && router.currentPath.isEmpty
        // Snapshot items ONCE per body eval — prevents index-out-of-range when
        // `items` (computed from router) changes mid-animation during tab swipe.
        let snapshot = items
        if !isHomeRoot {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(Array(snapshot.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.22))
                        }
                        crumb(item)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private func crumb(_ item: BreadcrumbItem) -> some View {
        Button(action: item.action) {
            Text(item.label)
                .font(.system(size: 11, weight: item.isCurrent ? .semibold : .regular))
                .foregroundStyle(
                    item.isCurrent
                        ? VitaColors.accentHover
                        : VitaColors.textWarm.opacity(0.42)
                )
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .disabled(item.isCurrent)
    }

    // MARK: - Build items from Router state

    private var items: [BreadcrumbItem] {
        var list: [BreadcrumbItem] = []

        let path = router.currentPath
        let isOnHomeRoot = router.selectedTab == .home && path.isEmpty

        // 1. Home is always the first crumb.
        list.append(BreadcrumbItem(
            label: "Home",
            isCurrent: isOnHomeRoot,
            action: {
                withAnimation(.easeInOut(duration: 0.22)) {
                    router.selectedTab = .home
                    router.popToRoot()
                }
            }
        ))

        // 2. Current tab (if not home). Becomes current when path is empty.
        if router.selectedTab != .home {
            list.append(BreadcrumbItem(
                label: router.selectedTab.rawValue,
                isCurrent: path.isEmpty,
                action: {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        router.popToRoot()
                    }
                }
            ))
        }

        // 3. Pushed routes (only those with a breadcrumbLabel).
        for (index, route) in path.enumerated() {
            guard let label = route.breadcrumbLabel else { continue }
            let isCurrent = index == path.count - 1
            let levelsToPop = path.count - 1 - index
            list.append(BreadcrumbItem(
                label: label,
                isCurrent: isCurrent,
                action: {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        for _ in 0..<levelsToPop {
                            router.goBack()
                        }
                    }
                }
            ))
        }

        return list
    }
}

private struct BreadcrumbItem {
    let label: String
    let isCurrent: Bool
    let action: () -> Void
}
