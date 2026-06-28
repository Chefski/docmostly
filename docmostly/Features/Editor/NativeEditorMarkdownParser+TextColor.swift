import Foundation
import SwiftUI

extension NativeEditorMarkdownParser {
    struct DocmostTextColorHTML {
        var range: Range<String.Index>
        var color: String
        var bodyMarkdown: String
    }

    static func textColorMarkdown(
        from run: AttributedString.Runs.Run,
        body: String
    ) -> String {
        guard let color = run[NativeEditorTextColorAttribute.self]?.trimmedNonEmpty else { return body }

        return #"<span style="color: \#(escapedInlineHTMLAttribute(color))">\#(body)</span>"#
    }

    static func nextDocmostTextColorHTML(in markdown: Substring) -> DocmostTextColorHTML? {
        var searchStart = markdown.startIndex

        while searchStart < markdown.endIndex,
              let openRange = markdown[searchStart...].range(of: "<span", options: .caseInsensitive) {
            let tagNameEnd = markdown.index(openRange.lowerBound, offsetBy: 5)
            guard isTextColorHTMLTagBoundary(at: tagNameEnd, in: markdown),
                  let openTagEnd = markdown[openRange.upperBound...].firstIndex(of: ">") else {
                searchStart = openRange.upperBound
                continue
            }

            let openingTag = String(markdown[openRange.lowerBound...openTagEnd])
            let attrs = docmostInlineHTMLAttributes(from: openingTag)
            guard attrs["data-type"] == nil,
                  attrs["data-comment-id"] == nil,
                  let color = textColor(from: attrs) else {
                searchStart = markdown.index(after: openRange.lowerBound)
                continue
            }

            let contentStart = markdown.index(after: openTagEnd)
            guard let closeRange = matchingCloseSpanRange(in: markdown, bodyStart: contentStart) else {
                return nil
            }

            return DocmostTextColorHTML(
                range: openRange.lowerBound..<closeRange.upperBound,
                color: color,
                bodyMarkdown: String(markdown[contentStart..<closeRange.lowerBound])
            )
        }

        return nil
    }

    static func appendTextColor(_ htmlTextColor: DocmostTextColorHTML, to result: inout AttributedString) {
        var coloredBody = AttributedString("")
        appendMarkdownText(
            htmlTextColor.bodyMarkdown,
            to: &coloredBody,
            usesFoundationMarkdownParser: false
        )
        applyTextColor(htmlTextColor.color, to: &coloredBody)
        result += coloredBody
    }

    private static func applyTextColor(_ color: String, to text: inout AttributedString) {
        let ranges = text.runs.map(\.range)
        for range in ranges {
            text[range][NativeEditorTextColorAttribute.self] = color
            if let swiftUIColor = Color(docmostlyHex: color) {
                text[range].foregroundColor = swiftUIColor
            }
        }
    }

    private static func textColor(from attrs: [String: String]) -> String? {
        guard let style = attrs["style"] else { return nil }

        return style
            .split(separator: ";")
            .compactMap { declaration -> String? in
                let parts = declaration.split(separator: ":", maxSplits: 1).map(String.init)
                guard parts.count == 2,
                      parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    .localizedCaseInsensitiveCompare("color") == .orderedSame else {
                    return nil
                }

                return parts[1].trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            }
            .first
    }

    private static func isTextColorHTMLTagBoundary(at index: String.Index, in text: Substring) -> Bool {
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
