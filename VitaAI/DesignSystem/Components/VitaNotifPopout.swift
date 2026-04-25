import SwiftUI

// MARK: - VitaNotifPopout
// Glass notification popout — 60% width, anchored top-trailing below TopNav
// Shows 5 visible items with scroll indicator bar

struct VitaNotifPopout: View {
    let onDismiss: () -> Void
    let onSettingsTap: () -> Void
    let onNavigate: (String) -> Void

    @Environment(\.appContainer) private var container
    @ObservedObject private var pushManager = PushManager.shared
    @State private var notifications: [VitaNotification] = []
    @State private var isVisible = false
    @State private var timeRefreshTick = false
    private let timeRefreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var unreadCount: Int {
        notifications.filter { !$0.read }.count
    }

    private var hasMoreThanVisible: Bool {
        notifications.count > 5
    }

    var body: some View {
        let _ = timeRefreshTick
        ZStack(alignment: .topTrailing) {
            // Dismiss backdrop — fills all content area
            Color.black.opacity(0.001)
                .onTapGesture { dismiss() }

            // Bubble — top trailing, below TopNav
            popoutContent
                .padding(.trailing, 12)
                .padding(.top, 4)
                .scaleEffect(isVisible ? 1 : 0.88, anchor: .topTrailing)
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : -12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Instant: use cached notifications (already fetched by PushManager)
            notifications = pushManager.cachedNotifications
            withAnimation(.spring(duration: 0.3, bounce: 0.12)) {
                isVisible = true
            }
            // Background refresh for freshness
            Task {
                await PushManager.shared.refreshUnreadCount()
                notifications = pushManager.cachedNotifications
            }
        }
        .onReceive(timeRefreshTimer) { _ in
            timeRefreshTick.toggle()
        }
    }

    // MARK: - Popout Content

