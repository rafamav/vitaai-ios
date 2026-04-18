import SwiftUI

// MARK: - Home content (mockup-matched: bg-qbank + hero + CTA + chips + sessions + topics)

struct QBankHomeContent: View {
    @Bindable var vm: QBankViewModel
    let onBack: () -> Void

    var body: some View {
        Group {
            if vm.state.progressLoading {
                ProgressView().tint(VitaColors.accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // -- PROGRESS HERO card
                        QBankProgressHero(
                            progress: vm.state.progress,
                            enrolledCount: vm.enrolledDisciplineSlugs.count
                        )
                            .padding(.horizontal, 16)
                            .padding(.top, 8)

                        // -- CTA: Nova Sessão
                        Button {
                            vm.goToDisciplines()
                        } label: {
                            Text("Nova Sess\u{e3}o")
                                .font(.system(size: 15, weight: .bold))
                                .tracking(-0.01 * 15)
                                .foregroundStyle(Color.white.opacity(0.95))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            VitaColors.accent.opacity(0.65),
                                            VitaColors.accentDark.opacity(0.45)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(VitaColors.accentLight.opacity(0.18), lineWidth: 0.5)
                                )
                                .shadow(color: VitaColors.accent.opacity(0.20), radius: 12, y: 4)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        Text("Selecione disciplinas e filtros ao iniciar uma nova sessão.")
                            .font(.system(size: 11))
                            .foregroundStyle(VitaColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        .padding(.top, 16)

                        // -- SESSOES RECENTES
                        QBankSectionLabel(title: "Sess\u{f5}es recentes")
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        if vm.state.recentSessions.isEmpty {
                            QBankInfoCard(
                                icon: "clock",
                                message: "Suas sessões recentes aparecerão aqui."
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(vm.state.recentSessions) { session in
                                    QBankSessionCard(session: session) {
                                        vm.resumeSession(session)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }

                        // -- DESEMPENHO POR TOPICO
                        QBankSectionLabel(title: "Desempenho por t\u{f3}pico")
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        if vm.state.progress.byTopic.isEmpty {
                            QBankInfoCard(
                                icon: "chart.bar",
                                message: "Ainda não recebemos desempenho por tópico para montar este resumo."
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        } else {
                            QBankTopicsCard(topics: Array(vm.state.progress.byTopic.prefix(5)))
                                .padding(.horizontal, 16)
                                .padding(.top, 6)

                            if vm.state.progress.byTopic.count > 5 {
                                Text("e mais \(vm.state.progress.byTopic.count - 5) temas...")
                                    .font(.system(size: 10))
                                    .foregroundStyle(VitaColors.textSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 6)
                            }
                        }

                        if let error = vm.state.error {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.dataRed)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)
                        }

                        Spacer(minLength: 120)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .onAppear {
            vm.loadHomeData()
        }
        .onChange(of: vm.state.progressLoading) { _, loading in
            // After first load completes: if the student has zero enrolled questions
            // AND zero recent sessions, jump straight to Disciplinas so the Home screen
            // never shows a lie like "0 / 95.424".
            guard !loading else { return }
            if vm.state.progress.totalAvailable == 0 && vm.state.recentSessions.isEmpty {
                vm.goToDisciplines()
            }
        }
    }
}

private struct QBankInfoCard: View {
    let icon: String
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(VitaColors.textSecondary)
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(VitaColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(VitaColors.surfaceBorder, lineWidth: 1)
        )
    }
}

// MARK: - QBank Background (bg-qbank fullscreen + dark overlay)

struct QBankBackground: View {
    var body: some View {
        ZStack {
            VitaColors.surface

            Image("bg-qbank")
                .resizable()
                .aspectRatio(contentMode: .fill)

            // Dark gradient overlay
            LinearGradient(
                stops: [
                    .init(color: VitaColors.surface.opacity(0.15), location: 0),
                    .init(color: VitaColors.surface.opacity(0.15), location: 0.40),
                    .init(color: VitaColors.surface.opacity(0.55), location: 1.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Progress Hero (Faculdade pattern — dark gradient + gold radial + motif + stats strip)

struct QBankProgressHero: View {
    let progress: QBankProgressResponse
    let enrolledCount: Int

    private var goldPrimary: Color { VitaColors.accentHover }
    private var goldMuted: Color { VitaColors.accentLight }

    var body: some View {
        ZStack(alignment: .topLeading) {
            heroSolidBackground
            heroGoldAccent
            heroQuestionMotif
            heroContent
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

    private var heroSolidBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.07, blue: 0.045),
                Color(red: 0.05, green: 0.035, blue: 0.022)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var heroGoldAccent: some View {
        RadialGradient(
            colors: [goldPrimary.opacity(0.22), Color.clear],
            center: UnitPoint(x: 1.0, y: 0.0),
            startRadius: 0,
            endRadius: 140
        )
    }

    private var heroQuestionMotif: some View {
        Image(systemName: "questionmark.square.fill")
            .font(.system(size: 64, weight: .ultraLight))
            .foregroundStyle(goldPrimary.opacity(0.08))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .padding(.top, 14)
            .padding(.trailing, 16)
    }

    private var heroContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Zona 1: eyebrow
            HStack(spacing: 6) {
                Circle()
                    .fill(goldPrimary)
                    .frame(width: 5, height: 5)
                Text("SUAS DISCIPLINAS")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(goldPrimary)
            }
            .padding(.bottom, 6)

            // Zona 2: big number (enrolled-scoped total)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(formatNumber(progress.totalAnswered))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.white)
                    .kerning(-0.4)
                    .monospacedDigit()
                Text("/ \(formatNumber(progress.totalAvailable))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.55))
                    .monospacedDigit()
            }

            HStack(spacing: 6) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(goldMuted.opacity(0.75))
                Text("quest\u{f5}es das suas mat\u{e9}rias")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
            .padding(.top, 3)

            Spacer(minLength: 0)

            // Zona 3: stats strip
            heroStatsStrip
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var heroStatsStrip: some View {
        HStack(spacing: 14) {
            heroStat(label: "Disciplinas", value: "\(enrolledCount)")
            heroStatDivider
            heroStat(label: "Respondidas", value: formatNumber(progress.totalAnswered))
            heroStatDivider
            heroStat(label: "Acerto", value: "\(Int(progress.normalizedAccuracy * 100))%")
            Spacer()
        }
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

    private func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pt_BR")
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Filter Chip (matches .chip CSS)

struct QBankFilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    isActive
                        ? VitaColors.accentLight.opacity(0.92)
                        : VitaColors.textWarm.opacity(0.55)
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    isActive
                        ? LinearGradient(
                            colors: [
                                VitaColors.accent.opacity(0.20),
                                VitaColors.accentDark.opacity(0.10)
                            ],
                            startPoint: .top, endPoint: .bottom
                          )
                        : LinearGradient(
                            colors: [
                                VitaColors.textWarm.opacity(0.05),
                                VitaColors.textWarm.opacity(0.02)
                            ],
                            startPoint: .top, endPoint: .bottom
                          )
                )
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(
                        isActive
                            ? VitaColors.accentHover.opacity(0.28)
                            : VitaColors.accentLight.opacity(0.10),
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Label (uppercase, matches .section-label CSS)

struct QBankSectionLabel: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 13, weight: .bold))
            .tracking(0.5)
            .foregroundStyle(VitaColors.sectionLabel)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Session Card (matches .glass-card.session-card CSS)

struct QBankSessionCard: View {
    let session: QBankSessionSummary
    let action: () -> Void

    private var pct: Int {
        guard !session.isActive, session.totalQuestions > 0 else { return 0 }
        return Int(Double(session.correctCount) / Double(session.totalQuestions) * 100)
    }

    private var displayTitle: String {
        if let t = session.title, !t.isEmpty { return t }
        if let first = session.disciplineTitles?.first, !first.isEmpty {
            let count = session.disciplineTitles?.count ?? 1
            return count > 1 ? "\(first) +\(count - 1)" : first
        }
        return "Sess\u{e3}o de \(session.totalQuestions) quest\u{f5}es"
    }

    private var metaText: String {
        let when = Self.formatRelative(session.createdAt)
        if session.isActive {
            return "\(session.currentIndex)/\(session.totalQuestions) \u{b7} \(when)"
        }
        return "\(session.correctCount)/\(session.totalQuestions) \u{b7} \(pct)% \u{b7} \(when)"
    }

    var body: some View {
        Button(action: action) {
            VitaGlassCard(cornerRadius: 18) {
                HStack(spacing: 12) {
                    // Session icon (matches .session-icon CSS)
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        VitaColors.glassInnerLight.opacity(0.22),
                                        VitaColors.accentDark.opacity(0.10)
                                    ],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VitaColors.accentHover.opacity(0.14), lineWidth: 1)
                        Image(systemName: session.isActive ? "clock" : "checkmark.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.85))
                    }
                    .frame(width: 40, height: 40)

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayTitle)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.90))
                            .lineLimit(1)
                        Text(metaText)
                            .font(.system(size: 10))
                            .foregroundStyle(VitaColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Accuracy % (only for finished sessions)
                    if !session.isActive {
                        Text("\(pct)%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.90))
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VitaColors.textSecondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date formatting (pt_BR)

    private static let iso8601WithFrac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd MMM HH:mm"
        return f
    }()

    static func formatRelative(_ raw: String, now: Date = Date(), calendar: Calendar = Calendar(identifier: .gregorian)) -> String {
        guard !raw.isEmpty else { return "" }
        let date = iso8601WithFrac.date(from: raw) ?? iso8601.date(from: raw)
        guard let date else { return "" }
        var cal = calendar
        cal.locale = Locale(identifier: "pt_BR")
        cal.timeZone = TimeZone.current
        let today = cal.startOfDay(for: now)
        let sessionDay = cal.startOfDay(for: date)
        if let diff = cal.dateComponents([.day], from: sessionDay, to: today).day {
            if diff == 0 { return "hoje \(timeFormatter.string(from: date))" }
            if diff == 1 { return "ontem \(timeFormatter.string(from: date))" }
        }
        return shortDateFormatter.string(from: date)
    }
}

// MARK: - Topics Card (matches .glass-card with .topic-row CSS)

struct QBankTopicsCard: View {
    let topics: [QBankProgressByTopic]

    var body: some View {
        VitaGlassCard(cornerRadius: 18) {
            VStack(spacing: 0) {
                ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                    let pct = Int((topic.accuracy > 1.0 ? topic.accuracy : topic.accuracy * 100))
                    if index > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.04))
                            .frame(height: 1)
                    }
                    HStack(spacing: 10) {
                        Text(topic.topicTitle)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Horizontal bar (80px)
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 99)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 80, height: 4)
                            RoundedRectangle(cornerRadius: 99)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            VitaColors.accent.opacity(0.6),
                                            VitaColors.accentHover.opacity(0.8)
                                        ],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: max(80 * CGFloat(topic.accuracy).clamped(to: 0...1), 2), height: 4)
                        }

                        Text("\(pct)%")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.70))
                            .frame(width: 32, alignment: .trailing)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Empty State

struct QBankEmptyState: View {
    var body: some View {
        VitaGlassCard(cornerRadius: 18) {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    VitaColors.glassInnerLight.opacity(0.22),
                                    VitaColors.accentDark.opacity(0.10)
                                ],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "book")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(VitaColors.accentLight.opacity(0.85))
                }
                .frame(width: 40, height: 40)

                Text("Comece a praticar")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.90))

                Text("Inicie uma sess\u{e3}o de quest\u{f5}es para acompanhar seu desempenho aqui")
                    .font(.system(size: 11))
                    .foregroundStyle(VitaColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(28)
        }
    }
}
