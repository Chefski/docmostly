import Foundation

extension NativeEditorMarkdownParser {
    static func listItemBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        let line = lines[index]
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        guard
            let rule = inputRule(from: trimmedLine),
            isListItem(rule.kind),
            let contentColumn = listContentColumn(from: line, trimmedLine: trimmedLine)
        else {
            return nil
        }

        var text = inlineText(from: rule.text)
        var currentIndex = lines.index(after: index)

        while currentIndex < lines.endIndex,
              let continuationText = listContinuationText(from: lines[currentIndex], contentColumn: contentColumn) {
            text += AttributedString("\n")
            text += inlineText(from: continuationText)
            currentIndex = lines.index(after: currentIndex)
        }

        return (
            NativeEditorBlock(
                kind: rule.kind,
                text: text,
                alignment: .left,
                indentLevel: listIndentLevel(fromLeadingColumns: leadingColumns(in: line))
            ),
            currentIndex
        )
    }

    static func listItemMarkdown(prefix: String, continuationPrefix: String, text: String) -> String {
        let lines = text.isEmpty ? [""] : text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        return lines.enumerated().map { item in
            "\(item.offset == 0 ? prefix : continuationPrefix)\(item.element)"
        }
        .joined(separator: "\n")
    }

    private static func listContinuationText(from line: String, contentColumn: Int) -> String? {
        guard leadingColumns(in: line) >= contentColumn else { return nil }

        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        if let rule = inputRule(from: trimmedLine), isListItem(rule.kind) {
            return nil
        }

        return textAfterDroppingColumns(contentColumn, from: line)
    }

    private static func listContentColumn(from line: String, trimmedLine: String) -> Int? {
        guard let markerWidth = listMarkerWidth(from: trimmedLine) else { return nil }
        return leadingColumns(in: line) + markerWidth
    }

    private static func listMarkerWidth(from trimmedLine: String) -> Int? {
        let taskPrefixes = [
            "- [ ] ", "* [ ] ", "+ [ ] ",
            "- [x] ", "- [X] ", "* [x] ", "* [X] ", "+ [x] ", "+ [X] "
        ]
        if let prefix = taskPrefixes.first(where: { trimmedLine.hasPrefix($0) }) {
            return prefix.count
        }

        if let bulletPrefix = ["- ", "* ", "+ "].first(where: { trimmedLine.hasPrefix($0) }) {
            return bulletPrefix.count
        }

        guard
            let dotIndex = trimmedLine.firstIndex(of: "."),
            trimmedLine.distance(from: trimmedLine.startIndex, to: dotIndex) <= 4
        else {
            return nil
        }

        let bodyStart = trimmedLine.index(after: dotIndex)
        guard
            Int(trimmedLine[..<dotIndex]) != nil,
            bodyStart < trimmedLine.endIndex,
            trimmedLine[bodyStart] == " "
        else {
            return nil
        }

        return trimmedLine.distance(from: trimmedLine.startIndex, to: trimmedLine.index(after: bodyStart))
    }

    private static func textAfterDroppingColumns(_ columnCount: Int, from line: String) -> String {
        var columns = 0
        var index = line.startIndex

        while index < line.endIndex, columns < columnCount {
            switch line[index] {
            case " ":
                columns += 1
                index = line.index(after: index)
            case "\t":
                columns += 2
                index = line.index(after: index)
            default:
                return String(line[index...])
            }
        }

        return String(line[index...])
    }

    private static func leadingColumns(in line: String) -> Int {
        var columns = 0

        for character in line {
            switch character {
            case " ":
                columns += 1
            case "\t":
                columns += 2
            default:
                return columns
            }
        }

        return columns
    }

    private static func listIndentLevel(fromLeadingColumns columns: Int) -> Int {
        min(columns / 2, 8)
    }

    private static func isListItem(_ kind: NativeEditorBlockKind) -> Bool {
        switch kind {
        case .bulletListItem, .orderedListItem, .taskListItem:
            true
        default:
            false
        }
    }
}
