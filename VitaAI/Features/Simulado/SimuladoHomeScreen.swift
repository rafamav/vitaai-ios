import SwiftUI

// MARK: - Simulado colors (remapped to gold palette, unified with VitaColors)
private enum SimuladoColors {
    static let tealPrimary = VitaColors.accentLight
    static let tealDark = VitaColors.accentDark
    static let sectionLabel = VitaColors.sectionLabel

    static let textPrimary = Color.white.opacity(0.90)
    static let textMuted = VitaColors.textSecondary

    static let cardBorder = VitaColors.surfaceBorder

    static let ctaGradient = LinearGradient(
        colors: [VitaColors.accent.opacity(0.65), VitaColors.accentDark.opacity(0.45)],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )

    static let badgeDoneBg = VitaColors.dataGreen.opacity(0.15)
    static let badgeDoneText = VitaColors.dataGreen.opacity(0.85)
    static let badgeDoneBorder = VitaColors.dataGreen.opacity(0.20)

    static let badgeProgressBg = VitaColors.accent.opacity(0.15)
    static let badgeProgressText = VitaColors.accentLight.opacity(0.85)
    static let badgeProgressBorder = VitaColors.accent.opacity(0.20)
}

// MARK: - SimuladoHomeScreen

struct SimuladoHomeScreen: View {
    @Environment(\.appContainer) private var container
    @State private var vm: SimuladoViewModel?
    let onBack: () -> Void
    let onNewSimulado: () -> Void
    let onOpenSession: (String) -> Void
    let onOpenResult: (String) -> Void
    let onOpenDiagnostics: () -> Void

    var body: some View {
        Group {
            if let vm {
                homeContent(vm: vm)
            } else {
                ZStack {
                    Color.clear.ignoresSafeArea()
                    ProgressView().tint(VitaColors.accent)
                }
            }
        }
        .onAppear {
            if vm == nil { vm = SimuladoViewModel(api: container.api, gamificationEvents: container.gamificationEvents) }
            vm?.loadAttempts()
        }
    }

    @ViewBuilder
    private func homeContent(vm: SimuladoViewModel) -> some View {
        ZStack {
            if vm.state.isLoading {
                ProgressView().tint(SimuladoColors.tealPrimary)
            } else if vm.state.attempts.isEmpty {
                emptyState
            } else {
                scrollContent(vm: vm)
            }
        }
        .navigationBarHidden(true)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(SimuladoColors.tealPrimary.opacity(0.4))
            Text("Nenhum simulado ainda")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(SimuladoColors.textPrimary)
            Text("Comece seu primeiro simulado para testar seus conhecimentos.")
                .font(.system(size: 13))
                .foregroundStyle(SimuladoColors.textMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: onNewSimulado) {
                Text("Começar primeiro simulado")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(SimuladoColors.ctaGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: SimuladoColors.tealDark.opacity(0.25), radius: 12, y: 8)
            }
            .padding(.horizontal, 16)
            Spacer()
        }
    }

    @ViewBuilder
    private func scrollContent(vm: SimuladoViewModel) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Stats hero card
                SimuladoStatsHero(stats: vm.state.stats)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                // CTA button
                Button(action: onNewSimulado) {
                    Text("Novo Simulado")
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .tracking(-0.15)
                        .foregroundStyle(.white.opacity(0.95))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(SimuladoColors.ctaGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(alignment: .top) {
                            // inset 0 1px 0 rgba(120,220,240,0.20) — top inner highlight
                            RoundedRectangle(cornerRadius: 14)
                                .fill(
                                    LinearGradient(
                                        colors: [SimuladoColors.tealPrimary.opacity(0.20), .clear],
                                        startPoint: .top, endPoint: .init(x: 0.5, y: 0.08)
                                    )
                                )
                                .frame(height: 4)
                        }
                        .shadow(color: SimuladoColors.tealDark.opacity(0.25), radius: 12, y: 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                // "RECENTES" section label
                HStack {
                    Text("Recentes")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(SimuladoColors.sectionLabel)
                        .tracking(0.5)
                        .textCase(.uppercase)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                // Attempt cards
                ForEach(vm.state.filteredAttempts) { attempt in
                    SimuladoAttemptCard(attempt: attempt) {
                        if attempt.status == "finished" { onOpenResult(attempt.id) }
                        else { onOpenSession(attempt.id) }
                    }
                    .padding(.horizontal, 16)
                    .contextMenu {
                        Button(role: .destructive) {
                            vm.deleteAttempt(attempt.id)
                        } label: {
                            Label("Apagar", systemImage: "trash")
                        }
                        Button {
                            vm.archiveAttempt(attempt.id)
                        } label: {
                            Label("Arquivar", systemImage: "archivebox")
                        }
                    }
                }

                // Diagnostic link
                Button(action: onOpenDiagnostics) {
                    HStack(spacing: 8) {
                        // 3-bar chart: left short, center tall, right medium (matches web SVG M18 20V10, M12 20V4, M6 20v-6)
                        SimuladoBarChartIcon()
                            .frame(width: 16, height: 16)
                        Text("Ver diagnóstico completo")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    .foregroundStyle(SimuladoColors.tealPrimary.opacity(0.70))
                    .padding(.vertical, 12)
                }
                .padding(.top, 4)
                .padding(.bottom, 120)
            }
        }
    }
}

// MARK: - Stats Hero Card

private struct SimuladoStatsHero: View {
    let stats: SimuladoStats

    private var avgPercent: String {
        let pct = stats.avgScore * 100
        if pct == pct.rounded() {
            return "\(Int(pct))%"
        }
        return String(format: "%.1f%%", pct)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Big score
            Text(avgPercent)
                .font(.system(size: 48, weight: .heavy))
                .tracking(-1.9)
                .foregroundStyle(SimuladoColors.tealPrimary.opacity(0.92))
                .padding(.top, 22)

            Text("Score médio")
                .font(.system(size: 12))
                .foregroundStyle(SimuladoColors.textMuted)
                .tracking(0.5)
                .padding(.top, 4)

            // Stats row
            HStack(spacing: 24) {
                SimuladoMiniStat(value: "\(stats.completedAttempts)", label: "Simulados")
                SimuladoMiniStat(value: "\(stats.totalQuestions)", label: "Questões")
                SimuladoMiniStat(value: "\(stats.totalCorrect)", label: "Acertos")
            }
            .padding(.top, 16)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity)
        .vitaGlassCard(cornerRadius: 18)
    }
}

