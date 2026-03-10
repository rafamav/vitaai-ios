import SwiftUI

// MARK: - SubjectIcons
// Maps discipline names to SF Symbols and colors.
// Mirrors Android subjectIcon() / subjectColor() from Theme.kt.

func subjectIcon(for name: String) -> String {
    let n = name.lowercased()
    switch true {
    case n.contains("farmacologia"):
        return "pills.fill"
    case n.contains("anatomia"):
        return "figure.stand"
    case n.contains("fisiologia"):
        return "heart.text.square.fill"
    case n.contains("bioquimica"), n.contains("bioquímica"):
        return "flask.fill"
    case n.contains("patologia"):
        return "microbe.fill"
    case n.contains("semiologia"):
        return "stethoscope"
    case n.contains("pediatria"):
        return "figure.and.child.holdinghands"
    case n.contains("cirurgia"):
        return "cross.case.fill"
    case n.contains("ginecologia"), n.contains("obstetricia"), n.contains("obstetrícia"):
        return "figure.dress.line.vertical.figure"
    case n.contains("psiquiatria"), n.contains("psicologia"):
        return "brain.head.profile"
    case n.contains("oftalmologia"):
        return "eye.fill"
    case n.contains("dermatologia"):
        return "hand.raised.fill"
    case n.contains("cardiologia"):
        return "heart.fill"
    case n.contains("neurologia"), n.contains("neuro"):
        return "brain"
    case n.contains("radiologia"), n.contains("imagem"):
        return "xray"
    case n.contains("infectologia"), n.contains("parasitologia"):
        return "ladybug.fill"
    case n.contains("imunologia"):
        return "shield.fill"
    case n.contains("emergencia"), n.contains("emergência"), n.contains("urgencia"), n.contains("urgência"):
        return "cross.fill"
    case n.contains("clinica medica"), n.contains("clínica médica"), n.contains("clínica"):
        return "stethoscope"
    case n.contains("familia"), n.contains("família"), n.contains("comunidade"):
        return "person.3.fill"
    case n.contains("legal"), n.contains("etica"), n.contains("ética"), n.contains("deontologia"):
        return "scalemass.fill"
    case n.contains("pesquisa"), n.contains("metodologia"), n.contains("epidemiologia"):
        return "chart.bar.doc.horizontal.fill"
    case n.contains("histologia"), n.contains("embriologia"):
        return "circle.grid.3x3.fill"
    case n.contains("microbiologia"):
        return "microbe.fill"
    case n.contains("genetica"), n.contains("genética"):
        return "staroflife.fill"
    case n.contains("medicina"):
        return "stethoscope"
    default:
        return "book.fill"
    }
}

/// Returns a thematic color for a discipline, cycling through a consistent palette.
/// Mirrors Android subjectColor() from Theme.kt.
func subjectColor(for name: String) -> Color {
    let n = name.lowercased()
    switch true {
    case n.contains("cardiologia"), n.contains("cardio"):
        return VitaColors.dataRed
    case n.contains("neurologia"), n.contains("neuro"), n.contains("psiquiatria"):
        return VitaColors.dataIndigo
    case n.contains("farmacologia"):
        return VitaColors.dataAmber
    case n.contains("fisiologia"), n.contains("bioquimica"), n.contains("bioquímica"):
        return Color(red: 0.40, green: 0.80, blue: 0.60) // green-teal
    case n.contains("anatomia"), n.contains("histologia"):
        return Color(red: 0.90, green: 0.55, blue: 0.30) // orange
    case n.contains("cirurgia"):
        return Color(red: 0.55, green: 0.35, blue: 0.80) // purple
    case n.contains("pediatria"):
        return Color(red: 0.30, green: 0.75, blue: 0.90) // sky blue
    case n.contains("ginecologia"), n.contains("obstetricia"), n.contains("obstetrícia"):
        return Color(red: 0.95, green: 0.45, blue: 0.70) // pink
    case n.contains("infectologia"), n.contains("parasitologia"), n.contains("microbiologia"):
        return Color(red: 0.60, green: 0.80, blue: 0.20) // lime
    case n.contains("radiologia"), n.contains("imagem"):
        return VitaColors.dataBlue
    case n.contains("imunologia"):
        return Color(red: 0.30, green: 0.65, blue: 0.95) // blue
    default:
        return VitaColors.accent
    }
}

// MARK: - Semester Time Progress

/// Returns how far through the current Brazilian academic semester we are (0.0–1.0).
///
/// 1st period: Feb 10 → Jun 30  (~140 days)
/// 2nd period: Aug 01 → Dec 15  (~137 days)
/// January: pre-semester → 0.0
func semesterTimeProgress() -> Double {
    let cal = Calendar.current
    let now = Date()
    let month = cal.component(.month, from: now)
    let year = cal.component(.year, from: now)

    let (startMonth, startDay, endMonth, endDay): (Int, Int, Int, Int)
    switch month {
    case 2...6:
        (startMonth, startDay, endMonth, endDay) = (2, 10, 6, 30)
    case 7...12:
        (startMonth, startDay, endMonth, endDay) = (8, 1, 12, 15)
    default:
        return 0.0 // January — pre-semester
    }

    var startComps = DateComponents()
    startComps.year = year; startComps.month = startMonth; startComps.day = startDay
    var endComps = DateComponents()
    endComps.year = year; endComps.month = endMonth; endComps.day = endDay

    guard let start = cal.date(from: startComps),
          let end = cal.date(from: endComps) else { return 0.0 }

    let total = end.timeIntervalSince(start)
    guard total > 0 else { return 0.0 }
    let elapsed = now.timeIntervalSince(start)
    return min(max(elapsed / total, 0.0), 1.0)
}
