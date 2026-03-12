import SwiftUI

struct UpcomingExamsRow: View {
    let exams: [UpcomingExam]

    var body: some View {
        // Mockup: lista vertical dentro de glass card — .provas style (gap:10px, no dividers)
        VStack(spacing: 0) {
            ForEach(exams) { exam in
                HStack(spacing: 10) {
                    // Subject icon (matches mockup prova-ico with 3D asset)
                    GlassAssetImage(
                        assetName: exam.subjectIconName,
                        fallbackSymbol: "book.fill",
                        size: 38
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(exam.subject)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.75))
                            .lineLimit(1)

                        Text(exam.formattedDate)
                            .font(.system(size: 10.5, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.40))
                    }

                    Spacer()

                    // Badge colorido por urgência — matches mockup .badge.urgent/.warn/.ok
                    ExamUrgencyBadge(daysUntil: exam.daysUntil)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Badge de urgência (matches mockup .badge.urgent/.warn/.ok)
private struct ExamUrgencyBadge: View {
    let daysUntil: Int

    private var label: String {
        "\(daysUntil) \(NSLocalizedString("dias", comment: ""))"
    }

    // Mockup CSS: urgent=rgba(200,120,80,*), warn=rgba(200,160,80,*), ok=rgba(180,160,100,*)
    private var bgColor: Color {
        if daysUntil <= 4 {
            return Color(red: 200/255, green: 120/255, blue: 80/255).opacity(0.15)
        } else if daysUntil <= 10 {
            return Color(red: 200/255, green: 160/255, blue: 80/255).opacity(0.12)
        } else {
            return Color(red: 180/255, green: 160/255, blue: 100/255).opacity(0.10)
        }
    }

    private var textColor: Color {
        if daysUntil <= 4 {
            return Color(red: 220/255, green: 160/255, blue: 120/255).opacity(0.90)
        } else if daysUntil <= 10 {
            return Color(red: 220/255, green: 180/255, blue: 120/255).opacity(0.85)
        } else {
            return Color(red: 200/255, green: 180/255, blue: 130/255).opacity(0.80)
        }
    }

    private var borderColor: Color {
        if daysUntil <= 4 {
            return Color(red: 200/255, green: 120/255, blue: 80/255).opacity(0.12)
        } else if daysUntil <= 10 {
            return Color(red: 200/255, green: 160/255, blue: 80/255).opacity(0.10)
        } else {
            return Color(red: 180/255, green: 160/255, blue: 100/255).opacity(0.08)
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bgColor)
            .overlay(
                Capsule().stroke(borderColor, lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

// MARK: - UpcomingExam helpers
private extension UpcomingExam {
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pt_BR")
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: date).capitalized
    }

    // Map subject name to 3D glass asset (with fallback SF symbol via Image(systemName:))
    var subjectIconName: String {
        let lower = subject.lowercased()
        if lower.contains("anatomia")    { return "glassv2-disc-anatomia-nobg" }
        if lower.contains("fisiologia")  { return "glassv2-disc-fisiologia-1-nobg" }
        if lower.contains("bioquim")     { return "glassv2-disc-bioquimica-nobg" }
        if lower.contains("farmacol")    { return "glassv2-disc-farmacologia-nobg" }
        if lower.contains("patologia")   { return "glassv2-disc-patologia-geral-nobg" }
        if lower.contains("neurologia")  { return "glassv2-disc-neurologia-nobg" }
        if lower.contains("pediatria")   { return "glassv2-disc-pediatria-1-nobg" }
        if lower.contains("cirurgia")    { return "glassv2-disc-cirurgia-1-nobg" }
        if lower.contains("clinica")     { return "glassv2-disc-clinica-medica-1-nobg" }
        if lower.contains("dermat")      { return "glassv2-disc-dermatologia-nobg" }
        if lower.contains("microbi")     { return "glassv2-disc-microbiologia-nobg" }
        if lower.contains("imunol")      { return "glassv2-disc-imunologia-nobg" }
        if lower.contains("histol")      { return "glassv2-disc-histologia-nobg" }
        if lower.contains("genética") || lower.contains("genetica") { return "glassv2-disc-genetica-nobg" }
        if lower.contains("psiquiatria") { return "glassv2-disc-psiquiatria-1-nobg" }
        if lower.contains("radiologia")  { return "glassv2-disc-radiologia-nobg" }
        if lower.contains("ortopedia")   { return "glassv2-disc-ortopedia-nobg" }
        if lower.contains("otorrin")     { return "glassv2-disc-otorrino-nobg" }
        if lower.contains("oftalmo")     { return "glassv2-disc-oftalmologia-nobg" }
        if lower.contains("semiolog")    { return "glassv2-disc-semiologia-nobg" }
        return "glassv2-exam-paper-nobg"
    }
}
