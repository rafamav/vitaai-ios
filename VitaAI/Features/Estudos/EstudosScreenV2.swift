import SwiftUI

// MARK: - EstudosScreenV2
// New Estudos screen with 5-block architecture per PAGE_SPEC.md
// Replaces the old tab-based EstudosScreen.
// To activate: replace EstudosScreen() with EstudosScreenV2() in AppRouter.

struct EstudosScreenV2: View {
    @Environment(\.appContainer) private var container
    @State private var viewModel: EstudosViewModelV2?

    /// Navigation callback for Route-based navigation
    var onNavigate: ((Route) -> Void)?

    var body: some View {
        Group {
            if let viewModel {
                switch viewModel.loadState {
                case .loading:
                    EstudosV2Skeleton()
                case .loaded:
                    EstudosV2Content(
                        viewModel: viewModel,
                        onNavigate: onNavigate
                    )
                case .error(let message):
                    VitaErrorState(
                        title: String(localized: "Erro ao carregar"),
                        message: message,
                        onRetry: {
                            Task { await viewModel.load() }
                        }
                    )
                }
            } else {
                EstudosV2Skeleton()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = EstudosViewModelV2(
                    api: container.api,
                    httpClient: container.httpClient
                )
                Task { await viewModel?.load() }
            }
        }
    }
}

// MARK: - Skeleton

private struct EstudosV2Skeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Continue section
                ShimmerText(width: 180, height: 10)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(0..<3, id: \.self) { _ in
                            ShimmerBox(height: 100, cornerRadius: 16)
                                .frame(width: 200)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Recommendation
                ShimmerText(width: 160, height: 10)
                    .padding(.horizontal, 20)
                ShimmerBox(height: 90, cornerRadius: 16)
                    .padding(.horizontal, 20)

                // Tools grid
                ShimmerText(width: 180, height: 10)
                    .padding(.horizontal, 20)
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ShimmerBox(height: 88, cornerRadius: 14)
                        ShimmerBox(height: 88, cornerRadius: 14)
                    }
                    HStack(spacing: 8) {
                        ShimmerBox(height: 88, cornerRadius: 14)
                        ShimmerBox(height: 88, cornerRadius: 14)
                    }
                }
                .padding(.horizontal, 20)

                // Recent materials
                ShimmerText(width: 150, height: 10)
                    .padding(.horizontal, 20)
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerBox(height: 52, cornerRadius: 12)
                        .padding(.horizontal, 20)
                }

                Spacer().frame(height: 120)
            }
        }
        .scrollDisabled(true)
        .allowsHitTesting(false)
    }
}

// MARK: - Content

private struct EstudosV2Content: View {
    let viewModel: EstudosViewModelV2
    let onNavigate: ((Route) -> Void)?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Block 1: Continuar de Onde Parou
                if !viewModel.continueItems.isEmpty {
                    SectionHeader(title: String(localized: "Continuar de Onde Parou"))
                    ContinueV2Scroll(
                        items: viewModel.continueItems,
                        onNavigate: onNavigate
                    )
                    .padding(.bottom, 16)
                }

