import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorTableMixedContentTests {
    @Test func docmostHTMLTableCellPreservesInlineSiblingsAroundCodeBlock() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td>Before <strong>code</strong><pre><code class="language-swift">let value = 1</code></pre>After code</td>
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
        let preservedContent = try #require(cell.preservedContent)
        #expect(cell.plainText == "Before codelet value = 1After code")
        #expect(preservedContent.map(\.type) == ["paragraph", "codeBlock", "paragraph"])
        let leadingParagraph = try #require(preservedContent.first)
        let codeBlock = try #require(preservedContent.dropFirst().first)
        let trailingParagraph = try #require(preservedContent.dropFirst(2).first)
        #expect(leadingParagraph.content?.map(\.text) == ["Before ", "code"])
        #expect(leadingParagraph.content?.dropFirst().first?.marks == [ProseMirrorMark(type: "bold")])
        #expect(codeBlock.attrs?["language"] == .string("swift"))
        #expect(codeBlock.content?.first?.text == "let value = 1")
        #expect(trailingParagraph.content?.first?.text == "After code")

        let node = NativeEditorDocument.node(from: block)
        let cellContent = try #require(node.content?.first?.content?.first?.content)
        #expect(cellContent.map(\.type) == ["paragraph", "codeBlock", "paragraph"])
        let encodedLeadingParagraph = try #require(cellContent.first)
        let encodedCodeBlock = try #require(cellContent.dropFirst().first)
        let encodedTrailingParagraph = try #require(cellContent.dropFirst(2).first)
        #expect(encodedLeadingParagraph.content?.map(\.text) == ["Before ", "code"])
        #expect(encodedLeadingParagraph.content?.dropFirst().first?.marks == [ProseMirrorMark(type: "bold")])
        #expect(encodedCodeBlock.content?.first?.text == "let value = 1")
        #expect(encodedTrailingParagraph.content?.first?.text == "After code")
    }
}
