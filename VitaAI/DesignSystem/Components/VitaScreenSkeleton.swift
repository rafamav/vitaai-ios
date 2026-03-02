import SwiftUI

// MARK: - VitaScreenSkeleton
//
// Screen-level skeleton composables that mirror real screen layouts.
// Built on VitaShimmer primitives: ShimmerBox, ShimmerText, ShimmerCircle.
//
// Available skeletons:
//   DashboardSkeleton  — top bar, week days, progress card, module cards
//   ChatSkeleton       — message bubbles, input bar
//   ListSkeleton       — search bar + avatar/text rows

// MARK: - DashboardSkeleton

/// Skeleton matching DashboardScreen layout — mirrors Android DashboardSkeleton.
struct DashboardSkeleton: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Top bar
                HStack(spacing: 12) {
                    ShimmerCircle(size: 40)
                    VStack(alignment: .leading, spacing: 6) {
                        ShimmerText(width: 80, height: 10)
                        ShimmerText(width: 130, height: 14)
                    }
                    Spacer()
                    ShimmerCircle(size: 24)
                }
                .padding(.bottom, 32)

                // Week days row
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { _ in
                        Spacer()
                        VStack(spacing: 6) {
                            ShimmerText(width: 20, height: 10)
                            ShimmerCircle(size: 32)
                        }
                        Spacer()
                    }
                }
                .padding(.bottom, 24)

                // Progress card
                ShimmerBox(height: 120, cornerRadius: 16)
                    .padding(.bottom, 24)

                // Section header
                HStack {
                    ShimmerText(width: 140, height: 16)
                    Spacer()
                    ShimmerText(width: 60, height: 12)
                }
                .padding(.bottom, 16)

                // Module cards (horizontal scroll placeholder)
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { _ in
                        ShimmerBox(height: 100, cornerRadius: 12)
                            .frame(width: 140)
                    }
                }
                .padding(.bottom, 24)

                // Suggestions section
                ShimmerText(width: 160, height: 16)
                    .padding(.bottom, 12)

                ForEach(0..<2, id: \.self) { _ in
                    ShimmerBox(height: 56, cornerRadius: 12)
                        .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .scrollDisabled(true)
    }
}

// MARK: - ChatSkeleton

/// Skeleton matching VitaChatScreen layout — mirrors Android ChatSkeleton.
struct ChatSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                ShimmerCircle(size: 24)
                ShimmerText(width: 100, height: 16)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 32)

            // Messages
            VStack(spacing: 16) {
                // Incoming
                HStack(alignment: .top, spacing: 8) {
                    ShimmerCircle(size: 28)
                    ShimmerBox(height: 48, cornerRadius: 16)
                        .frame(width: 220)
                    Spacer()
                }

                // Outgoing
                HStack {
                    Spacer()
                    ShimmerBox(height: 36, cornerRadius: 16)
                        .frame(width: 180)
                }

                // Incoming — longer
                HStack(alignment: .top, spacing: 8) {
                    ShimmerCircle(size: 28)
                    ShimmerBox(height: 72, cornerRadius: 16)
                        .frame(width: 260)
                    Spacer()
                }

                // Outgoing
                HStack {
                    Spacer()
                    ShimmerBox(height: 36, cornerRadius: 16)
                        .frame(width: 200)
                }
            }
            .padding(.horizontal, 20)

            Spacer()

            // Input bar
            ShimmerBox(height: 52, cornerRadius: 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }
}

// MARK: - ListSkeleton

/// Generic scrollable list skeleton — mirrors Android ListSkeleton.
struct ListSkeleton: View {
    var itemCount: Int = 6
    var showAvatar: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            ShimmerBox(height: 44, cornerRadius: 12)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)

            // List items
            ForEach(0..<itemCount, id: \.self) { index in
                HStack(spacing: 12) {
                    if showAvatar {
                        ShimmerCircle(size: 40)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        ShimmerText(
                            width: index % 2 == 0 ? 160 : 120,
                            height: 14
                        )
                        ShimmerText(
                            width: index % 2 == 0 ? 200 : 180,
                            height: 10
                        )
                    }
                    Spacer()
                    ShimmerText(width: 40, height: 10)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DashboardSkeleton") {
    ZStack {
        VitaColors.surface.ignoresSafeArea()
        DashboardSkeleton()
    }
}

#Preview("ChatSkeleton") {
    ZStack {
        VitaColors.surface.ignoresSafeArea()
        ChatSkeleton()
    }
}

#Preview("ListSkeleton") {
    ZStack {
        VitaColors.surface.ignoresSafeArea()
        ListSkeleton(itemCount: 5)
    }
}
#endif
