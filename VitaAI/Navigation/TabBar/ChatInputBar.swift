import SwiftUI

/// Persistent tappable chat input bar shown above the tab bar on the home screen.
/// Matches Android's NavGraph chatbar: placeholder field + mic icon, opens full chat on tap.
struct ChatInputBar: View {
    var onTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Plus button — opens chat (matches Android's "+" circle that opens chat)
            Button(action: onTap) {
                ZStack {
                    Circle()
                        .fill(VitaColors.surfaceElevated)
                        .frame(width: 40, height: 40)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }
            .buttonStyle(.plain)

            // Tappable placeholder field (fills remaining space)
            Button(action: onTap) {
                HStack(spacing: 0) {
                    Text("Pergunte algo...")
                        .font(.system(size: 15))
                        .foregroundStyle(VitaColors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "mic")
                        .font(.system(size: 16))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(VitaColors.glassBg)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(VitaColors.glassBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Scan / action button (matches Android's dark circle with crop icon)
            Button(action: onTap) {
                ZStack {
                    Circle()
                        .fill(VitaColors.accent)
                        .frame(width: 40, height: 40)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VitaColors.surface)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(VitaColors.surface)
    }
}
