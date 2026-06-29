import Foundation

extension NativeEditorMarkdownParser {
    static func tableBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        if let htmlTable = htmlTableBlock(in: lines, startingAt: index) {
            return htmlTable
        }

        let separatorIndex = lines.index(after: index)
        guard
            separatorIndex < lines.endIndex,
            let headerCells = markdownTableCells(from: lines[index]),
            let separatorAlignments = markdownTableSeparatorColumnAlignments(
                from: lines[separatorIndex],
                columnCount: headerCells.count
            )
        else {
            return nil
        }

        let columnCount = min(headerCells.count, NativeEditorTable.maximumColumnCount)
        let columnAlignments = normalizedTableColumnAlignments(separatorAlignments, columnCount: columnCount)
        var rows = [
            tableRow(
                from: headerCells,
                isHeader: true,
                columnCount: columnCount,
                columnAlignments: columnAlignments
            )
        ]
        var currentIndex = lines.index(after: separatorIndex)

        while currentIndex < lines.endIndex, rows.count < NativeEditorTable.maximumRowCount {
            let line = lines[currentIndex]
            guard
                let cells = markdownTableCells(from: line),
                isMarkdownTableSeparatorRow(line, columnCount: columnCount) == false
            else {
                break
            }

            rows.append(
                tableRow(
                    from: cells,
                    isHeader: false,
                    columnCount: columnCount,
                    columnAlignments: columnAlignments
                )
            )
            currentIndex = lines.index(after: currentIndex)
        }

