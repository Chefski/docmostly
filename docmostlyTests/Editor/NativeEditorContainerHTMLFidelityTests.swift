import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorContainerHTMLFidelityTests {
    @Test func importsDocmostCalloutDetailsAndMathHTMLAsNativeBlocks() throws {
        let markdown = """
        <div data-type="callout" data-callout-type="warning" data-callout-icon="rocket">
        Launch checklist
        </div>
        <details open="">
        <summary data-type="detailsSummary">Release notes</summary>
        <div data-type="detailsContent">
        Ship build
        </div>
        </details>
        <div data-type="mathBlock" data-katex="true">E = mc^2</div>
        """
        let blocks = NativeEditorMarkdownParser.blocks(from: markdown)

        try #require(blocks.count == 3)

        guard case .callout(let callout) = blocks[0].kind else {
            Issue.record("Expected Docmost callout HTML to import as a native callout block.")
            return
        }
        #expect(callout.style == "warning")
        #expect(callout.icon == "rocket")
        #expect(callout.previewText == "Launch checklist")
        #expect(blocks[0].rawNode?.type == "callout")
        #expect(blocks[0].rawNode?.attrs?["type"] == .string("warning"))
        #expect(blocks[0].rawNode?.attrs?["icon"] == .string("rocket"))

        guard case .details(let details) = blocks[1].kind else {
            Issue.record("Expected Docmost details HTML to import as a native details block.")
            return
        }
        #expect(details.summary == "Release notes")
        #expect(details.previewText == "Ship build")
        #expect(details.isOpen == true)
        #expect(blocks[1].rawNode?.type == "details")
        #expect(blocks[1].rawNode?.attrs?["open"] == .bool(true))

        guard case .mathBlock(let math) = blocks[2].kind else {
            Issue.record("Expected Docmost math block HTML to import as a native math block.")
            return
        }
        #expect(math.text == "E = mc^2")
        #expect(blocks[2].rawNode?.type == "mathBlock")
        #expect(blocks[2].rawNode?.attrs?["text"] == .string("E = mc^2"))
    }

    @Test func importedDocmostDetailsPreservesStructuredContentBlocks() throws {
        let markdown = """
        <details open="">
        <summary data-type="detailsSummary">Release notes</summary>
        <div data-type="detailsContent">
        <p>Ship build</p>
        <div data-type="pageBreak" class="page-break"></div>
        <p>Confirm smoke test</p>
        </div>
        </details>
        """
        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        guard case .details(let details) = block.kind else {
            Issue.record("Expected Docmost details HTML to import as a native details block.")
            return
        }

        let contentNode = try #require(block.rawNode?.content?.first { $0.type == "detailsContent" })
        let childTypes = contentNode.content?.map(\.type)

        #expect(details.summary == "Release notes")
        #expect(details.previewText == "Ship build\nConfirm smoke test")
        #expect(childTypes == ["paragraph", "pageBreak", "paragraph"])
    }

    @Test func importedDocmostCalloutPreservesStructuredContentBlocks() throws {
        let markdown = """
        <div data-type="callout" data-callout-type="warning" data-callout-icon="rocket">
        <p>Check migration plan</p>
        <div data-type="pageBreak" class="page-break"></div>
        <p>Confirm rollback owner</p>
        </div>
        """
        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        guard case .callout(let callout) = block.kind else {
            Issue.record("Expected Docmost callout HTML to import as a native callout block.")
            return
        }

        let childTypes = block.rawNode?.content?.map(\.type)

        #expect(callout.style == "warning")
        #expect(callout.icon == "rocket")
        #expect(callout.previewText == "Check migration plan\nConfirm rollback owner")
        #expect(childTypes == ["paragraph", "pageBreak", "paragraph"])
    }

    @Test func exportsNativeCalloutDetailsAsDocmostHTMLAndMathAsFenceMarkdown() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(
                kind: .callout(NativeEditorCalloutBlock(
                    style: "warning",
                    icon: "rocket",
                    previewText: "Launch checklist"
                )),
                text: AttributedString("Launch checklist"),
                alignment: .left
            ),
            NativeEditorBlock(
                kind: .details(NativeEditorDetailsBlock(
                    summary: "Release notes",
                    previewText: "Ship build",
                    isOpen: true
                )),
                text: AttributedString("Release notes"),
                alignment: .left
            ),
            NativeEditorBlock(
                kind: .mathBlock(NativeEditorMathBlock(text: "E = mc^2")),
                text: AttributedString("E = mc^2"),
                alignment: .left
            )
        ])
        viewModel.resetEditingHistory()

        #expect(viewModel.markdownForDocument() == """
        <div data-type="callout" data-callout-type="warning" data-callout-icon="rocket">
        Launch checklist
        </div>
        <details open="">
        <summary data-type="detailsSummary">Release notes</summary>
        <div data-type="detailsContent">
        Ship build
        </div>
        </details>
        $$
        E = mc^2
        $$
        """)
    }

    @Test func exportsSingleLineIconlessNativeCalloutAsDocmostFenceMarkdown() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(
                kind: .callout(NativeEditorCalloutBlock(
                    style: "info",
                    icon: nil,
                    previewText: "Check migration plan"
                )),
                text: AttributedString("Check migration plan"),
                alignment: .left
            )
        ])
        viewModel.resetEditingHistory()

        #expect(viewModel.markdownForDocument() == """
        :::info
        Check migration plan
        :::
        """)
    }

    @Test func exportsIconlessNativeCalloutAsDocmostFenceMarkdown() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(
                kind: .callout(NativeEditorCalloutBlock(
                    style: "warning",
                    icon: nil,
                    previewText: """
                    Check migration plan
                    Confirm rollback owner
                    """
                )),
                text: AttributedString("Check migration plan"),
                alignment: .left
            )
        ])
        viewModel.resetEditingHistory()

        #expect(viewModel.markdownForDocument() == """
        :::warning
        Check migration plan
        Confirm rollback owner
        :::
        """)
    }
}
