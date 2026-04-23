import SwiftUI

// MARK: - DisciplinePicker
//
// Replaces the horizontal scroll of chips (which cut off while scrolling).
// A single compact chip that, on tap, opens a popover with:
//   - "Auto-detectar" (default)
//   - All user disciplines (current + completed)
//   - "Outro..." → inline text field for a custom folder name
//
// Custom names land in `selectedDiscipline` just like any discipline, so
// the recording gets grouped under its own folder in the list view.

struct TranscricaoDisciplinePicker: View {
    @Binding var selected: String
    let disciplines: [String]
    let disabled: Bool

    @State private var isOpen = false
    @State private var showCustomInput = false
    @State private var customName = ""
    @FocusState private var customFocused: Bool

    private let autoLabel = "Auto-detectar"

    var body: some View {
        Button {
            isOpen = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isAuto ? "sparkles" : "folder.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(abbreviateDiscipline(selected.isEmpty ? autoLabel : selected))
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.6)
            }
            .foregroundStyle(VitaColors.accentHover.opacity(0.92))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(VitaColors.accent.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(VitaColors.accent.opacity(0.30), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .popover(isPresented: $isOpen, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
            pickerMenu
                .presentationCompactAdaptation(.popover)
        }
    }

    private var isAuto: Bool {
        selected.isEmpty || selected == autoLabel
    }

    // MARK: - Popover menu

    private var pickerMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            pickerRow(label: autoLabel, icon: "sparkles", value: autoLabel, showCheck: isAuto)

            if !disciplines.isEmpty {
                divider
                Text("MINHAS DISCIPLINAS")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(VitaColors.textWarm.opacity(0.45))
                    .tracking(0.8)
                    .padding(.horizontal, 14)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(disciplines, id: \.self) { d in
                            pickerRow(label: d, icon: "book.closed.fill", value: d, showCheck: selected == d)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            divider

            if showCustomInput {
                customInputRow
            } else {
                Button {
                    showCustomInput = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        customFocused = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(VitaColors.accentHover.opacity(0.8))
                            .frame(width: 20)
                        Text("Outro…")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 260)
        .background(popoverBackground)
    }

    private func pickerRow(label: String, icon: String, value: String, showCheck: Bool) -> some View {
        Button {
            selected = value
            isOpen = false
            showCustomInput = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.accentLight.opacity(0.70))
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 13, weight: showCheck ? .semibold : .regular))
                    .foregroundStyle(Color.white.opacity(showCheck ? 0.95 : 0.80))
                    .lineLimit(1)
                Spacer()
                if showCheck {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(VitaColors.accentHover)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var customInputRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 13))
                .foregroundStyle(VitaColors.accentHover.opacity(0.85))
            TextField("Nome da pasta", text: $customName)
                .focused($customFocused)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.95))
                .onSubmit(applyCustom)
            Button {
                applyCustom()
            } label: {
                Text("OK")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(VitaColors.accentHover)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(VitaColors.accent.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func applyCustom() {
        let trimmed = customName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        selected = trimmed
        customName = ""
        showCustomInput = false
        isOpen = false
    }

    // MARK: - Chrome

    private var divider: some View {
        Rectangle()
            .fill(VitaColors.accent.opacity(0.10))
            .frame(height: 1)
            .padding(.horizontal, 8)
    }

    private var popoverBackground: some View {
        ZStack {
            Color.clear
                .background(.ultraThinMaterial)
            LinearGradient(
                colors: [
                    Color(red: 0.055, green: 0.043, blue: 0.035).opacity(0.92),
                    Color(red: 0.035, green: 0.028, blue: 0.022).opacity(0.96),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            RoundedRectangle(cornerRadius: 0)
                .stroke(VitaColors.accent.opacity(0.18), lineWidth: 0.5)
        }
    }
}

// MARK: - LanguagePicker (native Menu)

struct TranscricaoLanguagePicker: View {
    @Binding var selected: String
    let disabled: Bool

    struct Language: Identifiable, Equatable {
        let code: String
        let label: String
        let flag: String
        var id: String { code }
    }

    static let all: [Language] = [
        .init(code: "pt", label: "Português",  flag: "🇧🇷"),
        .init(code: "en", label: "English",    flag: "🇺🇸"),
        .init(code: "es", label: "Español",    flag: "🇪🇸"),
        .init(code: "fr", label: "Français",   flag: "🇫🇷"),
        .init(code: "de", label: "Deutsch",    flag: "🇩🇪"),
        .init(code: "it", label: "Italiano",   flag: "🇮🇹"),
        .init(code: "la", label: "Latim",      flag: "📜"),
    ]

    private var current: Language {
        Self.all.first { $0.code == selected } ?? Self.all[0]
    }

    var body: some View {
        Menu {
            ForEach(Self.all) { lang in
                Button {
                    selected = lang.code
                } label: {
                    if selected == lang.code {
                        Label("\(lang.flag) \(lang.label)", systemImage: "checkmark")
                    } else {
                        Text("\(lang.flag) \(lang.label)")
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Text(current.flag)
                    .font(.system(size: 12))
                Text(current.code.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(VitaColors.accentHover.opacity(0.88))
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(VitaColors.accent.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.white.opacity(0.05)))
            .overlay(Capsule().stroke(VitaColors.accent.opacity(0.15), lineWidth: 1))
        }
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}

// MARK: - Pause/Resume Button

struct TranscricaoPauseResumeButton: View {
    let isPaused: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(isPaused ? "Retomar" : "Pausar")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(VitaColors.accentHover.opacity(0.88))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(VitaColors.accent.opacity(0.10)))
            .overlay(Capsule().stroke(VitaColors.accent.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shared helpers

/// Shortens long discipline names for the picker chip + row labels.
/// Shared with the filter chips in the recordings list.
func abbreviateDiscipline(_ name: String) -> String {
    let prepositions: Set<String> = ["de", "do", "da", "dos", "das", "em", "e", "a", "o", "na", "no", "para"]

    let words: [String] = name.lowercased().split(separator: " ").compactMap { segment in
        let w = String(segment)
        if prepositions.contains(w) { return nil }
        if w.allSatisfy({ "ivxlcdm".contains($0) }) && !w.isEmpty {
            return w.uppercased()
        }
        return w.prefix(1).uppercased() + w.dropFirst()
    }

    let full = words.joined(separator: " ")
    if full.count <= 18 { return full }

    guard let first = words.first else { return full }
    if words.count == 1 {
        return String(first.prefix(16)) + "."
    }

    var result = first
    if result.count > 12 {
        result = String(first.prefix(4)) + "."
    }

    for i in 1..<words.count {
        let w = words[i]
        let candidate = result + " " + w
        if candidate.count <= 18 {
            result = candidate
        } else if w.count <= 3 && w.allSatisfy({ "IVX".contains($0) }) {
            result += " " + w
        } else {
            break
        }
    }
    return result
}
