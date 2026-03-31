import SwiftUI

// MARK: - Gold Theme Colors → VitaColors references

private enum GoldAccent {
    static let primary     = VitaColors.accentHover      // rgba(255,200,120)
    static let secondary   = VitaColors.accent           // rgba(200,160,80)
    static let warm        = VitaColors.glassInnerLight  // rgba(200,155,70)
    static let textGold    = VitaColors.accentLight      // rgba(255,220,160)
    static let textGoldDim = VitaColors.textSecondary    // rgba(255,240,215,0.40)
    static let labelGold   = VitaColors.textSecondary    // rgba(255,241,215,0.40)
    static let border      = VitaColors.glassBorder      // rgba(255,200,120,0.14)
    static let amber       = VitaColors.dataAmber        // #f59e0b
}

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
    /// (courseId, colorIndex) — navigates to CourseDetailScreen
    var onNavigateToCourseDetail:      ((String, Int) -> Void)?
    var onNavigateToProvas:            (() -> Void)?
    var onNavigateToQBank:             (() -> Void)?
    var onNavigateToTranscricao:       (() -> Void)?

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
                    onNavigateToTranscricao:      onNavigateToTranscricao
                )
            } else {
                ProgressView()
                    .tint(GoldAccent.primary)
            }
        }
        .vitaScreenBg()
        .onAppear {
            if viewModel == nil {
                viewModel = EstudosViewModel(api: container.api)
                Task { await viewModel?.load() }
            }
        }
    }
}

// MARK: - Content

private struct EstudosContent: View {
    @Bindable var viewModel: EstudosViewModel
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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Continue studying card (API data or mock fallback)
                if let firstRec = viewModel.studyRecommendations.first {
                    ContinueStudyingCard(
                        recommendation: firstRec,
                        onNavigateToFlashcardSession: onNavigateToFlashcardSession
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                } else {
                    MockContinueStudyingHero()
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 12)
                }

                // 3 module cards horizontal
                ModulesRow(
                    onNavigateToQBank: onNavigateToQBank,
                    onNavigateToFlashcardStats: onNavigateToFlashcardStats,
                    onNavigateToSimulados: onNavigateToSimulados
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 14)

                // Suas disciplinas
                EstudosSectionLabel(text: "SUAS DISCIPLINAS")
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                DisciplinesCarousel(
                    courses: viewModel.courses,
                    onCourseClick: onNavigateToCourseDetail
                )
                .padding(.bottom, 16)

                // Vita sugere
                EstudosSectionLabel(text: "VITA SUGERE")
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                if viewModel.studyRecommendations.isEmpty {
                    MockMateriaisScroll()
                        .padding(.bottom, 16)
                } else {
                    MateriaisScroll(recommendations: viewModel.studyRecommendations)
                        .padding(.bottom, 16)
                }

                // Trabalhos pendentes
                EstudosSectionLabel(text: "TRABALHOS PENDENTES")
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                TrabalhosSection()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                // Sessoes recentes
                EstudosSectionLabel(text: "SESSÕES RECENTES")
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 10)

                if viewModel.recentActivity.isEmpty {
                    MockSessoesRecentesSection()
                        .padding(.horizontal, 16)
                } else {
                    SessoesRecentesSection(activities: viewModel.recentActivity)
                        .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 120)
        }
        .refreshable {
            await viewModel.load()
        }
    }
}

// MARK: - Section Label

private struct EstudosSectionLabel: View {
    let text: String

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(VitaColors.sectionLabel)
                .tracking(0.8)
            Spacer()
        }
    }
}

// MARK: - Continue Studying Card (data-driven from API recommendations)

private struct ContinueStudyingCard: View {
    let recommendation: DashboardRecommendation
    let onNavigateToFlashcardSession: ((String) -> Void)?

    /// Discipline label derived from deckId first component (e.g. "histologia-xyz" → "Histologia")
    private var disciplineLabel: String {
        let raw = recommendation.deckId.split(separator: "-").first.map(String.init) ?? ""
        return raw.isEmpty ? "Estudo" : raw.capitalized
    }

    /// Map discipline to hero image asset
    private var heroImageName: String? {
        let d = disciplineLabel.lowercased()
        if d.contains("histolog") { return "hero-histologia" }
        if d.contains("farmac")   { return "hero-farmacologia" }
        if d.contains("anatom")   { return "hero-anatomia" }
        if d.contains("patolog")  { return "hero-patologia" }
        return nil
    }

