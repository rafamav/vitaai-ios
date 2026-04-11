import SwiftUI

// MARK: - ConnectorSyncView
// Shared sync progress view: VitaMascot thinking + animated step rows.
// Used when any portal is syncing (WebAluno, Canvas, future connectors).
// Extracted from CanvasConnectScreen.syncingView — same visual, now generic.

struct ConnectorSyncView: View {
    let connectorName: String
    let steps: [SyncStep]
    var message: String?
    var progress: Double?  // 0-100
    var showRetry: Bool = false
    var errorMessage: String?
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VitaMascot(state: .thinking, size: 100, showStaff: true)
                .padding(.bottom, 24)

            Text(message ?? "Vita conectando ao \(connectorName)...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(VitaColors.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .animation(.easeInOut(duration: 0.3), value: message)

            // Progress bar
            if let progress, progress < 100 {
                ProgressView(value: progress, total: 100)
                    .tint(VitaColors.accent)
                    .padding(.horizontal, 48)
                    .padding(.top, 16)
                    .animation(.easeInOut(duration: 0.5), value: progress)
            }

            // Sync steps
            VStack(alignment: .leading, spacing: 12) {
                ForEach(steps) { step in
                    syncStepRow(step.label, done: step.done, active: step.active)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06), lineWidth: 1))
            )
            .padding(.horizontal, 32)
            .padding(.top, 24)

            // Retry section
            if showRetry {
                VStack(spacing: 12) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(VitaTypography.bodySmall)
                            .foregroundColor(.red.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }

                    VitaButton(
                        text: "Tentar Novamente",
                        action: { onRetry?() },
                        variant: .primary,
                        size: .lg,
                        isEnabled: true,
                        leadingSystemImage: "arrow.clockwise"
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                }
                .padding(.top, 20)
            }

            Spacer()
        }
        .padding(.bottom, 100)
    }

    // MARK: - Step Row

    private func syncStepRow(_ text: String, done: Bool, active: Bool) -> some View {
        HStack(spacing: 10) {
            if done {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(VitaColors.dataGreen)
            } else if active {
                ProgressView()
                    .tint(VitaColors.accent)
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            } else {
                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
            }

            Text(text)
                .font(.system(size: 13, weight: done || active ? .medium : .regular))
                .foregroundColor(done ? .white.opacity(0.7) : active ? .white.opacity(0.9) : .white.opacity(0.3))
        }
    }
}

// MARK: - SyncStep Model

struct SyncStep: Identifiable {
    let id: String
    let label: String
    var done: Bool = false
    var active: Bool = false

    init(_ label: String, done: Bool = false, active: Bool = false) {
        self.id = label
        self.label = label
        self.done = done
        self.active = active
    }
}

// MARK: - Phase ordering helper (moved from deleted CanvasConnectScreen)

extension CanvasSyncOrchestrator.Phase {
    private var order: Int {
        switch self {
        case .starting: return 0
        case .fetchingCourses: return 1
        case .fetchingData: return 2
        case .filteringPDFs: return 3
        case .downloadingPDFs: return 4
        case .uploading: return 5
        case .done: return 6
        case .error: return -1
        }
    }

    func isAfter(_ other: CanvasSyncOrchestrator.Phase) -> Bool {
        order > other.order
    }
}

// MARK: - Preset Steps

extension SyncStep {
    /// Standard steps for WebAluno/Mannesoft sync
    static func webalunoSteps(phase: String) -> [SyncStep] {
        let phases = ["login", "disciplines", "grades", "schedule", "extracting", "done"]
        let phaseIndex = phases.firstIndex(of: phase) ?? 0
        return [
            SyncStep("Login detectado", done: true),
            SyncStep("Buscando disciplinas", done: phaseIndex > 1, active: phaseIndex == 1),
            SyncStep("Buscando notas", done: phaseIndex > 2, active: phaseIndex == 2),
            SyncStep("Buscando horários", done: phaseIndex > 3, active: phaseIndex == 3),
            SyncStep("Extraindo dados", done: phaseIndex > 4, active: phaseIndex == 4),
            SyncStep("Extracao completa", done: phaseIndex >= 5),
        ]
    }

    /// Standard steps for Canvas sync (uses CanvasSyncOrchestrator.Phase)
    static func canvasSteps(phase: CanvasSyncOrchestrator.Phase) -> [SyncStep] {
        [
            SyncStep("Login detectado", done: true),
            SyncStep("Buscando disciplinas",
                     done: phase.isAfter(.fetchingCourses),
                     active: phase == .fetchingCourses),
            SyncStep("Buscando atividades e arquivos",
                     done: phase.isAfter(.fetchingData),
                     active: phase == .fetchingData),
            SyncStep("Identificando planos de ensino",
                     done: phase.isAfter(.filteringPDFs),
                     active: phase == .filteringPDFs),
            SyncStep("Baixando planos de ensino",
                     done: phase.isAfter(.downloadingPDFs),
                     active: phase == .downloadingPDFs),
            SyncStep("Enviando para Vita processar",
                     done: phase.isAfter(.uploading),
                     active: phase == .uploading),
            SyncStep("Extracao completa",
                     done: phase == .done),
        ]
    }
}
