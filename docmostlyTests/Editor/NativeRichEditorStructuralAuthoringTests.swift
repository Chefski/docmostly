import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorStructuralAuthoringTests {
    @Test func nestedCalloutEditPreservesContainerAttributesAndRichNodes() throws {
        let originalNode = ProseMirrorNode(
            type: "callout",
            attrs: ["type": .string("warning"), "icon": .string("⚠️"), "future": .string("keep")],
            content: [paragraph("Before")]
        )
        let viewModel = viewModel(containing: originalNode)
        let blockID = try #require(viewModel.document.blocks.first?.id)
        let replacement = [
            ProseMirrorNode(
                type: "heading",
                attrs: ["level": .int(2)],
                content: [ProseMirrorNode(type: "text", marks: [ProseMirrorMark(type: "bold")], text: "Release")]
            ),
            ProseMirrorNode(
                type: "bulletList",
                content: [
                    ProseMirrorNode(type: "listItem", content: [paragraph("Preserved")])
                ]
            )
        ]

        viewModel.updateNestedContent(blockID: blockID, target: .callout, content: replacement)

        let updatedNode = try #require(viewModel.document.blocks.first?.rawNode)
        #expect(updatedNode.attrs == originalNode.attrs)
        #expect(updatedNode.content == replacement)
        let serializedNode = try #require(viewModel.document.proseMirrorDocument.content.first)
        #expect(serializedNode.type == updatedNode.type)
        #expect(serializedNode.attrs == updatedNode.attrs)
        #expect(serializedNode.content?.map(\.type) == replacement.map(\.type))
        #expect(
            NativeEditorDocument.plainText(in: serializedNode.content ?? []) ==
                NativeEditorDocument.plainText(in: replacement)
        )

        let encodedDocument = try JSONEncoder().encode(viewModel.document.proseMirrorDocument)
        let decodedDocument = try JSONDecoder().decode(ProseMirrorDocument.self, from: encodedDocument)
        #expect(decodedDocument == viewModel.document.proseMirrorDocument)
    }

    @Test func reducingColumnsMergesRemovedRichChildrenIntoLastRetainedColumn() throws {
        let columns = ProseMirrorNode(
            type: "columns",
            attrs: ["layout": .string("four_equal"), "widthMode": .string("wide")],
            content: [
                column(width: 0.5, content: [paragraph("One")]),
                column(width: 1.5, content: [paragraph("Two")]),
                column(width: nil, content: [
                    ProseMirrorNode(
                        type: "heading",
                        attrs: ["level": .int(3)],
                        content: [ProseMirrorNode(type: "text", text: "Three")]
                    )
                ]),
                column(width: nil, content: [
                    ProseMirrorNode(type: "paragraph", content: []),
                    ProseMirrorNode(type: "horizontalRule")
                ])
            ]
        )
        let viewModel = viewModel(containing: columns)
        let blockID = try #require(viewModel.document.blocks.first?.id)

        viewModel.setColumnCount(blockID: blockID, count: 2)

        let updatedNode = try #require(viewModel.document.blocks.first?.rawNode)
        let updatedColumns = try #require(updatedNode.content)
        #expect(updatedColumns.count == 2)
        #expect(updatedNode.attrs?["layout"] == .string("two_equal"))
        #expect(updatedNode.attrs?["widthMode"] == .string("wide"))
        #expect(updatedColumns[0].attrs?["width"] == .double(0.5))
        #expect(updatedColumns[1].attrs?["width"] == .double(1.5))
        #expect(updatedColumns[1].content?.map(\.type) == ["paragraph", "heading", "horizontalRule"])
    }

    @Test func columnWidthEditPreservesColumnContentAndUnknownAttributes() throws {
        let originalContent = [paragraph("Rich column")]
        let columns = ProseMirrorNode(
            type: "columns",
            attrs: ["layout": .string("two_equal")],
            content: [
                ProseMirrorNode(
                    type: "column",
                    attrs: ["future": .bool(true)],
                    content: originalContent
                ),
                column(width: nil, content: [paragraph("Two")])
            ]
        )
        let viewModel = viewModel(containing: columns)
        let blockID = try #require(viewModel.document.blocks.first?.id)

        viewModel.updateColumnWidth(blockID: blockID, columnIndex: 0, width: 1.75)

        let updatedColumn = try #require(viewModel.document.blocks.first?.rawNode?.content?.first)
        #expect(updatedColumn.attrs?["width"] == .double(1.75))
        #expect(updatedColumn.attrs?["future"] == .bool(true))
        #expect(updatedColumn.content == originalContent)
    }

    @Test func syncedSourceRejectsNestedSyncedNodesButAcceptsRichAllowedContent() throws {
        let source = ProseMirrorNode(
            type: "transclusionSource",
            attrs: ["id": .string("sync-1")],
            content: [paragraph("Original")]
        )
        let viewModel = viewModel(containing: source)
        let blockID = try #require(viewModel.document.blocks.first?.id)

        viewModel.updateNestedContent(
            blockID: blockID,
            target: .transclusionSource,
            content: [ProseMirrorNode(type: "transclusionSource", content: [paragraph("Nested")])]
        )
        #expect(viewModel.document.blocks.first?.rawNode == source)

        let allowed = [ProseMirrorNode(type: "table", content: [])]
        viewModel.updateNestedContent(blockID: blockID, target: .transclusionSource, content: allowed)
        #expect(viewModel.document.blocks.first?.rawNode?.content == allowed)
    }

    @Test func syncedSourceAcceptsExistingPageBreaks() throws {
        let source = ProseMirrorNode(
            type: "transclusionSource",
            attrs: ["id": .string("sync-1")],
            content: [paragraph("Before"), ProseMirrorNode(type: "pageBreak"), paragraph("After")]
        )
        let viewModel = viewModel(containing: source)
        let blockID = try #require(viewModel.document.blocks.first?.id)
        let updatedContent = [paragraph("Updated"), ProseMirrorNode(type: "pageBreak"), paragraph("After")]

        viewModel.updateNestedContent(
            blockID: blockID,
            target: .transclusionSource,
            content: updatedContent
        )

        #expect(viewModel.document.blocks.first?.rawNode?.content == updatedContent)
    }

    @Test func mediaConfigurationPreservesServerManagedAndUnknownAttributes() throws {
        let image = ProseMirrorNode(
            type: "image",
            attrs: [
                "src": .string("/files/original.png"),
                "attachmentId": .string("attachment-1"),
                "size": .int(4096),
                "future": .string("keep")
            ]
        )
        let viewModel = viewModel(containing: image)
        let blockID = try #require(viewModel.document.blocks.first?.id)

        viewModel.updateMediaBlock(
            blockID: blockID,
            update: NativeEditorMediaBlockUpdate(
                source: "/files/updated.png",
                alternativeText: "Architecture",
                width: "50%",
                height: "",
                alignment: "right"
            )
        )

        let attrs = try #require(viewModel.document.blocks.first?.rawNode?.attrs)
        #expect(attrs["src"] == .string("/files/updated.png"))
        #expect(attrs["alt"] == .string("Architecture"))
        #expect(attrs["width"] == .string("50%"))
        #expect(attrs["align"] == .string("right"))
        #expect(attrs["attachmentId"] == .string("attachment-1"))
        #expect(attrs["size"] == .int(4096))
        #expect(attrs["future"] == .string("keep"))
    }

    private func viewModel(containing node: ProseMirrorNode) -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1")
        viewModel.document = NativeEditorDocument(
            proseMirrorDocument: ProseMirrorDocument(content: [node])
        )
        return viewModel
    }

    private func paragraph(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(type: "paragraph", content: [ProseMirrorNode(type: "text", text: text)])
    }

    private func column(width: Double?, content: [ProseMirrorNode]) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "column",
            attrs: width.map { ["width": .double($0)] },
            content: content
        )
    }
}