    var body: some View {
        Button {
            onNavigateToFlashcardSession?(recommendation.deckId)
        } label: {
            ZStack(alignment: .bottom) {
                // Layer 1 — background: hero image or fallback gradient
                if let img = heroImageName, UIImage(named: img) != nil {
                    Image(img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 180)
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 40/255, green: 60/255, blue: 90/255),
                            Color(red: 20/255, green: 35/255, blue: 55/255),
                            Color(red: 10/255, green: 15/255, blue: 30/255)
                        ],
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                    .frame(height: 180)
                }

                // Layer 2 — dark bottom overlay (transparent top → dark bottom)
                LinearGradient(
                    stops: [
                        .init(color: .clear,                                            location: 0.0),
                        .init(color: Color(red: 6/255, green: 4/255, blue: 8/255, opacity: 0.10), location: 0.40),
                        .init(color: Color(red: 6/255, green: 4/255, blue: 8/255, opacity: 0.50), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)

                // Layer 3 — glass panel pinned to bottom
                VStack(alignment: .leading, spacing: 0) {
                    // Badge — discipline name + monitor icon
                    HStack(spacing: 5) {
                        Image(systemName: "display")
                            .font(.system(size: 10))
                        Text(disciplineLabel.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                    }
                    .foregroundStyle(GoldAccent.textGold.opacity(0.80))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(GoldAccent.warm.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(GoldAccent.primary.opacity(0.18), lineWidth: 1)
                    )
                    .padding(.bottom, 10)

                    // Title
                    Text(recommendation.title)
                        .font(.system(size: 17, weight: .bold))
                        .tracking(-0.5)
                        .foregroundStyle(Color.white.opacity(0.96))
                        .lineLimit(2)
                        .padding(.bottom, 3)

                    // Meta
                    Text("\(recommendation.dueCount) pendentes")
                        .font(.system(size: 11))
                        .foregroundStyle(GoldAccent.textGoldDim)
                        .padding(.bottom, 8)

                    // Progress bar row
                    HStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 999)
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 999)
                                    .fill(
                                        LinearGradient(
                                            colors: [GoldAccent.warm.opacity(0.70), GoldAccent.primary.opacity(0.50)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * 0.78, height: 4)
                            }
                        }
                        .frame(height: 4)

                        Text("78%")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(GoldAccent.textGold.opacity(0.70))
                    }
                    .padding(.bottom, 12)

                    // CTA button
                    Text("Continuar")
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.02)
                        .foregroundStyle(GoldAccent.textGold.opacity(0.80))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(GoldAccent.primary.opacity(0.12), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    VitaColors.surfaceCard.opacity(0.80),
                                    VitaColors.surfaceElevated.opacity(0.75)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(GoldAccent.primary.opacity(0.12), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.30), radius: 12, y: 6)
                .padding(10)
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(GoldAccent.primary.opacity(0.16), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.50), radius: 20, y: 10)
            .shadow(color: GoldAccent.warm.opacity(0.07), radius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Continuar estudando \(recommendation.title)")
    }
}

// MARK: - Modules Row (3 horizontal cards with images)

private struct ModulesRow: View {
    let onNavigateToQBank: (() -> Void)?
    let onNavigateToFlashcardStats: (() -> Void)?
    let onNavigateToSimulados: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            ModuleImageCard(
                imageName: "tool-questoes",
                fallbackIcon: "questionmark.circle.fill",
                fallbackLabel: "Questões",
                fallbackColor: VitaColors.dataBlue,
                identifier: "estudos_questoes",
                onTap: { onNavigateToQBank?() }
            )

            ModuleImageCard(
                imageName: "tool-flashcards",
                fallbackIcon: "rectangle.on.rectangle.angled",
                fallbackLabel: "Flashcards",
                fallbackColor: VitaColors.dataIndigo,
                identifier: "estudos_flashcards",
                onTap: { onNavigateToFlashcardStats?() }
            )

            ModuleImageCard(
                imageName: "tool-simulados",
                fallbackIcon: "text.badge.checkmark",
                fallbackLabel: "Simulados",
                fallbackColor: VitaColors.dataGreen,
                identifier: "estudos_simulados",
                onTap: { onNavigateToSimulados?() }
            )
        }
    }
}

private struct ModuleImageCard: View {
    let imageName: String
    let fallbackIcon: String
    let fallbackLabel: String
    let fallbackColor: Color
    var identifier: String? = nil
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            // Try image first, fallback to icon+label glass card
            if UIImage(named: imageName) != nil {
                Color.clear
                    .frame(height: 110)
                    .overlay {
                        Image(imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.30), radius: 6, y: 4)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: fallbackIcon)
                        .font(.system(size: 28))
                        .foregroundStyle(fallbackColor)

