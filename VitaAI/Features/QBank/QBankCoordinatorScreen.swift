import SwiftUI
import WebKit

/// Top-level coordinator that owns the single QBankViewModel instance and routes
/// between the home / config / session / result sub-screens based on vm.state.activeScreen.
/// This is the entry point registered in Route + AppRouter.
struct QBankCoordinatorScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: QBankViewModel?
    let onBack: () -> Void

    var body: some View {
        Group {
            if let vm {
                coordinator(vm: vm)
            } else {
                ZStack {
                    VitaColors.surface.ignoresSafeArea()
                    ProgressView().tint(VitaColors.accent)
                }
            }
        }
        .onAppear {
            if vm == nil {
                vm = QBankViewModel(api: container.api)
                vm?.loadHomeData()
                vm?.loadFilters()
            }
        }
        .navigationBarHidden(true)
    }

    @ViewBuilder
    private func coordinator(vm: QBankViewModel) -> some View {
        switch vm.state.activeScreen {
        case .home:
            QBankHomeContent(vm: vm, onBack: onBack)

        case .disciplines:
            QBankDisciplineContent(vm: vm, onBack: {
                vm.goBackDiscipline()
            })

        case .config:
            QBankConfigContent(vm: vm, onBack: {
                vm.state.activeScreen = .disciplines // back to disciplines
            })

        case .session:
            QBankSessionContent(vm: vm, onBack: {
                vm.goToHome()
            })

        case .result:
            QBankResultContent(vm: vm, onBack: onBack, onNewSession: {
                vm.startNewSession()
            })
        }
    }
}

// MARK: - Convex Glass Modifier

private struct ConvexGlassModifier: ViewModifier {
    var isCyan: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    if isCyan {
                        Circle().fill(Color(red: 0.04, green: 0.10, blue: 0.12))
                        Circle().fill(
                            RadialGradient(
                                stops: [
                                    .init(color: Color(red: 0.13, green: 0.83, blue: 0.93).opacity(0.25), location: 0),
                                    .init(color: Color(red: 0.13, green: 0.83, blue: 0.93).opacity(0.05), location: 0.5),
                                    .init(color: Color.black.opacity(0.20), location: 1),
                                ],
                                center: UnitPoint(x: 0.5, y: 0.25),
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                    } else {
                        Circle().fill(Color(red: 0.086, green: 0.106, blue: 0.094))
                        Circle().fill(
                            RadialGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.10), location: 0),
                                    .init(color: Color.white.opacity(0.02), location: 0.5),
                                    .init(color: Color.black.opacity(0.20), location: 1),
                                ],
                                center: UnitPoint(x: 0.5, y: 0.25),
                                startRadius: 0,
                                endRadius: 40
                            )
                        )
                    }
                }
            )
            .overlay(
                Circle().stroke(
                    isCyan ? Color(red: 0.13, green: 0.83, blue: 0.93).opacity(0.2) : Color.white.opacity(0.12),
                    lineWidth: 1
                )
            )
            .shadow(color: Color.black.opacity(0.4), radius: 3, y: 2)
            .clipShape(Circle())
    }
}

private struct ConvexGlassCircle<Content: View>: View {
    let size: CGFloat
    var isCyan: Bool = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(width: size, height: size)
            .modifier(ConvexGlassModifier(isCyan: isCyan))
    }
}

// MARK: - Home content (thin wrapper that calls into the shared VM)

private struct QBankHomeContent: View {
    @Bindable var vm: QBankViewModel
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(width: 44, height: 44)
                }
                Text("Banco de Questões")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            if vm.state.progressLoading {
                Spacer()
                ProgressView().tint(VitaColors.accent)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 20) {
                        // Stats row
                        QBankStatsRow(progress: vm.state.progress)
                            .padding(.top, 8)

                        // Action CTAs
                        VStack(spacing: 10) {
                            QBankActionCTA(
                                icon: "play.fill",
                                title: "Nova Sessão",
                                subtitle: "Configure filtros e pratique com questões de provas reais",
                                isCyan: false
                            ) {
                                vm.goToDisciplines()
                            }

                            if vm.state.progress.totalAnswered > 0 {
                                QBankActionCTA(
                                    icon: "brain",
                                    title: "Estudo Inteligente",
                                    subtitle: "Prioriza questões erradas e não vistas para otimizar seu estudo",
                                    isCyan: true,
                                    isLoading: vm.state.isCreatingSmartSession
                                ) {
                                    vm.startSmartStudy()
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        // Quick access
                        HStack(spacing: 10) {
                            QBankQuickAccessButton(icon: "clock.arrow.circlepath", label: "Histórico") {
                                // TODO: navigate to history
                            }
                            QBankQuickAccessButton(icon: "bookmark", label: "Listas") {
                                // TODO: navigate to lists
                            }
                        }
                        .padding(.horizontal, 16)

                        // Recent sessions
                        if !vm.state.recentSessions.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                QBankSectionHeader(title: "Sessões Recentes")
                                    .padding(.horizontal, 16)
                                ForEach(vm.state.recentSessions) { session in
                                    QBankSessionRow(session: session) {
                                        vm.resumeSession(session)
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                        // Difficulty
                        if !vm.state.progress.byDifficulty.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                QBankSectionHeader(title: "Desempenho por Dificuldade")
                                    .padding(.horizontal, 16)
                                QBankDifficultyCard(items: vm.state.progress.byDifficulty)
                                    .padding(.horizontal, 16)
                            }
                        }

                        // Topics
                        if !vm.state.progress.byTopic.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                QBankSectionHeader(title: "Desempenho por Tema")
                                    .padding(.horizontal, 16)
                                ForEach(Array(vm.state.progress.byTopic.prefix(10))) { topic in
                                    QBankTopicRow(topic: topic)
                                        .padding(.horizontal, 16)
                                }
                                if vm.state.progress.byTopic.count > 10 {
                                    Text("e mais \(vm.state.progress.byTopic.count - 10) temas...")
                                        .font(.system(size: 10))
                                        .foregroundStyle(VitaColors.textTertiary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 2)
                                }
                            }
                        }

                        // Empty state
                        if vm.state.progress.totalAnswered == 0 {
                            QBankEmptyState()
                                .padding(.horizontal, 16)
                        }

                        if let error = vm.state.error {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.dataRed)
                                .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 24)
                    }
                }
            }
        }
        .background(VitaColors.surface.ignoresSafeArea())
        .onAppear { vm.loadHomeData() }
    }
}

