import SwiftUI
import UserNotifications

// MARK: - Notification Preferences Keys (AppStorage)

private enum NotifKeys {
    static let study       = "vita_notif_study"
    static let review      = "vita_notif_review"
    static let deadline    = "vita_notif_deadline"
    static let updates     = "vita_notif_updates"
    static let studyTime   = "vita_notif_study_time"
    static let quietStart  = "vita_notif_quiet_start"
    static let quietEnd    = "vita_notif_quiet_end"
    static let sound       = "vita_notif_sound"
    static let vibration   = "vita_notif_vibration"
}

// MARK: - NotificationSettingsScreen

struct NotificationSettingsScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appContainer) private var container

    // Notification type toggles
    @AppStorage(NotifKeys.study)    private var studyEnabled: Bool    = true
    @AppStorage(NotifKeys.review)   private var reviewEnabled: Bool   = true
    @AppStorage(NotifKeys.deadline) private var deadlineEnabled: Bool = true
    @AppStorage(NotifKeys.updates)  private var updatesEnabled: Bool  = false

    // Time settings
    @AppStorage(NotifKeys.studyTime)  private var studyTime:  String = "08:00"
    @AppStorage(NotifKeys.quietStart) private var quietStart: String = "22:00"
    @AppStorage(NotifKeys.quietEnd)   private var quietEnd:   String = "07:00"

    // General
    @AppStorage(NotifKeys.sound)     private var soundEnabled:     Bool = true
    @AppStorage(NotifKeys.vibration) private var vibrationEnabled: Bool = true

    // Time picker sheet state
    @State private var timePickerTarget: TimePickerTarget? = nil
    @State private var pickerHour: Int = 8
    @State private var pickerMinute: Int = 0

    // Entrance animation
    @State private var sectionOpacities: [Double] = [0, 0, 0]
    @State private var sectionOffsets: [Double]   = [20, 20, 20]

    // System permission status
    @State private var systemAuthDenied = false

    // Sync debounce task
    @State private var syncTask: Task<Void, Never>?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Permission banner (shown when user has denied system permissions)
                if systemAuthDenied {
                    permissionBanner
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                }

                // Section 1: Tipos de notificação
                sectionView(index: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Tipos de notificação")

                        VitaGlassCard {
                            VStack(spacing: 0) {
                                NotifToggleRow(
                                    icon: "book.fill",
                                    label: "Lembretes de estudo",
                                    description: "Horários de estudo programados",
                                    isOn: $studyEnabled
                                )
                                Divider().background(VitaColors.glassBorder)
                                NotifToggleRow(
                                    icon: "arrow.triangle.2.circlepath",
                                    label: "Lembretes de revisão",
                                    description: "Flashcards prontos para revisar",
                                    isOn: $reviewEnabled
                                )
                                Divider().background(VitaColors.glassBorder)
                                NotifToggleRow(
                                    icon: "calendar.badge.exclamationmark",
                                    label: "Lembretes de prazo",
                                    description: "Prazos de provas e atividades",
                                    isOn: $deadlineEnabled
                                )
                                Divider().background(VitaColors.glassBorder)
                                NotifToggleRow(
                                    icon: "bell.fill",
                                    label: "Atualizações",
                                    description: "Novidades e melhorias do app",
                                    isOn: $updatesEnabled
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Section 2: Horários
                sectionView(index: 1) {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Horários")

                        VitaGlassCard {
                            VStack(spacing: 0) {
                                TimeRow(
                                    icon: "clock.fill",
                                    label: "Horário de estudo",
                                    time: studyTime,
                                    onTap: {
                                        openTimePicker(for: .study, current: studyTime)
                                    }
                                )
                                Divider().background(VitaColors.glassBorder)
                                TimeRow(
                                    icon: "moon.stars.fill",
                                    label: "Silencioso: início",
                                    time: quietStart,
                                    onTap: {
                                        openTimePicker(for: .quietStart, current: quietStart)
                                    }
                                )
                                Divider().background(VitaColors.glassBorder)
                                TimeRow(
                                    icon: "sunrise.fill",
                                    label: "Silencioso: fim",
                                    time: quietEnd,
                                    onTap: {
                                        openTimePicker(for: .quietEnd, current: quietEnd)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                // Section 3: Geral
                sectionView(index: 2) {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("Geral")

                        VitaGlassCard {
                            VStack(spacing: 0) {
                                NotifToggleRow(
                                    icon: "speaker.wave.2.fill",
                                    label: "Som",
                                    description: "Reproduzir som nas notificações",
                                    isOn: $soundEnabled
                                )
                                Divider().background(VitaColors.glassBorder)
                                NotifToggleRow(
                                    icon: "iphone.radiowaves.left.and.right",
                                    label: "Vibração",
                                    description: "Vibrar ao receber notificações",
                                    isOn: $vibrationEnabled
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, 16)
        }
        .background(VitaColors.surface.ignoresSafeArea())
        .navigationTitle("Notificações")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VitaColors.accent)
                }
            }
        }
        .sheet(item: $timePickerTarget) { target in
            TimePickerSheet(
                title: target.label,
                hour: $pickerHour,
                minute: $pickerMinute,
                onConfirm: {
                    let formatted = String(format: "%02d:%02d", pickerHour, pickerMinute)
                    switch target {
                    case .study:      studyTime  = formatted
                    case .quietStart: quietStart = formatted
                    case .quietEnd:   quietEnd   = formatted
                    }
                    timePickerTarget = nil
                },
                onCancel: { timePickerTarget = nil }
            )
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .presentationBackground(VitaColors.surfaceCard)
        }
        .task {
            await checkSystemPermission()
            await loadPushPreferences()
        }
        .onAppear {
            animateEntrance()
        }
        .onChange(of: studyEnabled) { syncPushPreferences() }
        .onChange(of: reviewEnabled) { syncPushPreferences() }
        .onChange(of: deadlineEnabled) { syncPushPreferences() }
        .onChange(of: updatesEnabled) { syncPushPreferences() }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(VitaTypography.titleLarge)
            .foregroundStyle(VitaColors.white)
            .padding(.horizontal, 20)
    }

    private func sectionView<Content: View>(index: Int, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .opacity(sectionOpacities[index])
            .offset(y: sectionOffsets[index])
    }

    private func animateEntrance() {
        for i in 0..<3 {
            withAnimation(.easeOut(duration: 0.4).delay(Double(i) * 0.07)) {
                sectionOpacities[i] = 1
                sectionOffsets[i] = 0
            }
        }
    }

    private func openTimePicker(for target: TimePickerTarget, current: String) {
        let parts = current.split(separator: ":").compactMap { Int($0) }
        pickerHour   = parts.count > 0 ? parts[0] : 0
        pickerMinute = parts.count > 1 ? parts[1] : 0
        timePickerTarget = target
    }

    /// Load push preferences from the backend and apply to local @AppStorage.
    @MainActor
    private func loadPushPreferences() async {
        do {
            let prefs = try await container.api.getPushPreferences()
            studyEnabled = prefs.studyReminders
            reviewEnabled = prefs.reviewReminders
            deadlineEnabled = prefs.deadlineReminders
            updatesEnabled = prefs.updates
        } catch {
            // Silently fail — keep local defaults if network is unavailable.
        }
    }

    /// Debounced sync of push preferences to the backend.
    /// Mirrors Android: TokenStore saves locally + MedCoachApi.syncPushPreferences().
    private func syncPushPreferences() {
        syncTask?.cancel()
        syncTask = Task {
            // Debounce 500ms to avoid rapid-fire API calls on quick toggles
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let prefs = PushPreferences(
                studyReminders: studyEnabled,
                reviewReminders: reviewEnabled,
                deadlineReminders: deadlineEnabled,
                updates: updatesEnabled
            )
            try? await container.api.updatePushPreferences(prefs)
        }
    }

    @MainActor
    private func checkSystemPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        systemAuthDenied = settings.authorizationStatus == .denied
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Notificações desativadas")
                    .font(VitaTypography.labelLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                Text("Ative nas Configurações do iOS para receber alertas.")
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textSecondary)
            }

            Spacer()

            Button("Abrir") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(VitaTypography.labelMedium)
            .foregroundStyle(VitaColors.accent)
        }
        .padding(14)
        .background(.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - NotifToggleRow

private struct NotifToggleRow: View {
    let icon: String
    let label: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isOn ? VitaColors.accent : VitaColors.textTertiary)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(VitaTypography.bodyLarge)
                    .foregroundStyle(VitaColors.textPrimary)
                Text(description)
                    .font(VitaTypography.bodySmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(VitaColors.accent)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

// MARK: - TimeRow

private struct TimeRow: View {
    let icon: String
    let label: String
    let time: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(VitaColors.accent)
                    .frame(width: 26)

                Text(label)
                    .font(VitaTypography.bodyLarge)
                    .foregroundStyle(VitaColors.textPrimary)

                Spacer()

                Text(time)
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.accent)
                    .monospacedDigit()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Time Picker Sheet

private struct TimePickerSheet: View {
    let title: String
    @Binding var hour: Int
    @Binding var minute: Int
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancelar", action: onCancel)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textSecondary)

                Spacer()

                Text(title)
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.white)

                Spacer()

                Button("OK", action: onConfirm)
                    .font(VitaTypography.bodyMedium.bold())
                    .foregroundStyle(VitaColors.accent)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Pickers in HH:MM columns
            HStack(spacing: 0) {
                Picker("Hora", selection: $hour) {
                    ForEach(0..<24, id: \.self) { h in
                        Text(String(format: "%02d", h))
                            .foregroundStyle(VitaColors.textPrimary)
                            .tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Text(":")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)

                Picker("Minuto", selection: $minute) {
                    ForEach(0..<60, id: \.self) { m in
                        Text(String(format: "%02d", m))
                            .foregroundStyle(VitaColors.textPrimary)
                            .tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .colorScheme(.dark)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - TimePickerTarget

private enum TimePickerTarget: String, Identifiable {
    case study, quietStart, quietEnd

    var id: String { rawValue }

    var label: String {
        switch self {
        case .study:      return "Horário de estudo"
        case .quietStart: return "Início do silencioso"
        case .quietEnd:   return "Fim do silencioso"
        }
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsScreen()
    }
    .preferredColorScheme(.dark)
}