                    Text(fallbackLabel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 110)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [
                                    VitaColors.surfaceCard.opacity(0.92),
                                    VitaColors.surfaceElevated.opacity(0.88)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(GoldAccent.border, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.30), radius: 6, y: 4)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityLabel(fallbackLabel)
        .accessibilityIdentifier(identifier ?? "")
    }
}

// MARK: - Disciplines Carousel

private struct DisciplinesCarousel: View {
    let courses: [Course]
    let onCourseClick: ((String, Int) -> Void)?

    // Discipline image names matching the web assets
    private let disciplineImages = [
        "disc-farmacologia", "disc-anatomia", "disc-histologia",
        "disc-bioquimica", "disc-fisiologia-1", "disc-patologia-geral",
        "disc-medicina-legal", "disc-interprofissional"
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                if courses.isEmpty {
                    // Show placeholder discipline thumbnails
                    ForEach(Array(disciplineImages.enumerated()), id: \.offset) { index, name in
                        DisciplineThumbnail(imageName: name, index: index, onTap: nil)
                    }
                } else {
                    ForEach(Array(courses.enumerated()), id: \.element.id) { index, course in
                        let imageName = index < disciplineImages.count ? disciplineImages[index] : disciplineImages[index % disciplineImages.count]
                        DisciplineThumbnail(
                            imageName: imageName,
                            index: index,
                            onTap: { onCourseClick?(course.id, index) }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

private struct DisciplineThumbnail: View {
    let imageName: String
    let index: Int
    let onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            if UIImage(named: imageName) != nil {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.30), radius: 4, y: 2)
            } else {
                // Fallback golden placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                GoldAccent.warm.opacity(0.15),
                                GoldAccent.warm.opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 100, height: 130)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "graduationcap.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(GoldAccent.primary.opacity(0.50))
                            Text("Disc. \(index + 1)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(GoldAccent.textGold.opacity(0.50))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(GoldAccent.border, lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.30), radius: 4, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Materiais Scroll (Vita Sugere — data from API)

private struct MateriaisScroll: View {
    let recommendations: [DashboardRecommendation]

    var body: some View {
        if recommendations.isEmpty {
            // Empty state
            HStack {
                Text("Nenhuma sugestão no momento")
                    .font(.system(size: 12))
                    .foregroundStyle(GoldAccent.textGoldDim)
                Spacer()
            }
            .padding(.horizontal, 16)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(recommendations.enumerated()), id: \.element.deckId) { index, rec in
                        RecommendationCard(recommendation: rec, index: index)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct RecommendationCard: View {
    let recommendation: DashboardRecommendation
    var index: Int = 0

    private var isVideo: Bool { index % 2 == 0 }

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail area — purple for video, gold for PDF
            ZStack {
                if isVideo {
                    Rectangle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    VitaColors.dataIndigo.opacity(0.15),
                                    VitaColors.surface.opacity(0.95)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.10))
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.90))
                    }
                } else {
                    Rectangle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    GoldAccent.warm.opacity(0.12),
                                    VitaColors.surfaceCard.opacity(0.95)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: 60
                            )
                        )
                    Image(systemName: "doc.text")
                        .font(.system(size: 24))
                        .foregroundStyle(GoldAccent.primary.opacity(0.70))
                }
            }
            .frame(height: 80)

            // Text area
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.88))
                    .lineLimit(2)

                Text("\(recommendation.dueCount) cards pendentes")
                    .font(.system(size: 9.5))
                    .foregroundStyle(GoldAccent.textGoldDim.opacity(0.88))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 180)
        .background(
            LinearGradient(
                colors: [
                    VitaColors.surfaceCard.opacity(0.92),
                    VitaColors.surfaceElevated.opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.surfaceBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.30), radius: 8, y: 4)
    }
}

// MARK: - Trabalhos Pendentes Section

private struct TrabalhosItem {
    let icon: String
    let title: String
    let meta: String
    let dueLabel: String
}

private let mockTrabalhos: [TrabalhosItem] = [
    TrabalhosItem(icon: "doc.text",       title: "Relatório Caso Clinico",  meta: "Semiologia · Canvas",              dueLabel: "Sexta"),
    TrabalhosItem(icon: "checkmark.circle", title: "Mapa Mental — Farmaco", meta: "Farmacologia · Entrega individual", dueLabel: "Dom"),
    TrabalhosItem(icon: "person.3",        title: "Seminario em grupo",     meta: "Anatomia · Apresentação",           dueLabel: "Seg"),
]

private struct TrabalhosSection: View {
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(mockTrabalhos.enumerated()), id: \.offset) { _, item in
                TrabalhoCard(item: item)
            }
        }
    }
}

