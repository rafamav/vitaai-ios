import SwiftUI

// MARK: - VitaBottomSheet

/// Glass-morphism bottom sheet consistent with VitaGlassCard.
///
/// Features:
/// - Dark glass container (surfaceCard background, glassBorder stroke)
/// - Drag handle (VitaHandle pill or simple handle) at the top
/// - Optional title with VitaTypography.titleLarge
/// - Semi-transparent scrim
/// - iOS 17+ `.sheet` / `.presentationDetents` integration
///
/// Usage (modal sheet presentation):
/// ```swift
/// .sheet(isPresented: $isShowing) {
///     VitaBottomSheet(title: "Opções") {
///         // your content
///     }
/// }
/// ```
///
/// Usage (overlay / custom positioning):
/// ```swift
/// VitaBottomSheetOverlay(isPresented: $isShowing, title: "Opções") {
///     // your content
/// }
/// ```
struct VitaBottomSheet<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            _BottomSheetHandle()

            if let title {
                Text(title)
                    .font(VitaTypography.titleLarge)
                    .foregroundColor(VitaColors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }

            content()
                .padding(.horizontal, 20)

            // Bottom safe area spacer
            Spacer().frame(height: 32)
        }
        .frame(maxWidth: .infinity)
        .background(VitaColors.surfaceCard)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 20
            )
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 20
            )
            .stroke(VitaColors.glassBorder, lineWidth: 1)
        }
        // Native sheet presentation modifiers — caller can override
        .presentationBackground(Color.clear)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden) // We draw our own handle
        .presentationCornerRadius(20)
    }
}

// MARK: - _BottomSheetHandle (internal pill)

private struct _BottomSheetHandle: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 12)
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
            Spacer().frame(height: 12)
        }
    }
}

// MARK: - VitaBottomSheetOverlay (overlay variant)

/// Overlay variant — slides up from the bottom on top of existing content,
/// with a semi-transparent scrim. Useful when `.sheet` is not appropriate.
struct VitaBottomSheetOverlay<Content: View>: View {
    @Binding var isPresented: Bool
    var title: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            if isPresented {
                // Scrim
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.spring(duration: 0.3)) { isPresented = false } }
                    .transition(.opacity)

                // Sheet
                VStack {
                    Spacer()
                    VitaBottomSheet(title: title, content: content)
                        .transition(.move(edge: .bottom))
                }
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(.spring(duration: 0.35), value: isPresented)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("VitaBottomSheet") {
    ZStack {
        VitaColors.surface.ignoresSafeArea()
        Text("Screen content").foregroundColor(VitaColors.textSecondary)

        VitaBottomSheetOverlay(isPresented: .constant(true), title: "Configurações") {
            VStack(spacing: 12) {
                ForEach(["Opção 1", "Opção 2", "Opção 3"], id: \.self) { item in
                    HStack {
                        Text(item)
                            .font(VitaTypography.bodyMedium)
                            .foregroundColor(VitaColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(VitaColors.textTertiary)
                    }
                    .padding(.vertical, 8)
                    if item != "Opção 3" {
                        Divider().background(VitaColors.surfaceBorder)
                    }
                }
            }
        }
    }
}
#endif
