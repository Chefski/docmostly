import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeUnsupportedMarkdownTests {
    @Test func markdownExportPreservesUnsupportedRawBlockAsDocmostHTML() {
        let rawNode = ProseMirrorNode(
            type: "bookmark",
            attrs: [
                "title": .string("Spec"),
                "url": .string("https://example.com/spec")
            ],
            content: [
                ProseMirrorNode(
                    type: "paragraph",
                    content: [ProseMirrorNode(type: "text", text: "Spec")]
                )
            ]
        )
        let block = NativeEditorBlock(
            kind: .unsupported(type: "bookmark"),
            text: AttributedString("Unsupported bookmark block"),
            alignment: .left,
            rawNode: rawNode
        )

        #expect(NativeEditorMarkdownParser.markdown(from: [block]) == #"""
        <div data-type="bookmark" data-title="Spec" data-url="https://example.com/spec"><p>Spec</p></div>
        """#)
    }

    @Test func markdownImportPreservesGenericDocmostDataTypeHTMLAsUnsupportedRawBlock() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(from: #"""
        <div data-type="bookmark" data-title="Spec" data-url="https://example.com/spec"><p>Spec</p></div>
        """#).first)

        guard case .unsupported(let type) = block.kind else {
            Issue.record("Expected unknown Docmost data-type HTML to import as an unsupported raw block.")
            return
        }

        #expect(type == "bookmark")
        #expect(block.rawNode?.type == "bookmark")
        #expect(block.rawNode?.attrs?["title"] == .string("Spec"))
        #expect(block.rawNode?.attrs?["url"] == .string("https://example.com/spec"))
        #expect(block.rawNode?.content?.first?.type == "paragraph")
        #expect(block.rawNode?.content?.first?.content?.first?.text == "Spec")
    }
}
