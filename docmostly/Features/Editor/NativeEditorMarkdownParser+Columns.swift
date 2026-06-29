import Foundation

extension NativeEditorMarkdownParser {
    static func columnsHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard let columnsAttributes = divAttributes(from: lines[index], dataType: "columns") else {
            return nil
        }

        guard let body = htmlContainerBody(in: lines, startingAt: index, tagName: "div") else {
            return nil
        }

        var columns: [ParsedColumnHTML] = []
        var currentIndex = body.lines.startIndex

        while currentIndex < body.lines.endIndex {
            let line = body.lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                currentIndex = body.lines.index(after: currentIndex)
                continue
            }

            guard let column = parsedColumnHTML(in: body.lines, startingAt: currentIndex) else {
                return nil
            }
            columns.append(column.column)
            currentIndex = column.endIndex
        }

        guard columns.isEmpty == false else { return nil }
        let columnsBlock = nativeColumnsBlock(from: columnsAttributes, columns: columns)
        return (
            NativeEditorBlock(
                kind: .columns(columnsBlock),
                text: AttributedString(columnsBlock.previewText),
                alignment: .left,
                rawNode: columnsHTMLNode(from: columnsAttributes, columns: columns)
            ),
            body.endIndex
        )
    }

    static func columnsMarkdown(from columns: NativeEditorColumnsBlock) -> String {
        let columnTexts = columns.normalizedColumnTexts
        let columnWidths = columns.normalizedColumnWidths
        let widthMode = columns.widthMode.isEmpty ? "normal" : columns.widthMode
        let widthModeAttribute = widthMode == "normal"
            ? ""
            : #" data-width-mode="\#(escapedInlineHTMLAttribute(widthMode))""#
        let layout = escapedInlineHTMLAttribute(columns.layout)
        let openingTag = #"<div data-type="columns" data-layout="\#(layout)"\#(widthModeAttribute)>"#
        let columnMarkup = zip(columnTexts, columnWidths).map { text, width in
            columnMarkdown(text: text, width: width ?? 1)
        }.joined(separator: "\n")

        return """
        \(openingTag)
        \(columnMarkup)
        </div>
        """
    }

    static func rawColumnsMarkdown(from node: ProseMirrorNode?) -> String? {
        guard
            let node,
            node.type == "columns",
            rawColumnsNeedsStructuredMarkdown(node)
        else {
            return nil
        }

        let layout = escapedInlineHTMLAttribute(node.attrs?["layout"]?.stringValue ?? "two_equal")
        let widthMode = node.attrs?["widthMode"]?.stringValue ?? "normal"
        let widthModeAttribute = widthMode == "normal"
            ? ""
            : #" data-width-mode="\#(escapedInlineHTMLAttribute(widthMode))""#
        let columnMarkup = (node.content ?? [])
            .filter { $0.type == "column" }
            .map(rawColumnMarkdown(from:))
            .joined(separator: "\n")
        guard columnMarkup.isEmpty == false else { return nil }

        return """
        <div data-type="columns" data-layout="\(layout)"\(widthModeAttribute)>
        \(columnMarkup)
        </div>
        """
    }

    private struct ParsedColumnHTML {
        var text: String
        var width: Double?
        var content: [ProseMirrorNode]
    }

    private static func parsedColumnHTML(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (column: ParsedColumnHTML, endIndex: Array<String>.Index)? {
        guard let columnAttributes = divAttributes(from: lines[index], dataType: "column") else {
            return nil
        }

        guard let body = htmlContainerBody(in: lines, startingAt: index, tagName: "div") else {
            return nil
        }

        let content = containerContentNodes(from: body.lines)
        return (
            ParsedColumnHTML(
                text: columnText(from: body.lines, content: content),
                width: columnAttributes["data-width"].flatMap(Double.init),
                content: content
            ),
            body.endIndex
        )
    }

    private static func nativeColumnsBlock(
        from attributes: [String: String],
        columns: [ParsedColumnHTML]
    ) -> NativeEditorColumnsBlock {
        let columnTexts = columns.map(\.text)
        let columnWidths = columns.map(\.width)
        return NativeEditorColumnsBlock(
            layout: nonEmptyAttribute(attributes["data-layout"]) ?? "two_equal",
            widthMode: nonEmptyAttribute(attributes["data-width-mode"]) ?? "normal",
            columnCount: columnTexts.count,
            previewText: columnTexts.joined(separator: " "),
            columnTexts: columnTexts,
            columnWidths: columnWidths
        )
    }

    private static func divAttributes(from line: String, dataType: String) -> [String: String]? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLine.lowercased().hasPrefix("<div") else { return nil }
        guard let tagEnd = trimmedLine.firstIndex(of: ">"), tagEnd > trimmedLine.startIndex else {
            return nil
        }

        let openingTag = String(trimmedLine[trimmedLine.startIndex..<tagEnd])
        let attributes = docmostInlineHTMLAttributes(from: openingTag)
        guard attributes["data-type"]?.localizedCaseInsensitiveCompare(dataType) == .orderedSame else {
            return nil
        }

        return attributes
    }

    private static func columnText(from lines: [String], content: [ProseMirrorNode]) -> String {
        let preservedText = containerPreviewText(from: content)
        if preservedText.isEmpty == false {
            return preservedText
        }

        return lines.compactMap(columnTextLine(from:))
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func columnTextLine(from line: String) -> String? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLine.isEmpty == false else { return nil }

        let lowercasedLine = trimmedLine.lowercased()
        if lowercasedLine.hasPrefix("<p"), lowercasedLine.hasSuffix("</p>"),
           let openingEnd = trimmedLine.firstIndex(of: ">"),
           let closingRange = trimmedLine.range(of: "</p>", options: [.caseInsensitive, .backwards]) {
            let contentStart = trimmedLine.index(after: openingEnd)
            return unescapedInlineHTMLText(String(trimmedLine[contentStart..<closingRange.lowerBound]))
        }

        return unescapedInlineHTMLText(trimmedLine)
    }

    private static func columnMarkdown(text: String, width: Double) -> String {
        let widthText = htmlNumber(width)
        return """
        <div data-type="column" data-width="\(widthText)" style="flex: \(widthText)">
        \(escapedInlineHTMLText(text.trimmingCharacters(in: .whitespacesAndNewlines)))
        </div>
        """
    }

    private static func rawColumnsNeedsStructuredMarkdown(_ node: ProseMirrorNode) -> Bool {
        (node.content ?? [])
            .filter { $0.type == "column" }
            .contains { column in
                rawColumnNeedsStructuredMarkdown(column)
            }
    }

    private static func rawColumnNeedsStructuredMarkdown(_ node: ProseMirrorNode) -> Bool {
        let content = node.content ?? []
        guard content.count == 1, let paragraph = content.first, paragraph.type == "paragraph" else {
            return true
        }

        return paragraph.attrs?.isEmpty == false
    }

    private static func rawColumnMarkdown(from node: ProseMirrorNode) -> String {
        let widthText = htmlNumber(from: node.attrs?["width"])
        let body = (node.content ?? [])
            .map(rawColumnContentMarkdown(from:))
            .joined(separator: "\n")

        return """
        <div data-type="column" data-width="\(widthText)" style="flex: \(widthText)">
        \(body)
        </div>
        """
    }

    private static func rawColumnContentMarkdown(from node: ProseMirrorNode) -> String {
        switch node.type {
        case "paragraph":
            "<p>\(rawInlineHTMLMarkdown(from: node.content ?? []))</p>"
        case "heading":
            rawHeadingMarkdown(from: node)
        case "pageBreak":
            #"<div data-type="pageBreak" class="page-break"></div>"#
        case "horizontalRule":
            "<hr>"
        case "codeBlock":
            rawCodeBlockMarkdown(from: node)
        default:
            escapedInlineHTMLText(NativeEditorDocument.plainText(in: [node]))
        }
    }

    private static func rawHeadingMarkdown(from node: ProseMirrorNode) -> String {
        let level = min(max(node.attrs?["level"]?.intValue ?? 1, 1), 6)
        return "<h\(level)>\(rawInlineHTMLMarkdown(from: node.content ?? []))</h\(level)>"
    }

    private static func rawCodeBlockMarkdown(from node: ProseMirrorNode) -> String {
        let language = node.attrs?["language"]?.stringValue
            .map { #" class="language-\#(escapedInlineHTMLAttribute($0))""# } ?? ""
        return "<pre><code\(language)>\(escapedInlineHTMLText(NativeEditorDocument.plainText(in: [node])))</code></pre>"
    }

    private static func rawInlineHTMLMarkdown(from nodes: [ProseMirrorNode]) -> String {
        nodes.map { node in
            switch node.type {
            case "text":
                escapedInlineHTMLText(node.text ?? "")
            case "hardBreak":
                "<br>"
            default:
                escapedInlineHTMLText(NativeEditorDocument.plainText(in: [node]))
            }
        }
        .joined()
    }

    private static func columnsHTMLNode(
        from attributes: [String: String],
        columns: [ParsedColumnHTML]
    ) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "columns",
            attrs: [
                "layout": .string(nonEmptyAttribute(attributes["data-layout"]) ?? "two_equal"),
                "widthMode": .string(nonEmptyAttribute(attributes["data-width-mode"]) ?? "normal")
            ],
            content: columns.map(columnHTMLNode(from:))
        )
    }

    private static func columnHTMLNode(from column: ParsedColumnHTML) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "column",
            attrs: ["width": proseMirrorNumber(from: column.width ?? 1)],
            content: column.content.isEmpty ? [
                ProseMirrorNode(
                    type: "paragraph",
                    content: NativeEditorDocument.inlineNodes(from: inlineText(from: column.text))
                )
            ] : column.content
        )
    }

    private static func proseMirrorNumber(from value: Double) -> ProseMirrorJSONValue {
        if value.rounded() == value, let intValue = Int(exactly: value) {
            return .int(intValue)
        }

        return .double(value)
    }

    private static func htmlNumber(_ value: Double) -> String {
        let text = String(value)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    private static func htmlNumber(from value: ProseMirrorJSONValue?) -> String {
        switch value {
        case .int(let width):
            String(width)
        case .double(let width):
            htmlNumber(width)
        case .string(let width):
            width.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "1" : width
        case .bool, .object, .array, .null, nil:
            "1"
        }
    }

    private static func nonEmptyAttribute(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else {
            return nil
        }
        return value
    }
}
