import Foundation

extension NativeEditorMarkdownParser {
    static func escapedMarkdownPlainText(_ text: String) -> String {
        let escapableCharacters: Set<Character> = ["\\", "`", "*", "_", "[", "]", "<", "~", "!"]
        return text.reduce(into: "") { result, character in
            if escapableCharacters.contains(character) {
                result.append("\\")
            }
            result.append(character)
        }
    }

    static func unescapedMarkdownPlainText(_ text: String) -> String {
        var result = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            let nextIndex = text.index(after: index)
            if character == "\\", nextIndex < text.endIndex, markdownEscapableCharacters.contains(text[nextIndex]) {
                result.append(text[nextIndex])
                index = text.index(after: nextIndex)
            } else {
                result.append(character)
                index = nextIndex
            }
        }
        return result
    }

    static func escapedBlockLeadingMarkdown(in text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map(escapingMarkdownBlockPrefix)
            .joined(separator: "\n")
    }

    static func firstUnescapedRange(
        of delimiter: String,
        in markdown: Substring,
        startingAt startIndex: String.Index? = nil
    ) -> Range<String.Index>? {
        var searchStart = startIndex ?? markdown.startIndex
        while searchStart < markdown.endIndex,
              let range = markdown[searchStart...].range(of: delimiter) {
            if isEscapedMarkdownCharacter(at: range.lowerBound, in: markdown) == false {
                return range
            }
            searchStart = range.upperBound
        }
        return nil
    }

    static func isEscapedMarkdownCharacter(
        at index: String.Index,
        in markdown: Substring
    ) -> Bool {
        var slashCount = 0
        var currentIndex = index
        while currentIndex > markdown.startIndex {
            let previousIndex = markdown.index(before: currentIndex)
            guard markdown[previousIndex] == "\\" else { break }
            slashCount += 1
            currentIndex = previousIndex
        }
        return slashCount.isMultiple(of: 2) == false
    }

    private static func escapingMarkdownBlockPrefix(_ line: Substring) -> String {
        let text = String(line)
        let fixedPrefixes = ["# ", "## ", "### ", "#### ", "##### ", "###### ", "> ", "- ", "+ "]
        let exactMarkers = ["---", "***", "___"]
        let startsFixedSyntax = fixedPrefixes.contains { text.hasPrefix($0) }
        let startsFence = text.hasPrefix("```") || text.hasPrefix("~~~")
        let isSetextUnderline = text.isEmpty == false &&
            (text.allSatisfy { $0 == "-" } || text.allSatisfy { $0 == "=" })
        let isExactMarker = exactMarkers.contains(text)

        if let orderedListDotIndex = orderedListDotIndex(in: text) {
            var escaped = text
            escaped.insert("\\", at: orderedListDotIndex)
            return escaped
        }

        guard startsFixedSyntax || startsFence || isSetextUnderline || isExactMarker else { return text }
        return "\\\(text)"
    }

    private static func orderedListDotIndex(in text: String) -> String.Index? {
        guard let dotIndex = text.firstIndex(of: "."),
              text.distance(from: text.startIndex, to: dotIndex) <= 4,
              Int(text[..<dotIndex]) != nil else {
            return nil
        }
        let spaceIndex = text.index(after: dotIndex)
        return spaceIndex < text.endIndex && text[spaceIndex] == " " ? dotIndex : nil
    }

    private static let markdownEscapableCharacters: Set<Character> = [
        "!", "\"", "#", "$", "%", "&", "'", "(", ")", "*", "+", ",", "-", ".", "/", ":", ";",
        "<", "=", ">", "?", "@", "[", "\\", "]", "^", "_", "`", "{", "|", "}", "~"
    ]
}
