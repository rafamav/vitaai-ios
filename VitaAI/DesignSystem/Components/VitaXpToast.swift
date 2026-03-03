import SwiftUI

// MARK: - VitaXpToastState

/// State manager for XP gain toasts. Create once, pass down to `.vitaXpToastHost(_:)`.
///
/// Mirrors Android `GamificationManager.xpEvents: SharedFlow<XpEvent>` but adapted
/// to SwiftUI's view-driven model.
///
/// Usage:
/// ```swift
/// @State private var xpToastState = VitaXpToastState()
///
/// // In view:
/// .vitaXpToastHost(xpToastState)
///
/// // To trigger:
/// xpToastState.show(XpEvent(amount: 25, source: .dailyLogin))
/// ```
@MainActor
@Observable
final class VitaXpToastState {
    /// Wraps XpEvent with a stable UUID so task(id:) restarts on each new event.
    struct Entry: Identifiable {
        let id = UUID()
        let event: XpEvent
    }

    private(set) var current: Entry?

    func show(_ event: XpEvent) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            current = Entry(event: event)
        }
    }

    func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) {
            current = nil
        }
    }
}

// MARK: - View Extension

extension View {
    /// Attaches an XP toast overlay anchored below the navigation bar.
    /// Place this on the root content view (NavigationStack body or TabView).
    func vitaXpToastHost(_ state: VitaXpToastState) -> some View {
        overlay(alignment: .top) {
            _VitaXpToastHost(state: state)
        }
    }
}

// MARK: - _VitaXpToastHost

private struct _VitaXpToastHost: View {
    var state: VitaXpToastState

    var body: some View {
        ZStack {
            if let entry = state.current {
                _VitaXpToastPill(event: entry.event)
                    .padding(.top, 56) // below status bar + potential nav bar
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                    // Auto-dismiss: task restarts for each new entry.id
                    .task(id: entry.id) {
                        do {
                            try await Task.sleep(for: .seconds(2.0))
                            state.dismiss()
                        } catch {
                            // Cancelled — new toast arrived or dismissed manually
                        }
                    }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: state.current?.id)
    }
}

// MARK: - _VitaXpToastPill

/// The visual pill shown for "+25 XP" toasts. Teal-tinted with sparkle icon.
private struct _VitaXpToastPill: View {
    let event: XpEvent

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(VitaColors.accent)

            VStack(alignment: .leading, spacing: 1) {
                Text("+\(event.amount) XP")
                    .font(VitaTypography.titleSmall)
                    .foregroundColor(VitaColors.accent)
                Text(event.label)
                    .font(VitaTypography.labelSmall)
                    .foregroundColor(VitaColors.textSecondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Material blur base
                Capsule().fill(.ultraThinMaterial)
                // Teal tint overlay (0.15 alpha — mirrors Android)
                Capsule().fill(VitaColors.accent.opacity(0.15))
            }
        )
        .overlay(
            Capsule()
                .stroke(VitaColors.accent.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: VitaColors.accent.opacity(0.2), radius: 10, y: 4)
        .accessibilityLabel("+\(event.amount) XP, \(event.label)")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("VitaXpToast") {
    @Previewable @State var xpState = VitaXpToastState()

    ZStack {
        VitaColors.surface.ignoresSafeArea()

        VStack(spacing: 12) {
            VitaButton(text: "+25 XP Login", action: {
                xpState.show(XpEvent(amount: 25, source: .dailyLogin))
            }, variant: .primary)

            VitaButton(text: "+10 XP Flashcard", action: {
                xpState.show(XpEvent(amount: 10, source: .flashcardReview))
            }, variant: .secondary)

            VitaButton(text: "+50 XP Deck!", action: {
                xpState.show(XpEvent(amount: 50, source: .deckComplete))
            }, variant: .secondary)

            VitaButton(text: "+5 XP Chat", action: {
                xpState.show(XpEvent(amount: 5, source: .chatMessage))
            }, variant: .ghost)
        }
        .padding()
    }
    .vitaXpToastHost(xpState)
}
#endif