                // Block 2: Recomendado Para Ti
                if let rec = viewModel.recommendation {
                    SectionHeader(title: String(localized: "Recomendado Para Ti"))
                    EstudosV2RecommendationCard(
                        recommendation: rec,
                        onNavigate: onNavigate
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                // Block 3: Biblioteca de Ferramentas
                SectionHeader(title: String(localized: "Biblioteca de Ferramentas"))
                ToolsV2Grid(onNavigate: onNavigate)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                // Block 4: Materiais Recentes
                SectionHeader(title: String(localized: "Materiais Recentes"))
                if viewModel.recentMaterials.isEmpty {
                    EstudosV2EmptyRow(
                        icon: "doc.text",
                        text: String(localized: "Nenhum material encontrado")
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                } else {
                    MaterialsV2List(materials: viewModel.recentMaterials)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }

                // Block 5: Sessoes Recentes
                SectionHeader(title: String(localized: "Sessoes Recentes"))
                if viewModel.recentSessions.isEmpty {
                    EstudosV2EmptyRow(
                        icon: "clock",
                        text: String(localized: "Nenhuma sessao recente")
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                } else {
                    SessionsV2List(sessions: viewModel.recentSessions)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
            }
            .padding(.bottom, 120)
        }
        .refreshable {
            await viewModel.load()
        }
    }
}

// MARK: - Block 1: Continue Scroll

private struct ContinueV2Scroll: View {
    let items: [ContinueItem]
    let onNavigate: ((Route) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    ContinueV2Card(item: item, onNavigate: onNavigate)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct ContinueV2Card: View {
    let item: ContinueItem
    let onNavigate: ((Route) -> Void)?

    private var route: Route? {
        switch item.type {
        case .pdf:         return nil
        case .simulado:    return .simuladoHome
        case .flashcard:   return .flashcardStats
        case .transcricao: return .transcricao
        }
    }

    private var typeLabel: String {
        switch item.type {
        case .pdf:         return String(localized: "PDF")
        case .simulado:    return String(localized: "Simulado")
        case .flashcard:   return String(localized: "Flashcard")
        case .transcricao: return String(localized: "Transcricao")
        }
    }

    var body: some View {
        Button {
            if let route { onNavigate?(route) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Type badge
                HStack(spacing: 4) {
                    Image(systemName: item.icon)
                        .font(VitaTypography.labelSmall)
                    Text(typeLabel.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .kerning(0.6)
                }
                .foregroundStyle(VitaColors.accentLight.opacity(0.80))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(VitaColors.accent.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(VitaColors.accentHover.opacity(0.18), lineWidth: 1)
                )

                // Title
                Text(item.title)
                    .font(VitaTypography.titleSmall)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(2)

                // Subtitle
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                // Progress bar
                if let progress = item.progress {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 999)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 999)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            VitaColors.accent.opacity(0.70),
                                            VitaColors.accentHover.opacity(0.50),
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geo.size.width * min(progress, 1.0),
                                    height: 4
                                )
                        }
                    }
                    .frame(height: 4)
                }
            }
            .frame(width: 180, height: 120, alignment: .topLeading)
            .padding(14)
            .glassCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(typeLabel): \(item.title)")
    }
}

// MARK: - Block 2: Recommendation Card

private struct EstudosV2RecommendationCard: View {
    let recommendation: VitaRecommendation
    let onNavigate: ((Route) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(recommendation.discipline)
                    .font(VitaTypography.titleMedium)
                    .foregroundStyle(VitaColors.textPrimary)

                Spacer()

                if let priority = recommendation.priority, priority <= 2 {
                    Text(String(localized: "Prioridade"))
                        .font(.system(size: 9, weight: .bold))
                        .kerning(0.5)
                        .foregroundStyle(VitaColors.dataAmber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(VitaColors.dataAmber.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Text(recommendation.reason)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)
                .lineLimit(2)

            Button {
                onNavigate?(.qbank)
            } label: {
                Text(recommendation.suggestedAction)
                    .font(VitaTypography.labelLarge)
                    .foregroundStyle(VitaColors.accentLight.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                VitaColors.accentHover.opacity(0.12),
                                lineWidth: 1
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }
}

// MARK: - Block 3: Tools Grid

private struct ToolsV2Grid: View {
    let onNavigate: ((Route) -> Void)?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(ToolDefinition.allTools) { tool in
                ToolV2GridCard(tool: tool, onNavigate: onNavigate)
            }
        }
    }
}

private struct ToolV2GridCard: View {
    let tool: ToolDefinition
    let onNavigate: ((Route) -> Void)?

    private var accentColor: Color {
        switch tool.accentColor {
        case .gold:   return VitaColors.accent
        case .blue:   return VitaColors.dataBlue
        case .purple: return VitaColors.dataIndigo
        case .teal:   return VitaColors.dataTeal
        case .amber:  return VitaColors.dataAmber
        case .green:  return VitaColors.dataGreen
        }
    }

    var body: some View {
        Button {
            onNavigate?(tool.route)
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: tool.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(accentColor.opacity(0.85))
                }

                Text(tool.name)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .background(
                LinearGradient(
                    colors: [
                        VitaColors.surfaceCard.opacity(0.94),
                        VitaColors.surfaceElevated.opacity(0.90),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(VitaColors.glassBorder, lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tool.name)
    }
}

// MARK: - Block 4: Materials List

private struct MaterialsV2List: View {
    let materials: [RecentMaterial]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(materials) { material in
                MaterialV2Row(material: material)
            }
        }
    }
}

private struct MaterialV2Row: View {
    let material: RecentMaterial

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(VitaColors.accent.opacity(0.08))
                    .frame(width: 32, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                VitaColors.accent.opacity(0.06),
                                lineWidth: 1
                            )
                    )
                Image(systemName: material.icon)
                    .font(.system(size: 13))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.65))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(material.title)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(material.typeLabel)
                        .font(VitaTypography.labelSmall)
                        .foregroundStyle(VitaColors.textTertiary)

