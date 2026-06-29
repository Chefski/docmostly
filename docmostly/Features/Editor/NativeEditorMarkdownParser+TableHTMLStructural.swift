import Foundation

extension NativeEditorMarkdownParser {
    static func htmlTableStructuralContentMatches(
        from html: String,
        excluding excludedRanges: [NSRange]
    ) -> [HTMLTableContentMatch] {
        htmlRegexMatches(pattern: #"<div\b([^>]*)>(.*?)</div>"#, in: html)
            .compactMap { match -> HTMLTableContentMatch? in
                guard htmlTableRange(match.range, isNestedIn: excludedRanges) == false,
                      let attributeText = htmlRegexString(match: match, captureIndex: 1, in: html),
                      let body = htmlRegexString(match: match, captureIndex: 2, in: html) else {
                    return nil
                }

                let attrs = docmostInlineHTMLAttributes(from: "<div\(attributeText)>")
                guard let type = htmlTableStructuralDivType(from: attrs["data-type"]) else { return nil }

                return HTMLTableContentMatch(
                    range: match.range,
                    node: htmlTableStructuralNode(type: type, attrs: attrs, body: body)
                )
            }
    }

    private static func htmlTableStructuralNode(
        type: String,
        attrs: [String: String],
        body: String
    ) -> ProseMirrorNode {
        switch type {
        case "mathBlock":
            return ProseMirrorNode(
                type: "mathBlock",
                attrs: ["text": .string(htmlTableStructuralText(from: body))]
            )
        case "base-embed":
            return ProseMirrorNode(type: "base", attrs: [
                "pageId": nonEmptyHTMLTableAttribute(attrs["data-page-id"]).map(ProseMirrorJSONValue.string) ?? .null
            ])
        case "transclusionReference":
            return htmlTableTransclusionReferenceNode(attrs: attrs)
        case "transclusionSource":
            return htmlTableTransclusionSourceNode(attrs: attrs, body: body)
        default:
            return ProseMirrorNode(type: "subpages")
        }
    }

    private static func htmlTableTransclusionReferenceNode(attrs: [String: String]) -> ProseMirrorNode {
        var nodeAttrs = [String: ProseMirrorJSONValue]()

        if let sourcePageID = nonEmptyHTMLTableAttribute(attrs["data-source-page-id"]) {
            nodeAttrs["sourcePageId"] = .string(sourcePageID)
        }
        if let transclusionID = nonEmptyHTMLTableAttribute(attrs["data-transclusion-id"]) {
            nodeAttrs["transclusionId"] = .string(transclusionID)
        }

        return ProseMirrorNode(
            type: "transclusionReference",
            attrs: nodeAttrs.isEmpty ? nil : nodeAttrs
        )
    }

    private static func htmlTableTransclusionSourceNode(
        attrs: [String: String],
        body: String
    ) -> ProseMirrorNode {
        var nodeAttrs = [String: ProseMirrorJSONValue]()
        let text = htmlTableStructuralText(from: body)

        if let identifier = nonEmptyHTMLTableAttribute(attrs["data-id"]) {
            nodeAttrs["id"] = .string(identifier)
        }

        return ProseMirrorNode(
            type: "transclusionSource",
            attrs: nodeAttrs.isEmpty ? nil : nodeAttrs,
            content: [
                ProseMirrorNode(
                    type: "paragraph",
                    content: NativeEditorDocument.inlineNodes(from: inlineText(from: text))
                )
            ]
        )
    }

    private static func htmlTableStructuralDivType(from dataType: String?) -> String? {
        guard let dataType else { return nil }
        for supportedType in ["mathBlock", "base-embed", "transclusionReference", "transclusionSource", "subpages"]
            where dataType.localizedCaseInsensitiveCompare(supportedType) == .orderedSame {
            return supportedType
        }
        return nil
    }

    private static func htmlTableStructuralText(from html: String) -> String {
        let lineBreaks = htmlTableStructuralHTMLReplacing(pattern: #"<br\s*/?>"#, in: html, with: "\n")
        let withoutOpeningParagraphs = htmlTableStructuralHTMLReplacing(
            pattern: #"<p\b[^>]*>"#,
            in: lineBreaks,
            with: ""
        )
        let withoutClosingParagraphs = htmlTableStructuralHTMLReplacing(
            pattern: #"</p>"#,
            in: withoutOpeningParagraphs,
            with: "\n"
        )
        let withoutTags = htmlTableStructuralHTMLReplacing(
            pattern: #"<[^>]+>"#,
            in: withoutClosingParagraphs,
            with: ""
        )

        return unescapedInlineHTMLText(withoutTags).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func htmlTableStructuralHTMLReplacing(pattern: String, in text: String, with replacement: String)
        -> String {
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
