import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorStructuralHTMLFidelityTests {
    @Test func documentMarkdownConversionPreservesDocmostStructuralHTMLBlocks() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .subpages, text: AttributedString("Subpages"), alignment: .left),
            NativeEditorBlock(
                kind: .transclusionSource(NativeEditorTransclusionSourceBlock(
                    identifier: "sync-1",
                    previewText: "Reusable launch checklist"
                )),
                text: AttributedString("Reusable launch checklist"),
                alignment: .left
            ),
            NativeEditorBlock(
                kind: .transclusionReference(NativeEditorTransclusionReferenceBlock(
                    sourcePageID: "page-1",
                    transclusionID: "sync-1"
                )),
                text: AttributedString("Reusable launch checklist"),
                alignment: .left
            ),
            NativeEditorBlock(
                kind: .base(NativeEditorBaseBlock(
                    pageID: "base-page-1",
                    pendingKey: nil,
                    previewText: "Roadmap base"
                )),
                text: AttributedString("Roadmap base"),
                alignment: .left
            )
        ])
        viewModel.resetEditingHistory()

        #expect(viewModel.markdownForDocument() == """
        <div data-type="subpages"></div>
        <div data-type="transclusionSource" data-id="sync-1">
        Reusable launch checklist
        </div>
        <div data-type="transclusionReference" data-source-page-id="page-1" data-transclusion-id="sync-1"></div>
        <div data-type="base-embed" data-page-id="base-page-1"></div>
        """)
    }
}
