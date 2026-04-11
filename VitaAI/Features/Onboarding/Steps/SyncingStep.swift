import SwiftUI

// MARK: - Syncing Content (real progress from vita-crawl or Canvas/WebAluno)

struct SyncingStep: View {
    let api: VitaAPI
    @Bindable var viewModel: OnboardingViewModel
    @State private var percent: Double = 5
    @State private var label: String = String(localized: "sync_connecting")
    @State private var isDone = false
    @State private var hasError = false
    @State private var items: [SyncProgressItem] = []

    var body: some View {
        VStack(spacing: 16) {
            // Progress card
            VStack(spacing: 12) {
                // Status row
                HStack(spacing: 10) {
                    if isDone {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(VitaColors.dataGreen)
                    } else if hasError {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(VitaColors.dataAmber)
                    } else {
                        ProgressView()
                            .tint(VitaColors.accent)
                            .scaleEffect(0.85)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(isDone ? VitaColors.dataGreen.opacity(0.9) : hasError ? VitaColors.dataAmber.opacity(0.9) : VitaColors.accent.opacity(0.9))

                        if viewModel.syncGrades > 0 || viewModel.syncSchedule > 0 || viewModel.syncCourses > 0 {
                            HStack(spacing: 6) {
                                if viewModel.syncCourses > 0 {
                                    Text("\(viewModel.syncCourses) disciplinas")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                if viewModel.syncGrades > 0 {
                                    if viewModel.syncCourses > 0 {
                                        Text("\u{00B7}").font(.system(size: 11)).foregroundStyle(.white.opacity(0.2))
                                    }
                                    Text("\(viewModel.syncGrades) notas")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                                if viewModel.syncSchedule > 0 {
                                    if viewModel.syncCourses > 0 || viewModel.syncGrades > 0 {
                                        Text("\u{00B7}").font(.system(size: 11)).foregroundStyle(.white.opacity(0.2))
                                    }
                                    Text("\(viewModel.syncSchedule) horários")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.4))
                                }
                            }
                        }
                    }

                    Spacer()

                    Text("\(Int(percent))%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(VitaColors.accent.opacity(0.5))
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 5)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                isDone
                                    ? LinearGradient(colors: [VitaColors.dataGreen.opacity(0.5), VitaColors.dataGreen.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [VitaColors.accent.opacity(0.4), VitaColors.accent.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: geo.size.width * min(percent / 100, 1.0), height: 5)
                            .animation(.easeOut(duration: 0.5), value: percent)
                    }
                }
                .frame(height: 5)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDone ? VitaColors.dataGreen.opacity(0.03) : VitaColors.accent.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isDone ? VitaColors.dataGreen.opacity(0.12) : VitaColors.accent.opacity(0.12), lineWidth: 1)
                    )
            )

            // Granular items (if available from vita-crawl)
            if !items.isEmpty {
                VStack(spacing: 4) {
                    ForEach(items) { item in
                        HStack(spacing: 8) {
                            if item.status == "done" {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(VitaColors.dataGreen.opacity(0.7))
                            } else if item.status == "error" {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(VitaColors.dataRed.opacity(0.5))
                            } else {
                                ProgressView()
                                    .tint(VitaColors.accent.opacity(0.5))
                                    .scaleEffect(0.5)
                                    .frame(width: 11, height: 11)
                            }
                            Text(item.name)
                                .font(.system(size: 11))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                            Spacer()
                            if let detail = item.detail {
                                Text(detail)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.06))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
                )
            }

            // Retry button on error
            if hasError {
                Button {
                    hasError = false
                    startSync()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text(String(localized: "sync_retry"))
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VitaColors.accent.opacity(0.8))
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear { startSync() }
    }

    private func startSync() {
        // If we have a syncId from Connect step (vita-crawl), poll that
        if let syncId = viewModel.activeSyncId {
            pollVitaCrawl(syncId: syncId)
        } else {
            // Fallback: try Canvas + WebAluno direct sync
            runDirectSync()
        }
    }

    // MARK: - Vita Crawl polling (preferred path)

    private func pollVitaCrawl(syncId: String) {
        Task {
            await update(label: String(localized: "sync_scanning"), percent: 15)

            for i in 0..<90 { // max 3 min
                try? await Task.sleep(for: .seconds(2))

                guard let progress = try? await api.getSyncProgress(syncId: syncId) else { continue }

                await MainActor.run {
                    withAnimation {
                        percent = max(percent, progress.percent ?? 0)
                        if let lbl = progress.label, !lbl.isEmpty { label = lbl }
                        viewModel.syncGrades = max(viewModel.syncGrades, progress.grades ?? 0)
                        viewModel.syncSchedule = max(viewModel.syncSchedule, progress.schedule ?? 0)
                    }
                }

                if progress.isDone {
                    await finishSync()
                    return
                }

                if progress.isError {
                    await update(label: (progress.label ?? "").isEmpty ? String(localized: "sync_error") : (progress.label ?? ""), percent: percent)
                    hasError = true
                    return
                }
            }

            // Timeout — still finish, data may be partially available
            await update(label: String(localized: "sync_timeout"), percent: 90)
            await finishSync()
        }
    }

    // MARK: - Direct Canvas + WebAluno sync (fallback)

    private func runDirectSync() {
        Task {
            await update(label: String(localized: "sync_importing"), percent: 20)

            // Canvas
            do {
                let result = try await api.syncCanvas()
                await MainActor.run {
                    withAnimation {
                        viewModel.syncCourses = result.courses
                        viewModel.syncSchedule = result.calendarEvents
                        label = "\(result.courses) disciplinas encontradas"
                        percent = 55
                    }
                }
            } catch {
                print("[Sync] Canvas sync failed: \(error)")
            }

            await update(label: String(localized: "sync_fetching"), percent: 65)

            // WebAluno
            do {
                let status = try await api.getPortalStatus()
                let g = status.counts?.grades ?? 0
                let s = status.counts?.schedule ?? 0
                await MainActor.run {
                    withAnimation {
                        viewModel.syncGrades = max(viewModel.syncGrades, g)
                        viewModel.syncSchedule = max(viewModel.syncSchedule, s)
                        if g > 0 || s > 0 {
                            label = "\(viewModel.syncGrades) notas, \(viewModel.syncSchedule) horários"
                            percent = 85
                        }
                    }
                }
            } catch {
                print("[Sync] WebAluno status fetch failed: \(error)")
            }

            await finishSync()
        }
    }

    // MARK: - Finish

    private func finishSync() async {
        // Fetch actual subjects from API now that sync is done
        await viewModel.fetchSubjectsFromAPI()

        await MainActor.run {
            withAnimation {
                let parts: [String] = [
                    viewModel.syncCourses > 0 ? "\(viewModel.syncCourses) disciplinas" : nil,
                    viewModel.syncGrades > 0 ? "\(viewModel.syncGrades) notas" : nil,
                    viewModel.syncSchedule > 0 ? "\(viewModel.syncSchedule) horários" : nil,
                ].compactMap { $0 }

                label = parts.isEmpty ? String(localized: "sync_done") : parts.joined(separator: " \u{00B7} ")
                percent = 100
                isDone = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }

    @MainActor
    private func update(label: String, percent: Double) {
        withAnimation {
            self.label = label
            self.percent = percent
        }
    }
}
