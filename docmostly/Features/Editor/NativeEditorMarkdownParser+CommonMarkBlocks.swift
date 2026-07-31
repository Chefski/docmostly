import Foundation

extension NativeEditorMarkdownParser {
    static func commonMarkBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        indentedCodeBlock(in: lines, startingAt: index) ??
            setextHeadingBlock(in: lines, startingAt: index)
    }

    private static func indentedCodeBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        let trimmedLine = lines[index].trimmingCharacters(in: .whitespaces)
        if isIndentedListItem(trimmedLine) {
            return nil
        }
        guard let firstLine = indentedCodeLine(from: lines[index]) else { return nil }

        var content = [firstLine]
        var currentIndex = lines.index(after: index)
        while currentIndex < lines.endIndex {
            let line = lines[currentIndex]
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                content.append("")
            } else if let codeLine = indentedCodeLine(from: line) {
                content.append(codeLine)
            } else {
                break
            }
            currentIndex = lines.index(after: currentIndex)
        }

        while content.last?.isEmpty == true {
            content.removeLast()
        }
        let block = NativeEditorBlock(
            kind: .codeBlock(language: nil),
            text: AttributedString(content.joined(separator: "\n")),
            alignment: .left
        )
        return (block, currentIndex)
    }

    private static func indentedCodeLine(from line: String) -> String? {
        var columns = 0
        var index = line.startIndex
        while index < line.endIndex, columns < 4 {
            switch line[index] {
            case " ": columns += 1
            case "\t": columns = 4
            default: return nil
            }
            index = line.index(after: index)
        }
        guard columns >= 4 else { return nil }
        return String(line[index...])
    }

    private static func isIndentedListItem(_ line: String) -> Bool {
        guard let kind = inputRule(from: line)?.kind else { return false }
        switch kind {
        case .bulletListItem, .orderedListItem, .taskListItem:
            return true
        default:
            return false
        }
    }

    private static func setextHeadingBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        let underlineIndex = lines.index(after: index)
        let text = lines[index].trimmingCharacters(in: .whitespaces)
        guard underlineIndex < lines.endIndex,
              text.isEmpty == false,
              inputRule(from: text) == nil,
              let level = setextHeadingLevel(from: lines[underlineIndex]) else {
            return nil
        }

        let block = NativeEditorBlock(
            kind: .heading(level: level),
            text: inlineText(from: text),
            alignment: .left
        )
        return (block, lines.index(after: underlineIndex))
    }

    private static func setextHeadingLevel(from line: String) -> Int? {
        let underline = line.trimmingCharacters(in: .whitespaces)
        guard underline.isEmpty == false else { return nil }
        if underline.allSatisfy({ $0 == "=" }) {
            return 1
        }
        if underline.allSatisfy({ $0 == "-" }) {
            return 2
        }
        return nil
    }
}
