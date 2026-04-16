import SwiftUI

// MARK: - EstudosScreen

struct EstudosScreen: View {
    @Environment(\.appContainer) private var container

    // Navigation callbacks — injected by AppRouter/MainTabView
    var onNavigateToCanvasConnect:    (() -> Void)?
    var onNavigateToNotebooks:         (() -> Void)?
    var onNavigateToMindMaps:          (() -> Void)?
    var onNavigateToFlashcardSession:  ((String) -> Void)?
    var onNavigateToFlashcardStats:    (() -> Void)?
    var onNavigateToPdfViewer:         ((URL) -> Void)?
    var onNavigateToSimulados:         (() -> Void)?
    var onNavigateToOsce:              (() -> Void)?
    var onNavigateToAtlas:             (() -> Void)?
    var onNavigateToCourseDetail:      ((String, Int) -> Void)?
    var onNavigateToProvas:            (() -> Void)?
    var onNavigateToQBank:             (() -> Void)?
    var onNavigateToTranscricao:       (() -> Void)?
    var onNavigateToTrabalhos:         (() -> Void)?

    @State private var viewModel: EstudosViewModel?

    var body: some View {
        Group {
            if let viewModel {
                EstudosContent(
                    viewModel: viewModel,
                    onNavigateToCanvasConnect:   onNavigateToCanvasConnect,
                    onNavigateToNotebooks:        onNavigateToNotebooks,
                    onNavigateToMindMaps:         onNavigateToMindMaps,
                    onNavigateToFlashcardSession: onNavigateToFlashcardSession,
                    onNavigateToFlashcardStats:   onNavigateToFlashcardStats,
                    onNavigateToPdfViewer:        onNavigateToPdfViewer,
                    onNavigateToSimulados:        onNavigateToSimulados,
                    onNavigateToOsce:             onNavigateToOsce,
                    onNavigateToAtlas:            onNavigateToAtlas,
                    onNavigateToCourseDetail:     onNavigateToCourseDetail,
                    onNavigateToProvas:           onNavigateToProvas,
                    onNavigateToQBank:            onNavigateToQBank,
                    onNavigateToTranscricao:      onNavigateToTranscricao,
                    onNavigateToTrabalhos:        onNavigateToTrabalhos
                )
            } else {
                ProgressView()
                    .tint(VitaColors.accentHover)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = EstudosViewModel(api: container.api, userEmail: container.authManager.userEmail)
                Task { await viewModel?.load() }
            }
        }
    }
}

// MARK: - Content

private struct EstudosContent: View {
    @Bindable var viewModel: EstudosViewModel
    @Environment(\.appData) private var appData

    let onNavigateToCanvasConnect:    (() -> Void)?
    let onNavigateToNotebooks:         (() -> Void)?
    let onNavigateToMindMaps:          (() -> Void)?
    let onNavigateToFlashcardSession:  ((String) -> Void)?
    let onNavigateToFlashcardStats:    (() -> Void)?
    let onNavigateToPdfViewer:         ((URL) -> Void)?
    let onNavigateToSimulados:         (() -> Void)?
    let onNavigateToOsce:              (() -> Void)?
    let onNavigateToAtlas:             (() -> Void)?
    let onNavigateToCourseDetail:      ((String, Int) -> Void)?
    let onNavigateToProvas:            (() -> Void)?
    let onNavigateToQBank:             (() -> Void)?
    let onNavigateToTranscricao:       (() -> Void)?
    let onNavigateToTrabalhos:         (() -> Void)?

    // Design tokens — matching FaculdadeHomeScreen
    private var goldPrimary: Color { VitaColors.accentHover }
    private var goldMuted: Color { VitaColors.accentLight }
    private var textPrimary: Color { VitaColors.textPrimary }
    private var textWarm: Color { VitaColors.textWarm }
    private var textDim: Color { VitaColors.textWarm.opacity(0.30) }
    private var cardBg: Color { VitaColors.surfaceCard.opacity(0.55) }
    private var glassBorder: Color { VitaColors.textWarm.opacity(0.06) }

