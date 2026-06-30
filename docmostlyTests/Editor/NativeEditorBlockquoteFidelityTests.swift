import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorBlockquoteFidelityTests {
    @Test func preservesAdditionalBlockquoteContentWhenReencodingNativeEdits() throws {
        let trailingParagraph = ProseMirrorNode(
            type: "paragraph",
            attrs: ["id": .string("quote-paragraph-2")],
            content: [ProseMirrorNode(type: "text", text: "Follow-up quote")]
        )
        let original = ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "blockquote",
                attrs: ["dataKind": .string("annotation")],
                content: [
                    ProseMirrorNode(
                        type: "paragraph",
                        attrs: ["id": .string("quote-paragraph-1")],
                        content: [ProseMirrorNode(type: "text", text: "Original quote")]
                    ),
                    trailingParagraph
                ]
            )
        ])
        var document = NativeEditorDocument(proseMirrorDocument: original)

        document.blocks[0].text = AttributedString("Edited quote")

        let encodedBlockquote = try #require(document.proseMirrorDocument.content.first)
        let encodedContent = try #require(encodedBlockquote.content)
        #expect(encodedBlockquote.attrs?["dataKind"] == .string("annotation"))
        #expect(encodedContent.count == 2)
        #expect(encodedContent[0].attrs?["id"] == .string("quote-paragraph-1"))
        #expect(encodedContent[0].content?.first?.text == "Edited quote")
        #expect(encodedContent[1] == trailingParagraph)
    }
}
