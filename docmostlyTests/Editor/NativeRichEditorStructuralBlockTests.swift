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
            widthMode: "wide",
            columnTexts: ["Plan", "Build", "Ship"]
        )

        let node = viewModel.document.proseMirrorDocument.content[0]
        #expect(node.type == "columns")
        #expect(node.attrs?["layout"] == .string("three_equal"))
        #expect(node.attrs?["widthMode"] == .string("wide"))
        #expect(node.content?.count == 3)
        #expect(node.content?[0].content?.first?.content?.first?.text == "Plan")
        #expect(node.content?[1].content?.first?.content?.first?.text == "Build")
        #expect(node.content?[2].content?.first?.content?.first?.text == "Ship")
    }

    @Test func updatesFiveColumnBlockWithoutDroppingFinalColumn() {
        let viewModel = structuralBlockViewModel()
        let blockID = viewModel.document.blocks[0].id

        viewModel.updateColumns(
            blockID: blockID,
            layout: "five_equal",
            widthMode: "normal",
            columnTexts: ["Plan", "Build", "Review", "Launch", "Measure"]
        )

        let node = viewModel.document.proseMirrorDocument.content[0]
        #expect(node.type == "columns")
        #expect(node.attrs?["layout"] == .string("five_equal"))
        #expect(node.content?.count == 5)
        #expect(node.content?[4].content?.first?.content?.first?.text == "Measure")
    }

    @Test func updateColumnsNormalizesUnsupportedWidthModeToDocmostDefault() {
        let viewModel = structuralBlockViewModel()
        let blockID = viewModel.document.blocks[0].id

        viewModel.updateColumns(
            blockID: blockID,
            layout: "two_equal",
            widthMode: "full",
            columnTexts: ["Plan", "Ship"]
        )

        let node = viewModel.document.proseMirrorDocument.content[0]
        #expect(node.attrs?["widthMode"] == .string("normal"))
    }

    @Test func columnsNodePadsTextsAndWidthsToColumnCount() {
        let columns = NativeEditorColumnsBlock(
            layout: "three_equal",
            widthMode: "normal",
            columnCount: 3,
            previewText: "Plan",
            columnTexts: ["Plan"],
            columnWidths: [2]
        )
        let node = NativeEditorRichBlockNodeFactory.columnsNode(from: columns)

        #expect(node.content?.count == 3)
        #expect(node.content?[0].attrs?["width"] == .int(2))
        #expect(node.content?[1].attrs?["width"] == .null)
        #expect(node.content?[2].attrs?["width"] == .null)
        #expect(node.content?[0].content?.first?.content?.first?.text == "Plan")
        #expect(node.content?[1].content?.first?.content?.first?.text == nil)
        #expect(node.content?[2].content?.first?.content?.first?.text == nil)
    }

    @Test func columnsBlockEqualityNormalizesMissingWidths() {
        let columnsWithoutWidths = NativeEditorColumnsBlock(
            layout: "three_equal",
            widthMode: "normal",
            columnCount: 3,
            previewText: "Plan",
            columnTexts: ["Plan"]
        )
        let columnsWithNilWidths = NativeEditorColumnsBlock(
            layout: "three_equal",
            widthMode: "normal",
            columnCount: 3,
            previewText: "Plan",
            columnTexts: ["Plan"],
            columnWidths: [nil, nil, nil]
        )

        #expect(columnsWithoutWidths == columnsWithNilWidths)
        #expect(Set([columnsWithoutWidths, columnsWithNilWidths]).count == 1)
    }

    @Test func columnsNormalizationClampsDeclaredCountToDocmostMaximum() {
        let malformedColumns = NativeEditorColumnsBlock(
            layout: "five_equal",
            widthMode: "normal",
            columnCount: 999,
            previewText: "Plan",
            columnTexts: ["Plan"]
        )
        let maximumColumns = NativeEditorColumnsBlock(
            layout: "five_equal",
            widthMode: "normal",
            columnCount: 5,
            previewText: "Plan",
            columnTexts: ["Plan"]
        )

        let node = NativeEditorRichBlockNodeFactory.columnsNode(from: malformedColumns)
        #expect(node.content?.count == 5)
        #expect(malformedColumns == maximumColumns)
        #expect(Set([malformedColumns, maximumColumns]).count == 1)
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