        let table = NativeEditorTable(rows: rows)
        return (
            NativeEditorBlock(
                kind: .table(table),
                text: AttributedString(NativeEditorDocument.previewText(for: .table(table))),
                alignment: .left,
                rawNode: NativeEditorTableNodeFactory.node(from: table)
            ),
            currentIndex
        )
    }

    static func tableMarkdown(from table: NativeEditorTable) -> String {
        guard let headerRow = table.rows.first else { return "" }

        let columnCount = max(table.columnCount, 1)
        let rows = [
            markdownTableRow(from: headerRow, columnCount: columnCount),
            markdownTableSeparatorRow(columnAlignments: tableColumnAlignments(from: table, columnCount: columnCount))
        ] + table.rows.dropFirst().map {
            markdownTableRow(from: $0, columnCount: columnCount)
        }

        return rows.joined(separator: "\n")
    }

    private static func tableRow(
        from cells: [String],
        isHeader: Bool,
        columnCount: Int,
        columnAlignments: [NativeEditorTextAlignment?] = []
    ) -> NativeEditorTableRow {
        let normalizedCells = normalizedTableCells(cells, columnCount: columnCount)
        return NativeEditorTableRow(
            cells: normalizedCells.enumerated().map { offset, cell in
                let textAlignment = columnAlignments.indices.contains(offset) ? columnAlignments[offset] : nil
                return tableCell(from: cell, isHeader: isHeader, textAlignment: textAlignment)
            }
        )
    }

    private static func tableCell(
        from markdown: String,
        isHeader: Bool,
        textAlignment: NativeEditorTextAlignment?
    ) -> NativeEditorTableCell {
        let attributedText = inlineText(from: markdown)
        let inlineContent = NativeEditorDocument
            .inlineContent(from: NativeEditorDocument.inlineNodes(from: attributedText))
            .preservedForTableCell

        return NativeEditorTableCell(
            plainText: String(attributedText.characters),
            inlineContent: inlineContent,
            isHeader: isHeader,
            textAlignment: textAlignment,
            backgroundColorName: nil
        )
    }

    private static func normalizedTableCells(_ cells: [String], columnCount: Int) -> [String] {
        var result = Array(cells.prefix(columnCount))

        if result.count < columnCount {
            result.append(contentsOf: Array(repeating: "", count: columnCount - result.count))
        }

        return result
    }

    private static func markdownTableCells(from line: String) -> [String]? {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        guard trimmedLine.contains("|") else { return nil }

        var cells = splitMarkdownTableCells(from: trimmedLine)

        if trimmedLine.first == "|", cells.first?.isEmpty == true {
            cells.removeFirst()
        }

        if trimmedLine.last == "|", cells.last?.isEmpty == true {
            cells.removeLast()
        }

        let trimmedCells = cells.map { $0.trimmingCharacters(in: .whitespaces) }
        guard trimmedCells.isEmpty == false, trimmedCells.contains(where: { $0.isEmpty == false }) else {
            return nil
        }

        return trimmedCells
    }

    private static func splitMarkdownTableCells(from line: String) -> [String] {
        var cells = [""]
        var isEscaped = false
        let codeSpanRanges = markdownCodeSpanRanges(in: line[...], bodyStart: line.startIndex)
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]
            defer { index = line.index(after: index) }

            if isInsideMarkdownCodeSpan(index, ranges: codeSpanRanges) {
                cells[cells.count - 1].append(character)
                continue
            }

            if isEscaped {
                if character == "|" {
                    cells[cells.count - 1].append(character)
                } else if character == "\\" {
                    cells[cells.count - 1].append(character)
                } else {
                    cells[cells.count - 1].append("\\")
                    cells[cells.count - 1].append(character)
                }
                isEscaped = false
                continue
            }

            if character == "\\" {
                isEscaped = true
            } else if character == "|" {
                cells.append("")
            } else {
                cells[cells.count - 1].append(character)
            }
        }

        if isEscaped {
            cells[cells.count - 1].append("\\")
        }

        return cells
    }

    private static func isMarkdownTableSeparatorRow(_ line: String, columnCount: Int) -> Bool {
        markdownTableSeparatorColumnAlignments(from: line, columnCount: columnCount) != nil
    }

    private static func markdownTableSeparatorColumnAlignments(
        from line: String,
        columnCount: Int
    ) -> [NativeEditorTextAlignment?]? {
        guard
            columnCount > 0,
            let cells = markdownTableCells(from: line),
            cells.count == columnCount
        else {
            return nil
        }

        guard cells.allSatisfy(isMarkdownTableSeparatorCell) else { return nil }
        return cells.map(markdownTableSeparatorAlignment)
    }

    private static func isMarkdownTableSeparatorCell(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        let separator = trimmedText.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        guard separator.count >= 3 else { return false }
        return separator.allSatisfy { $0 == "-" }
    }

    private static func markdownTableSeparatorAlignment(from text: String) -> NativeEditorTextAlignment? {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)

        switch (trimmedText.first == ":", trimmedText.last == ":") {
        case (true, true):
            return .center
        case (false, true):
            return .right
        case (true, false):
            return .left
        case (false, false):
            return nil
        }
    }

    private static func markdownTableRow(from row: NativeEditorTableRow, columnCount: Int) -> String {
        let cells = normalizedTableCells(row.cells.map(markdownTableCellContent), columnCount: columnCount)
        return "| \(cells.map(escapedMarkdownTableCell).joined(separator: " | ")) |"
    }

    private static func markdownTableCellContent(from cell: NativeEditorTableCell) -> String {
        guard
            let inlineContent = cell.inlineContent,
            tableCellCanExportInlineMarkdown(cell)
        else {
            return cell.plainText
        }

        if tableCellInlineContentContainsUnsafeLink(inlineContent) {
            return markdownTableInlineContent(from: inlineContent)
        }

        return inlineMarkdown(from: NativeEditorDocument.attributedText(from: inlineContent))
    }

    private static func tableCellCanExportInlineMarkdown(_ cell: NativeEditorTableCell) -> Bool {
        guard let preservedContent = cell.preservedContent else { return true }
        let hasUnsupportedInlineContent = cell.inlineContent?.contains(where: isUnsupportedInlineContent) ?? false
        guard preservedContent.count == 1,
              let paragraph = preservedContent.first,
              paragraph.type == "paragraph",
              hasUnsupportedInlineContent == false else {
            return false
        }

        let attrs = paragraph.attrs ?? [:]
        return attrs.keys.allSatisfy { $0 == "textAlign" }
    }

    private static func isUnsupportedInlineContent(_ item: NativeEditorInlineContent) -> Bool {
        if case .unsupported = item {
            return true
        }

        return false
    }

    private static func tableCellInlineContentContainsUnsafeLink(
        _ inlineContent: [NativeEditorInlineContent]
    ) -> Bool {
        inlineContent.contains { item in
            guard case .text(_, let marks) = item else { return false }
            return marks.contains { mark in
                guard case .link(let href, _) = mark else { return false }
                return href.isEmpty == false && NativeEditorDocument.safeLinkURL(from: href) == nil
            }
        }
    }

    private static func markdownTableInlineContent(from inlineContent: [NativeEditorInlineContent]) -> String {
        inlineContent.map(markdownTableInlineContent).joined()
    }

    private static func markdownTableInlineContent(from item: NativeEditorInlineContent) -> String {
        guard case .text(let text, let marks) = item,
              let href = unsafeTableCellLinkHref(from: marks) else {
            return inlineMarkdown(from: NativeEditorDocument.attributedText(from: item))
        }

        let nonLinkMarks = marks.filter { mark in
            guard case .link = mark else { return true }
            return false
        }
        var segment = AttributedString(text)
        NativeEditorDocument.apply(nonLinkMarks, to: &segment)
        let label = escapedMarkdownTableLinkLabel(inlineMarkdown(from: segment))
        return "[\(label)](\(markdownTableLinkDestination(from: href)))"
    }

    private static func unsafeTableCellLinkHref(from marks: [NativeEditorTextMark]) -> String? {
        marks.compactMap { mark -> String? in
            guard case .link(let href, _) = mark,
                  href.isEmpty == false,
                  NativeEditorDocument.safeLinkURL(from: href) == nil else {
                return nil
            }

            return href
        }
        .first
    }

    private static func tableColumnAlignments(
        from table: NativeEditorTable,
        columnCount: Int
    ) -> [NativeEditorTextAlignment?] {
        (0..<columnCount).map { columnIndex in
            table.rows.lazy.compactMap { row -> NativeEditorTextAlignment? in
                guard row.cells.indices.contains(columnIndex) else { return nil }
                return row.cells[columnIndex].textAlignment
            }
            .first
        }
    }

    private static func normalizedTableColumnAlignments(
        _ alignments: [NativeEditorTextAlignment?],
        columnCount: Int
    ) -> [NativeEditorTextAlignment?] {
        var result = Array(alignments.prefix(columnCount))

        if result.count < columnCount {
            result.append(contentsOf: Array(repeating: nil, count: columnCount - result.count))
        }

        return result
    }

    private static func markdownTableSeparatorRow(columnAlignments: [NativeEditorTextAlignment?]) -> String {
        let cells = columnAlignments.map(markdownTableSeparatorCell)
        return "| \(cells.joined(separator: " | ")) |"
    }

    private static func markdownTableSeparatorCell(for alignment: NativeEditorTextAlignment?) -> String {
        switch alignment {
        case .left:
            ":---"
        case .center:
            ":---:"
        case .right:
            "---:"
        case .justify, nil:
            "---"
        }
    }

    private static func escapedMarkdownTableCell(_ text: String) -> String {
        var output = ""
        var previousCharacter: Character?
        var isInsideAngleWrappedLinkDestination = false

        for character in text {
            if character == "<", previousCharacter == "(" {
                isInsideAngleWrappedLinkDestination = true
            }

            if character == "\\", isInsideAngleWrappedLinkDestination == false {
                output += "\\\\"
            } else if character == "|" {
                output += "\\|"
            } else if character == "\n" || character == "\r" {
                output += " "
            } else {
                output.append(character)
            }

            if character == ">", isInsideAngleWrappedLinkDestination {
                isInsideAngleWrappedLinkDestination = false
            }
            previousCharacter = character
        }

        return output
    }

    private static func escapedMarkdownTableLinkLabel(_ text: String) -> String {
        text
            .replacing("\\", with: "\\\\")
            .replacing("[", with: "\\[")
            .replacing("]", with: "\\]")
    }

    private static func markdownTableLinkDestination(from href: String) -> String {
        guard href.contains(where: requiresAngleWrappedMarkdownLinkDestination) else {
            return href
        }

        return "<\(escapedAngleWrappedMarkdownLinkDestination(href))>"
    }

    private static func requiresAngleWrappedMarkdownLinkDestination(_ character: Character) -> Bool {
        character.isWhitespace || character == "(" || character == ")" || character == "<" || character == ">"
    }

    private static func escapedAngleWrappedMarkdownLinkDestination(_ href: String) -> String {
        href
            .replacing("\n", with: " ")
            .replacing("\r", with: " ")
    }
}
