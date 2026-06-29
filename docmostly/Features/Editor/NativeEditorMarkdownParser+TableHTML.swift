import Foundation

extension NativeEditorMarkdownParser {
    static func htmlTableBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard isHTMLTableStartLine(lines[index]),
              let htmlTable = htmlTableHTML(in: lines, startingAt: index) else {
            return nil
        }

        let rows = htmlTableRows(from: htmlTable.html)
        guard rows.isEmpty == false else { return nil }

        let table = NativeEditorTable(rows: rows)
        return (
            NativeEditorBlock(
                kind: .table(table),
                text: AttributedString(NativeEditorDocument.previewText(for: .table(table))),
                alignment: .left,
                rawNode: NativeEditorTableNodeFactory.node(from: table)
            ),
            htmlTable.endIndex
        )
    }

    private static func isHTMLTableStartLine(_ line: String) -> Bool {
        if htmlTagAttributes(from: line, tagName: "table") != nil {
            return true
        }

        guard let attrs = htmlTagAttributes(from: line, tagName: "div"),
              let className = attrs["class"] else {
            return false
        }

        return className.split(whereSeparator: \.isWhitespace).contains("tableWrapper")
    }

    private static func htmlTableHTML(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (html: String, endIndex: Array<String>.Index)? {
        let startsWithWrapper = htmlTagAttributes(from: lines[index], tagName: "div")?["class"]?
            .split(whereSeparator: \.isWhitespace)
            .contains("tableWrapper") ?? false
        var tableLines: [String] = []
        var sawTable = false
        var currentIndex = index

        while currentIndex < lines.endIndex {
            let line = lines[currentIndex]
            tableLines.append(line)

            if firstHTMLTagAttributes(in: line, tagName: "table") != nil {
                sawTable = true
            }

            if sawTable, containsHTMLClosingTag(in: line, tagName: "table") {
                var endIndex = lines.index(after: currentIndex)
                if startsWithWrapper,
                   endIndex < lines.endIndex,
                   containsHTMLClosingTag(in: lines[endIndex], tagName: "div") {
                    tableLines.append(lines[endIndex])
                    endIndex = lines.index(after: endIndex)
                }
                return (tableLines.joined(separator: "\n"), endIndex)
            }

            currentIndex = lines.index(after: currentIndex)
        }

        return nil
    }

    private static func htmlTableRows(from html: String) -> [NativeEditorTableRow] {
        htmlTableRowBodies(from: html).compactMap { rowHTML in
            let cells = htmlTableCells(from: rowHTML)
            return cells.isEmpty ? nil : NativeEditorTableRow(cells: cells)
        }
    }

    private static func htmlTableRowBodies(from html: String) -> [String] {
        htmlRegexMatches(pattern: #"<tr\b[^>]*>(.*?)</tr>"#, in: html).compactMap {
            htmlRegexString(match: $0, captureIndex: 1, in: html)
        }
    }

    private static func htmlTableCells(from rowHTML: String) -> [NativeEditorTableCell] {
        htmlRegexMatches(pattern: #"<(th|td)\b([^>]*)>(.*?)</\1>"#, in: rowHTML)
            .prefix(NativeEditorTable.maximumColumnCount)
            .compactMap { match in
                guard let tagName = htmlRegexString(match: match, captureIndex: 1, in: rowHTML),
                      let attributeText = htmlRegexString(match: match, captureIndex: 2, in: rowHTML),
                      let body = htmlRegexString(match: match, captureIndex: 3, in: rowHTML) else {
                    return nil
                }

                return htmlTableCell(tagName: tagName, attributeText: attributeText, body: body)
            }
    }

    private static func htmlTableCell(tagName: String, attributeText: String, body: String) -> NativeEditorTableCell {
        let attrs = docmostInlineHTMLAttributes(from: "<\(tagName)\(attributeText)>")
        let paragraphAttrs = htmlTableParagraphAttributes(in: body)
        let plainText = htmlTablePlainText(from: body)

        return NativeEditorTableCell(
            plainText: plainText,
            isHeader: tagName.localizedCaseInsensitiveCompare("th") == .orderedSame,
            textAlignment: htmlTableTextAlignment(from: paragraphAttrs),
            backgroundColor: nonEmptyHTMLTableAttribute(attrs["data-background-color"]) ??
                htmlStyleValue(named: "background-color", in: attrs["style"]),
            backgroundColorName: nonEmptyHTMLTableAttribute(attrs["data-background-color-name"]),
            columnSpan: htmlTableSpan(from: attrs["colspan"]),
            rowSpan: htmlTableSpan(from: attrs["rowspan"]),
            columnWidths: htmlTableColumnWidths(from: attrs)
        )
    }

    private static func htmlTableParagraphAttributes(in html: String) -> [String: String] {
        guard let match = htmlRegexMatches(pattern: #"<p\b([^>]*)>"#, in: html).first,
              let attributeText = htmlRegexString(match: match, captureIndex: 1, in: html) else {
            return [:]
        }

        return docmostInlineHTMLAttributes(from: "<p\(attributeText)>")
    }

    private static func htmlTableTextAlignment(from attrs: [String: String]) -> NativeEditorTextAlignment? {
        let value = nonEmptyHTMLTableAttribute(attrs["align"]) ??
            htmlStyleValue(named: "text-align", in: attrs["style"])
        guard let value else { return nil }
        return NativeEditorTextAlignment(rawValue: value.lowercased())
    }

    private static func htmlTablePlainText(from html: String) -> String {
        let paragraphSeparated = htmlRegexReplacing(
            pattern: #"</p>\s*<p\b[^>]*>"#,
            in: html,
            with: "\n"
        )
        let hardBreakSeparated = htmlRegexReplacing(
            pattern: #"<br\s*/?>"#,
            in: paragraphSeparated,
            with: "\n"
        )
        let withoutTags = htmlRegexReplacing(pattern: #"<[^>]+>"#, in: hardBreakSeparated, with: "")
        return unescapedInlineHTMLText(withoutTags).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func htmlTableSpan(from value: String?) -> Int {
        max(Int(value ?? "") ?? 1, 1)
    }

    private static func htmlTableColumnWidths(from attrs: [String: String]) -> [Int] {
        guard let value = nonEmptyHTMLTableAttribute(attrs["colwidth"] ?? attrs["data-colwidth"]) else {
            return []
        }

        return value.split { character in
            character == "," || character.isWhitespace
        }
        .compactMap { Int($0) }
    }

    private static func htmlStyleValue(named name: String, in style: String?) -> String? {
        guard let style else { return nil }
        let normalizedName = name.lowercased()

        for declaration in style.split(separator: ";") {
            let parts = declaration.split(separator: ":", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2, parts[0].lowercased() == normalizedName else {
                continue
            }

            return parts[1].isEmpty ? nil : parts[1]
        }

        return nil
    }

    private static func htmlRegexMatches(pattern: String, in text: String) -> [NSTextCheckingResult] {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        return expression.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
    }

    private static func htmlRegexString(
        match: NSTextCheckingResult,
        captureIndex: Int,
        in text: String
    ) -> String? {
        let range = match.range(at: captureIndex)
        guard range.location != NSNotFound,
              let textRange = Range(range, in: text) else {
            return nil
        }

        return String(text[textRange])
    }

    private static func htmlRegexReplacing(pattern: String, in text: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    private static func nonEmptyHTMLTableAttribute(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else { return nil }
        return value
    }
}
