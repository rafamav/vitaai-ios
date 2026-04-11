import SwiftUI

/// Unified hero stat block used at the top of each StudySuite screen
/// (Flashcards, QBank, Simulados, Transcrição).
///
/// Matches the pattern established by QBankHomeContent + SimuladoHomeScreen:
/// big primary number + label on the left, supporting mini-stats on the
/// right, everything wrapped in a gold glass card over the starry
/// `fundo-dashboard` background.
///
/// Rationale: Rafael wants the four screens to look like siblings, not four
/// disconnected features. The rule is "same hero silhouette, different
/// content." If you need a different layout, add a variant here — do NOT
/// fork the component inside a feature folder.
struct StudyHeroStat: View {
    /// Big headline number (e.g. "174", "85%", "7.4"). Accepts any string
    /// so callers can format their own units.
    let primary: String
    /// Small caption under the headline ("cards pra revisar", "acertos", ...)
    let primaryCaption: String
    /// Optional tint for the primary number. Defaults to gold.
    var primaryTint: Color = VitaColors.accentHover
    /// Right-hand mini stats. 0-3 entries render cleanly.
    let stats: [Stat]
    /// Optional subtitle shown above the mini-stats grid ("Atualizado agora").
    var subtitle: String? = nil

    struct Stat: Identifiable {
        let id = UUID()
        let value: String
        let label: String
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Primary headline
            VStack(alignment: .leading, spacing: 4) {
                Text(primary)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTint)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text(primaryCaption)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VitaColors.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Mini stats (right column)
            if !stats.isEmpty {
                VStack(alignment: .trailing, spacing: 8) {
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(VitaColors.textTertiary)
                    }
                    ForEach(stats) { stat in
                        HStack(spacing: 6) {
                            Text(stat.value)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(VitaColors.textPrimary)
                            Text(stat.label)
                                .font(.system(size: 10))
                                .foregroundStyle(VitaColors.textSecondary)
                        }
                    }
                }
                .frame(minWidth: 80, alignment: .trailing)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(VitaColors.glassBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(VitaColors.glassBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 6)
    }
}

/// Horizontal chip strip for subject selection. Unified across StudySuite.
/// Tapping "Todas" clears the filter (nil selection).
struct StudySubjectChips: View {
    let subjects: [StudyOverviewSubject]
    @Binding var selectedId: String?
    /// Optional trailing label for the "all" chip. Defaults to "Todas".
    var allLabel: String = "Todas"

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: allLabel, isSelected: selectedId == nil) {
                    selectedId = nil
                }
                ForEach(subjects, id: \.id) { subject in
                    chip(label: shortLabel(for: subject.name), isSelected: selectedId == subject.id) {
                        selectedId = subject.id
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isSelected ? VitaColors.surface : VitaColors.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? VitaColors.accent : VitaColors.glassBg)
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? VitaColors.accentHover : VitaColors.glassBorder,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    /// Shorten long subject names so chips don't blow up the row.
    /// Keeps first two significant words, strips roman-numeral suffixes only if >14 chars.
    private func shortLabel(for name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: ",", with: "")
            .split(separator: " ")
            .map(String.init)
        guard cleaned.count > 2 else { return name.capitalized(with: .init(identifier: "pt_BR")) }
        let head = cleaned.prefix(2).joined(separator: " ")
        // Preserve roman-numeral suffix if it exists ("I", "II", "III", "IV")
        if let last = cleaned.last, ["I", "II", "III", "IV", "V"].contains(last.uppercased()) {
            return (head + " " + last).capitalized(with: .init(identifier: "pt_BR"))
        }
        return head.capitalized(with: .init(identifier: "pt_BR"))
    }
}