// MARK: - Stats Row (3 cards with convex glass circles)

private struct QBankStatsRow: View {
    let progress: QBankProgressResponse

    private var accuracyColor: Color {
        let acc = Int(progress.accuracy * 100)
        if acc >= 70 { return VitaColors.dataGreen }
        if acc >= 50 { return VitaColors.dataAmber }
        if acc > 0 { return VitaColors.dataRed }
        return VitaColors.textPrimary
    }

    var body: some View {
        HStack(spacing: 10) {
            statCard(
                icon: "book",
                value: formatNumber(progress.totalAvailable),
                label: "Disponíveis"
            )
            statCard(
                icon: "target",
                value: formatNumber(progress.totalAnswered),
                label: "Respondidas"
            )
            statCard(
                icon: "trophy",
                value: "\(Int(progress.accuracy * 100))%",
                label: "Acerto",
                valueColor: accuracyColor
            )
        }
        .padding(.horizontal, 16)
    }

    private func statCard(icon: String, value: String, label: String, valueColor: Color? = nil) -> some View {
        VStack(spacing: 8) {
            ConvexGlassCircle(size: 32) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor ?? VitaColors.textPrimary)
                .tracking(-0.5)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(VitaColors.textTertiary)
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(VitaColors.glassBg)
                LinearGradient(
                    colors: [VitaColors.accent.opacity(0.05), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(VitaColors.glassBorder, lineWidth: 1))
    }

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Action CTA (Nova Sessao / Estudo Inteligente)

private struct QBankActionCTA: View {
    let icon: String
    let title: String
    let subtitle: String
    var isCyan: Bool = false
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ConvexGlassCircle(size: 44, isCyan: isCyan) {
                    if isLoading {
                        ProgressView()
                            .tint(isCyan ? VitaColors.accent : .white)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(isCyan ? VitaColors.accent : Color.white.opacity(0.9))
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textTertiary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(14)
            .background(VitaColors.glassBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(VitaColors.glassBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Quick Access Button

private struct QBankQuickAccessButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ConvexGlassCircle(size: 32) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.9))
                }
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
            }
            .padding(12)
            .background(VitaColors.glassBg)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(VitaColors.glassBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Header (9px uppercase)

private struct QBankSectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(VitaColors.textTertiary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}

// MARK: - Session Row (with convex glass status circle)

private struct QBankSessionRow: View {
    let session: QBankSessionSummary
    let action: () -> Void

    private var pct: Int {
        session.totalQuestions > 0 ? Int(Double(session.correctCount) / Double(session.totalQuestions) * 100) : 0
    }
    private var progressWidth: Double {
        if session.isActive {
            return session.totalQuestions > 0 ? Double(session.currentIndex) / Double(session.totalQuestions) : 0
        }
        return Double(pct) / 100
    }
    private var barColor: Color {
        session.isActive ? VitaColors.dataAmber : VitaColors.dataGreen
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ConvexGlassCircle(size: 40) {
                    Image(systemName: session.isActive ? "clock" : "checkmark.circle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(session.isActive ? VitaColors.dataAmber : VitaColors.dataGreen)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title ?? "Sessão de \(session.totalQuestions) questões")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(1)
                        .tracking(-0.1)

                    Text(session.isActive
                        ? "\(session.currentIndex)/\(session.totalQuestions) respondidas"
                        : "\(session.correctCount)/\(session.totalQuestions) corretas (\(pct)%)"
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(VitaColors.textTertiary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2).fill(VitaColors.surfaceElevated)
                            RoundedRectangle(cornerRadius: 2).fill(barColor)
                                .frame(width: max(geo.size.width * CGFloat(progressWidth), 2))
                        }
                    }
                    .frame(height: 3)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)
            }
            .padding(14)
            .background(VitaColors.glassBg)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(VitaColors.glassBorder, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Difficulty Card (single card with all difficulties)

private struct QBankDifficultyCard: View {
    let items: [QBankProgressByDifficulty]

    var body: some View {
        VStack(spacing: 14) {
            ForEach(items) { item in
                let pct = Int(item.accuracy * 100)
                let col: Color = pct >= 70 ? VitaColors.dataGreen : pct >= 50 ? VitaColors.dataAmber : VitaColors.dataRed
                VStack(spacing: 6) {
                    HStack {
                        Text(item.difficulty.difficultyLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                            .tracking(-0.1)
                        Spacer()
                        Text("\(item.correct)/\(item.answered)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(VitaColors.textTertiary)
                        Text("(\(pct)%)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(VitaColors.surfaceElevated)
                            RoundedRectangle(cornerRadius: 3).fill(col)
                                .frame(width: max(geo.size.width * CGFloat(item.accuracy).clamped(to: 0...1), 2))
                                .animation(.easeOut(duration: 0.6), value: item.accuracy)
                        }
                    }
                    .frame(height: 5)
                }
            }
        }
        .padding(16)
        .background(VitaColors.glassBg)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(VitaColors.glassBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Topic Row (individual card per topic)

private struct QBankTopicRow: View {
    let topic: QBankProgressByTopic

    private var pct: Int { Int(topic.accuracy * 100) }
    private var col: Color {
        pct >= 70 ? VitaColors.dataGreen : pct >= 50 ? VitaColors.dataAmber : VitaColors.dataRed
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(topic.topicTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
                    .tracking(-0.1)
                Spacer()
                Text("\(topic.correct)/\(topic.answered)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)
                Text("\(pct)%")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(col)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(VitaColors.surfaceElevated)
                    RoundedRectangle(cornerRadius: 2).fill(col)
                        .frame(width: max(geo.size.width * CGFloat(topic.accuracy).clamped(to: 0...1), 2))
                        .animation(.easeOut(duration: 0.6), value: topic.accuracy)
                }
            }
            .frame(height: 4)
        }
        .padding(12)
        .background(VitaColors.glassBg)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VitaColors.glassBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Empty State

private struct QBankEmptyState: View {
    var body: some View {
        VStack(spacing: 10) {
            ConvexGlassCircle(size: 40) {
                Image(systemName: "book")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.9))
            }
            Text("Comece a praticar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VitaColors.textPrimary)
                .tracking(-0.1)
            Text("Inicie uma sessão de questões para acompanhar seu desempenho aqui")
                .font(.system(size: 11))
                .foregroundStyle(VitaColors.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(VitaColors.glassBg)
                LinearGradient(
                    colors: [VitaColors.accent.opacity(0.05), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        )
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(VitaColors.glassBorder, lineWidth: 1))
    }
}

// MARK: - Discipline selection (progressive step)

private struct QBankDisciplineContent: View {
    @Bindable var vm: QBankViewModel
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(width: 44, height: 44)
                }
                Text("Disciplinas")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                if !vm.state.selectedDisciplineIds.isEmpty {
                    Text("\(vm.state.selectedDisciplineIds.count) sel.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(VitaColors.accent)
                        .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            // Breadcrumb
            if vm.state.disciplineBreadcrumb.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(vm.state.disciplineBreadcrumb.enumerated()), id: \.offset) { index, label in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9))
                                    .foregroundStyle(VitaColors.textTertiary.opacity(0.5))
                            }
                            Button {
                                vm.goBackBreadcrumb(to: index - 1)
                            } label: {
                                Text(label)
                                    .font(.system(size: 11, weight: index == vm.state.disciplineBreadcrumb.count - 1 ? .bold : .regular))
                                    .foregroundStyle(index == vm.state.disciplineBreadcrumb.count - 1 ? VitaColors.accent : VitaColors.textTertiary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }

            // Selected chips
            if !vm.state.selectedDisciplineIds.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(vm.state.selectedDisciplineIds), id: \.self) { id in
                            let title = findDisciplineTitle(id: id, in: vm.state.filters.disciplines)
                            HStack(spacing: 4) {
                                Text(title)
                                    .font(.system(size: 10, weight: .medium))
                                Button { vm.toggleDisciplineSelection(id) } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .bold))
                                }
                            }
                            .foregroundStyle(VitaColors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(VitaColors.accent.opacity(0.1))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(VitaColors.accent.opacity(0.2), lineWidth: 1))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }

            if vm.state.filtersLoading {
                Spacer()
                ProgressView().tint(VitaColors.accent)
                Spacer()
            } else {
                // Discipline list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.state.currentDisciplines) { disc in
                            DisciplineCard(
                                discipline: disc,
                                isSelected: vm.state.selectedDisciplineIds.contains(disc.id),
                                onTap: { vm.selectDiscipline(disc) },
                                onToggle: { vm.toggleDisciplineSelection(disc.id) }
                            )
                        }

                        if vm.state.currentDisciplines.isEmpty {
                            Text("Nenhuma disciplina disponível")
                                .font(.system(size: 13))
                                .foregroundStyle(VitaColors.textTertiary)
                                .padding(.vertical, 24)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }

                // Bottom CTA
                VStack(spacing: 0) {
                    Divider().overlay(VitaColors.glassBorder)
                    HStack {
                        if vm.state.selectedDisciplineIds.isEmpty {
                            Text("Selecione ou pule para usar todas")
                                .font(.system(size: 11))
                                .foregroundStyle(VitaColors.textTertiary)
                        } else {
                            Text("\(vm.state.selectedDisciplineIds.count) selecionada\(vm.state.selectedDisciplineIds.count == 1 ? "" : "s")")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(VitaColors.textPrimary)
                        }
                        Spacer()
                        VitaButton(
                            text: vm.state.selectedDisciplineIds.isEmpty ? "Pular" : "Próximo",
                            action: { vm.proceedFromDisciplines() }
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(VitaColors.surface)
            }
        }
        .background(VitaColors.surface.ignoresSafeArea())
    }

    private func findDisciplineTitle(id: Int, in nodes: [QBankDiscipline]) -> String {
        for node in nodes {
            if node.id == id { return node.title }
            let found = findDisciplineTitle(id: id, in: node.children)
            if found != "\(id)" { return found }
        }
        return "\(id)"
    }
}

private struct DisciplineCard: View {
    let discipline: QBankDiscipline
    let isSelected: Bool
    let onTap: () -> Void
    let onToggle: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox for leaf, dot for parent
                if discipline.children.isEmpty {
                    Button(action: onToggle) {
                        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                            .font(.system(size: 18))
                            .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textTertiary.opacity(0.5))
                    }
                    .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(VitaColors.accent.opacity(0.2))
                        .frame(width: 8, height: 8)
                        .frame(width: 24, height: 24)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(discipline.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textPrimary)
                        .lineLimit(2)

                    if discipline.questionCount > 0 {
                        Text("\(discipline.questionCount) questões")
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }

                Spacer()

                if !discipline.children.isEmpty {
                    HStack(spacing: 4) {
                        Text("\(discipline.children.count)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(VitaColors.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VitaColors.surfaceElevated.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VitaColors.textTertiary.opacity(0.5))
                    }
                }
            }
            .padding(14)
            .background(VitaColors.glassBg)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? VitaColors.accent.opacity(0.3) : VitaColors.glassBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Config content

private struct QBankConfigContent: View {
    @Bindable var vm: QBankViewModel
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                        .frame(width: 44, height: 44)
                }
                Text("Nova Sessão")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                Spacer()
                if vm.state.hasActiveFilters {
                    Button("Limpar") { vm.clearFilters() }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VitaColors.accent)
                        .padding(.trailing, 8)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            if vm.state.filtersLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView().tint(VitaColors.accent)
                    Text("Carregando filtros...")
                        .font(.system(size: 13))
                        .foregroundStyle(VitaColors.textTertiary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        QBankSectionTitle("Número de Questões")
                        HStack(spacing: 8) {
                            ForEach([10, 20, 30, 50, 100], id: \.self) { count in
                                QBankChip(label: "\(count)", isSelected: vm.state.questionCount == count) {
                                    vm.setQuestionCount(count)
                                }
                            }
                        }

                        QBankSectionTitle("Dificuldade")
                        HStack(spacing: 8) {
                            ForEach([("easy","Fácil"),("medium","Médio"),("hard","Difícil")], id: \.0) { key, label in
                                QBankChip(label: label, isSelected: vm.state.selectedDifficulties.contains(key)) {
                                    vm.toggleDifficulty(key)
                                }
                            }
                        }

                        if !vm.state.filters.institutions.isEmpty {
                            QBankSectionTitle("Bancas / Instituições")
                            QBankFlowLayout(spacing: 8) {
                                ForEach(vm.state.filters.institutions) { inst in
                                    QBankChip(label: inst.name, isSelected: vm.state.selectedInstitutionIds.contains(inst.id)) {
                                        vm.toggleInstitution(inst.id)
                                    }
                                }
                            }
                        }

                        if !vm.state.filters.years.isEmpty {
                            QBankSectionTitle("Ano")
                            let sortedYears = vm.state.filters.years.sorted(by: >)
                            QBankFlowLayout(spacing: 8) {
                                ForEach(sortedYears, id: \.self) { year in
                                    QBankChip(label: "\(year)", isSelected: vm.state.selectedYears.contains(year)) {
                                        vm.toggleYear(year)
                                    }
                                }
                            }
                        }

                        if !vm.state.filters.topics.isEmpty {
                            QBankSectionTitle("Tópicos")
                            QBankFlowLayout(spacing: 8) {
                                ForEach(vm.state.filters.topics) { topic in
                                    QBankChip(label: topic.title, isSelected: vm.state.selectedTopicIds.contains(topic.id)) {
                                        vm.toggleTopic(topic.id)
                                    }
                                }
                            }
                        }

                        QBankSectionTitle("Opções")
                        VStack(spacing: 10) {
                            QBankConfigToggleRow(
                                icon: "graduationcap",
                                title: "Apenas Residência Médica",
                                description: "Filtra somente questões de prova de residência",
                                isOn: vm.state.onlyResidence
                            ) { vm.setOnlyResidence(!vm.state.onlyResidence) }

                            QBankConfigToggleRow(
                                icon: "circle.dotted",
                                title: "Apenas Não Respondidas",
                                description: "Exclui questões que você já respondeu",
                                isOn: vm.state.onlyUnanswered
                            ) { vm.setOnlyUnanswered(!vm.state.onlyUnanswered) }
                        }

                        if let error = vm.state.error {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.dataRed)
                        }
                    }
                    .padding(16)
                }

                VStack(spacing: 8) {
                    if vm.state.sessionLoading {
                        VStack(spacing: 10) {
                            ProgressView().tint(VitaColors.accent)
                            Text("Montando sua sessão...")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(VitaColors.accent)
                        }
                        .padding(.vertical, 12)
                    } else {
                        VitaButton(
                            text: "Iniciar Sessão (\(vm.state.questionCount) questões)",
                            action: { vm.createSession() }
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .background(VitaColors.surface.ignoresSafeArea())
    }
}

// MARK: - Session content

private struct QBankSessionContent: View {
    @Bindable var vm: QBankViewModel
    let onBack: () -> Void

    @State private var showFinishAlert = false
    @State private var showExplanationSheet = false
    @State private var timerTask: Task<Void, Never>? = nil

    var timerStr: String {
        let s = vm.state.elapsedSeconds
        return "\(s / 60):\(String(format: "%02d", s % 60))"
    }

    var body: some View {
        ZStack {
            VitaColors.surface.ignoresSafeArea()
            if vm.state.questionLoading || vm.state.currentQuestionDetail == nil {
                VStack(spacing: 12) {
                    ProgressView().tint(VitaColors.accent)
                    Text("Carregando questão...")
                        .font(.system(size: 13))
                        .foregroundStyle(VitaColors.textTertiary)
                }
            } else if let question = vm.state.currentQuestionDetail {
                sessionContent(question: question)
            }
        }
        .sheet(isPresented: $showExplanationSheet) {
            if let question = vm.state.currentQuestionDetail {
                QBankExplanationSheet(question: question)
            }
        }
        .alert("Encerrar Sessão?", isPresented: $showFinishAlert) {
            Button("Encerrar", role: .destructive) { vm.finishSession() }
            Button("Continuar", role: .cancel) {}
        } message: {
            let answered = vm.state.sessionAnswers.count
            let total = vm.state.totalInSession
            Text("Você respondeu \(answered) de \(total) questões. Deseja encerrar?")
        }
        .onAppear { startTimer() }
        .onDisappear { timerTask?.cancel() }
    }

    @ViewBuilder
    private func sessionContent(question: QBankQuestionDetail) -> some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(VitaColors.textSecondary)
                        .frame(width: 40, height: 40)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Questão \(vm.state.progress1Based)/\(vm.state.totalInSession)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                    if let year = question.year {
                        Text("\(year) · \(question.difficulty.difficultyLabel)")
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
                Spacer()
                Text(timerStr)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VitaColors.textTertiary)
                if let inst = question.institutionName, !inst.isEmpty {
                    Text(inst)
                        .font(.system(size: 10))
                        .foregroundStyle(VitaColors.accent)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(VitaColors.accent.opacity(0.1))
                        .clipShape(Capsule())
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(VitaColors.glassBorder)
                    Rectangle()
                        .fill(VitaColors.accent)
                        .frame(width: geo.size.width * CGFloat(vm.state.sessionProgress))
                        .animation(.easeInOut(duration: 0.4), value: vm.state.sessionProgress)
                }
            }
            .frame(height: 2)

            // Topics tags
            if !question.topics.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(question.topics) { topic in
                            Text(topic.title)
                                .font(.system(size: 10))
                                .foregroundStyle(VitaColors.textSecondary)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(VitaColors.glassBg)
                                .overlay(Capsule().stroke(VitaColors.glassBorder, lineWidth: 1))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Badges
                    let hasBadges = question.isResidence || question.isCancelled || question.isOutdated
                    if hasBadges {
                        HStack(spacing: 6) {
                            if question.isResidence { QBankBadge(text: "Residência", color: VitaColors.dataBlue) }
                            if question.isCancelled { QBankBadge(text: "Anulada",    color: VitaColors.dataAmber) }
                            if question.isOutdated  { QBankBadge(text: "Desatualizada", color: VitaColors.textTertiary) }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                    }

                    // Statement
                    if question.statement.contains("<") {
                        QBankHTMLText(html: question.statement, textColor: "#FFFFFF", bgColor: "transparent")
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                    } else {
                        Text(question.statement)
                            .font(.system(size: 15))
                            .foregroundStyle(VitaColors.textPrimary)
                            .lineSpacing(4)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                    }

                    // Alternatives
                    let sortedAlts = question.alternatives.sorted { $0.sortOrder < $1.sortOrder }
                    ForEach(Array(sortedAlts.enumerated()), id: \.element.id) { idx, alt in
                        QBankAlternativeCard(
                            idx: idx,
                            alternative: alt,
                            selectedId: vm.state.selectedAlternativeId,
                            showFeedback: vm.state.showFeedback
                        ) {
                            vm.selectAlternative(id: alt.id)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, idx < sortedAlts.count - 1 ? 8 : 0)
                    }

                    // Inline explanation after feedback
                    if vm.state.showFeedback, let explanation = question.explanation, !explanation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Comentário")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(VitaColors.textPrimary)
                            if explanation.contains("<") {
                                QBankHTMLText(html: explanation, textColor: "#AAAAAA", bgColor: "transparent")
                            } else {
                                Text(explanation)
                                    .font(.system(size: 13))
                                    .foregroundStyle(VitaColors.textSecondary)
                                    .lineSpacing(3)
                            }
                        }
                        .padding(14)
                        .background(VitaColors.glassBg)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(VitaColors.glassBorder, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            // Bottom actions
            VStack(spacing: 8) {
                if vm.state.showFeedback {
                    HStack(spacing: 10) {
                        Button {
                            showExplanationSheet = true
                        } label: {
                            Text("Detalhes")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(VitaColors.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(VitaColors.accent, lineWidth: 1))
                        }
                        Button {
                            if vm.state.isLastQuestion { vm.finishSession() } else { vm.nextQuestion() }
                        } label: {
                            Text(vm.state.isLastQuestion ? "Ver Resultado" : "Próxima")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(VitaColors.surface)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(VitaColors.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                } else {
                    Button { vm.confirmAnswer() } label: {
                        Text("Confirmar")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VitaColors.surface)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(vm.state.selectedAlternativeId != nil ? VitaColors.accent : VitaColors.accent.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(vm.state.selectedAlternativeId == nil)
                }

                Button { showFinishAlert = true } label: {
                    Text("Encerrar Sessão")
                        .font(.system(size: 13))
                        .foregroundStyle(VitaColors.textTertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
        }
        .animation(.easeInOut(duration: 0.3), value: vm.state.showFeedback)
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                vm.tickTimer()
            }
        }
    }
}

// MARK: - Alternative Card (standalone for coordinator use)

private struct QBankAlternativeCard: View {
    let idx: Int
    let alternative: QBankAlternative
    let selectedId: Int?
    let showFeedback: Bool
    let onSelect: () -> Void

    private static let letters = ["A", "B", "C", "D", "E"]

    private var isSelected: Bool { selectedId == alternative.id }
    private var isCorrect: Bool { alternative.isCorrect }
    private var isWrongChoice: Bool { showFeedback && isSelected && !isCorrect }

    private var borderColor: Color {
        if showFeedback && isCorrect { return VitaColors.dataGreen }
        if isWrongChoice { return VitaColors.dataRed }
        if isSelected { return VitaColors.accent }
        return VitaColors.glassBorder
    }
    private var bgColor: Color {
        if showFeedback && isCorrect { return VitaColors.dataGreen.opacity(0.10) }
        if isWrongChoice { return VitaColors.dataRed.opacity(0.10) }
        if isSelected { return VitaColors.accent.opacity(0.08) }
        return Color.clear
    }
    private var letterColor: Color {
        if showFeedback && isCorrect { return VitaColors.dataGreen }
        if isWrongChoice { return VitaColors.dataRed }
        if isSelected { return VitaColors.accent }
        return VitaColors.textTertiary
    }
    private var letter: String {
        Self.letters.indices.contains(idx) ? Self.letters[idx] : "\(idx + 1)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isSelected || (showFeedback && isCorrect) ? borderColor.opacity(0.15) : VitaColors.glassBg)
                    .frame(width: 28, height: 28)
                if showFeedback && isCorrect {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VitaColors.dataGreen)
                } else if isWrongChoice {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VitaColors.dataRed)
                } else {
                    Text(letter)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(letterColor)
                }
            }
            Text(alternative.description)
                .font(.system(size: 14))
                .foregroundStyle(VitaColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(bgColor)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: showFeedback && isCorrect ? 1.5 : 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { if !showFeedback { onSelect() } }
        .animation(.easeInOut(duration: 0.2), value: showFeedback)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Explanation Sheet

private struct QBankExplanationSheet: View {
    let question: QBankQuestionDetail

    private static let letters = ["A", "B", "C", "D", "E"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Gabarito e Comentário")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .padding(.top, 20)

                let sortedAlts = question.alternatives.sorted { $0.sortOrder < $1.sortOrder }

                // Correct alternative
                ForEach(Array(sortedAlts.enumerated()), id: \.element.id) { idx, alt in
                    if alt.isCorrect {
                        HStack(spacing: 8) {
                            Text(Self.letters.indices.contains(idx) ? Self.letters[idx] : "\(idx+1)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(VitaColors.dataGreen)
                                .frame(width: 22, height: 22)
                                .background(VitaColors.dataGreen.opacity(0.15))
                                .clipShape(Circle())
                            Text(alt.description)
                                .font(.system(size: 13))
                                .foregroundStyle(VitaColors.textPrimary)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(VitaColors.dataGreen)
                        }
                        .padding(10)
                        .background(VitaColors.dataGreen.opacity(0.05))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(VitaColors.dataGreen.opacity(0.3), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }

                // Statistics
                if !question.statistics.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Distribuição das Respostas")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                        ForEach(Array(sortedAlts.enumerated()), id: \.element.id) { idx, alt in
                            if let stat = question.statistics.first(where: { $0.alternativeId == alt.id }) {
                                HStack(spacing: 8) {
                                    Text(Self.letters.indices.contains(idx) ? Self.letters[idx] : "\(idx+1)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(alt.isCorrect ? VitaColors.dataGreen : VitaColors.textTertiary)
                                        .frame(width: 18)
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3).fill(VitaColors.glassBorder)
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(alt.isCorrect ? VitaColors.dataGreen : VitaColors.accent.opacity(0.4))
                                                .frame(width: geo.size.width * CGFloat(stat.percentage / 100).clamped(to: 0...1))
                                        }
                                    }
                                    .frame(height: 8)
                                    Text("\(Int(stat.percentage))%")
                                        .font(.system(size: 10))
                                        .foregroundStyle(alt.isCorrect ? VitaColors.dataGreen : VitaColors.textTertiary)
                                        .frame(width: 32, alignment: .trailing)
                                }
                            }
                        }
                    }
                }

                // Explanation
                if let explanation = question.explanation, !explanation.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Comentário")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                        if explanation.contains("<") {
                            QBankHTMLText(html: explanation, textColor: "#AAAAAA", bgColor: "transparent")
                                .frame(minHeight: 80)
                        } else {
                            Text(explanation)
                                .font(.system(size: 13))
                                .foregroundStyle(VitaColors.textSecondary)
                                .lineSpacing(3)
                        }
                    }
                }

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 20)
        }
        .background(VitaColors.surface)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Result content

private struct QBankResultContent: View {
    @Bindable var vm: QBankViewModel
    let onBack: () -> Void
    let onNewSession: () -> Void

    @State private var animatedProgress: Double = 0

    private static let letters = ["A", "B", "C", "D", "E"]

    var body: some View {
        let answered = vm.state.sessionAnswers.count
        let correct = vm.state.correctCount
        let wrong = answered - correct
        let total = vm.state.totalInSession
        let unanswered = total - answered
        let accuracy = vm.state.accuracy
        let scoreColor: Color = accuracy >= 0.7 ? VitaColors.dataGreen : accuracy >= 0.5 ? VitaColors.dataAmber : VitaColors.dataRed

        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(VitaColors.textPrimary)
                            .frame(width: 44, height: 44)
                    }
                    Text("Resultado")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VitaColors.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 8)

                Spacer().frame(height: 32)

                // Score ring
                ZStack {
                    Circle()
                        .stroke(VitaColors.glassBorder, lineWidth: 10)
                        .frame(width: 160, height: 160)
                    Circle()
                        .trim(from: 0, to: animatedProgress)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(Int(accuracy * 100))%")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(scoreColor)
                        Text("de acerto")
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                }
                .onAppear {
                    withAnimation(.easeOut(duration: 1.0)) { animatedProgress = accuracy }
                }

                Spacer().frame(height: 24)

                HStack {
                    Spacer()
                    QBankResultStatItem(icon: "checkmark.circle.fill", count: correct,   label: "Corretas",  color: VitaColors.dataGreen)
                    Spacer()
                    QBankResultStatItem(icon: "xmark.circle.fill",    count: wrong,      label: "Erradas",   color: VitaColors.dataRed)
                    Spacer()
                    QBankResultStatItem(icon: "minus.circle.fill",    count: unanswered, label: "Em branco", color: VitaColors.textTertiary)
                    Spacer()
                }

                Spacer().frame(height: 8)

                let s = vm.state.elapsedSeconds
                let timeStr = s >= 3600 ? "\(s/3600)h \((s%3600)/60)m" : "\(s/60)m \(s%60)s"
                Text("Tempo total: \(timeStr)")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.textTertiary)

                // Difficulty breakdown
                let diffBreakdown = buildDiffBreakdown()
                if !diffBreakdown.isEmpty {
                    Spacer().frame(height: 20)
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Por Dificuldade")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                        ForEach(diffBreakdown, id: \.0) { (diff, t, c) in
                            let rate = t > 0 ? Double(c) / Double(t) : 0
                            let col: Color = rate >= 0.7 ? VitaColors.dataGreen : rate >= 0.5 ? VitaColors.dataAmber : VitaColors.dataRed
                            HStack(spacing: 10) {
                                Text(diff.difficultyLabel)
                                    .font(.system(size: 12))
                                    .foregroundStyle(VitaColors.textPrimary)
                                    .frame(width: 50, alignment: .leading)
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3).fill(VitaColors.glassBorder)
                                        RoundedRectangle(cornerRadius: 3).fill(col)
                                            .frame(width: geo.size.width * CGFloat(rate))
                                    }
                                }
                                .frame(height: 6)
                                Text("\(c)/\(t)")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(col)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                    .padding(16)
                    .background(VitaColors.glassBg)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(VitaColors.glassBorder, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal, 24)
                }

                // Question review
                let allIds = vm.state.session?.questionIds ?? []
                if !allIds.isEmpty {
                    Spacer().frame(height: 20)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Revisão das Questões")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.textPrimary)
                            .padding(.horizontal, 24)
                            .padding(.bottom, 8)
                        ForEach(Array(allIds.enumerated()), id: \.element) { idx, qId in
                            let answer = vm.state.sessionAnswers[qId]
                            let detail = vm.state.sessionDetails[qId]
                            QBankResultReviewRow(index: idx + 1, questionId: qId, detail: detail, answer: answer)
                                .padding(.horizontal, 24)
                        }
                    }
                }

                Spacer().frame(height: 24)

                VStack(spacing: 10) {
                    VitaButton(text: "Nova Sessão", action: onNewSession)
                    VitaButton(text: "Voltar ao Início", action: onBack, variant: .secondary)
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 32)
            }
        }
        .background(VitaColors.surface.ignoresSafeArea())
    }

    private func buildDiffBreakdown() -> [(String, Int, Int)] {
        var map: [String: (Int, Int)] = [:]
        for (qId, ans) in vm.state.sessionAnswers {
            guard let detail = vm.state.sessionDetails[qId] else { continue }
            var entry = map[detail.difficulty] ?? (0, 0)
            entry.0 += 1
            if ans.isCorrect { entry.1 += 1 }
            map[detail.difficulty] = entry
        }
        return ["easy", "medium", "hard"].compactMap { k in
            map[k].map { (k, $0.0, $0.1) }
        }
    }
}

