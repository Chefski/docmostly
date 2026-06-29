import Foundation
import Testing
@testable import docmostly

@MainActor
struct TableHTMLStructuralImportTests {
    @Test func docmostHTMLTableCellPreservesStructuralBlocks() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td>
        <div data-type="mathBlock" data-katex="true">E = mc^2</div>
        <div data-type="base-embed" data-page-id="base-page-1"></div>
        <div data-type="transclusionReference" data-source-page-id="source-page-1"
        data-transclusion-id="transclusion-1"></div>
        <div data-type="transclusionSource" data-id="source-1">
        Shared requirement
        </div>
        <div data-type="subpages"></div>
        </td>
        </tr>
        </tbody>
        </table>
        """

        let imported = try importedStructuralTableCell(from: markdown)
        let preservedContent = try #require(imported.cell.preservedContent)

        #expect(preservedContent.map(\.type) == [
            "mathBlock",
            "base",
            "transclusionReference",
            "transclusionSource",
            "subpages"
        ])
        expectMathBlock(preservedContent[0])
        expectBaseBlock(preservedContent[1])
        expectTransclusionReference(preservedContent[2])
        expectTransclusionSource(preservedContent[3])
        #expect(preservedContent[4].attrs == nil)

        #expect(imported.nodeContent.map(\.type) == preservedContent.map(\.type))
        #expect(imported.nodeContent[0].attrs?["text"] == .string("E = mc^2"))
        #expect(imported.nodeContent[1].attrs?["pageId"] == .string("base-page-1"))
        #expect(imported.nodeContent[2].attrs?["transclusionId"] == .string("transclusion-1"))
        #expect(imported.nodeContent[3].attrs?["id"] == .string("source-1"))
    }
}

@MainActor
private func importedStructuralTableCell(
    from markdown: String
) throws -> (cell: NativeEditorTableCell, nodeContent: [ProseMirrorNode]) {
    let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
    guard case .table(let table) = block.kind else {
        Issue.record("Expected Docmost HTML table to import as a native table block.")
        return (NativeEditorTableCell(plainText: "", isHeader: false, backgroundColorName: nil), [])
    }

    let cell = try #require(table.rows.first?.cells.first)
    let node = NativeEditorDocument.node(from: block)
    let cellContent = try #require(node.content?.first?.content?.first?.content)
    return (cell, cellContent)
}

private func expectMathBlock(_ node: ProseMirrorNode) {
    #expect(node.attrs?["text"] == .string("E = mc^2"))
}

private func expectBaseBlock(_ node: ProseMirrorNode) {
    #expect(node.attrs?["pageId"] == .string("base-page-1"))
}

private func expectTransclusionReference(_ node: ProseMirrorNode) {
    #expect(node.attrs?["sourcePageId"] == .string("source-page-1"))
    #expect(node.attrs?["transclusionId"] == .string("transclusion-1"))
}

private func expectTransclusionSource(_ node: ProseMirrorNode) {
    #expect(node.attrs?["id"] == .string("source-1"))
    #expect(node.content?.first?.type == "paragraph")
    #expect(node.content?.first?.content?.first?.text == "Shared requirement")
}
