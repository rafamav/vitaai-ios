import SwiftUI

/// Detects and highlights "professor signals" — phrases that indicate
/// content is important for exams (e.g., "cai na prova", "anotem isso").
enum ProfessorSignals {

    /// A detected signal in the transcript text
    struct Signal: Identifiable {
        let id = UUID()
        let range: Range<String.Index>
        let keyword: String
        let category: Category
    }

    enum Category {
        case examDirect    // "cai na prova", "questão de prova"
        case attention     // "prestem atenção", "anotem isso"
        case emphasis      // "muito importante", "fundamental"
        case memorize      // "memorizar", "decorar"
        case searchMatch   // busca do usuário

        var icon: String {
            switch self {
            case .examDirect: return "exclamationmark.triangle.fill"
            case .attention: return "eye.fill"
            case .emphasis: return "star.fill"
            case .memorize: return "brain.head.profile"            case .searchMatch: return "magnifyingglass"
            }
        }

        var color: Color {
            switch self {
            case .examDirect: return VitaColors.dataRed
            case .attention: return VitaColors.accentLight
            case .emphasis: return Color(red: 1.0, green: 0.85, blue: 0.3)
            case .memorize: return VitaColors.dataIndigo            case .searchMatch: return VitaColors.accent
            }
        }
    }

    // Ordered by specificity (longer phrases first to avoid partial matches)
    private static let patterns: [(String, Category)] = [
        // Exam direct (longer phrases first)
        ("vai cair na prova", .examDirect),
        ("vai cair nessa prova", .examDirect),
        ("cair na prova", .examDirect),
        ("cair nessa prova", .examDirect),
        ("cai na prova", .examDirect),
        ("cai nessa prova", .examDirect),
        ("questão de prova", .examDirect),
        ("tema de prova", .examDirect),
        ("vou cobrar", .examDirect),
        ("vou perguntar", .examDirect),
        ("isso cai", .examDirect),
        ("pode cair", .examDirect),
        ("cobrado em prova", .examDirect),
        ("matéria de prova", .examDirect),
        ("fiz ainda a prova", .examDirect),
        // Attention (longer phrases first)
        ("prestem atenção", .attention),
        ("presta atenção", .attention),
        ("presto atenção", .attention),
        ("prestar atenção", .attention),
        ("anotem isso", .attention),
        ("anota isso", .attention),
        ("anota aí", .attention),
        ("anotem aí", .attention),
        ("não esqueçam", .attention),
        ("não esquece", .attention),
        ("não se assustem", .attention),
        ("não se esqueçam", .attention),
        ("olha só", .attention),
        ("revisem isso", .attention),
        ("revisa isso", .attention),
        ("lembrem disso", .attention),
        ("guardem isso", .attention),
        ("estudem bem", .attention),
        // Emphasis (longer phrases first)
        ("extremamente importante", .emphasis),
        ("muito importante", .emphasis),
        ("super importante", .emphasis),
        ("bastante conteúdo", .emphasis),
        ("importante", .emphasis),
        ("fundamental", .emphasis),
        ("essencial", .emphasis),
        ("crítico", .emphasis),
        ("ponto chave", .emphasis),
        ("conceito chave", .emphasis),
        ("palavra chave", .emphasis),
        ("chave", .emphasis),
        // Memorize
        ("gravar na cabeça", .memorize),
        ("memorizar", .memorize),
        ("decorar", .memorize),
        ("decorem", .memorize),
        ("memorizem", .memorize),
    ]

    /// Scan text and return all detected professor signals
    static func detect(in text: String) -> [Signal] {
        var signals: [Signal] = []
        var usedRanges: [Range<String.Index>] = []

        for (phrase, category) in patterns {
            var searchStart = text.startIndex
            while let range = text.range(of: phrase, options: .caseInsensitive, range: searchStart..<text.endIndex) {
                let overlaps = usedRanges.contains { $0.overlaps(range) }
                if !overlaps {
                    signals.append(Signal(range: range, keyword: phrase, category: category))
                    usedRanges.append(range)
                }
                searchStart = range.upperBound
            }
        }

        signals.sort { $0.range.lowerBound < $1.range.lowerBound }
        return signals
    }

    /// Build an AttributedString with professor signals highlighted
    static func highlighted(_ text: String, signals: [Signal]) -> AttributedString {
        var attr = AttributedString(text)

        for signal in signals {
            let startOffset = text.distance(from: text.startIndex, to: signal.range.lowerBound)
            let endOffset = text.distance(from: text.startIndex, to: signal.range.upperBound)

            let attrStart = attr.index(attr.startIndex, offsetByCharacters: startOffset)
            let attrEnd = attr.index(attr.startIndex, offsetByCharacters: endOffset)

            attr[attrStart..<attrEnd].foregroundColor = signal.category.color
            attr[attrStart..<attrEnd].font = .system(size: 12, weight: .bold)
            attr[attrStart..<attrEnd].backgroundColor = signal.category.color.opacity(0.12)
        }

        return attr
    }

    /// Build AttributedString with default color + highlighted signals
    /// (use this when NOT applying .foregroundStyle on the Text view)
    static func highlightedWithDefault(_ text: String, signals: [Signal]) -> AttributedString {
        var attr = AttributedString(text)

        // Set default color on entire text
        attr.foregroundColor = Color.white.opacity(0.65)

        for signal in signals {
            let startOffset = text.distance(from: text.startIndex, to: signal.range.lowerBound)
            let endOffset = text.distance(from: text.startIndex, to: signal.range.upperBound)

            let attrStart = attr.index(attr.startIndex, offsetByCharacters: startOffset)
            let attrEnd = attr.index(attr.startIndex, offsetByCharacters: endOffset)

            attr[attrStart..<attrEnd].foregroundColor = signal.category.color
            attr[attrStart..<attrEnd].font = .system(size: 12, weight: .bold)
            attr[attrStart..<attrEnd].backgroundColor = signal.category.color.opacity(0.15)
        }

        return attr
    }
}

// MARK: - Signal Summary Badge

struct ProfessorSignalsSummary: View {
    let signals: [ProfessorSignals.Signal]

    var body: some View {
        if !signals.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(VitaColors.dataRed.opacity(0.9))

                Text("\(signals.count) trecho\(signals.count == 1 ? "" : "s") marcado\(signals.count == 1 ? "" : "s") como importante")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.75))

                Spacer()

                // Category dots
                HStack(spacing: 4) {
                    ForEach(Array(categoryBreakdown), id: \.key.hashValue) { cat, count in
                        HStack(spacing: 2) {
                            Circle()
                                .fill(cat.color)
                                .frame(width: 6, height: 6)
                            Text("\(count)")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(cat.color.opacity(0.8))
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(VitaColors.dataRed.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(VitaColors.dataRed.opacity(0.15), lineWidth: 1)
            )
        }
    }

    private var categoryBreakdown: [(key: ProfessorSignals.Category, value: Int)] {
        var counts: [ProfessorSignals.Category: Int] = [:]
        for s in signals {
            counts[s.category, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }
    }
}

// Make Category hashable for ForEach
extension ProfessorSignals.Category: Hashable {}
