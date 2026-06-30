import Foundation

extension NativeEditorMarkdownParser {
    private struct DocmostAnchorHTML {
        var range: Range<String.Index>
        var link: NativeEditorLink
        var bodyMarkdown: String
    }

    static func consumeDocmostAnchorHTML(
        in markdown: inout Substring,
        appendingTo result: inout AttributedString
    ) -> Bool {
        var didConsumeAnchor = false

        while let htmlAnchor = nextDocmostAnchorHTML(in: markdown) {
            appendMarkdownText(
                String(markdown[..<htmlAnchor.range.lowerBound]),
                to: &result,
                usesFoundationMarkdownParser: false
            )
            appendLink(htmlAnchor, to: &result)
            markdown = markdown[htmlAnchor.range.upperBound...]
            didConsumeAnchor = true
        }

        return didConsumeAnchor
    }

    private static func appendLink(_ htmlAnchor: DocmostAnchorHTML, to result: inout AttributedString) {
        var body = AttributedString("")
        appendMarkdownText(
            htmlAnchor.bodyMarkdown,
            to: &body,
            usesFoundationMarkdownParser: false
        )
        applyLink(htmlAnchor.link, to: &body)
        result += body
    }

    private static func applyLink(_ link: NativeEditorLink, to text: inout AttributedString) {
        let ranges = text.runs.map(\.range)
        for range in ranges {
            text[range][NativeEditorLinkAttribute.self] = link
            if let url = NativeEditorDocument.safeLinkURL(from: link.href) {
                text[range].link = url
            }
        }
    }

    private static func nextDocmostAnchorHTML(in markdown: Substring) -> DocmostAnchorHTML? {
        var searchStart = markdown.startIndex

        while searchStart < markdown.endIndex,
              let openRange = markdown[searchStart...].range(of: "<a", options: .caseInsensitive) {
            let tagNameEnd = markdown.index(openRange.lowerBound, offsetBy: 2)
            guard isHTMLAnchorBoundary(tagNameEnd, in: markdown) else {
                searchStart = markdown.index(after: openRange.lowerBound)
                continue
            }

            guard let openTagEnd = markdown[openRange.upperBound...].firstIndex(of: ">") else {
                return nil
            }

            let openingTag = String(markdown[openRange.lowerBound...openTagEnd])
            let attrs = docmostInlineHTMLAttributes(from: openingTag)
            guard
                let href = nonEmptyHTMLAttribute(attrs["href"]),
                let link = NativeEditorDocument.preservedLink(
                    href: href,
                    isInternal: docmostBooleanAttribute(attrs["data-internal"])
                )
            else {
                searchStart = markdown.index(after: openRange.lowerBound)
                continue
            }

            let contentStart = markdown.index(after: openTagEnd)
            guard let closeRange = markdown[contentStart...].range(of: "</a>", options: .caseInsensitive) else {
                return nil
            }

            return DocmostAnchorHTML(
                range: openRange.lowerBound..<closeRange.upperBound,
                link: link,
                bodyMarkdown: unescapedInlineHTMLText(String(markdown[contentStart..<closeRange.lowerBound]))
            )
        }

        return nil
    }

    private static func isHTMLAnchorBoundary(_ index: String.Index, in markdown: Substring) -> Bool {
        index == markdown.endIndex || markdown[index].isWhitespace || markdown[index] == ">"
    }

    private static func nonEmptyHTMLAttribute(_ value: String?) -> String? {
        let value = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }

    private static func docmostBooleanAttribute(_ value: String?) -> Bool {
        guard let value else { return false }

        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedValue.isEmpty == false else { return true }
        return normalizedValue != "false" && normalizedValue != "0"
    }
}
