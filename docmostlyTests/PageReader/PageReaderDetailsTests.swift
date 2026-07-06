import Foundation
import SwiftUI
import Testing
@testable import docmostly

struct PageReaderDetailsTests {
    @Test func detailStatsCountWordsAndCharactersAcrossTextBlocks() {
        let document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .heading(level: 1), text: AttributedString("Roadmap"), alignment: .left),
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Alpha beta"), alignment: .left),
            NativeEditorBlock(kind: .paragraph, text: AttributedString("  Gamma\nDelta  "), alignment: .left)
        ])

        let stats = PageReaderDetailStats.stats(in: document)

        #expect(stats.wordCount == 5)
        #expect(stats.characterCount == 30)
    }

    @Test func detailStatsIgnoreEmptyWhitespaceOnlyBlocks() {
        let document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("   "), alignment: .left),
            NativeEditorBlock(kind: .paragraph, text: AttributedString("\n"), alignment: .left)
        ])

        let stats = PageReaderDetailStats.stats(in: document)

        #expect(stats.wordCount == 0)
        #expect(stats.characterCount == 0)
    }

    @Test func detailStatsCountTableCellText() {
        let table = NativeEditorTable(rows: [
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(plainText: "Quarterly roadmap", isHeader: true, backgroundColorName: nil),
                NativeEditorTableCell(plainText: "Alpha beta", isHeader: true, backgroundColorName: nil)
            ]),
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(plainText: "  Gamma  ", isHeader: false, backgroundColorName: nil),
                NativeEditorTableCell(plainText: "", isHeader: false, backgroundColorName: nil)
            ])
        ])
        let document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Intro"), alignment: .left),
            NativeEditorBlock(kind: .table(table), text: AttributedString("2 rows x 2 columns"), alignment: .left)
        ])

        let stats = PageReaderDetailStats.stats(in: document)

        #expect(stats.wordCount == 6)
        #expect(stats.characterCount == 40)
    }
}
