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

    private static func nonEmptyAttribute(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else {
            return nil
        }
        return value
    }
}
