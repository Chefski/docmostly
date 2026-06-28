import Foundation

extension NativeEditorMarkdownParser {
    static func statusMarkdown(from status: NativeEditorStatusBadge) -> String {
        let color = escapedInlineHTMLAttribute(status.color)
        let text = escapedInlineHTMLText(status.text)
        return #"<span data-type="status" data-color="\#(color)">\#(text)</span>"#
    }

    static func nextDocmostStatusHTML(
        in markdown: Substring
    ) -> (range: Range<String.Index>, status: NativeEditorStatusBadge)? {
        var searchStart = markdown.startIndex

        while searchStart < markdown.endIndex,
              let openRange = markdown[searchStart...].range(of: "<span", options: .caseInsensitive) {
            guard let openTagEnd = markdown[openRange.upperBound...].firstIndex(of: ">") else {
                return nil
            }

            let openingTag = String(markdown[openRange.lowerBound...openTagEnd])
            let attrs = docmostInlineHTMLAttributes(from: openingTag)
            guard attrs["data-type"]?.localizedCaseInsensitiveCompare("status") == .orderedSame else {
                searchStart = markdown.index(after: openRange.lowerBound)
                continue
            }

            let contentStart = markdown.index(after: openTagEnd)
            guard let closeRange = matchingCloseSpanRange(in: markdown, bodyStart: contentStart) else {
                return nil
            }

            return (
                openRange.lowerBound..<closeRange.upperBound,
                NativeEditorStatusBadge(
                    text: unescapedInlineHTMLText(String(markdown[contentStart..<closeRange.lowerBound])),
                    color: attrs["data-color"]?.trimmedNonEmpty ?? "gray"
                )
            )
        }

        return nil
    }

    static func appendStatus(_ status: NativeEditorStatusBadge, to result: inout AttributedString) {
        var segment = AttributedString(status.text)
        segment[NativeEditorStatusAttribute.self] = status
        result += segment
    }
}

private extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
