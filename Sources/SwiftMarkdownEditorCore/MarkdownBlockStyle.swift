import Foundation

/// Block styles offered by the editor's long-press menu.
public enum MarkdownBlockStyle: String, CaseIterable, Sendable {
    case paragraph, h1, h2, h3, h4, h5, h6, quote, bulletList, numberedList, code

    public var title: String {
        switch self {
        case .paragraph: "正文"
        case .h1: "H1"
        case .h2: "H2"
        case .h3: "H3"
        case .h4: "H4"
        case .h5: "H5"
        case .h6: "H6"
        case .quote: "引用"
        case .bulletList: "无序列表"
        case .numberedList: "有序列表"
        case .code: "代码块"
        }
    }
}

/// A source block, measured in UTF-16 so a hit in UITextView maps directly to it.
public struct MarkdownSourceBlock: Equatable, Sendable {
    public let range: TextSpan
    public let style: MarkdownBlockStyle
}

/// Source-preserving block conversion for a Markdown editor.
///
/// The menu operates on one paragraph, heading, quote, contiguous list, or fenced
/// code block. Inline syntax inside those blocks remains source text. A selection
/// in the middle of a block is never used as the edit range.
public enum MarkdownBlockStyling {
    private struct Line {
        let text: String
        let start: Int
        var end: Int { start + text.utf16.count }
        var isBlank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    public static func block(in source: String, atUTF16Offset offset: Int) -> MarkdownSourceBlock? {
        let lines = split(source)
        guard !lines.isEmpty else { return nil }
        let hit = lines.lastIndex { $0.start <= offset } ?? 0
        // A fence can contain blank lines and Markdown-looking content. Resolve it
        // before classifying individual lines.
        var opening: (index: Int, character: Character, length: Int)?
        for i in lines.indices {
            if let start = opening {
                if isClosingFence(lines[i].text, character: start.character, minimumLength: start.length) {
                    if start.index <= hit && hit <= i {
                        return MarkdownSourceBlock(
                            range: TextSpan(lowerBound: lines[start.index].start, upperBound: lines[i].end),
                            style: .code
                        )
                    }
                    opening = nil
                }
            } else if let fence = fencePrefix(lines[i].text) {
                opening = (i, fence.character, fence.length)
            }
        }
        if let start = opening, hit >= start.index {
            return MarkdownSourceBlock(
                range: TextSpan(lowerBound: lines[start.index].start, upperBound: lines.last!.end),
                style: .code
            )
        }

        guard !lines[hit].isBlank else { return nil }

        let style = kind(of: lines[hit].text)
        var first = hit
        var last = hit
        if style == .paragraph || style == .quote || style == .bulletList || style == .numberedList {
            while first > 0, !lines[first - 1].isBlank, kind(of: lines[first - 1].text) == style { first -= 1 }
            while last + 1 < lines.count, !lines[last + 1].isBlank, kind(of: lines[last + 1].text) == style { last += 1 }
        }
        return MarkdownSourceBlock(
            range: TextSpan(lowerBound: lines[first].start, upperBound: lines[last].end),
            style: style
        )
    }

    /// Returns one native-undo-compatible edit, or nil when the style is unchanged.
    public static func transform(
        _ source: String,
        atUTF16Offset offset: Int,
        to target: MarkdownBlockStyle
    ) -> EditTransform? {
        guard let block = block(in: source, atUTF16Offset: offset), block.style != target else { return nil }
        let original = source.substring(in: block.range)
        var content: [String]
        if block.style == .code {
            var rows = original.components(separatedBy: "\n")
            let opener = rows.first.flatMap(fencePrefix)
            if !rows.isEmpty { rows.removeFirst() }
            if let opener, let last = rows.last,
               isClosingFence(last, character: opener.character, minimumLength: opener.length) {
                rows.removeLast()
            }
            content = rows
        } else {
            content = original.components(separatedBy: "\n").map { stripMarker($0, style: block.style) }
        }

        let replacement: String
        switch target {
        case .paragraph:
            replacement = content.joined(separator: "\n")
        case .h1, .h2, .h3, .h4, .h5, .h6:
            let level = Int(target.rawValue.dropFirst()) ?? 1
            replacement = String(repeating: "#", count: level) + " " + content.joined(separator: " ")
        case .quote:
            replacement = content.map { "> " + $0 }.joined(separator: "\n")
        case .bulletList:
            replacement = content.map { "- " + $0 }.joined(separator: "\n")
        case .numberedList:
            replacement = content.enumerated().map { "\($0.offset + 1). " + $0.element }.joined(separator: "\n")
        case .code:
            let body = content.joined(separator: "\n")
            let fence = String(repeating: "`", count: max(3, longestBacktickRun(in: body) + 1))
            replacement = fence + "\n" + body + "\n" + fence
        }
        let change = TextChange(range: block.range, replacement: replacement)
        return EditTransform(change: change, selection: Selection(caret: block.range.lowerBound + replacement.utf16.count))
    }

    private static func split(_ source: String) -> [Line] {
        var start = 0
        return source.components(separatedBy: "\n").map { text in
            defer { start += text.utf16.count + 1 }
            return Line(text: text, start: start)
        }
    }

    private static func kind(of text: String) -> MarkdownBlockStyle {
        let line = text.trimmingCharacters(in: .whitespaces)
        let hashes = line.prefix { $0 == "#" }.count
        if (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") {
            return MarkdownBlockStyle(rawValue: "h\(hashes)")!
        }
        if line.hasPrefix("> ") || line == ">" { return .quote }
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") { return .bulletList }
        if numberedPrefixLength(line) != nil { return .numberedList }
        return .paragraph
    }

    private static func stripMarker(_ text: String, style: MarkdownBlockStyle) -> String {
        let line = text.trimmingCharacters(in: .whitespaces)
        switch style {
        case .h1, .h2, .h3, .h4, .h5, .h6:
            return String(line.dropFirst(Int(style.rawValue.dropFirst())! + 1))
        case .quote:
            return String(line.dropFirst(line.hasPrefix("> ") ? 2 : 1))
        case .bulletList:
            return String(line.dropFirst(2))
        case .numberedList:
            return String(line.dropFirst(numberedPrefixLength(line) ?? 0))
        default:
            return text
        }
    }

    private static func numberedPrefixLength(_ line: String) -> Int? {
        let digits = line.prefix { $0.isNumber }
        guard !digits.isEmpty else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return digits.count + 2
    }

    private static func fencePrefix(_ line: String) -> (character: Character, length: Int)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard let character = trimmed.first, character == "`" || character == "~" else { return nil }
        let length = trimmed.prefix { $0 == character }.count
        return length >= 3 ? (character, length) : nil
    }

    private static func isClosingFence(_ line: String, character: Character, minimumLength: Int) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let run = trimmed.prefix { $0 == character }.count
        return run >= minimumLength && trimmed.dropFirst(run).isEmpty
    }

    private static func longestBacktickRun(in text: String) -> Int {
        var longest = 0
        var current = 0
        for character in text {
            current = character == "`" ? current + 1 : 0
            longest = max(longest, current)
        }
        return longest
    }
}
