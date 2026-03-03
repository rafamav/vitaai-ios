import SwiftUI

// MARK: - VitaMarkdown
//
// Native SwiftUI Markdown renderer using AttributedString (iOS 15+).
// Supports: H1-H3, bold, italic, inline code, code blocks, ordered/unordered lists,
// blockquotes, links, strikethrough, horizontal rules.
// Styled for VitaAI dark theme (cyan accent, glass surfaces).
//
// Android reference: VitaMarkdown.kt (Markwon library — same feature set ported natively).

@MainActor
struct VitaMarkdown: View {
    let content: String

    /// Optional override for text color. Defaults to VitaColors.textPrimary.
    var textColor: Color = VitaColors.textPrimary
    /// Optional base font size. Defaults to 14pt (bodyMedium).
    var fontSize: CGFloat = 14

    var body: some View {
        VitaMarkdownContent(
            content: content,
            textColor: textColor,
            fontSize: fontSize
        )
    }
}

// MARK: - Internal Renderer

/// Parses markdown into block elements and renders each one natively.
@MainActor
private struct VitaMarkdownContent: View {
    let content: String
    let textColor: Color
    let fontSize: CGFloat

    private var blocks: [MarkdownBlock] {
        MarkdownParser.parse(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let text, let level):
            headingView(text: text, level: level)

        case .paragraph(let spans):
            Text(renderSpans(spans, baseSize: fontSize))
                .font(.system(size: fontSize))
                .foregroundStyle(textColor)
                .fixedSize(horizontal: false, vertical: true)

        case .codeBlock(let code, _):
            codeBlockView(code: code)

        case .blockquote(let spans):
            blockquoteView(spans: spans)

        case .unorderedList(let items):
            unorderedListView(items: items)

        case .orderedList(let items):
            orderedListView(items: items)

        case .horizontalRule:
            Rectangle()
                .fill(VitaColors.surfaceBorder)
                .frame(height: 1)
                .padding(.vertical, 4)
        }
    }

    // MARK: Heading

    @ViewBuilder
    private func headingView(text: String, level: Int) -> some View {
        let (size, weight): (CGFloat, Font.Weight) = switch level {
        case 1: (fontSize * 1.6, .bold)
        case 2: (fontSize * 1.4, .semibold)
        default: (fontSize * 1.2, .semibold)
        }

        Text(text)
            .font(.system(size: size, weight: weight))
            .foregroundStyle(VitaColors.accent)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, level == 1 ? 8 : 4)
    }

    // MARK: Code Block

    private func codeBlockView(code: String) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(size: fontSize - 1, weight: .regular, design: .monospaced))
                .foregroundStyle(VitaColors.textPrimary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(VitaColors.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(VitaColors.surfaceBorder, lineWidth: 1)
        )
    }

    // MARK: Blockquote

    private func blockquoteView(spans: [InlineSpan]) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(VitaColors.accent)
                .frame(width: 3)
                .clipShape(Capsule())

            Text(renderSpans(spans, baseSize: fontSize))
                .font(.system(size: fontSize))
                .foregroundStyle(VitaColors.textSecondary)
                .italic()
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    // MARK: Lists

    private func unorderedListView(items: [[InlineSpan]]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, spans in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(VitaColors.textTertiary)
                        .frame(width: 4, height: 4)
                        .padding(.top, fontSize * 0.45)
                    Text(renderSpans(spans, baseSize: fontSize))
                        .font(.system(size: fontSize))
                        .foregroundStyle(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func orderedListView(items: [[InlineSpan]]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, spans in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.system(size: fontSize, weight: .medium))
                        .foregroundStyle(VitaColors.textSecondary)
                        .frame(minWidth: 20, alignment: .trailing)
                    Text(renderSpans(spans, baseSize: fontSize))
                        .font(.system(size: fontSize))
                        .foregroundStyle(textColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: Inline Span Rendering

    /// Converts InlineSpan array to a styled AttributedString.
    private func renderSpans(_ spans: [InlineSpan], baseSize: CGFloat) -> AttributedString {
        var result = AttributedString()
        for span in spans {
            result.append(attributedString(for: span, baseSize: baseSize))
        }
        return result
    }

    private func attributedString(for span: InlineSpan, baseSize: CGFloat) -> AttributedString {
        switch span {
        case .plain(let text):
            return AttributedString(text)

        case .bold(let text):
            var s = AttributedString(text)
            s.font = .system(size: baseSize, weight: .bold)
            s.foregroundColor = Color.white.opacity(0.95)
            return s

        case .italic(let text):
            var s = AttributedString(text)
            s.font = .system(size: baseSize).italic()
            return s

        case .boldItalic(let text):
            var s = AttributedString(text)
            s.font = .system(size: baseSize, weight: .bold).italic()
            s.foregroundColor = Color.white.opacity(0.95)
            return s

        case .inlineCode(let text):
            var s = AttributedString(text)
            s.font = .system(size: baseSize - 1, weight: .regular, design: .monospaced)
            s.foregroundColor = VitaColors.accent
            s.backgroundColor = VitaColors.surfaceElevated
            return s

        case .strikethrough(let text):
            var s = AttributedString(text)
            s.strikethroughStyle = .single
            s.foregroundColor = VitaColors.textSecondary
            return s

        case .link(let text, let url):
            var s = AttributedString(text)
            s.foregroundColor = VitaColors.accent
            s.underlineStyle = .single
            if let u = URL(string: url) {
                s.link = u
            }
            return s
        }
    }
}

// MARK: - Markdown AST

private enum MarkdownBlock {
    case heading(text: String, level: Int)
    case paragraph(spans: [InlineSpan])
    case codeBlock(code: String, language: String?)
    case blockquote(spans: [InlineSpan])
    case unorderedList(items: [[InlineSpan]])
    case orderedList(items: [[InlineSpan]])
    case horizontalRule
}

private enum InlineSpan {
    case plain(String)
    case bold(String)
    case italic(String)
    case boldItalic(String)
    case inlineCode(String)
    case strikethrough(String)
    case link(text: String, url: String)
}

// MARK: - Markdown Parser

/// Line-based Markdown parser. Handles GitHub-Flavored Markdown subset.
private enum MarkdownParser {
    static func parse(_ input: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = input.components(separatedBy: "\n")
        var index = 0

        while index < lines.count {
            let line = lines[index]

            // Fenced code block
            if line.hasPrefix("```") {
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                index += 1
                while index < lines.count && !lines[index].hasPrefix("```") {
                    codeLines.append(lines[index])
                    index += 1
                }
                blocks.append(.codeBlock(code: codeLines.joined(separator: "\n"), language: lang.isEmpty ? nil : lang))
                index += 1
                continue
            }

            // Horizontal rule: ---, ***, ___
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                blocks.append(.horizontalRule)
                index += 1
                continue
            }

            // ATX Heading (# H1, ## H2, ### H3)
            if line.hasPrefix("#") {
                let (level, text) = parseHeading(line)
                if level > 0 {
                    blocks.append(.heading(text: text, level: level))
                    index += 1
                    continue
                }
            }

            // Blockquote
            if line.hasPrefix("> ") || line == ">" {
                var quoteLines: [String] = []
                while index < lines.count && (lines[index].hasPrefix("> ") || lines[index] == ">") {
                    let stripped = lines[index].hasPrefix("> ") ? String(lines[index].dropFirst(2)) : ""
                    quoteLines.append(stripped)
                    index += 1
                }
                let combined = quoteLines.joined(separator: " ")
                blocks.append(.blockquote(spans: parseInline(combined)))
                continue
            }

            // Unordered list
            if isUnorderedListItem(line) {
                var items: [[InlineSpan]] = []
                while index < lines.count && isUnorderedListItem(lines[index]) {
                    let text = String(lines[index].dropFirst(2))
                    items.append(parseInline(text))
                    index += 1
                }
                blocks.append(.unorderedList(items: items))
                continue
            }

            // Ordered list
            if let _ = orderedListText(line) {
                var items: [[InlineSpan]] = []
                while index < lines.count, let text = orderedListText(lines[index]) {
                    items.append(parseInline(text))
                    index += 1
                }
                blocks.append(.orderedList(items: items))
                continue
            }

            // Blank line — skip
            if trimmed.isEmpty {
                index += 1
                continue
            }

            // Paragraph — collect until blank line or block element
            var paraLines: [String] = []
            while index < lines.count {
                let l = lines[index]
                let t = l.trimmingCharacters(in: .whitespaces)
                if t.isEmpty { break }
                if l.hasPrefix("#") || l.hasPrefix("```") || l.hasPrefix("> ") { break }
                if isUnorderedListItem(l) || orderedListText(l) != nil { break }
                paraLines.append(l)
                index += 1
            }
            let combined = paraLines.joined(separator: " ")
            if !combined.isEmpty {
                blocks.append(.paragraph(spans: parseInline(combined)))
            }
        }

        return blocks
    }

    // MARK: Helpers

    private static func parseHeading(_ line: String) -> (Int, String) {
        var level = 0
        var rest = line[line.startIndex...]
        while rest.first == "#" && level < 6 {
            level += 1
            rest = rest.dropFirst()
        }
        guard rest.first == " " || rest.isEmpty else { return (0, line) }
        return (level, String(rest).trimmingCharacters(in: .whitespaces))
    }

    private static func isUnorderedListItem(_ line: String) -> Bool {
        line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ")
    }

    private static func orderedListText(_ line: String) -> String? {
        // Match "1. ", "2. ", etc.
        let pattern = /^(\d+)\.\s+(.+)/
        if let match = try? pattern.wholeMatch(in: line) {
            return String(match.output.2)
        }
        return nil
    }

    // MARK: Inline Parser

    /// Parses a line for bold, italic, inline-code, strikethrough, links.
    static func parseInline(_ text: String) -> [InlineSpan] {
        var spans: [InlineSpan] = []
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            // Link: [text](url)
            if let linkRange = remaining.range(of: "["),
               let labelEnd = remaining[linkRange.upperBound...].range(of: "]("),
               let urlEnd = remaining[labelEnd.upperBound...].range(of: ")") {
                let prefix = String(remaining[..<linkRange.lowerBound])
                if !prefix.isEmpty { spans.append(.plain(prefix)) }
                let labelText = String(remaining[linkRange.upperBound..<labelEnd.lowerBound])
                let urlText = String(remaining[labelEnd.upperBound..<urlEnd.lowerBound])
                spans.append(.link(text: labelText, url: urlText))
                remaining = remaining[urlEnd.upperBound...]
                continue
            }

            // Bold-italic: ***text***
            if remaining.hasPrefix("***"), let end = remaining.dropFirst(3).range(of: "***") {
                let prefix = String(remaining[..<remaining.index(remaining.startIndex, offsetBy: 0)])
                if !prefix.isEmpty { spans.append(.plain(prefix)) }
                let inner = String(remaining[remaining.index(remaining.startIndex, offsetBy: 3)..<end.lowerBound])
                spans.append(.boldItalic(inner))
                remaining = remaining[end.upperBound...]
                continue
            }

            // Bold: **text**
            if remaining.hasPrefix("**"), let end = findClosing(in: remaining.dropFirst(2), marker: "**") {
                let inner = String(remaining.dropFirst(2).prefix(upTo: end))
                spans.append(.bold(inner))
                remaining = remaining.dropFirst(2)[end...].dropFirst(2)
                continue
            }

            // Italic: *text* or _text_
            if remaining.hasPrefix("*"), let end = findClosingChar(in: remaining.dropFirst(1), char: "*") {
                let inner = String(remaining.dropFirst(1).prefix(upTo: end))
                spans.append(.italic(inner))
                remaining = remaining.dropFirst(1)[end...].dropFirst(1)
                continue
            }
            if remaining.hasPrefix("_"), let end = findClosingChar(in: remaining.dropFirst(1), char: "_") {
                let inner = String(remaining.dropFirst(1).prefix(upTo: end))
                spans.append(.italic(inner))
                remaining = remaining.dropFirst(1)[end...].dropFirst(1)
                continue
            }

            // Strikethrough: ~~text~~
            if remaining.hasPrefix("~~"), let end = findClosing(in: remaining.dropFirst(2), marker: "~~") {
                let inner = String(remaining.dropFirst(2).prefix(upTo: end))
                spans.append(.strikethrough(inner))
                remaining = remaining.dropFirst(2)[end...].dropFirst(2)
                continue
            }

            // Inline code: `text`
            if remaining.hasPrefix("`"), let end = findClosingChar(in: remaining.dropFirst(1), char: "`") {
                let inner = String(remaining.dropFirst(1).prefix(upTo: end))
                spans.append(.inlineCode(inner))
                remaining = remaining.dropFirst(1)[end...].dropFirst(1)
                continue
            }

            // Plain character
            spans.append(.plain(String(remaining.removeFirst())))
        }

        // Merge consecutive plain spans for efficiency
        return mergedPlain(spans)
    }

    private static func findClosing(in sub: Substring, marker: String) -> Substring.Index? {
        var idx = sub.startIndex
        while idx < sub.endIndex {
            if sub[idx...].hasPrefix(marker) { return idx }
            idx = sub.index(after: idx)
        }
        return nil
    }

    private static func findClosingChar(in sub: Substring, char: Character) -> Substring.Index? {
        sub.firstIndex(of: char)
    }

    private static func mergedPlain(_ spans: [InlineSpan]) -> [InlineSpan] {
        var result: [InlineSpan] = []
        var buf = ""
        for span in spans {
            if case .plain(let t) = span {
                buf += t
            } else {
                if !buf.isEmpty { result.append(.plain(buf)); buf = "" }
                result.append(span)
            }
        }
        if !buf.isEmpty { result.append(.plain(buf)) }
        return result
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ScrollView {
        VitaMarkdown(content: """
        # Cardiologia
        ## Insuficiência Cardíaca

        A **insuficiência cardíaca** (IC) é uma síndrome clínica causada por _alteração estrutural_ ou funcional do coração.

        ### Diagnóstico

        Critérios de **Framingham** — 2 maiores *ou* 1 maior + 2 menores:

        - Dispneia paroxística noturna
        - Ortopneia
        - Cardiomegalia ao RX

        1. Solicitar BNP ou NT-proBNP
        2. Ecocardiograma transtorácico
        3. Cinecoronariografia se indicado

        > **Lembre-se:** IC com FE preservada (ICFEp) → FE ≥ 50%

        Código de exemplo:
        ```swift
        let ejectionFraction = 0.55
        let diagnosis = ejectionFraction >= 0.50 ? "ICFEp" : "ICFEr"
        ```

        Valor de referência: `BNP > 35 pg/mL` sugere IC.

        Referência: [UpToDate](https://www.uptodate.com)

        ---

        ~~Critério antigo~~ substituído pelos critérios de Framingham.
        """)
        .padding(20)
    }
    .background(VitaColors.surface)
    .preferredColorScheme(.dark)
}
#endif