    /// Grade subjects from appData (same source as Dashboard & Faculdade)
    private var gradeSubjects: [GradeSubject] {
        appData.gradesResponse?.current ?? []
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // 1. Hero card — progress overview
                estudosHeroCard
                    .padding(.horizontal, 16)

                // 2. Ferramentas — 2x2 grid + Atlas tall card
                ferramentasSection
                    .padding(.horizontal, 16)

                // 3. Disciplinas atuais — vertical list, Faculdade card pattern
                disciplinasSection
                    .padding(.horizontal, 16)

                // 4. Materiais recentes — horizontal scroll
                materiaisSection
                    .padding(.horizontal, 16)

                // 5. Trabalhos pendentes
                trabalhosSection
                    .padding(.horizontal, 16)

                // 6. Sessões recentes
                sessoesSection
                    .padding(.horizontal, 16)

                Spacer().frame(height: 100)
            }
            .padding(.top, 8)
        }
        .refreshable {
            await viewModel.load()
        }
    }

    // MARK: - 1. Hero Card

    private var estudosHeroCard: some View {
        ZStack(alignment: .topLeading) {
            // Base gradient
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.07, blue: 0.045),
                    Color(red: 0.05, green: 0.035, blue: 0.022)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            // Gold accent glow top-right
            RadialGradient(
                colors: [goldPrimary.opacity(0.22), Color.clear],
                center: UnitPoint(x: 1.0, y: 0.0),
                startRadius: 0,
                endRadius: 140
            )
            // Book motif — background decoration
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(goldPrimary.opacity(0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 14)
                .padding(.trailing, 16)
            // Content
            heroCardContent
        }
        .frame(height: 162)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            goldPrimary.opacity(0.40),
                            goldPrimary.opacity(0.10),
                            goldPrimary.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.30), radius: 14, y: 6)
    }

    private var heroCardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Eyebrow
            HStack(spacing: 6) {
                Circle()
                    .fill(goldPrimary)
                    .frame(width: 5, height: 5)
                Text("ESTUDOS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(goldPrimary)
            }
            .padding(.bottom, 6)

            // Title
            Text("Seu Progresso")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color.white)
                .kerning(-0.4)

            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(goldMuted.opacity(0.75))
                Text("Acompanhe sua evolução")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .padding(.top, 3)

            Spacer(minLength: 0)

            // Stats strip
            HStack(spacing: 14) {
                heroStat(label: "Due", value: "\(viewModel.flashcardsDue)")
                heroStatDivider
                heroStat(label: "Streak", value: "\(viewModel.streakDays)d")
                heroStatDivider
                heroStat(label: "Acerto", value: accuracyString)
                Spacer()
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var accuracyString: String {
        if viewModel.avgAccuracy <= 0 { return "—" }
        return "\(Int(viewModel.avgAccuracy))%"
    }

    private var heroStatDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 16)
    }

    private func heroStat(label: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(goldPrimary)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(Color.white.opacity(0.55))
        }
    }

    // MARK: - 2. Ferramentas Section

    private var ferramentasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("FERRAMENTAS DE ESTUDO")

            HStack(alignment: .top, spacing: 8) {
                // Left: 2x2 grid
                let leftColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)
                LazyVGrid(columns: leftColumns, spacing: 8) {
                    ToolCard(
                        imageName: "tool-questoes",
                        label: "QBanco",
                        accentColor: VitaColors.toolQBank,
                        onTap: { onNavigateToQBank?() }
                    )
                    ToolCard(
                        imageName: "tool-flashcards",
                        label: "Flashcards",
                        accentColor: VitaColors.toolFlashcards,
                        onTap: { onNavigateToFlashcardStats?() }
                    )
                    ToolCard(
                        imageName: "tool-simulados",
                        label: "Simulados",
                        accentColor: VitaColors.toolSimulados,
                        onTap: { onNavigateToSimulados?() }
                    )
                    ToolCard(
                        imageName: "tool-transcricao",
                        label: "Transcrição",
                        accentColor: VitaColors.toolTranscricao,
                        onTap: { onNavigateToTranscricao?() }
                    )
                }
                .frame(maxWidth: .infinity)

                // Right: Atlas tall card
                AtlasTallCard(onTap: { onNavigateToAtlas?() })
                    .frame(width: 106)
            }
        }
    }

    // MARK: - 3. Disciplinas Section

    private var disciplinasSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("DISCIPLINAS ATUAIS")
                Spacer()
                if !gradeSubjects.isEmpty {
                    Button {
                        // Navigate to full Faculdade disciplinas screen
                    } label: {
                        HStack(spacing: 3) {
                            Text("Ver todas")
                                .font(.system(size: 10, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundStyle(goldPrimary.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                }
            }

            if gradeSubjects.isEmpty {
                estudosEmptyRow(icon: "graduationcap", message: "Conecte seu portal para ver suas disciplinas")
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(gradeSubjects.prefix(4))) { subject in
                        Button {
                            onNavigateToCourseDetail?(subject.subjectName, 0)
                        } label: {
                            disciplinaCard(subject)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func disciplinaCard(_ subject: GradeSubject) -> some View {
        let color = SubjectColors.colorFor(subject: subject.subjectName)
        let shortName = subject.subjectName
            .replacingOccurrences(of: "(?i),.*$", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)

        return HStack(spacing: 12) {
            Rectangle()
                .fill(color)
                .frame(width: 3, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 2) {
                Text(shortName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(textWarm.opacity(0.90))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    if let grade = subject.finalGrade {
                        disciplinaMiniStat("Nota", value: String(format: "%.1f", grade))
                    }
                    if let freq = subject.attendance {
                        disciplinaMiniStat("Freq", value: String(format: "%.0f%%", freq))
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textWarm.opacity(0.20))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12).fill(cardBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12).stroke(glassBorder, lineWidth: 0.5)
        )
    }

    private func disciplinaMiniStat(_ label: String, value: String) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(textDim)
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(textWarm.opacity(0.70))
        }
    }

    // MARK: - 4. Materiais Recentes Section

    private var materiaisSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("MATERIAIS RECENTES")

            if viewModel.files.isEmpty {
                estudosEmptyRow(icon: "doc.text", message: "Conecte seu portal para ver materiais")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.files.prefix(8)) { file in
                            MaterialCard(
                                file: file,
                                onTap: {
                                    Task {
                                        if let url = await viewModel.downloadFile(fileId: file.id, fileName: file.displayName) {
                                            onNavigateToPdfViewer?(url)
                                        }
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 1) // prevent clipping shadows
                }
            }
        }
    }

    // MARK: - 5. Trabalhos Section

    private var trabalhosSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader("TRABALHOS PENDENTES")
                Spacer()
                if !viewModel.trabalhosPending.isEmpty || !viewModel.trabalhosOverdue.isEmpty {
                    Button { onNavigateToTrabalhos?() } label: {
                        HStack(spacing: 3) {
                            Text("Ver todos")
                                .font(.system(size: 10, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                        }
                        .foregroundStyle(goldPrimary.opacity(0.60))
                    }
                    .buttonStyle(.plain)
                }
            }

            let preview = Array((viewModel.trabalhosOverdue + viewModel.trabalhosPending).prefix(3))
            if preview.isEmpty {
                estudosEmptyRow(icon: "checkmark.circle", message: "Nenhum trabalho pendente")
            } else {
                VStack(spacing: 8) {
                    ForEach(preview) { item in
                        trabalhoRow(item)
                    }
                }
            }
        }
    }

    private func trabalhoRow(_ item: TrabalhoItem) -> some View {
        let isOverdue = (item.daysUntil ?? 0) < 0
        let barColor: Color = isOverdue ? VitaColors.dataRed : VitaColors.accent

        return HStack(spacing: 10) {
            Rectangle()
                .fill(barColor)
                .frame(width: 3, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(textWarm.opacity(0.90))
                    .lineLimit(1)
                Text(item.subjectName)
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(textDim)
                    .lineLimit(1)
            }

            Spacer()

            if let days = item.daysUntil {
                Text(trabalhoDaysLabel(days))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(barColor)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBg))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(glassBorder, lineWidth: 0.5))
    }

    private func trabalhoDaysLabel(_ days: Int) -> String {
        if days < 0 { return "\(abs(days))d atrasado" }
        if days == 0 { return "Hoje" }
        if days == 1 { return "Amanhã" }
        return "Em \(days)d"
    }

    // MARK: - 6. Sessões Recentes Section

    private var sessoesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("SESSÕES RECENTES")

            if viewModel.recentActivity.isEmpty {
                estudosEmptyRow(icon: "clock", message: "Nenhuma sessão recente")
            } else {
                VStack(spacing: 6) {
                    ForEach(viewModel.recentActivity) { activity in
                        activityRow(activity)
                    }
                }
            }
        }
    }

    private func activityRow(_ activity: ActivityFeedItem) -> some View {
        let icon = activityIcon(for: activity.action)
        let title = activity.action.replacingOccurrences(of: "_", with: " ").capitalized
        let timeStr = relativeTime(from: activity.createdAt)

        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(goldPrimary.opacity(0.08))
                    .frame(width: 30, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(goldPrimary.opacity(0.06), lineWidth: 1)
                    )
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.60))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(textWarm.opacity(0.85))
                if activity.xpAwarded > 0 {
                    Text("+\(activity.xpAwarded) XP")
                        .font(.system(size: 9.5))
                        .foregroundStyle(VitaColors.textSecondary)
                }
            }

            Spacer()

            Text(timeStr)
                .font(.system(size: 9.5))
                .foregroundStyle(textDim)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBg))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(glassBorder, lineWidth: 0.5))
    }

    private func activityIcon(for action: String) -> String {
        let a = action.lowercased()
        if a.contains("flashcard") { return "rectangle.on.rectangle.angled" }
        if a.contains("qbank") || a.contains("question") { return "checkmark.square" }
        if a.contains("simulado") { return "text.badge.checkmark" }
        return "display"
    }

    private func relativeTime(from isoString: String) -> String {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = fmt.date(from: isoString)
        if date == nil {
            fmt.formatOptions = [.withInternetDateTime]
            date = fmt.date(from: isoString)
        }
        guard let d = date else { return "" }
        let interval = Date().timeIntervalSince(d)
        if interval < 3600 { return "\(Int(interval / 60))min" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        if interval < 172800 { return "Ontem" }
        return "\(Int(interval / 86400))d"
    }

    // MARK: - Shared helpers

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .kerning(0.8)
            .textCase(.uppercase)
            .foregroundStyle(VitaColors.sectionLabel)
    }

    private func estudosEmptyRow(icon: String, message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(goldPrimary.opacity(0.35))
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(textDim)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(cardBg))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(glassBorder, lineWidth: 0.5))
    }
}

