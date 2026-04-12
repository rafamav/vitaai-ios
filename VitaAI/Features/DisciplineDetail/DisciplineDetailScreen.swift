import SwiftUI

// MARK: - DisciplineDetailScreen
// Real data from API. Hero card follows FaculdadeHomeScreen pattern.
// Background: fundo-dashboard.webp + 0.75 overlay (dark content screen).

struct DisciplineDetailScreen: View {
    let disciplineId: String
    let disciplineName: String

    var onBack: (() -> Void)?
    var onNavigateToFlashcards: ((String) -> Void)?
    var onNavigateToQBank: (() -> Void)?
    var onNavigateToSimulado: (() -> Void)?

    @State private var vm: DisciplineDetailViewModel?
    @Environment(\.appContainer) private var container

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background: fundo-dashboard + dark overlay
            Image("fundo-dashboard")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black.opacity(0.75)
                .ignoresSafeArea()

            if let vm {
                if vm.isLoading {
                    ProgressView()
                        .tint(VitaColors.accent)
                } else {
                    content(vm: vm)
                }
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { onBack?() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VitaColors.accent)
                }
            }
            ToolbarItem(placement: .principal) {
                Text(disciplineName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .lineLimit(1)
            }
        }
        .onAppear {
            if vm == nil {
                vm = DisciplineDetailViewModel(
                    api: container.api,
                    disciplineId: disciplineId,
                    disciplineName: disciplineName
                )
            }
        }
        .task {
            await vm?.load()
        }
    }

    // MARK: - Main content

    @ViewBuilder
    private func content(vm: DisciplineDetailViewModel) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                heroCard(vm: vm)
                gradesTable(vm: vm)
                nextExamSection(vm: vm)
                assignmentsSection(vm: vm)
                studySuggestionsSection(vm: vm)
                documentsSection(vm: vm)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Hero Card

    private func heroCard(vm: DisciplineDetailViewModel) -> some View {
        ZStack(alignment: .topLeading) {
            // Layer 1: Dark warm gradient base
            LinearGradient(
                colors: [
                    Color(red: 0.10, green: 0.07, blue: 0.045),
                    Color(red: 0.05, green: 0.035, blue: 0.022)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Layer 2: Subject-color radial accent (top-trailing)
            RadialGradient(
                colors: [vm.subjectColor.opacity(0.22), Color.clear],
                center: UnitPoint(x: 1.0, y: 0.0),
                startRadius: 0,
                endRadius: 140
            )

            // Layer 3: Decorative book icon
            Image(systemName: "book.fill")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(vm.subjectColor.opacity(0.08))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 14)
                .padding(.trailing, 16)

            // Layer 4: Content
            heroCardContent(vm: vm)
        }
        .frame(height: 162)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            VitaColors.accent.opacity(0.40),
                            VitaColors.accent.opacity(0.10),
                            VitaColors.accent.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.30), radius: 14, y: 6)
    }

    private func heroCardContent(vm: DisciplineDetailViewModel) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                // Eyebrow
                HStack(spacing: 6) {
                    Circle()
                        .fill(VitaColors.accent)
                        .frame(width: 5, height: 5)
                    Text(vm.semester.map { "\($0)º SEMESTRE" } ?? "DISCIPLINA")
                        .font(.system(size: 10, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(VitaColors.accent)
                }
                .padding(.bottom, 6)

                // Title
                Text(disciplineName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.white)
                    .kerning(-0.4)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                // Subtitle: professor
                if let prof = vm.professorName {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.75))
                        Text(prof)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                    .padding(.top, 3)
                }

                Spacer(minLength: 0)
            }

            Spacer()

            // VitaScore badge
            vitaScoreBadge(score: vm.vitaScore)
                .padding(.top, 2)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func vitaScoreBadge(score: Int) -> some View {
        let tierColor: Color = {
            if score >= 80 { return VitaTokens.PrimitiveColors.amber400 }
            if score >= 60 { return VitaTokens.PrimitiveColors.green400 }
            if score >= 40 { return VitaTokens.PrimitiveColors.cyan400 }
            return VitaTokens.PrimitiveColors.red400
        }()

        return ZStack {
            Circle()
                .fill(tierColor.opacity(0.15))
                .frame(width: 52, height: 52)
            Circle()
                .stroke(tierColor.opacity(0.50), lineWidth: 1.5)
                .frame(width: 52, height: 52)
            VStack(spacing: 1) {
                Text("\(score)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(tierColor)
                Text("VITA")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(tierColor.opacity(0.80))
            }
        }
    }

    // MARK: - Placeholder sections (future tasks)

    @ViewBuilder
    private func gradesTable(vm: DisciplineDetailViewModel) -> some View {
        EmptyView()
    }

    @ViewBuilder
    private func nextExamSection(vm: DisciplineDetailViewModel) -> some View {
        EmptyView()
    }

    @ViewBuilder
    private func assignmentsSection(vm: DisciplineDetailViewModel) -> some View {
        EmptyView()
    }

    @ViewBuilder
    private func studySuggestionsSection(vm: DisciplineDetailViewModel) -> some View {
        EmptyView()
    }

    @ViewBuilder
    private func documentsSection(vm: DisciplineDetailViewModel) -> some View {
        EmptyView()
    }
}