    private var popoutContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("Notificações")
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.surface)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(VitaColors.accentHover.opacity(0.92))
                        )
                }

                Spacer()

                if unreadCount > 0 {
                    Button(action: { markAllRead() }) {
                        Text("Marcar lidas")
                            .font(VitaTypography.labelMedium)
                            .foregroundStyle(VitaColors.accentHover.opacity(0.90))
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { dismiss(); onSettingsTap() }) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VitaColors.accent.opacity(0.65))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Rectangle()
                .fill(VitaColors.accentLight.opacity(0.05))
                .frame(height: 1)
                .padding(.horizontal, 10)

            if notifications.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(notifications) { item in
                        Button {
                            tapNotification(item)
                        } label: {
                            notifRow(item)
                        }
                        .buttonStyle(NotifButtonStyle())
                        .listRowInsets(EdgeInsets(top: 1.5, leading: 8, bottom: 1.5, trailing: 8))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.visible)
                .frame(maxHeight: notifListHeight)
                .refreshable { await refresh() }
            }
        }
        .frame(width: UIScreen.main.bounds.width * 0.78)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.055, green: 0.043, blue: 0.035).opacity(0.97),
                            Color(red: 0.039, green: 0.031, blue: 0.024).opacity(0.98)
                        ],
                        startPoint: .init(x: 0.5, y: 0),
                        endPoint: .init(x: 0.48, y: 1)
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(VitaColors.accentHover.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.55), radius: 24, x: 0, y: 16)
                .shadow(color: VitaColors.accent.opacity(0.06), radius: 10, x: 0, y: 0)
        )
    }

    /// Height for ~5 visible notification rows
    private var notifListHeight: CGFloat {
        let rowHeight: CGFloat = 70
        let visibleCount = min(notifications.count, 5)
        return CGFloat(visibleCount) * rowHeight + 16
    }

    // MARK: - Notification Row (tappable)

    private func notifRowButton(_ item: VitaNotification) -> some View {
        Button {
            NSLog("[NotifPopout] TAP on: %@ route=%@", item.title, item.route ?? "nil")
            tapNotification(item)
        } label: {
            notifRow(item)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func notifRow(_ item: VitaNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Gold icon medallion — D4 carved feel
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                VitaColors.accentHover.opacity(item.read ? 0.10 : 0.18),
                                VitaColors.accent.opacity(item.read ? 0.06 : 0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(VitaColors.accentHover.opacity(item.read ? 0.12 : 0.22), lineWidth: 0.6)
                    )
                Image(systemName: item.sfSymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(item.read ? VitaColors.accent.opacity(0.55) : VitaColors.accentHover.opacity(0.95))
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(item.read ? VitaColors.textPrimary.opacity(0.70) : VitaColors.textPrimary)
                    .lineLimit(1)

                Text(item.description)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(item.read ? VitaColors.textSecondary.opacity(0.85) : VitaColors.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            Text(item.relativeTime)
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 14)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [VitaColors.accentHover.opacity(0.18), .clear],
                            center: .center,
                            startRadius: 2,
                            endRadius: 28
                        )
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(VitaColors.accentHover.opacity(0.75))
            }
            Text("Tudo em dia!")
                .font(VitaTypography.titleSmall)
                .foregroundStyle(VitaColors.textPrimary.opacity(0.92))
            Text("Nenhuma notificação por agora.")
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Actions

    /// Pull-to-refresh: force backend GET /notifications (bypasses cache).
    private func refresh() async {
        await PushManager.shared.refreshUnreadCount()
        notifications = pushManager.cachedNotifications
    }

    private func tapNotification(_ item: VitaNotification) {
        if !item.read {
            if let idx = notifications.firstIndex(where: { $0.id == item.id }) {
                var updated = notifications
                let old = updated[idx]
                updated[idx] = VitaNotification(id: old.id, type: old.type, title: old.title, description: old.description, time: old.time, read: true, createdAt: old.createdAt)
                withAnimation(.easeInOut(duration: 0.2)) {
                    notifications = updated
                }
                // Sync cache immediately so reopening popout won't flash unread
                pushManager.updateCachedNotifications(updated)
            }
            Task {
                try? await container.api.markNotificationsRead(ids: [item.id])
                await pushManager.refreshUnreadCount()
            }
        }
        if let route = item.route, !route.isEmpty {
            onNavigate(route)
        }
    }

    private func markAllRead() {
        let updated = notifications.map {
            VitaNotification(id: $0.id, type: $0.type, title: $0.title, description: $0.description, time: $0.time, read: true, createdAt: $0.createdAt)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            notifications = updated
        }
        // Sync cache immediately
        pushManager.updateCachedNotifications(updated)
        Task {
            try? await container.api.markNotificationsRead(markAll: true)
            await pushManager.refreshUnreadCount()
        }
    }

    private func deleteNotification(_ item: VitaNotification) {
        withAnimation(.easeOut(duration: 0.2)) {
            notifications.removeAll { $0.id == item.id }
        }
        // Mark as read on backend (no delete endpoint yet)
        Task {
            try? await container.api.markNotificationsRead(ids: [item.id])
        }
    }

    private func dismiss() {
        withAnimation(.spring(duration: 0.3, bounce: 0.12)) {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Notif Button Style (no flash, full hit area)

private struct NotifButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .contentShape(Rectangle())
    }
}

// MARK: - Swipe to Delete (notification-specific)

private struct SwipeToDelete<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    private let threshold: CGFloat = -70

    var body: some View {
        ZStack(alignment: .trailing) {
            HStack {
                Spacer()
                Image(systemName: "trash.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white)
                    .frame(width: 56)
            }
            .background(VitaColors.dataRed.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(offset < -20 ? 1 : 0)

            content
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 15)
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = value.translation.width * 0.6
                            }
                        }
                        .onEnded { _ in
                            if offset < threshold {
                                withAnimation(.easeOut(duration: 0.2)) { offset = -300 }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    onDelete()
                                }
                            } else {
                                withAnimation(.spring(duration: 0.25)) { offset = 0 }
                            }
                        }
                )
        }
    }
}
