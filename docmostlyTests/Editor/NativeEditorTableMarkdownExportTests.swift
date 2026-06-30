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

    @Test func markdownExportUsesDocmostHTMLForPreservedRichTableCells() throws {
        let table = NativeEditorTable(rows: [
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(plainText: "Name", isHeader: true, backgroundColorName: nil)
            ]),
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(
                    plainText: "Before let value = 1",
                    preservedContent: [
                        ProseMirrorNode(
                            type: "paragraph",
                            content: [ProseMirrorNode(type: "text", text: "Before")]
                        ),
                        ProseMirrorNode(
                            type: "codeBlock",
                            attrs: ["language": .string("swift")],
                            content: [ProseMirrorNode(type: "text", text: "let value = 1")]
                        )
                    ],
                    isHeader: false,
                    backgroundColorName: nil
                )
            ])
        ])
        let block = NativeEditorBlock(kind: .table(table), text: AttributedString("Table"), alignment: .left)

        let markdown = NativeEditorMarkdownParser.markdown(from: [block])
        let importedBlock = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let importedTable) = importedBlock.kind else {
            Issue.record("Expected exported Docmost HTML table to reimport as a table.")
            return
        }

        #expect(markdown.contains("<table>"))
        #expect(markdown.contains("<pre><code class=\"language-swift\">let value = 1</code></pre>"))
        #expect(importedTable.rows[1].cells[0].preservedContent?.map(\.type) == ["paragraph", "codeBlock"])
        #expect(importedTable.rows[1].cells[0].preservedContent?[1].attrs?["language"] == .string("swift"))
    }

    @Test func markdownExportRoundTripsStructuredDocmostTableCellBlocks() throws {
        let table = NativeEditorTable(rows: [
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(plainText: "Content", isHeader: true, backgroundColorName: nil)
            ]),
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(
                    plainText: "Confirm docs",
                    preservedContent: [
                        ProseMirrorNode(
                            type: "taskList",
                            content: [
                                ProseMirrorNode(
                                    type: "taskItem",
                                    attrs: ["checked": .bool(true)],
                                    content: [
                                        ProseMirrorNode(
                                            type: "paragraph",
                                            content: [ProseMirrorNode(type: "text", text: "Confirm docs")]
                                        )
                                    ]
                                )
                            ]
                        ),
                        ProseMirrorNode(
                            type: "image",
                            attrs: [
                                "src": .string("/api/attachments/img/image-1.png"),
                                "alt": .string("Architecture"),
                                "attachmentId": .string("image-1"),
                                "width": .int(640)
                            ]
                        )
                    ],
                    isHeader: false,
                    backgroundColorName: nil
                )
            ])
        ])
        let block = NativeEditorBlock(kind: .table(table), text: AttributedString("Table"), alignment: .left)

        let markdown = NativeEditorMarkdownParser.markdown(from: [block])
        let importedBlock = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let importedTable) = importedBlock.kind else {
            Issue.record("Expected exported Docmost HTML table to reimport as a table.")
            return
        }

        let preservedContent = try #require(importedTable.rows[1].cells[0].preservedContent)
        #expect(markdown.contains("<ul data-type=\"taskList\">"))
        #expect(markdown.contains("<img src=\"/api/attachments/img/image-1.png\""))
        #expect(preservedContent.map(\.type) == ["taskList", "image"])
        #expect(preservedContent[0].content?.first?.attrs?["checked"] == .bool(true))
        #expect(preservedContent[1].attrs?["attachmentId"] == .string("image-1"))
    }

    @Test func markdownExportRoundTripsBlockquotesInsideDocmostTableCells() throws {
        let table = NativeEditorTable(rows: [
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(plainText: "Context", isHeader: true, backgroundColorName: nil)
            ]),
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(
                    plainText: "Decision context",
                    preservedContent: [
                        ProseMirrorNode(
                            type: "blockquote",
                            content: [
                                ProseMirrorNode(
                                    type: "paragraph",
                                    content: [ProseMirrorNode(type: "text", text: "Decision context")]
                                )
                            ]
                        )
                    ],
                    isHeader: false,
                    backgroundColorName: nil
                )
            ])
        ])
        let block = NativeEditorBlock(kind: .table(table), text: AttributedString("Table"), alignment: .left)

        let markdown = NativeEditorMarkdownParser.markdown(from: [block])
        let importedBlock = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .table(let importedTable) = importedBlock.kind else {
            Issue.record("Expected exported Docmost HTML table to reimport as a table.")
            return
        }

        let preservedContent = try #require(importedTable.rows[1].cells[0].preservedContent)
        #expect(markdown.contains("<blockquote>"))
        #expect(markdown.contains("<p>Decision context</p>"))
        #expect(markdown.contains(#"data-type="blockquote""#) == false)
        #expect(preservedContent.map(\.type) == ["blockquote"])
        #expect(preservedContent[0].content?.first?.content?.first?.text == "Decision context")
    }
}
