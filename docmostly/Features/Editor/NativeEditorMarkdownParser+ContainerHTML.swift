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
            callout.icon == nil ? nil : calloutHTMLMarkdown(from: callout)
        case .details(let details):
            detailsHTMLMarkdown(from: details)
        case .mathBlock(let math):
            mathBlockHTMLMarkdown(from: math)
        default:
            nil
        }
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

        let callout = NativeEditorCalloutBlock(
            style: sanitizedContainerCalloutStyle(attributes["data-callout-type"] ?? "info"),
            icon: nonEmptyContainerHTMLAttribute(attributes["data-callout-icon"]),
            previewText: containerBodyText(from: body.lines)
        )
        return (
            containerBlock(
                kind: .callout(callout),
                rawNode: NativeEditorRichBlockNodeFactory.calloutNode(from: callout)
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

        var summary = "Details"
        var contentLines: [String] = []
        var isInDetailsContent = false
        var currentIndex = lines.index(after: index)

        while currentIndex < lines.endIndex {
            let currentLine = lines[currentIndex]
            let trimmedLine = currentLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if containsHTMLClosingTag(in: trimmedLine, tagName: "details") {
                let details = NativeEditorDetailsBlock(
                    summary: summary,
                    previewText: containerBodyText(from: contentLines),
                    isOpen: attributes.keys.contains("open")
                )
                return (
                    containerBlock(
                        kind: .details(details),
                        rawNode: NativeEditorRichBlockNodeFactory.detailsNode(from: details)
                    ),
                    lines.index(after: currentIndex)
                )
            }

            if let parsedSummary = containerSummaryText(from: trimmedLine) {
                summary = parsedSummary
            } else if isDetailsContentOpeningLine(trimmedLine) {
                isInDetailsContent = true
            } else if isInDetailsContent, containsHTMLClosingTag(in: trimmedLine, tagName: "div") {
                isInDetailsContent = false
            } else if isInDetailsContent || trimmedLine.isEmpty == false {
                contentLines.append(currentLine)
            }

            currentIndex = lines.index(after: currentIndex)
        }

        return nil
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

    private static func mathBlockHTMLMarkdown(from math: NativeEditorMathBlock) -> String {
        let text = escapedInlineHTMLText(math.text.trimmingCharacters(in: .whitespacesAndNewlines))
        return #"<div data-type="mathBlock" data-katex="true">\#(text)</div>"#
    }

    private static func htmlContainerBody(
        in lines: [String],
        startingAt index: Array<String>.Index,
        tagName: String
    ) -> (lines: [String], endIndex: Array<String>.Index)? {
        let line = lines[index]
        if let inlineBody = inlineHTMLBody(in: line, tagName: tagName) {
            return ([inlineBody], lines.index(after: index))
        }

        var bodyLines: [String] = []
        var currentIndex = lines.index(after: index)
        while currentIndex < lines.endIndex {
            let currentLine = lines[currentIndex]
            if containsHTMLClosingTag(in: currentLine, tagName: tagName) {
                if let bodyPrefix = htmlLinePrefixBeforeClosingTag(in: currentLine, tagName: tagName) {
                    bodyLines.append(bodyPrefix)
                }
                return (bodyLines, lines.index(after: currentIndex))
            }

            bodyLines.append(currentLine)
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

    private static func isDetailsContentOpeningLine(_ line: String) -> Bool {
        guard let attributes = htmlTagAttributes(from: line, tagName: "div") else {
            return false
        }

        return attributes["data-type"]?.localizedCaseInsensitiveCompare("detailsContent") == .orderedSame
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

    private static func sanitizedContainerCalloutStyle(_ value: String) -> String {
        let sanitizedScalars = value.lowercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }
        let sanitized = String(String.UnicodeScalarView(sanitizedScalars))
        return sanitized.isEmpty ? "info" : sanitized
    }
}
