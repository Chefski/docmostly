import Foundation
import Testing
@testable import docmostly

struct NativeEditorRichBlockNodeIDTests {
    @Test func rawRichBlockEncodingAddsStableDocmostIDsToNestedEditableNodes() throws {
        let blockID = try #require(UUID(uuidString: "55555555-5555-5555-5555-555555555555"))
        let rawNode = ProseMirrorNode(
            type: "table",
            content: [
                ProseMirrorNode(
                    type: "tableRow",
                    content: [
                        ProseMirrorNode(
                            type: "tableCell",
                            content: [
                                ProseMirrorNode(
                                    type: "paragraph",
                                    content: [ProseMirrorNode(type: "text", text: "Native cell")]
                                )
                            ]
                        )
                    ]
                )
            ]
        )
        let block = NativeEditorBlock(
            id: blockID,
            kind: .table(NativeEditorTable(rows: [])),
            text: AttributedString("Native cell"),
            alignment: .left,
            rawNode: rawNode
        )
        let document = NativeEditorDocument(blocks: [block])

        let firstEncoding = try #require(document.proseMirrorDocument.content.first)
        let secondEncoding = try #require(document.proseMirrorDocument.content.first)
        let paragraph = try #require(firstEncoding.content?.first?.content?.first?.content?.first)
        let nodeID = try expectRichBlockDocmostNodeID(paragraph.attrs?["id"])

        #expect(paragraph.content?.first?.text == "Native cell")
        #expect(secondEncoding == firstEncoding)
        #expect(nodeID.isEmpty == false)
    }

    @Test func rawRichBlockEncodingPreservesImportedDocmostIDs() throws {
        let blockID = try #require(UUID(uuidString: "66666666-6666-6666-6666-666666666666"))
        let rawNode = ProseMirrorNode(
            type: "callout",
            attrs: ["type": .string("info")],
            content: [
                ProseMirrorNode(
                    type: "paragraph",
                    attrs: ["id": .string("importednode")],
                    content: [ProseMirrorNode(type: "text", text: "Imported")]
                ),
                ProseMirrorNode(
                    type: "paragraph",
                    content: [ProseMirrorNode(type: "text", text: "Generated")]
                )
            ]
        )
        let block = NativeEditorBlock(
            id: blockID,
            kind: .callout(NativeEditorCalloutBlock(style: "info", icon: nil, previewText: "Imported")),
            text: AttributedString("Imported"),
            alignment: .left,
            rawNode: rawNode
        )

        let encodedNode = try #require(NativeEditorDocument(blocks: [block]).proseMirrorDocument.content.first)
        let importedParagraph = try #require(encodedNode.content?.first)
        let generatedParagraph = try #require(encodedNode.content?.dropFirst().first)

        #expect(importedParagraph.attrs?["id"] == .string("importednode"))
        _ = try expectRichBlockDocmostNodeID(generatedParagraph.attrs?["id"])
    }
}

private func expectRichBlockDocmostNodeID(_ value: ProseMirrorJSONValue?) throws -> String {
    let nodeID = try #require(value?.stringValue)
    #expect(nodeID.count == 12)
    #expect(Set(nodeID).isSubset(of: Set("abcdefghijklmnopqrstuvwxyz")))
    return nodeID
}