// MARK: - Tool Card (2x2 grid cell)

private struct ToolCard: View {
    let imageName: String
    let label: String
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                if UIImage(named: imageName) != nil {
                    Color.clear
                        .frame(height: 90)
                        .overlay {
                            Image(imageName)
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(VitaColors.surfaceCard.opacity(0.55))
                        .frame(height: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(VitaColors.textWarm.opacity(0.06), lineWidth: 0.5)
                        )
                }

                // Label scrim
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.60)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .padding(.bottom, 7)
            }
            .frame(height: 90)
            .frame(maxWidth: .infinity)
            .shadow(color: .black.opacity(0.30), radius: 6, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Atlas Tall Card

private struct AtlasTallCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                if UIImage(named: "tool-atlas3d") != nil {
                    Color.clear
                        .overlay {
                            Image("tool-atlas3d")
                                .resizable()
                                .scaledToFill()
                        }
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    VitaColors.surfaceCard.opacity(0.80),
                                    VitaColors.surfaceElevated.opacity(0.70)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(VitaColors.textWarm.opacity(0.06), lineWidth: 0.5)
                        )
                }

                // Label scrim
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.60)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))

                Text("Atlas 3D")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))
                    .padding(.bottom, 7)
            }
            .shadow(color: .black.opacity(0.30), radius: 6, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Atlas 3D")
    }
}

// MARK: - Material Card (horizontal scroll cell)

private struct MaterialCard: View {
    let file: CanvasFile
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                // Icon area
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(VitaColors.accentHover.opacity(0.08))
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(VitaColors.accentHover.opacity(0.70))
                }
                .frame(height: 72)

                // Text
                VStack(alignment: .leading, spacing: 3) {
                    Text(file.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.90))
                        .lineLimit(2)
                    Text(file.courseName ?? "")
                        .font(.system(size: 9.5))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.35))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
            }
            .frame(width: 140)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(VitaColors.surfaceCard.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(VitaColors.textWarm.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(file.displayName)
    }
}