private struct SimuladoMiniStat: View {
    let value: String
    let label: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.88))
            Text(label)
                .font(.system(size: 9.5, weight: .regular))
                .foregroundStyle(SimuladoColors.textMuted)
                .tracking(0.4)
                .textCase(.uppercase)
        }
    }
}

// MARK: - Attempt Card

private struct SimuladoAttemptCard: View {
    let attempt: SimuladoAttemptEntry
    let onTap: () -> Void

    private var isFinished: Bool { attempt.status == "finished" }
    private var scoreDisplay: String {
        if isFinished {
            return "\(Int(attempt.score * 100))%"
        }
        return "\(attempt.correctQ)/\(attempt.totalQ)"
    }

    private var dateDisplay: String {
        guard let raw = attempt.startedAt, raw.count >= 10 else { return "" }
        let parts = String(raw.prefix(10)).split(separator: "-")
        guard parts.count == 3 else { return "" }
        let months = ["", "jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
        let day = String(parts[2])
        if let monthInt = Int(parts[1]), monthInt > 0, monthInt <= 12 {
            return "\(day) \(months[monthInt])"
        }
        return "\(day)/\(parts[1])"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    SimuladoColors.tealDark.opacity(0.22),
                                    SimuladoColors.tealDark.opacity(0.10)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(SimuladoColors.cardBorder, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 3)

                    Image(systemName: isFinished ? "checkmark.square" : "clock")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(SimuladoColors.tealPrimary.opacity(0.85))
                }
                .frame(width: 40, height: 40)

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(attempt.title.isEmpty ? (attempt.subject ?? "Simulado") : attempt.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(SimuladoColors.textPrimary)
                        .lineLimit(1)
                    Text("\(attempt.totalQ) questões · \(dateDisplay)")
                        .font(.system(size: 10))
                        .foregroundStyle(SimuladoColors.textMuted)
                }

                Spacer(minLength: 4)

                // Score + badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text(scoreDisplay)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(SimuladoColors.tealPrimary.opacity(0.90))

                    Text(isFinished ? "Concluído" : "Em andamento")
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(
                            isFinished ? SimuladoColors.badgeDoneBg : SimuladoColors.badgeProgressBg
                        )
                        .foregroundStyle(
                            isFinished ? SimuladoColors.badgeDoneText : SimuladoColors.badgeProgressText
                        )
                        .overlay(
                            Capsule()
                                .stroke(
                                    isFinished ? SimuladoColors.badgeDoneBorder : SimuladoColors.badgeProgressBorder,
                                    lineWidth: 1
                                )
                        )
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .vitaGlassCard(cornerRadius: 18)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 10)
    }
}

// MARK: - Bar Chart Icon (matches web SVG: left=short, center=tall, right=medium)

private struct SimuladoBarChartIcon: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width
            let h = size.height
            let barW: CGFloat = w * 0.14
            let gap = (w - barW * 3) / 4
            let color = GraphicsContext.Shading.color(SimuladoColors.tealPrimary.opacity(0.85))
            // Left bar: 30% height
            let leftH = h * 0.30
            ctx.fill(Path(CGRect(x: gap, y: h - leftH, width: barW, height: leftH).insetBy(dx: -0.5, dy: 0)), with: color)
            // Center bar: 80% height (tallest)
            let midH = h * 0.80
            ctx.fill(Path(CGRect(x: gap * 2 + barW, y: h - midH, width: barW, height: midH)), with: color)
            // Right bar: 50% height
            let rightH = h * 0.50
            ctx.fill(Path(CGRect(x: gap * 3 + barW * 2, y: h - rightH, width: barW, height: rightH)), with: color)
        }
    }
}