private struct TrabalhoCard: View {
    let item: TrabalhosItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [GoldAccent.warm.opacity(0.25), GoldAccent.warm.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(GoldAccent.primary.opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.30), radius: 4, y: 2)

                Image(systemName: item.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(GoldAccent.textGold.opacity(0.85))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineLimit(1)

                Text(item.meta)
                    .font(.system(size: 10))
                    .foregroundStyle(GoldAccent.textGoldDim.opacity(0.90))
            }

            Spacer()

            Text(item.dueLabel)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(GoldAccent.amber.opacity(0.75))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(GoldAccent.amber.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(GoldAccent.amber.opacity(0.12), lineWidth: 1)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [
                    VitaColors.surfaceCard.opacity(0.93),
                    VitaColors.surfaceElevated.opacity(0.89)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(GoldAccent.primary.opacity(0.12), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.40), radius: 12, y: 4)
    }
}

// MARK: - Sessões Recentes Section (data from API activity feed)

private struct SessoesRecentesSection: View {
    let activities: [ActivityFeedItem]

    var body: some View {
        if activities.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .font(.system(size: 18))
                    .foregroundStyle(GoldAccent.textGoldDim.opacity(0.50))

                Text("Nenhuma sessão recente")
                    .font(.system(size: 12))
                    .foregroundStyle(GoldAccent.textGoldDim)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.02))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(spacing: 6) {
                ForEach(activities) { activity in
                    ActivityCard(activity: activity)
                }
            }
        }
    }
}

private struct ActivityCard: View {
    let activity: ActivityFeedItem

    private var icon: String {
        let a = activity.action.lowercased()
        if a.contains("flashcard") { return "rectangle.on.rectangle.angled" }
        if a.contains("qbank") || a.contains("question") { return "checkmark.square" }
        if a.contains("simulado") { return "text.badge.checkmark" }
        return "display"
    }

    private var displayTitle: String {
        activity.action
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private var timeLabel: String {
        // Parse ISO date and show relative time
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: activity.createdAt) else {
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: activity.createdAt) else { return "" }
            return relativeTime(from: date)
        }
        return relativeTime(from: date)
    }

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "\(Int(interval / 60))min atras" }
        if interval < 86400 { return "\(Int(interval / 3600))h atras" }
        if interval < 172800 { return "Ontem" }
        return "\(Int(interval / 86400)) dias atras"
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(GoldAccent.warm.opacity(0.08))
                    .frame(width: 30, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(GoldAccent.warm.opacity(0.06), lineWidth: 1)
                    )

                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(GoldAccent.textGold.opacity(0.60))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(displayTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))

                if activity.xpAwarded > 0 {
                    Text("+\(activity.xpAwarded) XP")
                        .font(.system(size: 9.5))
                        .foregroundStyle(GoldAccent.textGoldDim.opacity(0.80))
                }
            }

            Spacer()

            Text(timeLabel)
                .font(.system(size: 9.5))
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

// MARK: - Mock Continue Studying Hero (shown when no API data, matches mockup exactly)

private struct MockContinueStudyingHero: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            if UIImage(named: "hero-histologia") != nil {
                Color.clear
                    .frame(height: 180)
                    .overlay {
                        Image("hero-histologia")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
            } else {
                LinearGradient(
                    colors: [VitaColors.surfaceCard, VitaColors.surface],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )
                .frame(height: 180)
            }

            // Dark bottom overlay
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: VitaColors.surface.opacity(0.10), location: 0.40),
                    .init(color: VitaColors.surface.opacity(0.50), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)

            // Glass panel
            VStack(alignment: .leading, spacing: 0) {
                // Badge
                HStack(spacing: 5) {
                    Image(systemName: "display")
                        .font(.system(size: 10))
                    Text("HISTOLOGIA")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(1)
                }
                .foregroundStyle(GoldAccent.textGold.opacity(0.80))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(GoldAccent.warm.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(GoldAccent.primary.opacity(0.18), lineWidth: 1)
                )
                .padding(.bottom, 10)

                // Title
                Text("Tecido Epitelial \u{2014} Revis\u{e3}o")
                    .font(.system(size: 17, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(2)
                    .padding(.bottom, 3)

                // Meta
                Text("32 respondidas \u{b7} 8 restantes")
                    .font(.system(size: 11))
                    .foregroundStyle(GoldAccent.textGoldDim)
                    .padding(.bottom, 8)

                // Progress bar
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 999)
                                .fill(Color.white.opacity(0.06))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 999)
                                .fill(
                                    LinearGradient(
                                        colors: [GoldAccent.warm.opacity(0.70), GoldAccent.primary.opacity(0.50)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * 0.78, height: 4)
                        }
                    }
                    .frame(height: 4)

                    Text("78%")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(GoldAccent.textGold.opacity(0.70))
                }
                .padding(.bottom, 12)

                // CTA
                Text("Continuar")
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.02)
                    .foregroundStyle(GoldAccent.textGold.opacity(0.80))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(GoldAccent.primary.opacity(0.12), lineWidth: 1)
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [
                                VitaColors.surfaceCard.opacity(0.80),
                                VitaColors.surfaceElevated.opacity(0.75)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(GoldAccent.primary.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.30), radius: 12, y: 6)
            .padding(10)
        }
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(GoldAccent.primary.opacity(0.16), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.50), radius: 20, y: 10)
        .shadow(color: GoldAccent.warm.opacity(0.07), radius: 14)
    }
}

