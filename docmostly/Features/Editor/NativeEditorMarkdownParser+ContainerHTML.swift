import Foundation

extension NativeEditorMarkdownParser {
    static func docmostContainerHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        if let callout = calloutHTMLBlock(in: lines, startingAt: index) {
            return callout
        }

        if let details = detailsContainerHTMLBlock(in: lines, startingAt: index) {
            return details
        }

        return mathBlockHTMLBlock(in: lines, startingAt: index)
    }

    static func docmostContainerHTMLMarkdown(from block: NativeEditorBlock) -> String? {
        switch block.kind {
        case .callout(let callout):
            calloutNeedsDocmostHTMLMarkdown(callout) ? calloutHTMLMarkdown(from: callout) : nil
        case .details(let details):
            detailsHTMLMarkdown(from: details)
        default:
            nil
        }
    }

    private static func calloutNeedsDocmostHTMLMarkdown(_ callout: NativeEditorCalloutBlock) -> Bool {
        guard callout.icon == nil else { return true }
        return calloutFenceCannotPreserveStyle(callout.style)
    }

    private static func calloutFenceCannotPreserveStyle(_ style: String) -> Bool {
        let sanitizedStyle = sanitizedContainerCalloutStyle(style)
        let docmostCalloutStyles: Set<String> = ["default", "info", "note", "success", "warning", "danger"]
        let docmostFenceStyles: Set<String> = ["info", "success", "warning", "danger"]
        return docmostCalloutStyles.contains(sanitizedStyle) && docmostFenceStyles.contains(sanitizedStyle) == false
    }

    private static func calloutHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard
            let attributes = htmlTagAttributes(from: lines[index], tagName: "div"),
            attributes["data-type"]?.localizedCaseInsensitiveCompare("callout") == .orderedSame
        else {
            return nil
        }

        let body = htmlContainerBody(in: lines, startingAt: index, tagName: "div")
        guard let body else { return nil }

        let contentNodes = containerContentNodes(from: body.lines)
        let callout = NativeEditorCalloutBlock(
            style: sanitizedContainerCalloutStyle(attributes["data-callout-type"] ?? "info"),
            icon: nonEmptyContainerHTMLAttribute(attributes["data-callout-icon"]),
            previewText: containerPreviewText(from: contentNodes)
        )
        return (
            containerBlock(
                kind: .callout(callout),
                rawNode: calloutHTMLNode(from: callout, content: contentNodes)
            ),
            body.endIndex
        )
    }

    private static func detailsContainerHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.localizedCaseInsensitiveCompare("<details>") != .orderedSame,
              let attributes = htmlTagAttributes(from: line, tagName: "details") else {
            return nil
        }

        guard let body = htmlContainerBody(in: lines, startingAt: index, tagName: "details") else {
            return nil
        }

        let detailsHTML = body.lines.joined(separator: "\n")
        let contentLines = containerDivBody(in: detailsHTML, dataType: "detailsContent")
            .map(containerBodyLines(from:)) ?? []
        let contentNodes = containerContentNodes(from: contentLines)
        let summary = containerSummaryText(in: body.lines) ?? "Details"
        let details = NativeEditorDetailsBlock(
            summary: summary,
            previewText: containerPreviewText(from: contentNodes),
            isOpen: attributes.keys.contains("open")
        )

        return (
            containerBlock(
                kind: .details(details),
                rawNode: detailsHTMLNode(from: details, content: contentNodes)
            ),
            body.endIndex
        )
    }

    private static func mathBlockHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard
            let attributes = htmlTagAttributes(from: lines[index], tagName: "div"),
            attributes["data-type"]?.localizedCaseInsensitiveCompare("mathBlock") == .orderedSame,
            attributes.keys.contains("data-katex")
        else {
            return nil
        }

        let body = htmlContainerBody(in: lines, startingAt: index, tagName: "div")
        guard let body else { return nil }

        let math = NativeEditorMathBlock(text: containerBodyText(from: body.lines))
        return (
            containerBlock(kind: .mathBlock(math), rawNode: NativeEditorRichBlockNodeFactory.mathBlockNode(from: math)),
            body.endIndex
        )
    }

    static func unsupportedDocmostHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard
            let container = htmlContainerElement(in: lines, startingAt: index, tagName: "div"),
            let type = nonEmptyContainerHTMLAttribute(container.attributes["data-type"]),
            isKnownDocmostHTMLDataType(type) == false
        else {
            return nil
        }

        let contentNodes = containerContentNodes(from: container.bodyLines)
        let rawNode = ProseMirrorNode(
            type: type,
            attrs: unsupportedDocmostHTMLAttrs(from: container.attributes),
            content: contentNodes.isEmpty ? nil : contentNodes
        )
        return (
            NativeEditorBlock(
                kind: .unsupported(type: type),
                text: AttributedString(NativeEditorDocument.previewText(for: .unsupported(type: type))),
                alignment: .left,
                rawNode: rawNode
            ),
            container.endIndex
        )
    }

    private static func calloutHTMLMarkdown(from callout: NativeEditorCalloutBlock) -> String {
        let openingTag = containerHTMLTag("div", attributes: [
            ("data-type", "callout"),
            ("data-callout-type", sanitizedContainerCalloutStyle(callout.style)),
            ("data-callout-icon", callout.icon)
        ])

        return """
        \(openingTag)
        \(escapedInlineHTMLText(callout.previewText.trimmingCharacters(in: .whitespacesAndNewlines)))
        </div>
        """
    }

    private static func detailsHTMLMarkdown(from details: NativeEditorDetailsBlock) -> String {
        let openingTag = containerHTMLTag("details", attributes: [
            ("open", details.isOpen ? "" : nil)
        ])
        let summary = escapedInlineHTMLText(details.summary.trimmingCharacters(in: .whitespacesAndNewlines))
        let body = escapedInlineHTMLText(details.previewText.trimmingCharacters(in: .whitespacesAndNewlines))

        return """
        \(openingTag)
        <summary data-type="detailsSummary">\(summary)</summary>
        <div data-type="detailsContent">
        \(body)
        </div>
        </details>
        """
    }

    static func htmlContainerBody(
        in lines: [String],
        startingAt index: Array<String>.Index,
        tagName: String
    ) -> (lines: [String], endIndex: Array<String>.Index)? {
        let line = lines[index]
        if let inlineBody = inlineHTMLBody(in: line, tagName: tagName) {
            return ([inlineBody], lines.index(after: index))
        }

        var bodyLines: [String] = []
        var depth = 1
        var currentIndex = lines.index(after: index)
        while currentIndex < lines.endIndex {
            let currentLine = lines[currentIndex]
            let nextDepth = depth + htmlTagDepthDelta(in: currentLine, tagName: tagName)
            if nextDepth <= 0 {
                if let bodyPrefix = htmlLinePrefixBeforeClosingTag(in: currentLine, tagName: tagName) {
                    bodyLines.append(bodyPrefix)
                }
                return (bodyLines, lines.index(after: currentIndex))
            }

            bodyLines.append(currentLine)
            depth = nextDepth
            currentIndex = lines.index(after: currentIndex)
        }

        return nil
    }

    private static func inlineHTMLBody(in line: String, tagName: String) -> String? {
        guard
            containsHTMLClosingTag(in: line, tagName: tagName),
            let openingEnd = line.firstIndex(of: ">"),
            let closingRange = line.range(of: "</\(tagName)>", options: [.caseInsensitive, .backwards])
        else {
            return nil
        }

        let bodyStart = line.index(after: openingEnd)
        guard bodyStart <= closingRange.lowerBound else { return "" }
        return String(line[bodyStart..<closingRange.lowerBound])
    }

    private static func htmlLinePrefixBeforeClosingTag(in line: String, tagName: String) -> String? {
        guard let closingRange = line.range(of: "</\(tagName)>", options: [.caseInsensitive, .backwards]) else {
            return nil
        }

        let prefix = String(line[..<closingRange.lowerBound])
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : prefix
    }

    private static func containerSummaryText(from line: String) -> String? {
        guard
            line.localizedCaseInsensitiveContains("<summary"),
            line.localizedCaseInsensitiveContains("</summary>"),
            let openingEnd = line.firstIndex(of: ">"),
            let closingRange = line.range(of: "</summary>", options: [.caseInsensitive, .backwards])
        else {
            return nil
        }

        let contentStart = line.index(after: openingEnd)
        guard contentStart <= closingRange.lowerBound else { return "" }
        return unescapedInlineHTMLText(String(line[contentStart..<closingRange.lowerBound]))
    }

    private static func containerBodyText(from lines: [String]) -> String {
        lines.compactMap(containerBodyLineText(from:))
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containerBodyLineText(from line: String) -> String? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLine.isEmpty == false else { return nil }

        if trimmedLine.localizedCaseInsensitiveCompare("<p>") == .orderedSame ||
            trimmedLine.localizedCaseInsensitiveCompare("</p>") == .orderedSame {
            return nil
        }

        if let paragraphText = paragraphHTMLText(from: trimmedLine) {
            return paragraphText
        }

        return unescapedInlineHTMLText(trimmedLine)
    }

    private static func paragraphHTMLText(from line: String) -> String? {
        guard
            line.localizedCaseInsensitiveContains("<p"),
            line.localizedCaseInsensitiveContains("</p>"),
            let openingEnd = line.firstIndex(of: ">"),
            let closingRange = line.range(of: "</p>", options: [.caseInsensitive, .backwards])
        else {
            return nil
        }

        let contentStart = line.index(after: openingEnd)
        guard contentStart <= closingRange.lowerBound else { return "" }
        return unescapedInlineHTMLText(String(line[contentStart..<closingRange.lowerBound]))
    }

    private static func containerSummaryText(in lines: [String]) -> String? {
        lines.lazy
            .compactMap { line in
                containerSummaryText(from: line.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .first
    }

    static func containerContentNodes(from lines: [String]) -> [ProseMirrorNode] {
        let html = lines.joined(separator: "\n")
        if let nodes = htmlTablePreservedContent(from: html, dropsSinglePlainParagraph: false) {
            return nodes
        }

        let text = containerBodyText(from: lines)
        guard text.isEmpty == false else { return [] }
        return [containerParagraphNode(text)]
    }

    static func containerPreviewText(from nodes: [ProseMirrorNode]) -> String {
        nodes.map { NativeEditorDocument.plainText(in: [$0]) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")
    }

    private static func calloutHTMLNode(
        from callout: NativeEditorCalloutBlock,
        content: [ProseMirrorNode]
    ) -> ProseMirrorNode {
        var attrs: [String: ProseMirrorJSONValue] = ["type": .string(callout.style)]
        if let icon = callout.icon {
            attrs["icon"] = .string(icon)
        }

        return ProseMirrorNode(
            type: "callout",
            attrs: attrs,
            content: content.isEmpty ? [containerParagraphNode(callout.previewText)] : content
        )
    }

    private static func detailsHTMLNode(
        from details: NativeEditorDetailsBlock,
        content: [ProseMirrorNode]
    ) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "details",
            attrs: ["open": .bool(details.isOpen)],
            content: [
                ProseMirrorNode(
                    type: "detailsSummary",
                    content: NativeEditorDocument.inlineNodes(from: inlineText(from: details.summary))
                ),
                ProseMirrorNode(
                    type: "detailsContent",
                    content: content.isEmpty ? [containerParagraphNode(details.previewText)] : content
                )
            ]
        )
    }

    private static func containerParagraphNode(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "paragraph",
            content: NativeEditorDocument.inlineNodes(from: inlineText(from: text))
        )
    }

    private static func containerDivBody(in html: String, dataType: String) -> String? {
        let tags = htmlRegexMatches(pattern: #"</?div\b[^>]*>"#, in: html)
        for (index, tag) in tags.enumerated() {
            guard let tagText = htmlRegexString(match: tag, captureIndex: 0, in: html),
                  containerDivTagIsClosing(tagText) == false,
                  containerDivTagIsSelfClosing(tagText) == false else {
                continue
            }

            let attrs = docmostInlineHTMLAttributes(from: tagText)
            guard attrs["data-type"]?.localizedCaseInsensitiveCompare(dataType) == .orderedSame else {
                continue
            }

            return containerDivBody(in: html, tags: tags, openingTagIndex: index)
        }

        return nil
    }

    private static func containerDivBody(
        in html: String,
        tags: [NSTextCheckingResult],
        openingTagIndex: Int
    ) -> String? {
        let openingTag = tags[openingTagIndex]
        var depth = 0

        for currentTag in tags[openingTagIndex...] {
            guard let tagText = htmlRegexString(match: currentTag, captureIndex: 0, in: html) else {
                continue
            }

            if containerDivTagIsClosing(tagText) {
                depth -= 1
                if depth == 0 {
                    return containerHTMLBody(in: html, openingTag: openingTag, closingTag: currentTag)
                }
            } else if containerDivTagIsSelfClosing(tagText) == false {
                depth += 1
            }
        }

        return nil
    }

    private static func containerHTMLBody(
        in html: String,
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

    static func containerBodyLines(from html: String) -> [String] {
        html.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private static func containerDivTagIsClosing(_ tagText: String) -> Bool {
        tagText.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("</")
    }

    private static func containerDivTagIsSelfClosing(_ tagText: String) -> Bool {
        tagText.trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix("/>")
    }

    private static func containerBlock(kind: NativeEditorBlockKind, rawNode: ProseMirrorNode) -> NativeEditorBlock {
        NativeEditorBlock(
            kind: kind,
            text: AttributedString(NativeEditorDocument.previewText(for: kind)),
            alignment: .left,
            rawNode: rawNode
        )
    }

    private static func containerHTMLTag(_ name: String, attributes: [(String, String?)]) -> String {
        let attributeText = attributes.compactMap { key, value -> String? in
            guard let value else { return nil }
            return #"\#(key)="\#(escapedInlineHTMLAttribute(value))""#
        }.joined(separator: " ")

        return attributeText.isEmpty ? "<\(name)>" : "<\(name) \(attributeText)>"
    }

    private static func nonEmptyContainerHTMLAttribute(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else {
            return nil
        }
        return value
    }

    private static func unsupportedDocmostHTMLAttrs(
        from attributes: [String: String]
    ) -> [String: ProseMirrorJSONValue]? {
        let rawAttrs = attributes.reduce(into: [String: ProseMirrorJSONValue]()) { result, attribute in
            guard attribute.key.hasPrefix("data-"),
                  attribute.key != "data-type" else {
                return
            }

            let dataAttributeName = String(attribute.key.dropFirst("data-".count))
            let key = proseMirrorAttrName(fromDocmostDataAttributeName: dataAttributeName)
            guard key.isEmpty == false else { return }
            result[key] = .string(attribute.value)
        }

        return rawAttrs.isEmpty ? nil : rawAttrs
    }

    private struct HTMLContainerElement {
        var attributes: [String: String]
        var bodyLines: [String]
        var endIndex: Array<String>.Index
    }

    private struct NormalizedHTMLContainerLines {
        var attributes: [String: String]
        var lines: [String]
        var openingEndIndex: Array<String>.Index
    }

    private static func htmlContainerElement(
        in lines: [String],
        startingAt index: Array<String>.Index,
        tagName: String
    ) -> HTMLContainerElement? {
        guard let normalized = normalizedHTMLContainerLines(in: lines, startingAt: index, tagName: tagName),
              let body = htmlContainerBody(
                in: normalized.lines,
                startingAt: normalized.lines.startIndex,
                tagName: tagName
              )
        else {
            return nil
        }

        let endIndex = normalized.openingEndIndex + body.endIndex
        guard endIndex <= lines.endIndex else { return nil }
        return HTMLContainerElement(
            attributes: normalized.attributes,
            bodyLines: body.lines,
            endIndex: endIndex
        )
    }

    private static func normalizedHTMLContainerLines(
        in lines: [String],
        startingAt index: Array<String>.Index,
        tagName: String
    ) -> NormalizedHTMLContainerLines? {
        guard lineStartsWithOpeningHTMLTag(lines[index], tagName: tagName) else {
            return nil
        }

        var openingLines: [String] = []
        var currentIndex = index

        while currentIndex < lines.endIndex {
            openingLines.append(lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines))
            let normalizedOpeningLine = openingLines.joined(separator: " ")
            if let attributes = htmlTagAttributes(from: normalizedOpeningLine, tagName: tagName) {
                var normalizedLines = [normalizedOpeningLine]
                normalizedLines.append(contentsOf: lines[lines.index(after: currentIndex)..<lines.endIndex])
                return NormalizedHTMLContainerLines(
                    attributes: attributes,
                    lines: normalizedLines,
                    openingEndIndex: currentIndex
                )
            }

            currentIndex = lines.index(after: currentIndex)
        }

        return nil
    }

    private static func isKnownDocmostHTMLDataType(_ type: String) -> Bool {
        knownDocmostHTMLDataTypes.contains {
            $0.localizedCaseInsensitiveCompare(type) == .orderedSame
        }
    }

    private static func lineStartsWithOpeningHTMLTag(_ line: String, tagName: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedLine = trimmedLine.lowercased()
        let prefix = "<\(tagName.lowercased())"
        guard lowercasedLine.hasPrefix(prefix) else { return false }

        let boundaryIndex = trimmedLine.index(trimmedLine.startIndex, offsetBy: prefix.count)
        return boundaryIndex == trimmedLine.endIndex ||
            trimmedLine[boundaryIndex].isWhitespace ||
            trimmedLine[boundaryIndex] == ">" ||
            trimmedLine[boundaryIndex] == "/"
    }

    private static var knownDocmostHTMLDataTypes: [String] {
        [
            "attachment",
            "base-embed",
            "callout",
            "column",
            "columns",
            "detailsContent",
            "detailsSummary",
            "drawio",
            "embed",
            "excalidraw",
            "mathBlock",
            "pageBreak",
            "pdf",
            "subpages",
            "taskItem",
            "taskList",
            "transclusionReference",
            "transclusionSource"
        ]
    }

    private static func sanitizedContainerCalloutStyle(_ value: String) -> String {
        let sanitizedScalars = value.lowercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }
        let sanitized = String(String.UnicodeScalarView(sanitizedScalars))
        return sanitized.isEmpty ? "info" : sanitized
    }
}
