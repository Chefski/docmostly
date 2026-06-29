import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorTableHTMLImportTests {
    @Test func docmostHTMLTableImportsAsNativeTableBlock() throws {
        let markdown = """
        <div class="tableWrapper">
        <table>
        <thead>
        <tr>
        <th colspan="2" colwidth="120,160" data-background-color="#DBEAFE" data-background-color-name="blue">
        <p style="text-align: center">Phase</p>
        </th>
        </tr>
        </thead>
        <tbody>
        <tr>
        <td data-background-color="#FEF3C7" data-background-color-name="yellow"><p>Build</p></td>
        <td><p>Taylor</p></td>
        </tr>
        </tbody>
        </table>
        </div>
        """

        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let table) = block.kind else {
            Issue.record("Expected Docmost HTML table to import as a native table block.")
            return
        }

        #expect(table.rows.count == 2)
        #expect(table.rows[0].cells.count == 1)
        #expect(table.rows[0].cells[0].plainText == "Phase")
        #expect(table.rows[0].cells[0].isHeader)
        #expect(table.rows[0].cells[0].textAlignment == .center)
        #expect(table.rows[0].cells[0].backgroundColor == "#DBEAFE")
        #expect(table.rows[0].cells[0].backgroundColorName == "blue")
        #expect(table.rows[0].cells[0].columnSpan == 2)
        #expect(table.rows[0].cells[0].columnWidths == [120, 160])
        #expect(table.rows[1].cells.map(\.plainText) == ["Build", "Taylor"])
        #expect(table.rows[1].cells[0].backgroundColor == "#FEF3C7")
        #expect(table.rows[1].cells[0].backgroundColorName == "yellow")

        let node = NativeEditorDocument.node(from: block)
        #expect(node.type == "table")
        let headerCell = try #require(node.content?.first?.content?.first)
        #expect(headerCell.type == "tableHeader")
        #expect(headerCell.attrs?["colspan"] == .int(2))
        #expect(headerCell.attrs?["colwidth"] == .array([.int(120), .int(160)]))
        #expect(headerCell.attrs?["backgroundColor"] == .string("#DBEAFE"))
        #expect(headerCell.attrs?["backgroundColorName"] == .string("blue"))
    }
}
