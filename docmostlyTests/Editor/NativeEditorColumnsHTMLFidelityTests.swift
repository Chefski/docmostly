import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorColumnsHTMLFidelityTests {
    @Test func importedDocmostColumnsPreserveStructuredColumnContent() throws {
        let markdown = """
        <div data-type="columns" data-layout="two_equal" data-width-mode="wide">
        <div data-type="column" data-width="2" style="flex: 2">
        <p>Plan rollout</p>
        <div data-type="pageBreak" class="page-break"></div>
        <p>Confirm metrics</p>
        </div>
        <div data-type="column" data-width="1" style="flex: 1">
        <p>Ship notes</p>
        </div>
        </div>
        """
        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        guard case .columns(let columns) = block.kind else {
            Issue.record("Expected Docmost columns HTML to import as a native columns block.")
            return
        }

        let columnNodes = try #require(block.rawNode?.content)

        #expect(columns.layout == "two_equal")
        #expect(columns.widthMode == "wide")
        #expect(columns.previewText == "Plan rollout\nConfirm metrics Ship notes")
        #expect(columns.columnTexts == ["Plan rollout\nConfirm metrics", "Ship notes"])
        #expect(columns.columnWidths == [2, 1])
        #expect(columnNodes.map(\.type) == ["column", "column"])
        #expect(columnNodes[0].attrs?["width"] == .int(2))
        #expect(columnNodes[1].attrs?["width"] == .int(1))
        #expect(columnNodes[0].content?.map(\.type) == ["paragraph", "pageBreak", "paragraph"])
        #expect(columnNodes[1].content?.map(\.type) == ["paragraph"])
    }

    @Test func importedDocmostColumnsExportStructuredColumnContent() throws {
        let markdown = """
        <div data-type="columns" data-layout="two_equal" data-width-mode="wide">
        <div data-type="column" data-width="2" style="flex: 2">
        <p>Plan rollout</p>
        <div data-type="pageBreak" class="page-break"></div>
        <p>Confirm metrics</p>
        </div>
        <div data-type="column" data-width="1" style="flex: 1">
        <p>Ship notes</p>
        </div>
        </div>
        """
        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        #expect(NativeEditorMarkdownParser.markdown(from: [block]) == markdown)
    }
}
