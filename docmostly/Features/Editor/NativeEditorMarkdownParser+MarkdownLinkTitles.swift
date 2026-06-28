import Foundation

extension NativeEditorMarkdownParser {
    static func markdownLinkTitle(from destination: String) -> String? {
        markdownLinkDestinationParts(from: destination).title
    }

    static func markdownLinkSource(from destination: String) -> String {
        markdownLinkDestinationParts(from: destination).source
    }

    static func markdownLinkTitlePart(from title: String?) -> String {
        guard let title, title.isEmpty == false else { return "" }
        return " \"\(escapedMarkdownLinkTitle(title))\""
    }

    private static func escapedMarkdownLinkTitle(_ text: String) -> String {
        text.replacing("\\", with: "\\\\")
            .replacing("\"", with: "\\\"")
            .replacing("\r", with: " ")
            .replacing("\n", with: " ")
    }

    private static func unescapedMarkdownLinkTitle(_ text: String) -> String {
        var result = ""
        var isEscaped = false

        for character in text {
            if isEscaped {
                result.append(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else {
                result.append(character)
            }
        }

        if isEscaped {
            result.append("\\")
        }

        return result
    }

    private static func markdownLinkDestinationParts(from destination: String) -> (source: String, title: String?) {
        let destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let titleMatch = markdownLinkTitleMatch(in: destination) else {
            return (normalizedMarkdownLinkSource(destination), nil)
        }

        let rawTitle = String(destination[titleMatch.titleRange])
        let title = unescapedMarkdownLinkTitle(rawTitle)
        let source = normalizedMarkdownLinkSource(String(destination[..<titleMatch.sourceEnd]))
        return (source, title.isEmpty ? nil : title)
    }

    private static func markdownLinkTitleMatch(in destination: String) -> MarkdownLinkTitleMatch? {
        guard destination.isEmpty == false else { return nil }

        let closeIndex = destination.index(before: destination.endIndex)
        guard isEscapedCharacter(at: closeIndex, in: destination) == false else { return nil }

        switch destination[closeIndex] {
        case "\"":
            return delimiterTitleMatch(in: destination, openDelimiter: "\"", closeIndex: closeIndex)
        case "'":
            return delimiterTitleMatch(in: destination, openDelimiter: "'", closeIndex: closeIndex)
        case ")":
            return delimiterTitleMatch(in: destination, openDelimiter: "(", closeIndex: closeIndex)
        default:
            return nil
        }
    }

    private static func delimiterTitleMatch(
        in destination: String,
        openDelimiter: Character,
        closeIndex: String.Index
    ) -> MarkdownLinkTitleMatch? {
        var match: MarkdownLinkTitleMatch?
        var index = destination.startIndex

        while index < closeIndex {
            if destination[index] == openDelimiter,
               isEscapedCharacter(at: index, in: destination) == false,
               index != destination.startIndex {
                let previousIndex = destination.index(before: index)
                if destination[previousIndex].isWhitespace {
                    match = MarkdownLinkTitleMatch(
                        sourceEnd: previousIndex,
                        titleRange: destination.index(after: index)..<closeIndex
                    )
                }
            }

            index = destination.index(after: index)
        }

        return match
    }

    private static func normalizedMarkdownLinkSource(_ source: String) -> String {
        var source = source.trimmingCharacters(in: .whitespacesAndNewlines)

        if source.hasPrefix("<"), source.hasSuffix(">") {
            source.removeFirst()
            source.removeLast()
        }

        return source.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isEscapedCharacter(at index: String.Index, in text: String) -> Bool {
        var backslashCount = 0
        var currentIndex = index

        while currentIndex > text.startIndex {
            let previousIndex = text.index(before: currentIndex)
            guard text[previousIndex] == "\\" else { break }

            backslashCount += 1
            currentIndex = previousIndex
        }

        return backslashCount.isMultiple(of: 2) == false
    }
}

private struct MarkdownLinkTitleMatch {
    let sourceEnd: String.Index
    let titleRange: Range<String.Index>
}
