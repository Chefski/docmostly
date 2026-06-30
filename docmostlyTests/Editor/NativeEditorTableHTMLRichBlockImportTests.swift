import Foundation
import Testing
@testable import docmostly

@MainActor
struct TableHTMLRichBlockImportTests {
    @Test func docmostHTMLTableCellPreservesEmbedAndDiagramContent() throws {
        let markdown = """
        <table>
        <tbody>
        <tr>
        <td>
        <div data-type="embed" data-src="https://www.figma.com/file/design"
        data-provider="figma" data-align="center" data-width="640" data-height="360">
        <a href="https://www.figma.com/file/design" target="blank">Figma</a>
        </div>
        <div data-type="drawio" data-src="/api/files/drawio-1/diagram.drawio.svg"
        data-title="System map" data-alt="Architecture map" data-width="100%"
        data-height="480" data-size="2048" data-aspect-ratio="1.7777778"
        data-align="right" data-attachment-id="drawio-1">
        <img src="/api/files/drawio-1/diagram.drawio.svg" alt="Architecture map" width="100%">
        </div>
        <div data-type="excalidraw" data-src="/api/files/excalidraw-1/diagram.excalidraw.svg"
        data-title="Sketch" data-alt="Wireframe" data-width="720"
        data-height="405" data-size="4096" data-aspect-ratio="1.7777778"
        data-align="center" data-attachment-id="excalidraw-1">
        <img src="/api/files/excalidraw-1/diagram.excalidraw.svg" alt="Wireframe" width="720">
        </div>
        </td>
        </tr>
        </tbody>
        </table>
        """

        let imported = try importedSingleTableCell(from: markdown)
        let preservedContent = try #require(imported.cell.preservedContent)

        #expect(imported.cell.plainText.isEmpty)
        #expect(preservedContent.map(\.type) == ["embed", "drawio", "excalidraw"])
        expectEmbedNode(preservedContent[0])
        expectDrawioNode(preservedContent[1])
        expectExcalidrawNode(preservedContent[2])

        #expect(imported.nodeContent.map(\.type) == ["embed", "drawio", "excalidraw"])
        #expect(imported.nodeContent[0].attrs?["provider"] == .string("figma"))
        #expect(imported.nodeContent[1].attrs?["attachmentId"] == .string("drawio-1"))
        #expect(imported.nodeContent[2].attrs?["attachmentId"] == .string("excalidraw-1"))
    }
}

@MainActor
private func importedSingleTableCell(
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

private func expectEmbedNode(_ node: ProseMirrorNode) {
    #expect(node.attrs?["src"] == .string("https://www.figma.com/file/design"))
    #expect(node.attrs?["provider"] == .string("figma"))
    #expect(node.attrs?["align"] == .string("center"))
    #expect(node.attrs?["width"] == .int(640))
    #expect(node.attrs?["height"] == .int(360))
}

private func expectDrawioNode(_ node: ProseMirrorNode) {
    #expect(node.attrs?["src"] == .string("/api/files/drawio-1/diagram.drawio.svg"))
    #expect(node.attrs?["title"] == .string("System map"))
    #expect(node.attrs?["alt"] == .string("Architecture map"))
    #expect(node.attrs?["width"] == .string("100%"))
    #expect(node.attrs?["height"] == .int(480))
    #expect(node.attrs?["size"] == .int(2_048))
    #expect(node.attrs?["aspectRatio"] == .double(1.7777778))
    #expect(node.attrs?["align"] == .string("right"))
    #expect(node.attrs?["attachmentId"] == .string("drawio-1"))
}

private func expectExcalidrawNode(_ node: ProseMirrorNode) {
    #expect(node.attrs?["src"] == .string("/api/files/excalidraw-1/diagram.excalidraw.svg"))
    #expect(node.attrs?["title"] == .string("Sketch"))
    #expect(node.attrs?["alt"] == .string("Wireframe"))
    #expect(node.attrs?["width"] == .int(720))
    #expect(node.attrs?["height"] == .int(405))
    #expect(node.attrs?["size"] == .int(4_096))
    #expect(node.attrs?["aspectRatio"] == .double(1.7777778))
    #expect(node.attrs?["align"] == .string("center"))
    #expect(node.attrs?["attachmentId"] == .string("excalidraw-1"))
}
