import Foundation

extension NativeEditorMarkdownParser {
    static func columnsHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard let columnsAttributes = divAttributes(from: lines[index], dataType: "columns") else {
            return nil
        }

        var columns: [ParsedColumnHTML] = []
        var currentIndex = lines.index(after: index)

        while currentIndex < lines.endIndex {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.localizedCaseInsensitiveCompare("</div>") == .orderedSame {
                guard columns.isEmpty == false else { return nil }
                let columnsBlock = nativeColumnsBlock(from: columnsAttributes, columns: columns)
                return (
                    NativeEditorBlock(
                        kind: .columns(columnsBlock),
                        text: AttributedString(columnsBlock.previewText),
                        alignment: .left,
                        rawNode: NativeEditorRichBlockNodeFactory.columnsNode(from: columnsBlock)
                    ),
                    lines.index(after: currentIndex)
                )
            }

            guard let column = parsedColumnHTML(in: lines, startingAt: currentIndex) else {
                return nil
            }
            columns.append(column.column)
            currentIndex = column.endIndex
        }

        return nil
    }

    static func columnsMarkdown(from columns: NativeEditorColumnsBlock) -> String {
        let columnTexts = normalizedColumnTexts(from: columns)
        let columnWidths = normalizedColumnWidths(from: columns, columnCount: columnTexts.count)
        let widthMode = columns.widthMode.isEmpty ? "normal" : columns.widthMode
        let widthModeAttribute = widthMode == "normal"
            ? ""
            : #" data-width-mode="\#(escapedInlineHTMLAttribute(widthMode))""#
        let layout = escapedInlineHTMLAttribute(columns.layout)
        let openingTag = #"<div data-type="columns" data-layout="\#(layout)\#(widthModeAttribute)>"#
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
    }

    private static func parsedColumnHTML(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (column: ParsedColumnHTML, endIndex: Array<String>.Index)? {
        guard let columnAttributes = divAttributes(from: lines[index], dataType: "column") else {
            return nil
        }

        var bodyLines: [String] = []
        var currentIndex = lines.index(after: index)

        while currentIndex < lines.endIndex {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.localizedCaseInsensitiveCompare("</div>") == .orderedSame {
                return (
                    ParsedColumnHTML(
                        text: columnText(from: bodyLines),
                        width: columnAttributes["data-width"].flatMap(Double.init)
                    ),
                    lines.index(after: currentIndex)
                )
            }

            bodyLines.append(lines[currentIndex])
            currentIndex = lines.index(after: currentIndex)
        }

        return nil
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

    private static func columnText(from lines: [String]) -> String {
        lines.compactMap(columnTextLine(from:))
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func columnTextLine(from line: String) -> String? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLine.isEmpty == false else { return nil }

        let lowercasedLine = trimmedLine.lowercased()
        if lowercasedLine.hasPrefix("<p"), lowercasedLine.hasSuffix("</p>"),
           let openingEnd = trimmedLine.firstIndex(of: ">"),
           let closingStart = lowercasedLine.range(of: "</p>", options: .backwards)?.lowerBound {
            return unescapedInlineHTMLText(String(trimmedLine[trimmedLine.index(after: openingEnd)..<closingStart]))
        }

        return unescapedInlineHTMLText(trimmedLine)
    }

    private static func normalizedColumnTexts(from columns: NativeEditorColumnsBlock) -> [String] {
        if columns.columnTexts.isEmpty == false {
            return Array(columns.columnTexts.prefix(max(columns.columnCount, 1)))
        }

        let columnCount = max(columns.columnCount, 1)
        let firstColumnText = columns.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
        return (0..<columnCount).map { index in index == 0 ? firstColumnText : "" }
    }

    private static func normalizedColumnWidths(
        from columns: NativeEditorColumnsBlock,
        columnCount: Int
    ) -> [Double?] {
        (0..<columnCount).map { index in
            columns.columnWidths.indices.contains(index) ? columns.columnWidths[index] : nil
        }
    }

    private static func columnMarkdown(text: String, width: Double) -> String {
        let widthText = htmlNumber(width)
        return """
        <div data-type="column" data-width="\(widthText)" style="flex: \(widthText)">
        \(escapedInlineHTMLText(text.trimmingCharacters(in: .whitespacesAndNewlines)))
        </div>
        """
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