private struct QBankResultStatItem: View {
    let icon: String
    let count: Int
    let label: String
    let color: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            Text("\(count)").font(.system(size: 18, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 10)).foregroundStyle(VitaColors.textTertiary)
        }
    }
}

private struct QBankResultReviewRow: View {
    let index: Int
    let questionId: Int
    let detail: QBankQuestionDetail?
    let answer: QBankAnswerResponse?

    private var statusColor: Color { answer.map { $0.isCorrect ? VitaColors.dataGreen : VitaColors.dataRed } ?? VitaColors.textTertiary }
    private var statusIcon: String  { answer.map { $0.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill" } ?? "minus.circle" }
    private var statement: String {
        guard let d = detail else { return "Questão \(questionId)" }
        let s = d.statement.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return s.isEmpty ? "Questão \(questionId)" : s
    }

    var body: some View {
        HStack(spacing: 10) {
            Text("\(index)").font(.system(size: 11, weight: .semibold)).foregroundStyle(VitaColors.textTertiary).frame(width: 24)
            Text(statement).font(.system(size: 12)).foregroundStyle(VitaColors.textSecondary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: statusIcon).font(.system(size: 16)).foregroundStyle(statusColor)
        }
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) { Rectangle().fill(VitaColors.glassBorder).frame(height: 0.5) }
    }
}

// (Old stats/difficulty/topic views removed — replaced by convex glass versions above)

// MARK: - QBank Badge

struct QBankBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
            .clipShape(Capsule())
    }
}

