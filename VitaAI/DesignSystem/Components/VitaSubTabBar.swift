import SwiftUI

// MARK: - VitaSubTabBar
//
// Reusable horizontal capsule tab bar for secondary navigation inside a main tab.
// Designed for the Vita gold glass theme. Active pill gets filled subtle gold;
// inactives stay outlined-muted. Scrolls horizontally if content overflows.
//
// Usage:
//   @State private var selected = 0
//   VitaSubTabBar(
//       titles: ["Agenda", "Matérias", "Documentos"],
//       selected: $selected
//   )

struct VitaSubTabBar: View {
    let titles: [String]
    @Binding var selected: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    pill(title: title, isActive: index == selected) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                            selected = index
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func pill(title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    isActive
                        ? VitaColors.accentHover
                        : VitaColors.textWarm.opacity(0.50)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(
                            isActive
                                ? VitaColors.accentHover.opacity(0.10)
                                : VitaColors.glassInnerLight.opacity(0.04)
                        )
                )
                .overlay(
                    Capsule()
                        .stroke(
                            isActive
                                ? VitaColors.accentHover.opacity(0.30)
                                : VitaColors.textWarm.opacity(0.06),
                            lineWidth: 0.8
                        )
                )
        }
        .buttonStyle(.plain)
    }
}
