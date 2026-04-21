import SwiftUI
import Sentry

// MARK: - PlannerScreen
// Daily study planner. Shows tasks for today, completion progress, streak.
// Glassmorphism gold design. API: GET /api/estudos/plan

struct PlannerScreen: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: PlannerViewModel?
    let onBack: () -> Void
    var onNavigate: ((Route) -> Void)?

    var body: some View {
        Group {
            if let vm = viewModel {
                PlannerContent(vm: vm, onBack: onBack, onNavigate: onNavigate)
            } else {
                ZStack {
                    Color.clear
                    ProgressView()
                        .tint(VitaColors.accent)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if viewModel == nil {
                viewModel = PlannerViewModel(api: container.api)
                Task {
                    await viewModel?.load()
                    SentrySDK.reportFullyDisplayed()
                }
            }
        }
        .trackScreen("Planner")
    }
}

// MARK: - Content

private struct PlannerContent: View {
    let vm: PlannerViewModel
    let onBack: () -> Void
    var onNavigate: ((Route) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            PlannerTopBar(onBack: onBack)

            if vm.isLoading {
                Spacer()
                ProgressView()
                    .tint(VitaColors.accent)
                Spacer()
            } else if let error = vm.errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(VitaColors.textTertiary)
                    Text(error)
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Tentar novamente") {
                        Task { await vm.load() }
                    }
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.accent)
                }
                .padding(.horizontal, 32)
                Spacer()
            } else if vm.tasks.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundStyle(VitaColors.accent.opacity(0.5))
                    Text("Nenhuma tarefa para hoje")
                        .font(VitaTypography.bodyMedium)
                        .foregroundStyle(VitaColors.textSecondary)
                    Text("Aproveite para revisar ou adicionar metas")
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)
                }
                Spacer()
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero — date + greeting + progress ring
                        PlannerHero(vm: vm)
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                            .fadeUpAppear(delay: 0.05)

                        // Stats row
                        PlannerStatsRow(vm: vm)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .fadeUpAppear(delay: 0.12)

                        // Tasks list
                        PlannerTasksList(vm: vm, onNavigate: onNavigate)
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .fadeUpAppear(delay: 0.19)

                        Spacer().frame(height: 140)
                    }
                }
                .refreshable {
                    await vm.load()
                }
            }
        }
    }
}

// MARK: - Top Bar

private struct PlannerTopBar: View {
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.60))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.04))
                    .clipShape(Circle())
            }

            Text(NSLocalizedString("Plano de Estudo", comment: "Planner title"))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.85))

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Hero

private struct PlannerHero: View {
    let vm: PlannerViewModel

    var body: some View {
        VStack(spacing: 12) {
            // Date
            Text(vm.todayDate)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.30))

            // Greeting
            Text("\(vm.greeting)! 👋")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.82))

            // Completion ring
            ZStack {
                // Track
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 6)
                    .frame(width: 80, height: 80)

                // Progress
                Circle()
                    .trim(from: 0, to: vm.completionProgress)
                    .stroke(
                        LinearGradient(
                            colors: [
                                VitaColors.accent.opacity(0.70),
                                VitaColors.accentDark.opacity(0.45)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .shadow(color: VitaColors.accent.opacity(0.20), radius: 8)

                // Count text
                VStack(spacing: 2) {
                    Text("\(vm.completedCount)/\(vm.totalCount)")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(VitaColors.accent.opacity(0.88))
                    Text(NSLocalizedString("tarefas", comment: "tasks label"))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.25))
                        .textCase(.uppercase)
                }
            }
            .padding(.top, 4)

            // Motivational text
            if vm.completedCount == vm.totalCount && vm.totalCount > 0 {
                Text(NSLocalizedString("Parabens! Plano concluido! 🎉", comment: "All tasks done"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VitaColors.dataGreen.opacity(0.70))
            } else if vm.completedCount > 0 {
                Text(String(format: NSLocalizedString("Faltam %d tarefas para concluir", comment: "Tasks remaining"), vm.totalCount - vm.completedCount))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.30))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}

// MARK: - Stats Row

private struct PlannerStatsRow: View {
    let vm: PlannerViewModel

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            PlannerStatPill(
                icon: "flame.fill",
                value: "\(vm.streakDays)",
                label: NSLocalizedString("Streak", comment: ""),
                color: VitaColors.dataAmber
            )
            PlannerStatPill(
                icon: "clock.fill",
                value: "\(vm.studyMinutesToday)m",
                label: NSLocalizedString("Hoje", comment: ""),
                color: VitaColors.accent
            )
            PlannerStatPill(
                icon: "target",
                value: "\(Int(vm.completionProgress * 100))%",
                label: NSLocalizedString("Meta", comment: ""),
                color: VitaColors.dataGreen
            )
        }
    }
}

private struct PlannerStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color.opacity(0.55))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color.opacity(0.80))
                Text(label)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.22))
                    .textCase(.uppercase)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard()
    }
}

// MARK: - Tasks List

private struct PlannerTasksList: View {
    let vm: PlannerViewModel
    var onNavigate: ((Route) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text(NSLocalizedString("TAREFAS DO DIA", comment: "").uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.40))
                    .kerning(1.0)
                Spacer()
                Text(String(format: NSLocalizedString("%d de %d", comment: "x of y"), vm.completedCount, vm.totalCount))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VitaColors.accent.opacity(0.45))
            }
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach(vm.tasks) { task in
                    PlannerTaskRow(task: task, onToggle: {
                        Task { await vm.toggleTask(task) }
                    }, onTap: {
                        if let route = task.linkedRoute {
                            onNavigate?(route)
                        }
                    })

                    if task.id != vm.tasks.last?.id {
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 1)
                            .padding(.horizontal, 14)
                    }
                }
            }
            .glassCard()
        }
    }
}

private struct PlannerTaskRow: View {
    let task: PlannerTask
    let onToggle: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            task.isCompleted
                                ? VitaColors.accent.opacity(0.15)
                                : Color.white.opacity(0.03)
                        )
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(
                                    task.isCompleted
                                        ? VitaColors.accent.opacity(0.30)
                                        : Color.white.opacity(0.10),
                                    lineWidth: 1.5
                                )
                        )

                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VitaColors.accent.opacity(0.80))
                    }
                }
            }
            .buttonStyle(.plain)

            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(task.color.opacity(task.isCompleted ? 0.06 : 0.10))
                    .frame(width: 32, height: 32)
                Image(systemName: task.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(task.color.opacity(task.isCompleted ? 0.30 : 0.60))
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        task.isCompleted
                            ? Color.white.opacity(0.30)
                            : Color.white.opacity(0.72)
                    )
                    .strikethrough(task.isCompleted, color: Color.white.opacity(0.15))
                    .lineLimit(1)
                Text(task.subtitle)
                    .font(.system(size: 9, weight: .regular))
                    .foregroundStyle(Color.white.opacity(task.isCompleted ? 0.12 : 0.25))
                    .lineLimit(1)
            }

            Spacer()

            // Time estimate
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(task.estimatedMinutes)m")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.white.opacity(task.isCompleted ? 0.12 : 0.25))

                if task.linkedRoute != nil && !task.isCompleted {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(VitaColors.accent.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if !task.isCompleted && task.linkedRoute != nil {
                onTap()
            }
        }
    }
}
