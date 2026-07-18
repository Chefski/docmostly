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

    @Test func containerPropertyUpdatesPreserveStructuredNestedContent() throws {
        let calloutNode = structuredCalloutNode()
        let detailsNode = structuredDetailsNode()
        let columnsNode = structuredColumnsNode()
        let syncedNode = structuredSyncedNode()
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(
            proseMirrorDocument: ProseMirrorDocument(content: [calloutNode, detailsNode, columnsNode, syncedNode])
        )
        let baselineNodes = viewModel.document.proseMirrorDocument.content

        let calloutID = viewModel.document.blocks[0].id
        let detailsID = viewModel.document.blocks[1].id
        let columnsID = viewModel.document.blocks[2].id
        let syncedID = viewModel.document.blocks[3].id
        let callout = try #require(viewModel.document.blocks[0].rawNode)
        let details = try #require(viewModel.document.blocks[1].rawNode)
        let columns = try #require(viewModel.document.blocks[2].rawNode)
        let synced = try #require(viewModel.document.blocks[3].rawNode)

        viewModel.updateCallout(
            blockID: calloutID,
            style: "warning",
            icon: "⚠️",
            text: NativeEditorDocument.plainText(in: callout.content ?? [])
        )
        viewModel.updateDetails(
            blockID: detailsID,
            summary: "More",
            body: NativeEditorDocument.plainText(in: details.content ?? []),
            isOpen: true
        )
        viewModel.updateColumns(
            blockID: columnsID,
            layout: "two_left_sidebar",
            widthMode: "wide",
            columnTexts: (columns.content ?? []).map { NativeEditorDocument.plainText(in: $0.content ?? []) }
        )
        viewModel.updateTransclusionSource(
            blockID: syncedID,
            identifier: "sync-2",
            text: NativeEditorDocument.plainText(in: synced.content ?? [])
        )

        let updatedNodes = viewModel.document.proseMirrorDocument.content
        #expect(updatedNodes[0].content == baselineNodes[0].content)
        #expect(updatedNodes[0].attrs?["type"] == .string("warning"))
        #expect(updatedNodes[1].content == baselineNodes[1].content)
        #expect(updatedNodes[1].attrs?["open"] == .bool(true))
        #expect(updatedNodes[2].content == baselineNodes[2].content)
        #expect(updatedNodes[2].attrs?["layout"] == .string("two_left_sidebar"))
        #expect(updatedNodes[3].content == baselineNodes[3].content)
        #expect(updatedNodes[3].attrs?["id"] == .string("sync-2"))
    }

    private func structuredCalloutNode() -> ProseMirrorNode {
        ProseMirrorNode(
            type: "callout",
            attrs: ["type": .string("info")],
            content: [
                ProseMirrorNode(
                    type: "heading",
                    attrs: ["level": .int(2)],
                    content: [ProseMirrorNode(type: "text", text: "Important")]
                ),
                ProseMirrorNode(
                    type: "bulletList",
                    content: [
                        ProseMirrorNode(
                            type: "listItem",
                            content: [
                                ProseMirrorNode(
                                    type: "paragraph",
                                    content: [ProseMirrorNode(type: "text", text: "Keep formatting")]
                                )
                            ]
                        )
                    ]
                )
            ]
        )
    }

    private func structuredDetailsNode() -> ProseMirrorNode {
        ProseMirrorNode(
            type: "details",
            attrs: ["open": .bool(false)],
            content: [
                ProseMirrorNode(
                    type: "detailsSummary",
                    content: [ProseMirrorNode(type: "text", text: "More")]
                ),
                ProseMirrorNode(
                    type: "detailsContent",
                    content: [structuredEmbedNode()]
                )
            ]
        )
    }

    private func structuredColumnsNode() -> ProseMirrorNode {
        ProseMirrorNode(
            type: "columns",
            attrs: ["layout": .string("two_equal"), "widthMode": .string("normal")],
            content: [
                ProseMirrorNode(
                    type: "column",
                    content: [
                        ProseMirrorNode(
                            type: "heading",
                            attrs: ["level": .int(3)],
                            content: [ProseMirrorNode(type: "text", text: "Left")]
                        )
                    ]
                ),
                ProseMirrorNode(
                    type: "column",
                    content: [ProseMirrorNode(type: "paragraph", content: [])]
                )
            ]
        )
    }

    private func structuredSyncedNode() -> ProseMirrorNode {
        ProseMirrorNode(
            type: "transclusionSource",
            attrs: ["id": .string("sync-1")],
            content: [structuredEmbedNode()]
        )
    }

    private func structuredEmbedNode() -> ProseMirrorNode {
        ProseMirrorNode(
            type: "embed",
            attrs: ["src": .string("https://open.spotify.com/track/example")]
        )
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
