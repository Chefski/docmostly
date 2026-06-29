import Foundation
import Testing
@testable import docmostly

struct NativeEditorTablePayloadTests {
    @Test func decodesTableCellSpanAndColumnWidthAttributes() throws {
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
                      "attrs": {
                        "colspan": 2,
                        "rowspan": 3,
                        "colwidth": [120, 160],
                        "backgroundColorName": "blue"
                      },
                      "content": [
                        {
                          "type": "paragraph",
                          "content": [{ "type": "text", "text": "Merged" }]
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

        let document = try NativeEditorDocument(proseMirrorJSONData: data)

        guard case .table(let table) = document.blocks.first?.kind else {
            Issue.record("Expected table block")
            return
        }

        let cell = try #require(table.rows.first?.cells.first)
        #expect(cell.plainText == "Merged")
        #expect(cell.isHeader == true)
        #expect(cell.columnSpan == 2)
        #expect(cell.rowSpan == 3)
        #expect(cell.columnWidth == 120)
        #expect(cell.columnWidths == [120, 160])
        #expect(cell.backgroundColorName == "blue")
    }

    @Test func preservesTableCellBackgroundColorAttribute() throws {
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
                      "attrs": {
                        "backgroundColor": "rgb(254, 243, 199)",
                        "backgroundColorName": "yellow"
                      },
                      "content": [
                        {
                          "type": "paragraph",
                          "content": [{ "type": "text", "text": "Risk" }]
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

        let document = try NativeEditorDocument(proseMirrorJSONData: data)

        guard case .table(let table) = document.blocks.first?.kind else {
            Issue.record("Expected table block")
            return
        }

        let cell = try #require(table.rows.first?.cells.first)
        #expect(cell.backgroundColor == "rgb(254, 243, 199)")
        #expect(cell.backgroundColorName == "yellow")

        let reencodedDocument = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .table(table), text: AttributedString("Table"), alignment: .left)
        ])
        let encodedCell = try #require(
            reencodedDocument.proseMirrorDocument.content.first?.content?.first?.content?.first
        )
        #expect(encodedCell.attrs?["backgroundColor"] == .string("rgb(254, 243, 199)"))
        #expect(encodedCell.attrs?["backgroundColorName"] == .string("yellow"))
    }

    @Test func editingTableCellPreservesParagraphAttributesInOtherCells() throws {
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
                          "attrs": { "textAlign": "right" },
                          "content": [{ "type": "text", "text": "Metric" }]
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

        let document = try NativeEditorDocument(proseMirrorJSONData: data)

        guard case .table(var table) = document.blocks.first?.kind else {
            Issue.record("Expected table block")
            return
        }

        table.rows[0].cells[1].plainText = "Ready"
        table.rows[0].cells[1].inlineContent = nil
        table.rows[0].cells[1].preservedContent = nil

        let reencodedDocument = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .table(table), text: AttributedString("Table"), alignment: .left)
        ])
        let firstCell = try #require(
            reencodedDocument.proseMirrorDocument.content.first?.content?.first?.content?.first
        )
        let firstParagraph = try #require(firstCell.content?.first)

        #expect(firstParagraph.attrs?["textAlign"] == .string("right"))
        #expect(firstParagraph.content?.first?.text == "Metric")
    }

    @MainActor
    @Test func tableCellBackgroundRespectsRGBAAlphaPercentages() {
        let components = NativeEditorTableLayout.cssRGBAComponents(from: "rgba(255, 0, 0, 50%)")

        #expect(components?.red == 255)
        #expect(components?.green == 0)
        #expect(components?.blue == 0)
        #expect(components?.opacity == 0.5)
    }

    @MainActor
    @Test func tableCellBackgroundRespectsRGBColorPercentages() {
        let components = NativeEditorTableLayout.cssRGBAComponents(from: "rgb(100%, 0%, 50%)")

        #expect(components?.red == 255)
        #expect(components?.green == 0)
        #expect(components?.blue == 127.5)
        #expect(components?.opacity == 1)
    }
}
