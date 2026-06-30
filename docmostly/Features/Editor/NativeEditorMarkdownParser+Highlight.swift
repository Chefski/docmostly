import Foundation
import SwiftUI

extension NativeEditorMarkdownParser {
    struct DocmostHighlightHTML {
        var range: Range<String.Index>
        var color: String?
        var colorName: String?
        var bodyMarkdown: String
    }

    static func highlightMarkdown(
        from run: AttributedString.Runs.Run,
        body: String
    ) -> String {
        let color = run[NativeEditorHighlightColorAttribute.self]?.trimmedNonEmpty
        let colorName = run[NativeEditorHighlightColorNameAttribute.self]?.trimmedNonEmpty
        guard color != nil || colorName != nil else { return body }

        var attrs: [(String, String)] = []
        if let color {
            attrs.append(("data-color", color))
            attrs.append(("style", "background-color: \(color); color: inherit"))
        }
        if let colorName {
            attrs.append(("data-highlight-color-name", colorName.lowercased()))
        }

        let attrText = attrs
            .map { name, value in #"\#(name)="\#(escapedInlineHTMLAttribute(value))""# }
            .joined(separator: " ")
        return "<mark \(attrText)>\(body)</mark>"
    }

    static func nextDocmostHighlightHTML(in markdown: Substring) -> DocmostHighlightHTML? {
        var searchStart = markdown.startIndex
        let codeSpanRanges = markdownCodeSpanRanges(in: markdown, bodyStart: markdown.startIndex)

        while searchStart < markdown.endIndex,
              let openRange = markdown[searchStart...].range(of: "<mark", options: .caseInsensitive) {
            guard isInsideMarkdownCodeSpan(openRange.lowerBound, ranges: codeSpanRanges) == false else {
                searchStart = openRange.upperBound
                continue
            }

            let tagNameEnd = markdown.index(openRange.lowerBound, offsetBy: 5)
            guard isHighlightHTMLTagBoundary(at: tagNameEnd, in: markdown),
                  let openTagEnd = markdown[openRange.upperBound...].firstIndex(of: ">") else {
                searchStart = openRange.upperBound
                continue
            }

            let contentStart = markdown.index(after: openTagEnd)
            guard let closeRange = matchingCloseMarkRange(
                in: markdown,
                startingAt: contentStart,
                codeSpanRanges: codeSpanRanges
            ) else {
                return nil
            }

            let attrs = docmostInlineHTMLAttributes(from: String(markdown[openRange.lowerBound...openTagEnd]))
            return DocmostHighlightHTML(
                range: openRange.lowerBound..<closeRange.upperBound,
                color: highlightColor(from: attrs),
                colorName: attrs["data-highlight-color-name"]?.trimmedNonEmpty,
                bodyMarkdown: String(markdown[contentStart..<closeRange.lowerBound])
            )
        }

        return nil
    }

    private static func matchingCloseMarkRange(
        in markdown: Substring,
        startingAt contentStart: String.Index,
        codeSpanRanges: [Range<String.Index>]
    ) -> Range<String.Index>? {
        var searchStart = contentStart

        while searchStart < markdown.endIndex,
              let closeRange = markdown[searchStart...].range(of: "</mark>", options: .caseInsensitive) {
            guard isInsideMarkdownCodeSpan(closeRange.lowerBound, ranges: codeSpanRanges) == false else {
                searchStart = closeRange.upperBound
                continue
            }

            return closeRange
        }

        return nil
    }

    static func appendHighlight(_ htmlHighlight: DocmostHighlightHTML, to result: inout AttributedString) {
        var highlightedBody = AttributedString("")
        appendMarkdownText(
            htmlHighlight.bodyMarkdown,
            to: &highlightedBody,
            usesFoundationMarkdownParser: false
        )
        applyHighlight(
            color: htmlHighlight.color,
            colorName: htmlHighlight.colorName,
            to: &highlightedBody
        )
        result += highlightedBody
    }

    private static func applyHighlight(
        color: String?,
        colorName: String?,
        to text: inout AttributedString
    ) {
        guard color != nil || colorName != nil else { return }

        let ranges = text.runs.map(\.range)
        for range in ranges {
            if let color {
                text[range][NativeEditorHighlightColorAttribute.self] = color
                text[range].backgroundColor = Color(docmostlyHex: color)
            }
            if let colorName {
                text[range][NativeEditorHighlightColorNameAttribute.self] = colorName
            }
        }
    }

    private static func highlightColor(from attrs: [String: String]) -> String? {
        if let color = attrs["data-color"]?.trimmedNonEmpty {
            return color
        }

        guard let style = attrs["style"] else { return nil }
        return style
            .split(separator: ";")
            .compactMap { declaration -> String? in
                let parts = declaration.split(separator: ":", maxSplits: 1).map(String.init)
                guard parts.count == 2,
                      parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare("background-color") == .orderedSame else {
                    return nil
                }

                return parts[1].trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            }
            .first
    }

    private static func isHighlightHTMLTagBoundary(at index: String.Index, in text: Substring) -> Bool {
        index == text.endIndex || text[index].isWhitespace || text[index] == ">" || text[index] == "/"
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
