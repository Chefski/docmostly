import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorStructuralBlockTests {
    @Test func updatesColumnsBlockWithNativeColumnText() {
        let viewModel = structuralBlockViewModel()
        let blockID = viewModel.document.blocks[0].id

        viewModel.updateColumns(
            blockID: blockID,
            layout: "three_equal",
            widthMode: "full",
            columnTexts: ["Plan", "Build", "Ship"]
        )

        let node = viewModel.document.proseMirrorDocument.content[0]
        #expect(node.type == "columns")
        #expect(node.attrs?["layout"] == .string("three_equal"))
        #expect(node.attrs?["widthMode"] == .string("full"))
        #expect(node.content?.count == 3)
        #expect(node.content?[0].content?.first?.content?.first?.text == "Plan")
        #expect(node.content?[1].content?.first?.content?.first?.text == "Build")
        #expect(node.content?[2].content?.first?.content?.first?.text == "Ship")
    }

    @Test func updatesSyncedBlockIdentifiers() {
        let viewModel = structuralBlockViewModel()
        let sourceID = viewModel.document.blocks[1].id
        let referenceID = viewModel.document.blocks[2].id

        viewModel.updateTransclusionSource(
            blockID: sourceID,
            identifier: "sync-2",
            text: "Shared launch plan"
        )
        viewModel.updateTransclusionReference(
            blockID: referenceID,
            sourcePageID: "page-2",
            transclusionID: "sync-2"
        )

        let nodes = viewModel.document.proseMirrorDocument.content
        #expect(nodes[1].type == "transclusionSource")
        #expect(nodes[1].attrs?["id"] == .string("sync-2"))
        #expect(nodes[1].content?.first?.content?.first?.text == "Shared launch plan")

        #expect(nodes[2].type == "transclusionReference")
        #expect(nodes[2].attrs?["sourcePageId"] == .string("page-2"))
        #expect(nodes[2].attrs?["transclusionId"] == .string("sync-2"))
    }

    private func structuralBlockViewModel() -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [
            columnsBlock(),
            transclusionSourceBlock(),
            transclusionReferenceBlock()
        ])
        return viewModel
    }

    private func columnsBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .columns(NativeEditorColumnsBlock(
                layout: "two_equal",
                widthMode: "normal",
                columnCount: 2,
                previewText: "Left Right",
                columnTexts: ["Left", "Right"]
            )),
            text: AttributedString("Left Right"),
            alignment: .left,
            rawNode: ProseMirrorNode(type: "columns")
        )
    }

    private func transclusionSourceBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .transclusionSource(NativeEditorTransclusionSourceBlock(
                identifier: "sync-1",
                previewText: "Shared plan"
            )),
            text: AttributedString("Shared plan"),
            alignment: .left,
            rawNode: ProseMirrorNode(type: "transclusionSource")
        )
    }

    private func transclusionReferenceBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .transclusionReference(NativeEditorTransclusionReferenceBlock(
                sourcePageID: "page-1",
                transclusionID: "sync-1"
            )),
            text: AttributedString("sync-1"),
            alignment: .left,
            rawNode: ProseMirrorNode(type: "transclusionReference")
        )
    }
}
