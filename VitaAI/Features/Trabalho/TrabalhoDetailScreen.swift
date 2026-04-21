import SwiftUI

// MARK: - TrabalhoDetailScreen
// Portal-agnostic assignment detail screen.
// Data comes from academic_evaluations (any portal: Canvas, Mannesoft, etc.)
// Route: trabalhoDetail(id:) — inside shell (topnav + bottomnav + fundo estrelado)

struct TrabalhoDetailScreen: View {
    let assignmentId: String
    var onBack: () -> Void
    var onOpenEditor: (String) -> Void

    @Environment(\.appContainer) private var container
    @State private var item: TrabalhoItem?
    @State private var isLoading = true
    @State private var showEditor = false
    @State private var isGenerating = false
    @State private var cleanDescription: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    ProgressView()
                        .tint(VitaColors.accentHover)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if let item {
                    heroCard(item)
                    deadlineSection(item)
                    descriptionSection(item)
                    actionsSection(item)
                    detailsSection(item)
                } else {
                    VitaEmptyState(
                        title: "Trabalho não encontrado",
                        message: "Este trabalho pode ter sido removido."
                    ) {
                        Image(systemName: "doc.questionmark")
                            .font(.system(size: 32))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.4))
                    }
                    .padding(.top, 40)
                }

                Spacer().frame(height: 130)
            }
            .padding(.horizontal, 16)
        }
        .refreshable { await loadDetail() }
        .task {
            await loadDetail()
            ScreenLoadContext.finish(for: "TrabalhoDetail")
        }
        .trackScreen("TrabalhoDetail", extra: ["assignment_id": assignmentId])
        .fullScreenCover(isPresented: $showEditor) {
            if #available(iOS 17, *) {
                TrabalhoEditorView(
                    assignmentId: assignmentId,
                    templateId: nil,
                    onDismiss: {
                        showEditor = false
                        Task { await loadDetail() }
                    }
                )
            }
        }
    }

    // MARK: - Load

    private func loadDetail() async {
        isLoading = true
        do {
            let response = try await container.api.getTrabalhos()
            let all = response.pending + response.completed + response.overdue
            item = all.first(where: { $0.id == assignmentId })
        } catch {
            print("[TrabalhoDetail] load error: \(error)")
        }
        isLoading = false
    }

    // MARK: - Hero Card

    private func heroCard(_ item: TrabalhoItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status pill
            HStack(spacing: 8) {
                statusPill(item)
                if let types = item.submissionTypes.first, !types.isEmpty {
                    Text(item.submissionTypeLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(VitaColors.textWarm.opacity(0.50))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(VitaColors.glassBg)
                        .clipShape(Capsule())
                }
                Spacer()
            }

            // Title
            Text(item.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.95))
                .fixedSize(horizontal: false, vertical: true)

            // Subject
            if !item.subjectName.isEmpty {
                Text(item.subjectName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.55))
            }

            // Score / Points
            if let pts = item.pointsPossible, pts > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(VitaColors.accent)
                    if let score = item.score {
                        Text("\(String(format: "%.1f", score)) / \(String(format: "%.0f", pts)) pts")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VitaColors.accent)
                    } else {
                        Text("\(String(format: "%.0f", pts)) pts")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [
                            VitaColors.surfaceCard.opacity(0.90),
                            VitaColors.surfaceElevated.opacity(0.85)
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(VitaColors.accentHover.opacity(0.14), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 6)
        .padding(.top, 8)
    }

    // MARK: - Deadline Section

    private func deadlineSection(_ item: TrabalhoItem) -> some View {
        Group {
            if let days = item.daysUntil {
                VStack(spacing: 10) {
                    sectionLabel("Prazo")

                    VitaGlassCard {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                // Countdown
                                VStack(spacing: 2) {
                                    Text(countdownText(days))
                                        .font(.system(size: 22, weight: .bold))
                                        .foregroundStyle(urgencyColor(days))
                                    Text(countdownSubtext(days))
                                        .font(.system(size: 11))
                                        .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                                }
                                .frame(width: 90)

                                // Date
                                VStack(alignment: .leading, spacing: 2) {
                                    if let dateStr = item.date {
                                        Text(formatDate(dateStr))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.white.opacity(0.85))
                                    }
                                    if item.submitted {
                                        HStack(spacing: 4) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 12))
                                                .foregroundStyle(VitaColors.dataGreen)
                                            Text("Entregue")
                                                .font(.system(size: 12))
                                                .foregroundStyle(VitaColors.dataGreen)
                                        }
                                    }
                                }

                                Spacer()
                            }

                            // Progress bar (visual countdown)
                            if days >= 0 && !item.submitted {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(VitaColors.surfaceElevated)
                                            .frame(height: 4)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(urgencyColor(days).opacity(0.8))
                                            .frame(width: geo.size.width * urgencyFraction(days), height: 4)
                                    }
                                }
                                .frame(height: 4)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
    }

    // MARK: - Description Section

    private func descriptionSection(_ item: TrabalhoItem) -> some View {
        Group {
            if item.descriptionHtml != nil || item.description != nil {
                VStack(spacing: 8) {
                    sectionLabel("O que fazer")

                    VitaGlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            // Canvas sends description as raw HTML with inline
                            // styles + data-* attrs. Strip on every branch.
                            let raw = cleanDescription
                                ?? item.descriptionHtml
                                ?? item.description
                                ?? ""
                            let cleaned = stripHtml(raw)
                            if !cleaned.isEmpty {
                                Text(cleaned)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.white.opacity(0.82))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .lineLimit(12)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
    }

    // MARK: - Actions Section

    private func actionsSection(_ item: TrabalhoItem) -> some View {
        VStack(spacing: 8) {
            sectionLabel("Ações")

            // Primary CTA — Vita faz o trabalho
            if !item.submitted {
                Button {
                    showEditor = true
                } label: {
                    HStack(spacing: 10) {
                        Image("vita_btn")
                            .resizable()
                            .frame(width: 24, height: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Vita, faz pra mim")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.white.opacity(0.95))
                            Text("IA gera o trabalho baseado no enunciado")
                                .font(.system(size: 11))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.4))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        VitaColors.accent.opacity(0.12),
                                        VitaColors.accentDark.opacity(0.08)
                                    ],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(VitaColors.accent.opacity(0.20), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            // Secondary — Abrir editor
            if !item.submitted {
                Button {
                    showEditor = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil.line")
                            .font(.system(size: 16))
                            .foregroundStyle(VitaColors.accentLight.opacity(0.65))
                        Text("Escrever manualmente")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.75))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(VitaColors.textWarm.opacity(0.3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(VitaColors.surfaceCard.opacity(0.70))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(VitaColors.glassBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            // Completed state
            if item.submitted {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(VitaColors.dataGreen)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trabalho entregue")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VitaColors.dataGreen)
                        if let at = item.submittedAt {
                            Text("Em \(formatDate(at))")
                                .font(.system(size: 12))
                                .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                        }
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(VitaColors.dataGreen.opacity(0.08))
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(VitaColors.dataGreen.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Details Section

    private func detailsSection(_ item: TrabalhoItem) -> some View {
        VStack(spacing: 8) {
            sectionLabel("Detalhes")

            VitaGlassCard {
                VStack(spacing: 12) {
                    detailRow(icon: "doc.text", label: "Tipo", value: item.type == "exam" ? "Prova" : "Trabalho")
                    detailRow(icon: "arrow.up.doc", label: "Entrega", value: item.submissionTypeLabel)
                    if let grade = item.grade, !grade.isEmpty {
                        detailRow(icon: "graduationcap", label: "Nota", value: grade)
                    }
                    detailRow(icon: "globe", label: "Fonte", value: sourceLabel(item))
                }
                .padding(16)
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textWarm.opacity(0.40))
                .frame(width: 22)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.textWarm.opacity(0.50))
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.80))
        }
    }

    // MARK: - Helpers

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .italic()
            .foregroundStyle(VitaColors.textWarm.opacity(0.50))
            .padding(.top, 22)
            .padding(.bottom, 6)
    }

    private func statusPillData(_ item: TrabalhoItem) -> (String, Color) {
        if item.submitted { return ("ENTREGUE", VitaColors.dataGreen) }
        if let days = item.daysUntil, days < 0 { return ("ATRASADO", VitaColors.dataRed) }
        if item.status == "graded" { return ("CORRIGIDO", VitaColors.accent) }
        return ("PENDENTE", VitaColors.accent)
    }

    private func statusPill(_ item: TrabalhoItem) -> some View {
        let data = statusPillData(item)
        return Text(data.0)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(data.1)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(data.1.opacity(0.12))
            .clipShape(Capsule())
    }

    private func urgencyColor(_ days: Int) -> Color {
        if days < 0 { return VitaColors.dataRed }
        if days <= 1 { return VitaColors.dataRed }
        if days <= 3 { return VitaColors.dataAmber }
        if days <= 7 { return VitaColors.accent }
        return VitaColors.dataGreen
    }

    private func urgencyFraction(_ days: Int) -> Double {
        // 0 days = full bar (urgent), 14+ days = small sliver
        let max = 14.0
        let remaining = min(Double(days), max)
        return 1.0 - (remaining / max)
    }

    private func countdownText(_ days: Int) -> String {
        if days < 0 { return "\(abs(days))d" }
        if days == 0 { return "Hoje" }
        return "\(days)d"
    }

    private func countdownSubtext(_ days: Int) -> String {
        if days < 0 { return "atrasado" }
        if days == 0 { return "vence hoje" }
        if days == 1 { return "amanhã" }
        return "restantes"
    }

    private func formatDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) ?? ISO8601DateFormatter().date(from: iso) else {
            return iso
        }
        let df = DateFormatter()
        df.locale = Locale(identifier: "pt_BR")
        df.dateFormat = "d 'de' MMMM, HH:mm"
        return df.string(from: date)
    }

    private func stripHtml(_ html: String) -> String {
        // Preserve paragraph/line breaks before stripping tags.
        var s = html.replacingOccurrences(of: "(?i)<\\s*br\\s*/?>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)</\\s*p\\s*>", with: "\n\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)</\\s*li\\s*>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "(?i)<\\s*li[^>]*>", with: "• ", options: .regularExpression)
        // Drop all tags (any attributes: data-start, style="...", class="..." etc).
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode common entities.
        let entities: [String: String] = [
            "&nbsp;": " ", "&amp;": "&", "&quot;": "\"", "&apos;": "'",
            "&#39;": "'", "&lt;": "<", "&gt;": ">", "&aacute;": "á",
            "&eacute;": "é", "&iacute;": "í", "&oacute;": "ó", "&uacute;": "ú",
            "&Aacute;": "Á", "&Eacute;": "É", "&ccedil;": "ç", "&Ccedil;": "Ç",
            "&atilde;": "ã", "&otilde;": "õ", "&ntilde;": "ñ", "&hellip;": "…",
            "&ldquo;": "\u{201C}", "&rdquo;": "\u{201D}", "&mdash;": "—", "&ndash;": "–",
        ]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        // Numeric entities &#1234; → char.
        s = s.replacingOccurrences(
            of: "&#([0-9]+);",
            with: "",
            options: .regularExpression
        )
        // Collapse runs of spaces/tabs (but keep newlines).
        s = s.replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
        // Collapse 3+ newlines to 2.
        s = s.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sourceLabel(_ item: TrabalhoItem) -> String {
        if item.canvasAssignmentId != nil { return "Canvas" }
        switch item.type {
        case "exam": return "Portal acadêmico"
        default: return "Portal acadêmico"
        }
    }
}