struct NativeEditorStructuralPolicyTests {
    @Test func tableFocusMovesAcrossRowsAndAppendsAfterLastCell() {
        #expect(
            NativeEditorTableFocusNavigation.destination(
                from: NativeEditorTableCellCoordinate(rowIndex: 0, columnIndex: 1),
                direction: .forward,
                rowCount: 2,
                columnCount: 2
            ) == .cell(NativeEditorTableCellCoordinate(rowIndex: 1, columnIndex: 0))
        )
        #expect(
            NativeEditorTableFocusNavigation.destination(
                from: NativeEditorTableCellCoordinate(rowIndex: 1, columnIndex: 1),
                direction: .forward,
                rowCount: 2,
                columnCount: 2
            ) == .appendRowAndFocus(NativeEditorTableCellCoordinate(rowIndex: 2, columnIndex: 0))
        )
        #expect(
            NativeEditorTableFocusNavigation.destination(
                from: NativeEditorTableCellCoordinate(rowIndex: 1, columnIndex: 0),
                direction: .backward,
                rowCount: 2,
                columnCount: 2
            ) == .cell(NativeEditorTableCellCoordinate(rowIndex: 0, columnIndex: 1))
        )
    }

    @Test func columnLayoutUsesWebPresetsAndStacksNarrowCanvases() {
        #expect(
            NativeEditorColumnsLayoutPolicy.weights(
                layout: "three_with_sidebars",
                explicitWidths: [nil, nil, nil],
                count: 3
            ) == [0.7, 1.6, 0.7]
        )
        #expect(
            NativeEditorColumnsLayoutPolicy.weights(
                layout: "two_equal",
                explicitWidths: [0.5, 1.5],
                count: 2
            ) == [0.5, 1.5]
        )
        #expect(NativeEditorColumnsLayoutPolicy.shouldStack(availableWidth: 320, count: 2))
        #expect(NativeEditorColumnsLayoutPolicy.shouldStack(availableWidth: 900, count: 3) == false)
    }
}
