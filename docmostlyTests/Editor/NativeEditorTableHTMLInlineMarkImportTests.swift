import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorTableInlineMarkTests {
    @Test func docmostHTMLTableCellPreservesStandardInlineHTMLMarks() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td><p>Use <strong>bold</strong>, <em>italic</em>, <code>code</code>, and <s>old</s></p></td>
        </tr>
        </tbody>
        </table>
        """

        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let table) = block.kind else {
            Issue.record("Expected Docmost HTML table to import as a native table block.")
            return
        }

        let cell = try #require(table.rows.first?.cells.first)
        #expect(cell.plainText == "Use bold, italic, code, and old")
        #expect(cell.inlineContent == [
            .text("Use ", marks: []),
            .text("bold", marks: [.bold]),
            .text(", ", marks: []),
            .text("italic", marks: [.italic]),
            .text(", ", marks: []),
            .text("code", marks: [.code]),
            .text(", and ", marks: []),
            .text("old", marks: [.strikethrough])
        ])

        let node = NativeEditorDocument.node(from: block)
        let content = try #require(node.content?.first?.content?.first?.content?.first?.content)
        #expect(content.map(\.text) == ["Use ", "bold", ", ", "italic", ", ", "code", ", and ", "old"])
        #expect(content[1].marks == [ProseMirrorMark(type: "bold")])
        #expect(content[3].marks == [ProseMirrorMark(type: "italic")])
        #expect(content[5].marks == [ProseMirrorMark(type: "code")])
        #expect(content[7].marks == [ProseMirrorMark(type: "strike")])
    }
}
