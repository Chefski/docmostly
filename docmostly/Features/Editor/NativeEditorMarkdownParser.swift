import Foundation

struct NativeEditorMarkdownInputRule: Equatable {
    var kind: NativeEditorBlockKind
    var text: String
}

enum NativeEditorMarkdownParser {
    static func blocks(from markdown: String) -> [NativeEditorBlock] {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [NativeEditorBlock] = []
        var index = lines.startIndex

        while index < lines.endIndex {
            if let fencedCode = fencedCodeBlock(in: lines, startingAt: index) {
                blocks.append(fencedCode.block)
                index = fencedCode.endIndex
                continue
            }

            if let block = block(from: lines[index]) {
                blocks.append(block)
            }
            index = lines.index(after: index)
        }

        return blocks.isEmpty ? [NativeEditorDocument.emptyBlock()] : blocks
    }

    static func inputRule(from text: String) -> NativeEditorMarkdownInputRule? {
        if let codeRule = codeInputRule(from: text) {
            return codeRule
        }

        return lineInputRule(from: text)
    }

    static func markdown(from blocks: [NativeEditorBlock]) -> String {
        blocks.map(markdownLine(from:)).joined(separator: "\n")
    }

    private static func block(from line: String) -> NativeEditorBlock? {
        let indentLevel = listIndentLevel(from: line)
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        guard trimmedLine.isEmpty == false else { return nil }

        if isDivider(trimmedLine) {
            return NativeEditorBlock(kind: .divider, text: AttributedString("Divider"), alignment: .left)
        }

        if let rule = inputRule(from: trimmedLine) {
            return NativeEditorBlock(
                kind: rule.kind,
                text: inlineText(from: rule.text),
                alignment: .left,
                indentLevel: rule.kind.isListItem ? indentLevel : 0
            )
        }

        return NativeEditorBlock(kind: .paragraph, text: inlineText(from: trimmedLine), alignment: .left)
    }

    private static func fencedCodeBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        let line = lines[index].trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix("```") else { return nil }

        let language = String(line.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        var content: [String] = []
        var currentIndex = lines.index(after: index)

        while currentIndex < lines.endIndex {
            let currentLine = lines[currentIndex]
            if currentLine.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                return (
                    codeBlock(language: language, text: content.joined(separator: "\n")),
                    lines.index(after: currentIndex)
                )
            }

            content.append(currentLine)
            currentIndex = lines.index(after: currentIndex)
        }

        return (codeBlock(language: language, text: content.joined(separator: "\n")), currentIndex)
    }

    private static func codeBlock(language: String, text: String) -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .codeBlock(language: language.isEmpty ? nil : language),
            text: AttributedString(text),
            alignment: .left
        )
    }

    private static func codeInputRule(from text: String) -> NativeEditorMarkdownInputRule? {
        guard text.hasPrefix("```") else { return nil }

        let language = String(text.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
        return NativeEditorMarkdownInputRule(kind: .codeBlock(language: language.isEmpty ? nil : language), text: "")
    }

    private static func lineInputRule(from text: String) -> NativeEditorMarkdownInputRule? {
        if let taskRule = taskInputRule(from: text) {
            return taskRule
        }

        if let orderedRule = orderedInputRule(from: text) {
            return orderedRule
        }

        return simpleInputRule(from: text)
    }

    private static func simpleInputRule(from text: String) -> NativeEditorMarkdownInputRule? {
        let rules: [(String, NativeEditorBlockKind)] = [
            ("## ", .heading(level: 2)),
            ("# ", .heading(level: 1)),
            ("- ", .bulletListItem),
            ("* ", .bulletListItem),
            ("> ", .blockquote)
        ]

        guard let rule = rules.first(where: { text.hasPrefix($0.0) }) else { return nil }
        return NativeEditorMarkdownInputRule(kind: rule.1, text: String(text.dropFirst(rule.0.count)))
    }

    private static func taskInputRule(from text: String) -> NativeEditorMarkdownInputRule? {
        let uncheckedPrefixes = ["- [ ] ", "* [ ] ", "[] ", "[ ] "]
        let checkedPrefixes = ["- [x] ", "- [X] ", "* [x] ", "* [X] ", "[x] ", "[X] "]

        if let prefix = uncheckedPrefixes.first(where: { text.hasPrefix($0) }) {
            return NativeEditorMarkdownInputRule(
                kind: .taskListItem(isChecked: false),
                text: String(text.dropFirst(prefix.count))
            )
        }

        guard let prefix = checkedPrefixes.first(where: { text.hasPrefix($0) }) else { return nil }
        return NativeEditorMarkdownInputRule(
            kind: .taskListItem(isChecked: true),
            text: String(text.dropFirst(prefix.count))
        )
    }

    private static func orderedInputRule(from text: String) -> NativeEditorMarkdownInputRule? {
        guard
            let dotIndex = text.firstIndex(of: "."),
            text.distance(from: text.startIndex, to: dotIndex) <= 4
        else {
            return nil
        }

        let numberText = String(text[..<dotIndex])
        let bodyStart = text.index(after: dotIndex)
        guard
            let ordinal = Int(numberText),
            bodyStart < text.endIndex,
            text[bodyStart] == " "
        else {
            return nil
        }

        let contentStart = text.index(after: bodyStart)
        return NativeEditorMarkdownInputRule(
            kind: .orderedListItem(ordinal: ordinal),
            text: String(text[contentStart...])
        )
    }

    private static func inlineText(from markdown: String) -> AttributedString {
        (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }

    private static func markdownLine(from block: NativeEditorBlock) -> String {
        let indent = String(repeating: "  ", count: block.indentLevel)
        let text = String(block.text.characters)

        switch block.kind {
        case .heading(let level):
            return "\(String(repeating: "#", count: max(level, 1))) \(text)"
        case .bulletListItem:
            return "\(indent)- \(text)"
        case .orderedListItem(let ordinal):
            return "\(indent)\(ordinal). \(text)"
        case .taskListItem(let isChecked):
            return "\(indent)- [\(isChecked ? "x" : " ")] \(text)"
        case .blockquote:
            return "> \(text)"
        case .codeBlock(let language):
            return codeMarkdown(language: language, text: text)
        case .divider:
            return "---"
        default:
            return text
        }
    }

    private static func codeMarkdown(language: String?, text: String) -> String {
        """
        ```\(language ?? "")
        \(text)
        ```
        """
    }

    private static func isDivider(_ text: String) -> Bool {
        text == "---" || text == "***"
    }

    private static func listIndentLevel(from line: String) -> Int {
        var columns = 0

        for character in line {
            switch character {
            case " ":
                columns += 1
            case "\t":
                columns += 2
            default:
                return min(columns / 2, 8)
            }
        }

        return min(columns / 2, 8)
    }
}

private extension NativeEditorBlockKind {
    var isListItem: Bool {
        switch self {
        case .bulletListItem, .orderedListItem, .taskListItem:
            true
        default:
            false
        }
    }
}