// MARK: - Mock Materiais Scroll (Vita Sugere fallback with mockup data)

private struct MockSuggestionItem: Identifiable {
    let id: Int
    let title: String
    let meta: String
    let isVideo: Bool
}

private let mockSuggestionItems: [MockSuggestionItem] = [
    MockSuggestionItem(id: 0, title: "Tecido epitelial \u{2014} aula completa", meta: "YouTube \u{b7} Baseado no seu erro recente", isVideo: true),
    MockSuggestionItem(id: 1, title: "Resumo gerado pelo Vita", meta: "Histologia \u{b7} Pra sua prova de quinta", isVideo: false),
    MockSuggestionItem(id: 2, title: "Farmaco \u{2014} SNA em 8 min", meta: "YouTube \u{b7} Voc\u{ea} errou 5x nesse tema", isVideo: true),
]

private struct MockMateriaisScroll: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(mockSuggestionItems) { item in
                    VStack(spacing: 0) {
                        ZStack {
                            if item.isVideo {
                                Rectangle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                VitaColors.dataIndigo.opacity(0.15),
                                                VitaColors.surface.opacity(0.95)
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 60
                                        )
                                    )
                                ZStack {
                                    Circle()
                                        .fill(Color.white.opacity(0.10))
                                        .frame(width: 28, height: 28)
                                        .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.white.opacity(0.90))
                                }
                            } else {
                                Rectangle()
                                    .fill(
                                        RadialGradient(
                                            colors: [
                                                GoldAccent.warm.opacity(0.12),
                                                VitaColors.surfaceCard.opacity(0.95)
                                            ],
                                            center: .center,
                                            startRadius: 0,
                                            endRadius: 60
                                        )
                                    )
                                Image(systemName: "doc.text")
                                    .font(.system(size: 24))
                                    .foregroundStyle(GoldAccent.primary.opacity(0.70))
                            }
                        }
                        .frame(height: 80)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.88))
                                .lineLimit(2)

                            Text(item.meta)
                                .font(.system(size: 9.5))
                                .foregroundStyle(GoldAccent.textGoldDim.opacity(0.88))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                    .frame(width: 180)
                    .background(
                        LinearGradient(
                            colors: [
                                VitaColors.surfaceCard.opacity(0.92),
                                VitaColors.surfaceElevated.opacity(0.88)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.surfaceBorder, lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.30), radius: 8, y: 4)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Mock Sessoes Recentes (shown when no API activity, matches mockup)

private struct MockSessionItem: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let meta: String
    let time: String
}

private let mockSessionItems: [MockSessionItem] = [
    MockSessionItem(id: 0, icon: "display", title: "Farmacologia \u{b7} Flashcards", meta: "47 respondidas em 15 min", time: "Hoje, 9:30"),
    MockSessionItem(id: 1, icon: "checkmark.square", title: "Anatomia \u{b7} Quest\u{f5}es", meta: "23 quest\u{f5}es \u{b7} 78% acerto", time: "Ontem"),
]

private struct MockSessoesRecentesSection: View {
    var body: some View {
        VStack(spacing: 6) {
            ForEach(mockSessionItems) { session in
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(GoldAccent.warm.opacity(0.08))
                            .frame(width: 30, height: 30)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(GoldAccent.warm.opacity(0.06), lineWidth: 1)
                            )

                        Image(systemName: session.icon)
                            .font(.system(size: 11))
                            .foregroundStyle(GoldAccent.textGold.opacity(0.60))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.85))

                        Text(session.meta)
                            .font(.system(size: 9.5))
                            .foregroundStyle(GoldAccent.textGoldDim.opacity(0.80))
                    }

                    Spacer()

                    Text(session.time)
                        .font(.system(size: 9.5))
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
    }
}
