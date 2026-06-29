import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorLinkFidelityTests {
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
