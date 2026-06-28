import Foundation

extension NativeEditorMarkdownParser {
    static func tableBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        let separatorIndex = lines.index(after: index)
        guard
            separatorIndex < lines.endIndex,
            let headerCells = markdownTableCells(from: lines[index]),
            isMarkdownTableSeparatorRow(lines[separatorIndex], columnCount: headerCells.count)
        else {
            return nil
        }

        let columnCount = min(headerCells.count, NativeEditorTable.maximumColumnCount)
        var rows = [tableRow(from: headerCells, isHeader: true, columnCount: columnCount)]
        var currentIndex = lines.index(after: separatorIndex)

        while currentIndex < lines.endIndex, rows.count < NativeEditorTable.maximumRowCount {
            let line = lines[currentIndex]
            guard
                let cells = markdownTableCells(from: line),
                isMarkdownTableSeparatorRow(line, columnCount: columnCount) == false
            else {
                break
            }

            rows.append(tableRow(from: cells, isHeader: false, columnCount: columnCount))
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
            markdownTableSeparatorRow(columnCount: columnCount)
        ] + table.rows.dropFirst().map {
            markdownTableRow(from: $0, columnCount: columnCount)
        }

        return rows.joined(separator: "\n")
    }

    private static func tableRow(
        from cells: [String],
        isHeader: Bool,
        columnCount: Int
    ) -> NativeEditorTableRow {
        NativeEditorTableRow(
            cells: normalizedTableCells(cells, columnCount: columnCount).map {
                tableCell(from: $0, isHeader: isHeader)
            }
        )
    }

    private static func tableCell(from markdown: String, isHeader: Bool) -> NativeEditorTableCell {
        let attributedText = inlineText(from: markdown)
        let inlineContent = NativeEditorDocument
            .inlineContent(from: NativeEditorDocument.inlineNodes(from: attributedText))
            .preservedForTableCell

        return NativeEditorTableCell(
            plainText: String(attributedText.characters),
            inlineContent: inlineContent,
            isHeader: isHeader,
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

        var cells = [""]
        var isEscaped = false

        for character in trimmedLine {
            if isEscaped {
                if character == "|" {
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

    private static func isMarkdownTableSeparatorRow(_ line: String, columnCount: Int) -> Bool {
        guard
            columnCount > 0,
            let cells = markdownTableCells(from: line),
            cells.count == columnCount
        else {
            return false
        }

        return cells.allSatisfy(isMarkdownTableSeparatorCell)
    }

    private static func isMarkdownTableSeparatorCell(_ text: String) -> Bool {
        let trimmedText = text.trimmingCharacters(in: .whitespaces)
        let separator = trimmedText.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        guard separator.count >= 3 else { return false }
        return separator.allSatisfy { $0 == "-" }
    }

    private static func markdownTableRow(from row: NativeEditorTableRow, columnCount: Int) -> String {
        let cells = normalizedTableCells(row.cells.map(markdownTableCellContent), columnCount: columnCount)
        return "| \(cells.map(escapedMarkdownTableCell).joined(separator: " | ")) |"
    }

    private static func markdownTableCellContent(from cell: NativeEditorTableCell) -> String {
        guard cell.preservedContent == nil, let inlineContent = cell.inlineContent else {
            return cell.plainText
        }

        return inlineMarkdown(from: NativeEditorDocument.attributedText(from: inlineContent))
    }

    private static func markdownTableSeparatorRow(columnCount: Int) -> String {
        "| \(Array(repeating: "---", count: columnCount).joined(separator: " | ")) |"
    }

    private static func escapedMarkdownTableCell(_ text: String) -> String {
        text.replacing("\\", with: "\\\\")
            .replacing("|", with: "\\|")
            .replacing("\n", with: " ")
            .replacing("\r", with: " ")
    }
}
