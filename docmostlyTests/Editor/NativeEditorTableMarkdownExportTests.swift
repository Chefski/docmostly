import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorTableMarkdownExportTests {
    @Test func markdownTableRoundTripPreservesLiteralBackslashesInCells() throws {
        let table = NativeEditorTable(rows: [
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(plainText: "Path", isHeader: true, backgroundColorName: nil)
            ]),
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(plainText: #"C:\Temp\spec.txt"#, isHeader: false, backgroundColorName: nil)
            ])
        ])
        let block = NativeEditorBlock(kind: .table(table), text: AttributedString("Table"), alignment: .left)

        let markdown = NativeEditorMarkdownParser.markdown(from: [block])
        let importedBlock = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let importedTable) = importedBlock.kind else {
            Issue.record("Expected table Markdown to reimport as a table.")
            return
        }

        #expect(importedTable.rows[1].cells[0].plainText == #"C:\Temp\spec.txt"#)
        #expect(NativeEditorMarkdownParser.markdown(from: [importedBlock]) == markdown)
    }

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
