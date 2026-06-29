import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorTableMarkdownExportTests {
    @Test func markdownExportPreservesInlineMarksInsideAlignedTableCells() throws {
        let document = try NativeEditorDocument(proseMirrorJSONData: Data("""
        {
          "type": "doc",
          "content": [
            {
              "type": "table",
              "content": [
                {
                  "type": "tableRow",
                  "content": [
                    {
                      "type": "tableHeader",
                      "content": [
                        {
                          "type": "paragraph",
                          "attrs": { "textAlign": "center" },
                          "content": [{ "type": "text", "text": "File" }]
                        }
                      ]
                    }
                  ]
                },
                {
                  "type": "tableRow",
                  "content": [
                    {
                      "type": "tableCell",
                      "content": [
                        {
                          "type": "paragraph",
                          "attrs": { "textAlign": "center" },
                          "content": [
                            {
                              "type": "text",
                              "text": "Spec",
                              "marks": [
                                {
                                  "type": "link",
                                  "attrs": { "href": "/api/files/file-1/Spec.pdf" }
                                }
                              ]
                            }
                          ]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.utf8))

        #expect(
            NativeEditorMarkdownParser.markdown(from: document.blocks) ==
                """
                | File |
                | :---: |
                | [Spec](/api/files/file-1/Spec.pdf) |
                """
        )
    }
}
