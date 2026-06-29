import Foundation

extension NativeEditorMarkdownParser {
    static func htmlTableInlineContent(from html: String) -> [NativeEditorInlineContent] {
        let attributedText = htmlTableInlineAttributedText(from: html)
        return NativeEditorDocument.inlineContent(from: NativeEditorDocument.inlineNodes(from: attributedText))
    }

    static func htmlTableInlineAttributedText(from html: String) -> AttributedString {
        var output = AttributedString("")
        var remaining = htmlTableInlineHTML(from: html)[...]

        while let range = nextHTMLTablePreservedInlineRange(in: remaining) {
            appendHTMLTablePlainText(String(remaining[..<range.lowerBound]), to: &output)
            appendHTMLTablePreservedInline(String(remaining[range]), to: &output)
            remaining = remaining[range.upperBound...]
        }

        appendHTMLTablePlainText(String(remaining), to: &output)
        return output
    }

    private static func htmlTableInlineHTML(from html: String) -> String {
        let paragraphSeparated = htmlTableInlineRegexReplacing(
            pattern: #"</p>\s*<p\b[^>]*>"#,
            in: html,
            with: "\n"
        )
        let hardBreakSeparated = htmlTableInlineRegexReplacing(
            pattern: #"<br\s*/?>"#,
            in: paragraphSeparated,
            with: "\n"
        )
        let withoutOpeningParagraphs = htmlTableInlineRegexReplacing(
            pattern: #"<p\b[^>]*>"#,
            in: hardBreakSeparated,
            with: ""
        )
        return htmlTableInlineRegexReplacing(pattern: #"</p>"#, in: withoutOpeningParagraphs, with: "")
    }

    private static func nextHTMLTablePreservedInlineRange(in html: Substring) -> Range<String.Index>? {
        [
            nextHTMLTablePreservedSpanRange(in: html),
            nextHTMLTablePreservedTagRange(in: html, tagName: "a"),
            nextHTMLTablePreservedTagRange(in: html, tagName: "mark"),
            nextHTMLTablePreservedTagRange(in: html, tagName: "u"),
            nextHTMLTablePreservedTagRange(in: html, tagName: "sup"),
            nextHTMLTablePreservedTagRange(in: html, tagName: "sub"),
            nextHTMLTableStandardMarkRange(in: html)
        ]
        .compactMap { $0 }
        .min { $0.lowerBound < $1.lowerBound }
    }

    private static func nextHTMLTableStandardMarkRange(in html: Substring) -> Range<String.Index>? {
        [
            "strong",
            "b",
            "em",
            "i",
            "code",
            "s",
            "strike",
            "del"
        ]
        .compactMap { nextHTMLTablePreservedTagRange(in: html, tagName: $0) }
        .min { $0.lowerBound < $1.lowerBound }
    }

    private static func nextHTMLTablePreservedSpanRange(in html: Substring) -> Range<String.Index>? {
        var searchStart = html.startIndex

        while searchStart < html.endIndex,
              let openRange = html[searchStart...].range(of: "<span", options: .caseInsensitive) {
            guard let openTagEnd = html[openRange.upperBound...].firstIndex(of: ">") else {
                return nil
            }

            let attrs = docmostInlineHTMLAttributes(from: String(html[openRange.lowerBound...openTagEnd]))
            guard htmlTableShouldPreserveSpan(attrs: attrs) else {
                searchStart = html.index(after: openRange.lowerBound)
                continue
            }

            let contentStart = html.index(after: openTagEnd)
            guard let closeRange = matchingCloseSpanRange(in: html, bodyStart: contentStart) else {
                return nil
            }

            return openRange.lowerBound..<closeRange.upperBound
        }

        return nil
    }

    private static func htmlTableShouldPreserveSpan(attrs: [String: String]) -> Bool {
        attrs["data-type"] != nil ||
            attrs["data-comment-id"] != nil ||
            attrs["style"]?.localizedCaseInsensitiveContains("color") == true
    }

    private static func nextHTMLTablePreservedTagRange(
        in html: Substring,
        tagName: String
    ) -> Range<String.Index>? {
        var searchStart = html.startIndex
        let openingPrefix = "<\(tagName)"
        let closingTag = "</\(tagName)>"

        while searchStart < html.endIndex,
              let openRange = html[searchStart...].range(of: openingPrefix, options: .caseInsensitive) {
            let nameEnd = html.index(openRange.lowerBound, offsetBy: openingPrefix.count)
            guard htmlTableIsTagBoundary(at: nameEnd, in: html),
                  let openTagEnd = html[openRange.upperBound...].firstIndex(of: ">") else {
                searchStart = openRange.upperBound
                continue
            }

            let contentStart = html.index(after: openTagEnd)
            guard let closeRange = html[contentStart...].range(of: closingTag, options: .caseInsensitive) else {
                return nil
            }

            return openRange.lowerBound..<closeRange.upperBound
        }

        return nil
    }

    private static func htmlTableIsTagBoundary(at index: String.Index, in html: Substring) -> Bool {
        index == html.endIndex || html[index].isWhitespace || html[index] == ">" || html[index] == "/"
    }

    private static func appendHTMLTablePlainText(_ html: String, to output: inout AttributedString) {
        guard html.isEmpty == false else { return }

        let withoutTags = htmlTableInlineRegexReplacing(pattern: #"<[^>]+>"#, in: html, with: "")
        output += AttributedString(unescapedInlineHTMLText(withoutTags))
    }

    private static func appendHTMLTablePreservedInline(_ html: String, to output: inout AttributedString) {
        if let standardMark = htmlTableStandardMark(from: html) {
            var markedText = htmlTableInlineAttributedText(from: standardMark.body)
            NativeEditorDocument.apply([standardMark.mark], to: &markedText)
            output += markedText
            return
        }

        var preserved = AttributedString("")
        appendMarkdownText(html, to: &preserved, usesFoundationMarkdownParser: false)
        output += preserved
    }

    private static func htmlTableStandardMark(from html: String) -> (mark: NativeEditorTextMark, body: String)? {
        let trimmedHTML = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedHTML.hasPrefix("<"),
              let openTagEnd = trimmedHTML.firstIndex(of: ">") else {
            return nil
        }

        let tagNameStart = trimmedHTML.index(after: trimmedHTML.startIndex)
        let tagName = htmlTableOpeningTagName(in: trimmedHTML, startingAt: tagNameStart).lowercased()
        guard let mark = htmlTableStandardMark(for: tagName) else { return nil }

        let closingTag = "</\(tagName)>"
        guard let closeRange = trimmedHTML.range(
            of: closingTag,
            options: [.caseInsensitive, .backwards]
        ) else {
            return nil
        }

        let bodyStart = trimmedHTML.index(after: openTagEnd)
        return (mark, String(trimmedHTML[bodyStart..<closeRange.lowerBound]))
    }

    private static func htmlTableStandardMark(for tagName: String) -> NativeEditorTextMark? {
        switch tagName {
        case "strong", "b":
            .bold
        case "em", "i":
            .italic
        case "code":
            .code
        case "s", "strike", "del":
            .strikethrough
        default:
            nil
        }
    }

    private static func htmlTableOpeningTagName(in html: String, startingAt index: String.Index) -> String {
        var currentIndex = index
        while currentIndex < html.endIndex,
              html[currentIndex].isHTMLTableInlineTagNameCharacter {
            currentIndex = html.index(after: currentIndex)
        }

        return String(html[index..<currentIndex])
    }

    private static func htmlTableInlineRegexReplacing(
        pattern: String,
        in text: String,
        with replacement: String
    ) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}

private extension Character {
    var isHTMLTableInlineTagNameCharacter: Bool {
        isLetter || isNumber || self == "-"
    }
}
