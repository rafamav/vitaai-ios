import SwiftUI

// MARK: - OsceScreen — entry point

struct OsceScreen: View {
    let onBack: () -> Void

    @Environment(\.appContainer) private var container
    @State private var viewModel: OsceViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                OsceContent(viewModel: vm, onBack: onBack)
            } else {
                ProgressView()
                    .tint(VitaColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    VitaToolScreenBg(accent: .teal)
            }
        }
        .onAppear {
            if viewModel == nil {
                let vm = OsceViewModel(api: container.api, sseClient: container.osceSseClient, gamificationEvents: container.gamificationEvents)
                viewModel = vm
                vm.loadSpecialties()
            }
        }
    }
}

// MARK: - Content (phase router)

private struct OsceContent: View {
    @Bindable var viewModel: OsceViewModel
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            OsceTopBar(
                phase: viewModel.phase,
                onBack: onBack,
                onNewCase: viewModel.resetCase
            )

            Group {
                switch viewModel.phase {
                case .selectSpecialty:
                    OsceSpecialtyView(viewModel: viewModel)
                        .transition(.opacity)
                case .caseActive:
                    OsceSessionView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                case .completed:
                    OsceResultView(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.phase)
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Top Bar

private struct OsceTopBar: View {
    let phase: OsceViewModel.OscePhase
    let onBack: () -> Void
    let onNewCase: () -> Void

    var body: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VitaColors.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityIdentifier("backButton")

            Spacer()

            Text("Caso Clínico OSCE")
                .font(VitaTypography.titleMedium)
                .fontWeight(.semibold)
                .foregroundStyle(VitaColors.textPrimary)

            Spacer()

            if phase != .selectSpecialty {
                Button("Novo Caso", action: onNewCase)
                    .font(VitaTypography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.accent)
                    .frame(height: 44)
                    .padding(.trailing, 4)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VitaColors.glassBorder)
                .frame(height: 1)
        }
    }
}

// MARK: - Specialty Selection

private struct OsceSpecialtyView: View {
    @Bindable var viewModel: OsceViewModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Escolha a especialidade")
                        .font(VitaTypography.titleMedium)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)
                    Text("Você receberá um caso clínico com paciente simulado e será avaliado por IA em 5 etapas.")
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // 5-step preview strip
                OsceStepPreviewStrip()
                    .padding(.horizontal, 20)

                if let error = viewModel.error {
                    Text(error)
                        .font(VitaTypography.bodySmall)
                        .foregroundStyle(VitaColors.dataRed)
                        .padding(.horizontal, 20)
                }

                // Specialty grid
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(viewModel.specialties, id: \.self) { specialty in
                        SpecialtyCard(
                            specialty: specialty,
                            isLoading: viewModel.isLoading,
                            onTap: { viewModel.startCase(specialty: specialty) }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
    }
}

private struct OsceStepPreviewStrip: View {
    var body: some View {
        VitaGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("5 etapas de avaliação", systemImage: "list.number")
                    .font(VitaTypography.labelMedium)
                    .fontWeight(.semibold)
                    .foregroundStyle(VitaColors.accent)

                HStack(spacing: 0) {
                    ForEach(Array(OsceViewModel.stepNames.enumerated()), id: \.offset) { idx, name in
                        HStack(spacing: 3) {
                            Text("\(idx + 1)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(VitaColors.surface)
                                .frame(width: 15, height: 15)
                                .background(VitaColors.accent)
                                .clipShape(Circle())
                            Text(name)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(VitaColors.textSecondary)
                                .lineLimit(1)
                            if idx < OsceViewModel.stepNames.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 7))
                                    .foregroundStyle(VitaColors.textTertiary)
                                    .padding(.horizontal, 1)
                            }
                        }
                        if idx < OsceViewModel.stepNames.count - 1 {
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

private struct SpecialtyCard: View {
    let specialty: String
    let isLoading: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: { if !isLoading { onTap() } }) {
            VitaGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(VitaColors.accent.opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: iconForSpecialty(specialty))
                                .font(.system(size: 18))
                                .foregroundStyle(VitaColors.accent)
                        }
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .tint(VitaColors.accent)
                                .scaleEffect(0.75)
                        }
                    }

                    Text(specialty)
                        .font(VitaTypography.labelLarge)
                        .fontWeight(.semibold)
                        .foregroundStyle(VitaColors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    private func iconForSpecialty(_ s: String) -> String {
        switch s {
        case "Cardiologia":    return "heart.fill"
        case "Pediatria":      return "figure.child"
        case "Ginecologia":    return "cross.case.fill"
        case "Cirurgia Geral": return "scissors"
        case "Clínica Médica": return "stethoscope"
        case "Emergência":     return "staroflife.fill"
        case "Neurologia":     return "brain.head.profile"
        case "Ortopedia":      return "figure.walk"
        default:               return "cross.fill"
        }
    }
}
