import SwiftUI

/// Unified rich hero block shared across the StudySuite shells
/// (Questões / Flashcards / Simulados / Transcrição).
///
/// Liquid-glass premium silhouette: dark themed surface + radial glow + soft
/// decorative motif + eyebrow + large primary number + mini stats strip at
/// the bottom. Each tool injects its signature hue via `StudyShellTheme` so
/// the four pages feel connected to their dashboard entry point (brain
/// orange / heart purple / silhouette blue / microphone teal) while sharing
/// one layout, one set of paddings, one set of radii.
///
/// Rafael's ask (2026-04-18): "hero tem que ter bordas e efeitos de luz e
/// profundidade dentro, numero grande, liquid glass premium, cores do item
/// do dashboard correspondente". That is what this component renders.
struct StudyHeroStat: View {
    /// Big headline number (e.g. "174", "85%", "7.4"). Caller formats the unit.
    let primary: String
    /// Small caption under the headline ("cards pra revisar", "acertos", ...)
    let primaryCaption: String
    /// Mini stats shown in a strip along the bottom. 0-3 entries look clean.
    let stats: [Stat]
    /// Optional subtitle shown before the eyebrow label — rarely used.
    var subtitle: String? = nil
    /// Theme that drives hue, surface gradient, motif, eyebrow label.
    /// Defaults to Questões so existing callers don't break mid-refactor.
    var theme: StudyShellTheme = .questoes

    struct Stat: Identifiable {
        let id = UUID()
        let value: String
        let label: String
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 1. Themed surface (dark gradient, hue-family)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.surfaceTop, theme.surfaceBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // 2. Radial accent glow, top-right
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [theme.glow.opacity(0.38), theme.glow.opacity(0.0)],
                        center: .topTrailing,
                        startRadius: 6,
                        endRadius: 260
                    )
                )
                .blendMode(.screen)

            // 3. Decorative motif symbol, top-right — soft, clipped to card
            Image(systemName: theme.motifSymbol)
                .font(.system(size: 110, weight: .light))
                .foregroundStyle(theme.primary.opacity(0.10))
                .rotationEffect(.degrees(-8))
                .offset(x: 30, y: -18)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .allowsHitTesting(false)

            // 4. Content — eyebrow, big number, caption, stats strip
            VStack(alignment: .leading, spacing: 0) {
                eyebrow

                Text(primary)
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [theme.primaryLight, theme.primary],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: theme.primary.opacity(0.45), radius: 16, y: 0)
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                    .tracking(-1.2)
                    .padding(.top, 10)

                Text(primaryCaption)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.62))
                    .padding(.top, 4)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                if !stats.isEmpty {
                    statsStrip
                        .padding(.top, 18)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 22)
        }
        .overlay(alignment: .top) {
            // 5. Inner top highlight line — overhead-light feel
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [theme.primaryLight.opacity(0.30), .clear],
                        startPoint: .top,
                        endPoint: .init(x: 0.5, y: 0.10)
                    )
                )
                .frame(height: 10)
                .padding(.horizontal, 1)
        }
        .overlay(
            // 6. Gradient stroke — liquid glass rim
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            theme.primaryLight.opacity(0.55),
                            theme.primary.opacity(0.10),
                            theme.primaryLight.opacity(0.25),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: theme.primary.opacity(0.28), radius: 22, x: 0, y: 12)
        .shadow(color: .black.opacity(0.45), radius: 14, x: 0, y: 6)
    }

    // MARK: - Eyebrow (dot + uppercased theme label + optional subtitle)

    private var eyebrow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(theme.primary)
                .frame(width: 6, height: 6)
                .shadow(color: theme.primary.opacity(0.6), radius: 4)
            Text((subtitle ?? theme.eyebrow).uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(1.6)
                .foregroundStyle(theme.primaryLight.opacity(0.80))
        }
    }

    // MARK: - Stats strip (bottom row with subtle dividers)

    private var statsStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.element.id) { idx, stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text(stat.value)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(stat.label.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color.white.opacity(0.45))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if idx < stats.count - 1 {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    theme.primaryMuted.opacity(0.0),
                                    theme.primaryMuted.opacity(0.45),
                                    theme.primaryMuted.opacity(0.0),
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 1, height: 28)
                }
            }
        }
    }
}

// MARK: - Subject chip strip (themed selected state)

/// Lightweight row used by `StudySubjectChips` — decoupled from any specific
/// API response (GradeSubject, StudyOverviewSubject, etc.) so the shell only
/// depends on the canonical SOT (AppDataManager.gradesResponse) upstream.
struct StudySubjectChipItem: Identifiable, Hashable {
    let id: String
    let name: String
}

/// Horizontal chip strip for subject selection. Unified across StudySuite.
/// Tapping "Todas" clears the filter (nil selection). The selected chip uses
/// the shell's theme primary so Questões chips read orange, Flashcards
/// purple, etc. — no more gold leaking onto a purple shell.
struct StudySubjectChips: View {
    let subjects: [StudySubjectChipItem]
    @Binding var selectedId: String?
    /// Optional trailing label for the "all" chip. Defaults to "Todas".
    var allLabel: String = "Todas"
    /// Theme drives the selected chip fill + stroke. Defaults to Questões.
    var theme: StudyShellTheme = .questoes

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: allLabel, isSelected: selectedId == nil) {
                    selectedId = nil
                }
                ForEach(subjects) { subject in
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
                .foregroundStyle(
                    isSelected
                        ? Color.white.opacity(0.95)
                        : VitaColors.textSecondary
                )
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [theme.primary, theme.primary.opacity(0.75)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(VitaColors.glassBg)
                    )
                )
                .overlay(
                    Capsule().stroke(
                        isSelected
                            ? theme.primaryLight.opacity(0.70)
                            : VitaColors.glassBorder,
                        lineWidth: 1
                    )
                )
                .shadow(
                    color: isSelected ? theme.primary.opacity(0.35) : .clear,
                    radius: 8, y: 3
                )
        }
        .buttonStyle(.plain)
    }

    /// Shorten long subject names so chips don't blow up the row.
    /// Keeps first two significant words, preserves roman-numeral suffix.
    private func shortLabel(for name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: ",", with: "")
            .split(separator: " ")
            .map(String.init)
        guard cleaned.count > 2 else { return name.capitalized(with: .init(identifier: "pt_BR")) }
        let head = cleaned.prefix(2).joined(separator: " ")
        if let last = cleaned.last, ["I", "II", "III", "IV", "V"].contains(last.uppercased()) {
            return (head + " " + last).capitalized(with: .init(identifier: "pt_BR"))
        }
        return head.capitalized(with: .init(identifier: "pt_BR"))
    }
}
