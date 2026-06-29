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

    @Test func docmostHTMLTableCellPreservesContainerStructuralBlocks() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td>
        <details open="">
        <summary data-type="detailsSummary">Release notes</summary>
        <div data-type="detailsContent">
        Ship native table support
        </div>
        </details>
        <div data-type="columns" data-layout="two_equal" data-width-mode="fixed">
        <div data-type="column" data-width="1" style="flex: 1">
        <p>First column</p>
        <div data-type="pageBreak" class="page-break"></div>
        <p>First follow-up</p>
        </div>
        <div data-type="column" data-width="2.5" style="flex: 2.5">
        Second column
        </div>
        </div>
        </td>
        </tr>
        </tbody>
        </table>
        """

        let imported = try importedStructuralTableCell(from: markdown)
        let preservedContent = try #require(imported.cell.preservedContent)

        #expect(preservedContent.map(\.type) == ["details", "columns"])
        expectDetailsBlock(preservedContent[0])
        expectColumnsBlock(preservedContent[1])

        #expect(imported.nodeContent.map(\.type) == preservedContent.map(\.type))
        #expect(imported.nodeContent[0].content?.first?.type == "detailsSummary")
        #expect(imported.nodeContent[1].content?.map(\.type) == ["column", "column"])
    }

    @Test func docmostHTMLTableCellPreservesPageBreakBlocks() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td>
        <div data-type="pageBreak" class="page-break"></div>
        </td>
        </tr>
        </tbody>
        </table>
        """

        let imported = try importedStructuralTableCell(from: markdown)
        let preservedContent = try #require(imported.cell.preservedContent)

        #expect(preservedContent.map(\.type) == ["pageBreak"])
        #expect(preservedContent.first?.attrs == nil)
        #expect(imported.nodeContent.map(\.type) == ["pageBreak"])
    }

    @Test func docmostHTMLTableCellPreservesTransclusionSourceStructuredContent() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td>
        <div data-type="transclusionSource" data-id="source-1">
        <p>Shared requirement</p>
        <div data-type="pageBreak" class="page-break"></div>
        <p>Shared follow-up</p>
        </div>
        </td>
        </tr>
        </tbody>
        </table>
        """

        let imported = try importedStructuralTableCell(from: markdown)
        let preservedContent = try #require(imported.cell.preservedContent)
        let transclusionSource = try #require(preservedContent.first)

        #expect(preservedContent.map(\.type) == ["transclusionSource"])
        #expect(transclusionSource.attrs?["id"] == .string("source-1"))
        #expect(transclusionSource.content?.map(\.type) == ["paragraph", "pageBreak", "paragraph"])
        #expect(transclusionSource.content?.first?.content?.first?.text == "Shared requirement")
        #expect(transclusionSource.content?[2].content?.first?.text == "Shared follow-up")
        #expect(imported.nodeContent.first?.content?.map(\.type) == ["paragraph", "pageBreak", "paragraph"])
    }

    @Test func docmostHTMLTableCellKeepsNestedStructuralBlocksInsideCallouts() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td>
        <div data-type="callout" data-callout-type="warning" data-callout-icon="rocket">
        <div data-type="mathBlock" data-katex="true">E = mc^2</div>
        </div>
        </td>
        </tr>
        </tbody>
        </table>
        """

        let imported = try importedStructuralTableCell(from: markdown)
        let preservedContent = try #require(imported.cell.preservedContent)
        let callout = try #require(preservedContent.first)
        let encodedCallout = try #require(imported.nodeContent.first)

        #expect(preservedContent.map(\.type) == ["callout"])
        #expect(callout.content?.map(\.type) == ["mathBlock"])
        #expect(callout.content?.first?.attrs?["text"] == .string("E = mc^2"))
        #expect(imported.nodeContent.map(\.type) == ["callout"])
        #expect(encodedCallout.content?.map(\.type) == ["mathBlock"])
        #expect(encodedCallout.content?.first?.attrs?["text"] == .string("E = mc^2"))
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

private func expectDetailsBlock(_ node: ProseMirrorNode) {
    #expect(node.attrs?["open"] == .bool(true))
    #expect(node.content?.map(\.type) == ["detailsSummary", "detailsContent"])
    #expect(node.content?.first?.content?.first?.text == "Release notes")
    #expect(node.content?[1].content?.first?.type == "paragraph")
    #expect(node.content?[1].content?.first?.content?.first?.text == "Ship native table support")
}

private func expectColumnsBlock(_ node: ProseMirrorNode) {
    #expect(node.attrs?["layout"] == .string("two_equal"))
    #expect(node.attrs?["widthMode"] == .string("fixed"))
    #expect(node.content?.count == 2)
    #expect(node.content?.first?.attrs?["width"] == .int(1))
    #expect(node.content?.first?.content?.first?.content?.first?.text == "First column")
    #expect(node.content?.first?.content?.map(\.type) == ["paragraph", "pageBreak", "paragraph"])
    #expect(node.content?.first?.content?[2].content?.first?.text == "First follow-up")
    #expect(node.content?[1].attrs?["width"] == .double(2.5))
    #expect(node.content?[1].content?.first?.content?.first?.text == "Second column")
}