                    if let subtitle = material.subtitle {
                        Text(subtitle)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            if let createdAt = material.createdAt {
                Text(EstudosV2RelativeTime.format(from: createdAt))
                    .font(VitaTypography.labelSmall)
                    .foregroundStyle(VitaColors.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.surfaceBorder, lineWidth: 1)
        )
    }
}

// MARK: - Block 5: Sessions List

private struct SessionsV2List: View {
    let sessions: [StudySessionEntry]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(sessions) { session in
                SessionV2Row(session: session)
            }
        }
    }
}

private struct SessionV2Row: View {
    let session: StudySessionEntry

    private var icon: String {
        let type = session.type.lowercased()
        if type.contains("flashcard") { return "rectangle.on.rectangle.angled" }
        if type.contains("qbank") || type.contains("question") {
            return "checkmark.square"
        }
        if type.contains("simulado") { return "text.badge.checkmark" }
        if type.contains("pdf") { return "doc.text" }
        if type.contains("transcri") { return "waveform" }
        return "book"
    }

    private var durationLabel: String? {
        guard let duration = session.duration, duration > 0 else { return nil }
        let minutes = duration / 60
        if minutes < 1 { return String(localized: "<1 min") }
        return String(localized: "\(minutes) min")
    }

    private var accuracyLabel: String? {
        guard let accuracy = session.accuracy, accuracy > 0 else { return nil }
        return "\(Int(accuracy * 100))%"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(VitaColors.accent.opacity(0.08))
                    .frame(width: 30, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                VitaColors.accent.opacity(0.06),
                                lineWidth: 1
                            )
                    )
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.60))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(VitaTypography.bodyMedium)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let discipline = session.discipline {
                        Text(discipline)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textTertiary)
                    }

                    if let label = durationLabel {
                        Text(label)
                            .font(VitaTypography.labelSmall)
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                }
            }

            Spacer()

            if let label = accuracyLabel {
                Text(label)
                    .font(VitaTypography.labelMedium)
                    .foregroundStyle(VitaColors.dataGreen)
            }

            Text(EstudosV2RelativeTime.format(from: session.createdAt))
                .font(VitaTypography.labelSmall)
                .foregroundStyle(VitaColors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.surfaceBorder, lineWidth: 1)
        )
    }
}

// MARK: - Empty Row

private struct EstudosV2EmptyRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(VitaColors.textTertiary)

            Text(text)
                .font(VitaTypography.bodySmall)
                .foregroundStyle(VitaColors.textSecondary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.02))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.surfaceBorder, lineWidth: 1)
        )
    }
}

// MARK: - Relative Time Formatter

private enum EstudosV2RelativeTime {
    static func format(from isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }
        guard let date else { return "" }

        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return String(localized: "Agora") }
        if interval < 3600 {
            return String(localized: "\(Int(interval / 60))min")
        }
        if interval < 86400 {
            return String(localized: "\(Int(interval / 3600))h")
        }
        if interval < 172800 { return String(localized: "Ontem") }
        return String(localized: "\(Int(interval / 86400))d")
    }
}
