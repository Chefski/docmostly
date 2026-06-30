import Foundation

extension NativeEditorMarkdownParser {
    static func inlineText(from markdown: String) -> AttributedString {
        var result = AttributedString("")
        var remaining = markdown[...]
        let codeSpanRanges = markdownCodeSpanRanges(in: remaining, bodyStart: remaining.startIndex)

        while let inlineDelimiter = nextInlineMathDelimiter(in: remaining, codeSpanRanges: codeSpanRanges) {
            let openRange = inlineDelimiter.range
            appendMarkdownText(
                String(remaining[..<openRange.lowerBound]),
                to: &result,
                usesFoundationMarkdownParser: false
            )

            let contentStart = openRange.upperBound
            guard let closeRange = remaining[contentStart...].range(of: inlineDelimiter.value) else {
                appendMarkdownText(String(remaining[openRange.lowerBound...]), to: &result)
                return result
            }

            guard isValidInlineMathDelimiter(
                inlineDelimiter.value,
                openingRange: openRange,
                closingRange: closeRange,
                in: remaining
            ) else {
                appendMarkdownText(
                    String(remaining[openRange.lowerBound..<openRange.upperBound]),
                    to: &result,
                    usesFoundationMarkdownParser: false
                )
                remaining = remaining[openRange.upperBound...]
                continue
            }

            let mathText = String(remaining[contentStart..<closeRange.lowerBound])
            guard mathText.isEmpty == false else {
                appendMarkdownText(String(remaining[openRange.lowerBound..<closeRange.upperBound]), to: &result)
                remaining = remaining[closeRange.upperBound...]
                continue
            }

            appendInlineMath(mathText, to: &result)
            remaining = remaining[closeRange.upperBound...]
        }

        appendMarkdownText(
            String(remaining),
            to: &result,
            usesFoundationMarkdownParser: shouldUseFoundationMarkdownParser(for: markdown, after: result)
        )
        return result
    }

    static func inlineMathInputRuleText(from text: String) -> AttributedString? {
        guard let shortcut = trailingInlineMathShortcut(in: text) else { return nil }

        var result = AttributedString(String(text[..<shortcut.openingRange.lowerBound]))
        appendInlineMath(shortcut.text, to: &result)
        return result
    }

    private static func shouldUseFoundationMarkdownParser(
        for markdown: String,
        after result: AttributedString
    ) -> Bool {
        let trimmedMarkdown = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.characters.isEmpty && trimmedMarkdown.hasPrefix("<") == false
    }

    private static func appendInlineMath(_ text: String, to result: inout AttributedString) {
        let math = NativeEditorMathInline(text: text)
        var segment = AttributedString(text)
        segment[NativeEditorMathInlineAttribute.self] = math
        segment.inlinePresentationIntent = .code
        result += segment
    }

    private static func trailingInlineMathShortcut(
        in text: String
    ) -> (openingRange: Range<String.Index>, text: String)? {
        guard text.hasSuffix("$$") else { return nil }

        let closingStart = text.index(text.endIndex, offsetBy: -2)
        guard
            let openingRange = text.range(
                of: "$$",
                options: .backwards,
                range: text.startIndex..<closingStart
            )
        else {
            return nil
        }

        let mathText = String(text[openingRange.upperBound..<closingStart])
        guard mathText.isEmpty == false, mathText.contains("$") == false else { return nil }

        if openingRange.lowerBound > text.startIndex {
            let previousIndex = text.index(before: openingRange.lowerBound)
            guard text[previousIndex].isWhitespace else { return nil }
        }

        return (openingRange, mathText)
    }

    private static func isValidInlineMathDelimiter(
        _ delimiter: String,
        openingRange: Range<String.Index>,
        closingRange: Range<String.Index>,
        in markdown: Substring
    ) -> Bool {
        let content = markdown[openingRange.upperBound..<closingRange.lowerBound]
        guard let firstContentCharacter = content.first,
              firstContentCharacter.isWhitespace == false,
              let lastContentCharacter = content.last,
              lastContentCharacter.isWhitespace == false else {
            return false
        }

        if openingRange.lowerBound > markdown.startIndex {
            let previousIndex = markdown.index(before: openingRange.lowerBound)
            guard markdown[previousIndex] == " " else { return false }
        }

        if delimiter == "$", closingRange.upperBound < markdown.endIndex {
            return markdown[closingRange.upperBound].isNumber == false
        }

        return true
    }

    private static func nextInlineMathDelimiter(
        in markdown: Substring,
        codeSpanRanges: [Range<String.Index>]
    ) -> (range: Range<String.Index>, value: String)? {
        var searchStart = markdown.startIndex

        while searchStart < markdown.endIndex,
              let dollarIndex = markdown[searchStart...].firstIndex(of: "$") {
            let singleDollarRange = dollarIndex..<markdown.index(after: dollarIndex)
            guard isInsideMarkdownCodeSpan(dollarIndex, ranges: codeSpanRanges) == false else {
                searchStart = singleDollarRange.upperBound
                continue
            }

            let nextIndex = markdown.index(after: dollarIndex)
            if nextIndex < markdown.endIndex, markdown[nextIndex] == "$" {
                return (dollarIndex..<markdown.index(after: nextIndex), "$$")
            }

            return (singleDollarRange, "$")
        }

        return nil
    }
}
