import Foundation

extension NativeEditorMarkdownParser {
    static func htmlTableStructuralContentMatches(
        from html: String,
        excluding excludedRanges: [NSRange]
    ) -> [HTMLTableContentMatch] {
        let containerMatches = htmlTableContainerStructuralContentMatches(from: html, excluding: excludedRanges)
        let containerRanges = excludedRanges + containerMatches.map(\.range)
        let divMatches = htmlRegexMatches(pattern: #"<div\b([^>]*)>(.*?)</div>"#, in: html)
            .compactMap { match -> HTMLTableContentMatch? in
                guard htmlTableRange(match.range, isContainedIn: containerRanges) == false,
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

        return containerMatches + divMatches
    }

    private static func htmlTableContainerStructuralContentMatches(
        from html: String,
        excluding excludedRanges: [NSRange]
    ) -> [HTMLTableContentMatch] {
        htmlTableDetailsContentMatches(from: html, excluding: excludedRanges) +
            htmlTableColumnsContentMatches(from: html, excluding: excludedRanges) +
            htmlTableTransclusionSourceContentMatches(from: html, excluding: excludedRanges)
    }

    private static func htmlTableDetailsContentMatches(
        from html: String,
        excluding excludedRanges: [NSRange]
    ) -> [HTMLTableContentMatch] {
        htmlRegexMatches(pattern: #"<details\b([^>]*)>(.*?)</details>"#, in: html)
            .compactMap { match -> HTMLTableContentMatch? in
                guard htmlTableRange(match.range, isNestedIn: excludedRanges) == false,
                      let attributeText = htmlRegexString(match: match, captureIndex: 1, in: html),
                      let body = htmlRegexString(match: match, captureIndex: 2, in: html) else {
                    return nil
                }

                let attrs = docmostInlineHTMLAttributes(from: "<details\(attributeText)>")
                return HTMLTableContentMatch(
                    range: match.range,
                    node: htmlTableDetailsNode(attrs: attrs, body: body)
                )
            }
    }

    private static func htmlTableColumnsContentMatches(
        from html: String,
        excluding excludedRanges: [NSRange]
    ) -> [HTMLTableContentMatch] {
        htmlTableTypedDivContainers(from: html, dataType: "columns")
            .compactMap { container -> HTMLTableContentMatch? in
                guard htmlTableRange(container.range, isNestedIn: excludedRanges) == false else {
                    return nil
                }

                return HTMLTableContentMatch(
                    range: container.range,
                    node: htmlTableColumnsNode(attrs: container.attrs, body: container.body)
                )
            }
    }

    private static func htmlTableTransclusionSourceContentMatches(
        from html: String,
        excluding excludedRanges: [NSRange]
    ) -> [HTMLTableContentMatch] {
        htmlTableTypedDivContainers(from: html, dataType: "transclusionSource")
            .compactMap { container -> HTMLTableContentMatch? in
                guard htmlTableRange(container.range, isNestedIn: excludedRanges) == false else {
                    return nil
                }

                return HTMLTableContentMatch(
                    range: container.range,
                    node: htmlTableTransclusionSourceNode(attrs: container.attrs, body: container.body)
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
        case "pageBreak":
            return ProseMirrorNode(type: "pageBreak")
        default:
            return ProseMirrorNode(type: "subpages")
        }
    }

    private static func htmlTableDetailsNode(attrs: [String: String], body: String) -> ProseMirrorNode {
        let summary = htmlTableDetailsSummary(from: body)
        let detailsContent = htmlTableDetailsContent(from: body)

        return ProseMirrorNode(
            type: "details",
            attrs: ["open": .bool(htmlTableDetailsIsOpen(attrs: attrs))],
            content: [
                ProseMirrorNode(
                    type: "detailsSummary",
                    content: NativeEditorDocument.inlineNodes(from: inlineText(from: summary))
                ),
                ProseMirrorNode(
                    type: "detailsContent",
                    content: [
                        ProseMirrorNode(
                            type: "paragraph",
                            content: NativeEditorDocument.inlineNodes(from: inlineText(from: detailsContent))
                        )
                    ]
                )
            ]
        )
    }

    private static func htmlTableColumnsNode(attrs: [String: String], body: String) -> ProseMirrorNode {
        let columns = htmlTableTypedDivContainers(from: body, dataType: "column")
        return ProseMirrorNode(
            type: "columns",
            attrs: [
                "layout": .string(nonEmptyHTMLTableAttribute(attrs["data-layout"]) ?? "two_equal"),
                "widthMode": .string(nonEmptyHTMLTableAttribute(attrs["data-width-mode"]) ?? "normal")
            ],
            content: columns.map(htmlTableColumnNode(from:))
        )
    }

    private static func htmlTableColumnNode(from container: HTMLTableDivContainer) -> ProseMirrorNode {
        let content = htmlTableColumnContent(from: container.body)
        return ProseMirrorNode(
            type: "column",
            attrs: [
                "width": htmlTableStructuralNumber(
                    from: nonEmptyHTMLTableAttribute(container.attrs["data-width"]) ?? "1"
                )
            ],
            content: content
        )
    }

    private static func htmlTableColumnContent(from body: String) -> [ProseMirrorNode] {
        let content = containerContentNodes(from: containerBodyLines(from: body))
        if content.isEmpty == false {
            return content
        }

        return [
            ProseMirrorNode(
                type: "paragraph",
                content: NativeEditorDocument.inlineNodes(from: inlineText(from: htmlTableStructuralText(from: body)))
            )
        ]
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
        let content = containerContentNodes(from: containerBodyLines(from: body))

        if let identifier = nonEmptyHTMLTableAttribute(attrs["data-id"]) {
            nodeAttrs["id"] = .string(identifier)
        }

        return ProseMirrorNode(
            type: "transclusionSource",
            attrs: nodeAttrs.isEmpty ? nil : nodeAttrs,
            content: content.isEmpty ? [
                ProseMirrorNode(
                    type: "paragraph",
                    content: NativeEditorDocument.inlineNodes(
                        from: inlineText(from: htmlTableStructuralText(from: body))
                    )
                )
            ] : content
        )
    }

    private static func htmlTableRange(_ range: NSRange, isContainedIn ranges: [NSRange]) -> Bool {
        ranges.contains { container in
            range.location >= container.location && NSMaxRange(range) <= NSMaxRange(container)
        }
    }

    private static func htmlTableStructuralDivType(from dataType: String?) -> String? {
        guard let dataType else { return nil }
        for supportedType in [
            "mathBlock",
            "base-embed",
            "transclusionReference",
            "transclusionSource",
            "subpages",
            "pageBreak"
        ]
            where dataType.localizedCaseInsensitiveCompare(supportedType) == .orderedSame {
            return supportedType
        }
        return nil
    }

    private static func htmlTableDetailsSummary(from html: String) -> String {
        guard let match = htmlRegexMatches(pattern: #"<summary\b[^>]*>(.*?)</summary>"#, in: html).first,
              let body = htmlRegexString(match: match, captureIndex: 1, in: html) else {
            return "Details"
        }

        let summary = htmlTableStructuralText(from: body)
        return summary.isEmpty ? "Details" : summary
    }

    private static func htmlTableDetailsContent(from html: String) -> String {
        guard let detailsContent = htmlTableTypedDivContainers(from: html, dataType: "detailsContent").first else {
            return ""
        }

        return htmlTableStructuralText(from: detailsContent.body)
    }

    private static func htmlTableDetailsIsOpen(attrs: [String: String]) -> Bool {
        guard let value = attrs["open"] else { return false }
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedValue == "" || normalizedValue == "open" || normalizedValue == "true" || normalizedValue == "1"
    }

    private static func htmlTableStructuralNumber(from value: String) -> ProseMirrorJSONValue {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let intValue = Int(trimmedValue) {
            return .int(intValue)
        }
        if let doubleValue = Double(trimmedValue) {
            return .double(doubleValue)
        }
        return .int(1)
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

    static func htmlTableTypedDivContainers(from html: String, dataType: String) -> [HTMLTableDivContainer] {
        let tags = htmlRegexMatches(pattern: #"</?div\b[^>]*>"#, in: html)
        var containers: [HTMLTableDivContainer] = []

        for (index, tagMatch) in tags.enumerated() {
            guard let tagText = htmlRegexString(match: tagMatch, captureIndex: 0, in: html),
                  htmlTableDivTagIsClosing(tagText) == false,
                  htmlTableDivTagIsSelfClosing(tagText) == false else {
                continue
            }

            let attrs = docmostInlineHTMLAttributes(from: tagText)
            guard attrs["data-type"]?.localizedCaseInsensitiveCompare(dataType) == .orderedSame,
                  let container = htmlTableDivContainer(
                    from: html,
                    tags: tags,
                    openingTagIndex: index,
                    attrs: attrs
                  ) else {
                continue
            }

            containers.append(container)
        }

        return containers
    }

    private static func htmlTableDivContainer(
        from html: String,
        tags: [NSTextCheckingResult],
        openingTagIndex: Int,
        attrs: [String: String]
    ) -> HTMLTableDivContainer? {
        let openingTag = tags[openingTagIndex]
        var depth = 0

        for currentTag in tags[openingTagIndex...] {
            guard let tagText = htmlRegexString(match: currentTag, captureIndex: 0, in: html) else {
                continue
            }

            if htmlTableDivTagIsClosing(tagText) {
                depth -= 1
                if depth == 0 {
                    guard let body = htmlTableHTMLBody(
                        from: html,
                        openingTag: openingTag,
                        closingTag: currentTag
                    ) else {
                        return nil
                    }

                    return HTMLTableDivContainer(
                        range: NSRange(
                            location: openingTag.range.location,
                            length: NSMaxRange(currentTag.range) - openingTag.range.location
                        ),
                        attrs: attrs,
                        body: body
                    )
                }
            } else if htmlTableDivTagIsSelfClosing(tagText) == false {
                depth += 1
            }
        }

        return nil
    }

    private static func htmlTableHTMLBody(
        from html: String,
        openingTag: NSTextCheckingResult,
        closingTag: NSTextCheckingResult
    ) -> String? {
        guard let bodyStart = Range(openingTag.range, in: html)?.upperBound,
              let bodyEnd = Range(closingTag.range, in: html)?.lowerBound,
              bodyStart <= bodyEnd else {
            return nil
        }

        return String(html[bodyStart..<bodyEnd])
    }

    private static func htmlTableDivTagIsClosing(_ tagText: String) -> Bool {
        tagText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("</")
    }

    private static func htmlTableDivTagIsSelfClosing(_ tagText: String) -> Bool {
        tagText.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/>")
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

struct HTMLTableDivContainer {
    var range: NSRange
    var attrs: [String: String]
    var body: String
}