// MARK: - HTML Text Renderer (WKWebView)

struct QBankHTMLText: UIViewRepresentable {
    let html: String
    var textColor: String = "#FFFFFF"
    var bgColor: String = "transparent"

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHtml = """
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
          body {
            font-family: -apple-system, sans-serif;
            font-size: 15px;
            line-height: 1.5;
            color: \(textColor);
            background: \(bgColor);
            margin: 0; padding: 0;
            -webkit-text-size-adjust: none;
          }
          img { max-width: 100%; height: auto; border-radius: 8px; margin: 4px 0; }
          table { border-collapse: collapse; width: 100%; }
          td, th { border: 1px solid rgba(255,255,255,0.12); padding: 6px 8px; font-size: 12px; }
          p { margin: 0 0 8px 0; }
        </style>
        </head>
        <body>\(html)</body>
        </html>
        """
        webView.loadHTMLString(styledHtml, baseURL: nil)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.evaluateJavaScript("document.body.scrollHeight") { result, _ in
                guard let height = result as? CGFloat else { return }
                DispatchQueue.main.async {
                    webView.frame.size.height = height
                }
            }
        }
    }
}

// MARK: - Config Screen Helpers

struct QBankSectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(VitaColors.textPrimary)
    }
}

struct QBankChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? VitaColors.accent : VitaColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isSelected ? VitaColors.accent.opacity(0.12) : VitaColors.glassBg)
                .overlay(
                    Capsule().stroke(
                        isSelected ? VitaColors.accent.opacity(0.3) : VitaColors.glassBorder,
                        lineWidth: 1
                    )
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct QBankFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

struct QBankConfigToggleRow: View {
    let icon: String
    let title: String
    let description: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(isOn ? VitaColors.accent : VitaColors.textTertiary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VitaColors.textPrimary)
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.textTertiary)
                }

                Spacer()

                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isOn ? VitaColors.accent : VitaColors.textTertiary.opacity(0.4))
            }
            .padding(12)
            .background(isOn ? VitaColors.accent.opacity(0.06) : VitaColors.glassBg)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isOn ? VitaColors.accent.opacity(0.2) : VitaColors.glassBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CGFloat clamping

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        Swift.max(range.lowerBound, Swift.min(self, range.upperBound))
    }
}
