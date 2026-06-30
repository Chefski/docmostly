import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCodeBlockAttributeTests {
    @Test func preservesCodeBlockAttributesWhenReencodingNativeEdits() throws {
        let original = ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "codeBlock",
                attrs: [
                    "id": .string("code-block-1"),
                    "language": .string("swift")
                ],
                content: [ProseMirrorNode(type: "text", text: "let value = true")]
            )
        ])
        var document = NativeEditorDocument(proseMirrorDocument: original)

        document.blocks[0].text = AttributedString("let value = false")

        let encodedBlock = try #require(document.proseMirrorDocument.content.first)
        #expect(encodedBlock.attrs?["id"] == .string("code-block-1"))
        #expect(encodedBlock.attrs?["language"] == .string("swift"))
        #expect(encodedBlock.content?.first?.text == "let value = false")
    }
}
