import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorLinkFidelityTests {
    @Test func importsDocmostHTMLAnchorsAsNativeLinkMarks() throws {
        let blocks = NativeEditorMarkdownParser.blocks(
            from: #"Review <a href="/p/roadmap-abc123#shipping" data-internal="true">Roadmap</a> today."#
        )
        let document = NativeEditorDocument(blocks: blocks)

        let inlineNodes = document.proseMirrorDocument.content.first?.content ?? []
        #expect(inlineNodes.map(\.text) == ["Review ", "Roadmap", " today."])

        let linkMark = try #require(inlineNodes[1].marks?.first)
        #expect(linkMark == ProseMirrorMark(
            type: "link",
            attrs: [
                "href": .string("/p/roadmap-abc123#shipping"),
                "internal": .bool(true)
            ]
        ))
    }

    @Test func preservesDocmostRelativeInternalLinksFromProseMirror() throws {
        let document = try NativeEditorDocument(proseMirrorJSONData: Data("""
        {
          "type": "doc",
          "content": [
            {
              "type": "paragraph",
              "content": [
                {
                  "type": "text",
                  "text": "Spec",
                  "marks": [
                    {
                      "type": "link",
                      "attrs": {
                        "href": "/api/files/file-1/Spec.pdf",
                        "internal": true
                      }
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.utf8))

        let reencodedText = try #require(document.proseMirrorDocument.content.first?.content?.first)
        #expect(reencodedText.marks == [
            ProseMirrorMark(
                type: "link",
                attrs: [
                    "href": .string("/api/files/file-1/Spec.pdf"),
                    "internal": .bool(true)
                ]
            )
        ])

        #expect(NativeEditorMarkdownParser.markdown(from: document.blocks) == "[Spec](/api/files/file-1/Spec.pdf)")
    }
}
