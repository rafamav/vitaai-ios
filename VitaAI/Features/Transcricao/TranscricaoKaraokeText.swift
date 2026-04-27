import SwiftUI

/// Displays transcript text with word-level karaoke highlighting synced to audio playback,
/// plus professor signal highlights for important keywords.
struct TranscricaoKaraokeText: View {
    let words: [WhisperWord]
    let signals: [ProfessorSignals.Signal]
    let activeWordIndex: Int?
    let isPlaying: Bool
    let onTapWord: (Int) -> Void

    /// Full plain text reconstructed from words
    private var fullText: String {
        words.map(\.word).joined(separator: " ")
    }

    var body: some View {
        // Use FlowLayout-style word wrapping
        WrappingHStack(words: words, signals: signals, activeWordIndex: activeWordIndex, isPlaying: isPlaying, onTapWord: onTapWord)
    }
}

// MARK: - Wrapping word layout

private struct WrappingHStack: View {
    let words: [WhisperWord]
    let signals: [ProfessorSignals.Signal]
    let activeWordIndex: Int?
    let isPlaying: Bool
    let onTapWord: (Int) -> Void

    // Precompute which word indices have professor signals
    private var signalIndices: Set<Int> {
        guard !signals.isEmpty else { return [] }
        let fullText = words.map(\.word).joined(separator: " ")
        let lowerFull = fullText.lowercased()
        var indices = Set<Int>()

        for signal in signals {
            // Find which words overlap this signal's text range
            var charPos = 0
            for (i, word) in words.enumerated() {
                let wordStart = charPos
                let wordEnd = charPos + word.word.count
                let lowerWord = fullText[fullText.index(fullText.startIndex, offsetBy: wordStart)..<fullText.index(fullText.startIndex, offsetBy: min(wordEnd, fullText.count))]
                _ = lowerWord // just for bounds

                // Check if this word's position overlaps with any signal keyword
                let signalStart = lowerFull.distance(from: lowerFull.startIndex, to: signal.range.lowerBound)
                let signalEnd = lowerFull.distance(from: lowerFull.startIndex, to: signal.range.upperBound)

                if wordStart < signalEnd && wordEnd > signalStart {
                    indices.insert(i)
                }
                charPos = wordEnd + 1 // +1 for space
            }
        }
        return indices
    }

    var body: some View {
        // Use Text concatenation for proper word wrapping
        words.enumerated().reduce(Text("")) { result, pair in
            let (index, word) = pair
            let isActive = index == activeWordIndex && isPlaying
            let isPassed = isPlaying && activeWordIndex != nil && index < (activeWordIndex ?? 0)
            let isSignal = signalIndices.contains(index)

            let separator = index == 0 ? Text("") : Text(" ")

            var wordText = Text(word.word)
                .font(.system(size: 13))

            if isActive {
                // Current word — gold highlight
                wordText = wordText
                    .foregroundColor(VitaColors.accentLight)
                    .bold()
            } else if isPassed {
                // Already spoken — slightly brighter
                wordText = wordText
                    .foregroundColor(Color.white.opacity(0.70))
            } else {
                // Not yet spoken
                wordText = wordText
                    .foregroundColor(Color.white.opacity(0.45))
            }

            if isSignal {
                // Professor signal — colored underline effect via background
                wordText = wordText
                    .foregroundColor(signalColor(for: index))
                    .bold()
                    .underline(true, color: signalColor(for: index).opacity(0.5))
            }

            return result + separator + wordText
        }
        .lineSpacing(6)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 12)
        // Suaviza transição entre palavra ativa N e N+1 (antes era hard-cut a cada 50ms,
        // dava sensação de "indo aos saltos"). Easing curto = highlight respira.
        .animation(.easeOut(duration: 0.18), value: activeWordIndex)
    }

    private func signalColor(for wordIndex: Int) -> Color {
        // Find which signal this word belongs to, return its category color
        let fullText = words.map(\.word).joined(separator: " ")
        let lowerFull = fullText.lowercased()
        var charPos = 0
        for (i, word) in words.enumerated() {
            if i == wordIndex {
                for signal in signals {
                    let signalStart = lowerFull.distance(from: lowerFull.startIndex, to: signal.range.lowerBound)
                    let signalEnd = lowerFull.distance(from: lowerFull.startIndex, to: signal.range.upperBound)
                    let wordEnd = charPos + word.word.count
                    if charPos < signalEnd && wordEnd > signalStart {
                        return signal.category.color
                    }
                }
                break
            }
            charPos += word.word.count + 1
        }
        return VitaColors.accentLight
    }
}

// MARK: - Fallback: Plain transcript with professor signal highlights only (no word timestamps)

struct TranscricaoHighlightedText: View {
    let text: String
    let signals: [ProfessorSignals.Signal]

    var body: some View {
        if signals.isEmpty {
            Text(text)
                .font(.system(size: 12))
                .lineSpacing(4)
                .foregroundStyle(Color.white.opacity(0.65))
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 12)
        } else {
            Text(ProfessorSignals.highlightedWithDefault(text, signals: signals))
                .font(.system(size: 12))
                .lineSpacing(4)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard(cornerRadius: 12)
        }
    }
}
