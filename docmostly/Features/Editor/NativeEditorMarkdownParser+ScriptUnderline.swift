import Foundation

extension NativeEditorMarkdownParser {
    struct DocmostScriptUnderlineHTML {
        var range: Range<String.Index>
        var mark: NativeEditorTextMark
        var bodyMarkdown: String
    }

    static func nextDocmostScriptUnderlineHTML(in markdown: Substring) -> DocmostScriptUnderlineHTML? {
        ["u", "sup", "sub"]
            .compactMap { nextDocmostScriptUnderlineHTML(in: markdown, tagName: $0) }
            .min { lhs, rhs in lhs.range.lowerBound < rhs.range.lowerBound }
    }

    static func appendScriptUnderline(_ htmlMark: DocmostScriptUnderlineHTML, to result: inout AttributedString) {
        var body = AttributedString("")
        appendMarkdownText(
            htmlMark.bodyMarkdown,
            to: &body,
            usesFoundationMarkdownParser: false
        )
        NativeEditorDocument.apply([htmlMark.mark], to: &body)
        result += body
    }

    private static func nextDocmostScriptUnderlineHTML(
        in markdown: Substring,
        tagName: String
    ) -> DocmostScriptUnderlineHTML? {
        var searchStart = markdown.startIndex
        let codeSpanRanges = markdownCodeSpanRanges(in: markdown, bodyStart: markdown.startIndex)

        while searchStart < markdown.endIndex,
              let openingRange = nextOpeningScriptUnderlineTag(
                in: markdown,
                tagName: tagName,
                startingAt: searchStart
              ) {
            guard isInsideMarkdownCodeSpan(openingRange.lowerBound, ranges: codeSpanRanges) == false else {
                searchStart = openingRange.upperBound
                continue
            }

            guard let closeRange = matchingClosingScriptUnderlineTag(
                in: markdown,
                tagName: tagName,
                startingAt: openingRange.upperBound,
                codeSpanRanges: codeSpanRanges
            ) else {
                return nil
            }

            return DocmostScriptUnderlineHTML(
                range: openingRange.lowerBound..<closeRange.upperBound,
                mark: scriptUnderlineMark(for: tagName),
                bodyMarkdown: String(markdown[openingRange.upperBound..<closeRange.lowerBound])
            )
        }

        return nil
    }

    private static func nextOpeningScriptUnderlineTag(
        in markdown: Substring,
        tagName: String,
        startingAt searchStart: String.Index
    ) -> Range<String.Index>? {
        var currentSearchStart = searchStart

        while currentSearchStart < markdown.endIndex,
              let openIndex = markdown[currentSearchStart...].firstIndex(of: "<") {
            let nameStart = markdown.index(after: openIndex)
            guard nameStart < markdown.endIndex, markdown[nameStart] != "/" else {
                currentSearchStart = nameStart
                continue
            }

            let nameEnd = scriptUnderlineTagNameEnd(in: markdown, startingAt: nameStart)
            let name = String(markdown[nameStart..<nameEnd])
            guard name.compare(tagName, options: .caseInsensitive) == .orderedSame,
                  isScriptUnderlineTagBoundary(at: nameEnd, in: markdown),
                  let tagEnd = scriptUnderlineOpeningTagEnd(in: markdown, startingAt: nameEnd) else {
                currentSearchStart = nameEnd
                continue
            }

            return openIndex..<markdown.index(after: tagEnd)
        }

        return nil
    }

    private static func matchingClosingScriptUnderlineTag(
        in markdown: Substring,
        tagName: String,
        startingAt bodyStart: String.Index,
        codeSpanRanges: [Range<String.Index>]
    ) -> Range<String.Index>? {
        let closingTag = "</\(tagName)>"
        var searchStart = bodyStart

        while searchStart < markdown.endIndex,
              let closeRange = markdown[searchStart...].range(of: closingTag, options: .caseInsensitive) {
            guard isInsideMarkdownCodeSpan(closeRange.lowerBound, ranges: codeSpanRanges) == false else {
                searchStart = closeRange.upperBound
                continue
            }

            return closeRange
        }

        return nil
    }

    private static func scriptUnderlineMark(for tagName: String) -> NativeEditorTextMark {
        switch tagName {
        case "sup":
            .superscript
        case "sub":
            .subscript
        default:
            .underline
        }
    }

    private static func scriptUnderlineTagNameEnd(
        in markdown: Substring,
        startingAt index: String.Index
    ) -> String.Index {
        var currentIndex = index
        while currentIndex < markdown.endIndex, markdown[currentIndex].isLetter {
            currentIndex = markdown.index(after: currentIndex)
        }
        return currentIndex
    }

    private static func isScriptUnderlineTagBoundary(at index: String.Index, in markdown: Substring) -> Bool {
        index == markdown.endIndex || markdown[index].isWhitespace || markdown[index] == ">" || markdown[index] == "/"
    }

    private static func scriptUnderlineOpeningTagEnd(
        in markdown: Substring,
        startingAt index: String.Index
    ) -> String.Index? {
        var currentIndex = index
        var quote: Character?

        while currentIndex < markdown.endIndex {
            let character = markdown[currentIndex]
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ">" {
                return currentIndex
            }

            currentIndex = markdown.index(after: currentIndex)
        }

        return nil
    }
}
