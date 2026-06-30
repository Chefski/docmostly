import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorTableTests {
    @Test func tableSlashCommandCreatesDocmostDefaultTableShape() throws {
        let viewModel = tableViewModel()

        guard case .table(let table) = viewModel.document.blocks[0].kind else {
            Issue.record("Expected table block")
            return
        }

        #expect(table.rows.count == 3)
        #expect(table.columnCount == 3)
        #expect(table.rows.first?.cells.allSatisfy(\.isHeader) == true)
        #expect(table.rows.dropFirst().flatMap(\.cells).allSatisfy { $0.isHeader == false })
        #expect(table.rows.flatMap(\.cells).allSatisfy { $0.plainText.isEmpty })

        let tableNode = try #require(viewModel.document.proseMirrorDocument.content.first)
        #expect(tableNode.content?.count == 3)
        #expect(tableNode.content?.first?.content?.map(\.type) == ["tableHeader", "tableHeader", "tableHeader"])
        #expect(tableNode.content?.dropFirst().allSatisfy { row in
            row.content?.allSatisfy { $0.type == "tableCell" } == true
        } == true)
    }

    @Test func updatesTableCellAndReencodesRawTableNode() {
        let viewModel = tableViewModel()
        let blockID = viewModel.document.blocks[0].id

        viewModel.updateTableCell(blockID: blockID, rowIndex: 1, columnIndex: 0, text: "Native iOS")

        guard case .table(let table) = viewModel.document.blocks[0].kind else {
            Issue.record("Expected table block")
            return
        }

        let node = viewModel.document.proseMirrorDocument.content.first
        let secondRow = node?.content?[1]
        let firstCell = secondRow?.content?.first
        let paragraph = firstCell?.content?.first
        let text = paragraph?.content?.first
        #expect(table.rows[1].cells[0].plainText == "Native iOS")
        #expect(node?.type == "table")
        #expect(firstCell?.type == "tableCell")
        #expect(text?.text == "Native iOS")
        #expect(viewModel.isDirty == true)
    }

    @Test func insertsAndDeletesTableRowsAndColumns() {
        let viewModel = tableViewModel()
        let blockID = viewModel.document.blocks[0].id

        viewModel.insertTableRowBelow(blockID: blockID, rowIndex: 0)
        viewModel.insertTableColumnAfter(blockID: blockID, columnIndex: 0)

        guard case .table(let expandedTable) = viewModel.document.blocks[0].kind else {
            Issue.record("Expected table block")
            return
        }
        #expect(expandedTable.rows.count == 4)
        #expect(expandedTable.columnCount == 4)
        #expect(expandedTable.rows[0].cells[1].isHeader == true)
        #expect(expandedTable.rows[1].cells.allSatisfy { $0.isHeader == false })

        viewModel.deleteTableRow(blockID: blockID, rowIndex: 1)
        viewModel.deleteTableColumn(blockID: blockID, columnIndex: 1)

        guard case .table(let reducedTable) = viewModel.document.blocks[0].kind else {
            Issue.record("Expected table block")
            return
        }
        #expect(reducedTable.rows.count == 3)
        #expect(reducedTable.columnCount == 3)
        #expect(viewModel.document.proseMirrorDocument.content.first?.content?.count == 3)
    }

    @Test func updatesTableColumnWidthAndReencodesCellColwidth() {
        let viewModel = tableViewModel()
        let blockID = viewModel.document.blocks[0].id

        viewModel.updateTableColumnWidth(blockID: blockID, columnIndex: 1, width: 236)

        guard case .table(let table) = viewModel.document.blocks[0].kind else {
            Issue.record("Expected table block")
            return
        }

        #expect(table.rows.allSatisfy { $0.cells[1].columnWidth == 236 })
        let node = viewModel.document.proseMirrorDocument.content.first
        let firstRowSecondCell = node?.content?.first?.content?[1]
        #expect(firstRowSecondCell?.attrs?["colwidth"] == .array([.int(236)]))
    }

    @Test func editingMergedTableCellPreservesSpanAndColumnWidthAttributes() {
        let table = NativeEditorTable(rows: [
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(
                    plainText: "Merged",
                    isHeader: true,
                    backgroundColor: "rgb(219, 234, 254)",
                    backgroundColorName: "blue",
                    columnWidth: 120,
                    columnSpan: 2,
                    rowSpan: 2,
                    columnWidths: [120, 160]
                ),
                NativeEditorTableCell(plainText: "Status", isHeader: true, backgroundColorName: nil)
            ]),
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(plainText: "Native", isHeader: false, backgroundColorName: nil),
                NativeEditorTableCell(plainText: "Ready", isHeader: false, backgroundColorName: nil)
            ])
        ])
        let block = NativeEditorBlock(kind: .table(table), text: AttributedString("Table"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        let blockID = viewModel.document.blocks[0].id

        viewModel.updateTableCell(blockID: blockID, rowIndex: 0, columnIndex: 0, text: "Updated")

        let firstCell = viewModel.document.proseMirrorDocument.content.first?.content?.first?.content?.first
        #expect(firstCell?.attrs?["colspan"] == .int(2))
        #expect(firstCell?.attrs?["rowspan"] == .int(2))
        #expect(firstCell?.attrs?["colwidth"] == .array([.int(120), .int(160)]))
        #expect(firstCell?.attrs?["backgroundColor"] == .string("rgb(219, 234, 254)"))
        #expect(firstCell?.attrs?["backgroundColorName"] == .string("blue"))
        #expect(firstCell?.content?.first?.content?.first?.text == "Updated")
    }

    @Test func editingAlignedTableCellPreservesParagraphAlignmentAttribute() throws {
        let data = Data("""
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
                      "type": "tableCell",
                      "content": [
                        {
                          "type": "paragraph",
                          "attrs": { "textAlign": "center" },
                          "content": [{ "type": "text", "text": "Status" }]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.utf8)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = try NativeEditorDocument(proseMirrorJSONData: data)
        let blockID = try #require(viewModel.document.blocks.first?.id)

        viewModel.updateTableCell(blockID: blockID, rowIndex: 0, columnIndex: 0, text: "Ready")

        let cell = try #require(viewModel.document.proseMirrorDocument.content.first?.content?.first?.content?.first)
        let paragraph = try #require(cell.content?.first)
        #expect(paragraph.attrs?["textAlign"] == .string("center"))
        #expect(paragraph.content?.first?.text == "Ready")
    }

    @Test func editingTableCellPreservesInlineMarksInOtherCells() throws {
        let data = Data("""
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
                          "content": [{ "type": "text", "text": "Feature" }]
                        }
                      ]
                    },
                    {
                      "type": "tableHeader",
                      "content": [
                        {
                          "type": "paragraph",
                          "content": [{ "type": "text", "text": "Status" }]
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
                          "content": [
                            {
                              "type": "text",
                              "text": "Tables",
                              "marks": [{ "type": "bold" }]
                            }
                          ]
                        }
                      ]
                    },
                    {
                      "type": "tableCell",
                      "content": [
                        {
                          "type": "paragraph",
                          "content": [{ "type": "text", "text": "Draft" }]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.utf8)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = try NativeEditorDocument(proseMirrorJSONData: data)
        let blockID = try #require(viewModel.document.blocks.first?.id)

        viewModel.updateTableCell(blockID: blockID, rowIndex: 1, columnIndex: 1, text: "Ready")

        let bodyRow = try #require(viewModel.document.proseMirrorDocument.content.first?.content?.dropFirst().first)
        let preservedText = try #require(bodyRow.content?.first?.content?.first?.content?.first)
        #expect(preservedText.text == "Tables")
        #expect(preservedText.marks?.contains(ProseMirrorMark(type: "bold")) == true)
    }

    @Test func markdownExportPreservesRelativeLinksInsideTableCells() {
        let table = NativeEditorTable(rows: [
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(plainText: "File", isHeader: true, backgroundColorName: nil)
            ]),
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(
                    plainText: "Spec",
                    inlineContent: [
                        .text("Spec", marks: [.link(href: "/api/files/file-1/Spec.pdf")])
                    ],
                    isHeader: false,
                    backgroundColorName: nil
                )
            ])
        ])

        #expect(
            NativeEditorMarkdownParser.tableMarkdown(from: table) ==
                """
                | File |
                | --- |
                | [Spec](/api/files/file-1/Spec.pdf) |
                """
        )
    }

    @Test func markdownExportWrapsUnsafeRelativeLinksInsideTableCells() {
        let table = NativeEditorTable(rows: [
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(plainText: "File", isHeader: true, backgroundColorName: nil)
            ]),
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(
                    plainText: "Spec",
                    inlineContent: [
                        .text("Spec", marks: [.link(href: "/p/project plan)/Spec.pdf")])
                    ],
                    isHeader: false,
                    backgroundColorName: nil
                )
            ])
        ])

        #expect(
            NativeEditorMarkdownParser.tableMarkdown(from: table) ==
                """
                | File |
                | --- |
                | [Spec](</p/project plan)/Spec.pdf>) |
                """
        )
    }

    @Test func markdownExportDoesNotDoubleEscapeAngleWrappedTableLinkBackslashes() {
        let table = NativeEditorTable(rows: [
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(plainText: "File", isHeader: true, backgroundColorName: nil)
            ]),
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(
                    plainText: "Spec",
                    inlineContent: [
                        .text("Spec", marks: [.link(href: #"folder name\doc"#)])
                    ],
                    isHeader: false,
                    backgroundColorName: nil
                )
            ])
        ])

        #expect(
            NativeEditorMarkdownParser.tableMarkdown(from: table) ==
                #"""
                | File |
                | --- |
                | [Spec](<folder name\doc>) |
                """#
        )
    }

    @Test func markdownImportExportPreservesTableColumnAlignmentMarkers() throws {
        let blocks = NativeEditorMarkdownParser.blocks(from: """
        | Metric | Owner | Status |
        | :--- | :---: | ---: |
        | Launch | Taylor | Ready |
        """)

        let block = try #require(blocks.first)
        guard case .table(let table) = block.kind else {
            Issue.record("Expected table block")
            return
        }

        #expect(
            NativeEditorMarkdownParser.tableMarkdown(from: table) ==
                """
                | Metric | Owner | Status |
                | :--- | :---: | ---: |
                | Launch | Taylor | Ready |
                """
        )

        let rows = try #require(block.rawNode?.content)
        let headerCells = try #require(rows.first?.content)
        let bodyCells = try #require(rows.dropFirst().first?.content)
        #expect(headerCells[0].content?.first?.attrs?["textAlign"] == .string("left"))
        #expect(headerCells[1].content?.first?.attrs?["textAlign"] == .string("center"))
        #expect(headerCells[2].content?.first?.attrs?["textAlign"] == .string("right"))
        #expect(bodyCells[0].content?.first?.attrs?["textAlign"] == .string("left"))
        #expect(bodyCells[1].content?.first?.attrs?["textAlign"] == .string("center"))
        #expect(bodyCells[2].content?.first?.attrs?["textAlign"] == .string("right"))
    }

    @Test func editingTableCellPreservesUnsupportedRichContentInOtherCells() throws {
        let data = Data("""
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
                      "type": "tableCell",
                      "content": [
                        {
                          "type": "image",
                          "attrs": {
                            "src": "/files/table-image.png",
                            "alt": "Architecture"
                          }
                        }
                      ]
                    },
                    {
                      "type": "tableCell",
                      "content": [
                        {
                          "type": "paragraph",
                          "content": [{ "type": "text", "text": "Draft" }]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.utf8)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = try NativeEditorDocument(proseMirrorJSONData: data)
        let blockID = try #require(viewModel.document.blocks.first?.id)

        viewModel.updateTableCell(blockID: blockID, rowIndex: 0, columnIndex: 1, text: "Ready")

        let firstRow = try #require(viewModel.document.proseMirrorDocument.content.first?.content?.first)
        let firstCell = try #require(firstRow.content?.first)
        let preservedImage = try #require(firstCell.content?.first)
        #expect(preservedImage.type == "image")
        #expect(preservedImage.attrs?["src"] == .string("/files/table-image.png"))
        #expect(preservedImage.attrs?["alt"] == .string("Architecture"))
    }

    private func tableViewModel() -> NativeRichEditorViewModel {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/table"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)
        viewModel.applySlashCommand(.table)
        return viewModel
    }
}
