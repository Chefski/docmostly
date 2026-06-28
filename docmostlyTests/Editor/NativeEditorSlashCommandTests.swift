import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorSlashCommandTests {
    @Test func slashCommandInventoryIncludesBaseColumnsAndProviderEmbeds() {
        let titles = NativeEditorCommand.allCases.map(\.title)

        #expect(titles.contains("Base (Inline)"))
        #expect(titles.contains("Kanban"))
        #expect(titles.contains("3 Columns"))
        #expect(titles.contains("4 Columns"))
        #expect(titles.contains("5 Columns"))
        #expect(titles.contains("Iframe embed"))
        #expect(titles.contains("Airtable"))
        #expect(titles.contains("Loom"))
        #expect(titles.contains("Figma"))
        #expect(titles.contains("Typeform"))
        #expect(titles.contains("Miro"))
        #expect(titles.contains("YouTube"))
        #expect(titles.contains("Vimeo"))
        #expect(titles.contains("Framer"))
        #expect(titles.contains("Google Drive"))
        #expect(titles.contains("Google Sheets"))
    }

    @Test func applyingColumnSlashCommandsCreatesDocmostColumnLayouts() {
        let expectations = [
            ColumnCommandExpectation(command: .columns, layout: "two_equal", columnCount: 2),
            ColumnCommandExpectation(command: .columns3, layout: "three_equal", columnCount: 3),
            ColumnCommandExpectation(command: .columns4, layout: "four_equal", columnCount: 4),
            ColumnCommandExpectation(command: .columns5, layout: "five_equal", columnCount: 5)
        ]

        for expectation in expectations {
            let viewModel = viewModelAfterApplying(expectation.command)
            let block = viewModel.document.blocks[0]

            guard case .columns(let columns) = block.kind else {
                Issue.record("Expected columns block")
                continue
            }

            let node = viewModel.document.proseMirrorDocument.content.first
            #expect(columns.layout == expectation.layout)
            #expect(columns.columnCount == expectation.columnCount)
            #expect(node?.type == "columns")
            #expect(node?.attrs?["layout"] == .string(expectation.layout))
            #expect(node?.content?.count == expectation.columnCount)
        }
    }

    @Test func applyingProviderEmbedSlashCommandsCreatesProviderSpecificEmbedNodes() {
        let expectations = [
            EmbedCommandExpectation(command: .iframeEmbed, title: "Iframe embed", provider: "iframe"),
            EmbedCommandExpectation(command: .airtableEmbed, title: "Airtable", provider: "airtable"),
            EmbedCommandExpectation(command: .loomEmbed, title: "Loom", provider: "loom"),
            EmbedCommandExpectation(command: .figmaEmbed, title: "Figma", provider: "figma"),
            EmbedCommandExpectation(command: .typeformEmbed, title: "Typeform", provider: "typeform"),
            EmbedCommandExpectation(command: .miroEmbed, title: "Miro", provider: "miro"),
            EmbedCommandExpectation(command: .youtubeEmbed, title: "YouTube", provider: "youtube"),
            EmbedCommandExpectation(command: .vimeoEmbed, title: "Vimeo", provider: "vimeo"),
            EmbedCommandExpectation(command: .framerEmbed, title: "Framer", provider: "framer"),
            EmbedCommandExpectation(command: .googleDriveEmbed, title: "Google Drive", provider: "gdrive"),
            EmbedCommandExpectation(command: .googleSheetsEmbed, title: "Google Sheets", provider: "gsheets")
        ]

        for expectation in expectations {
            let viewModel = viewModelAfterApplying(expectation.command)
            let block = viewModel.document.blocks[0]

            guard case .embed(let embed) = block.kind else {
                Issue.record("Expected embed block for \(expectation.title)")
                continue
            }

            let node = viewModel.document.proseMirrorDocument.content.first
            #expect(embed.provider == expectation.provider)
            #expect(node?.type == "embed")
            #expect(node?.attrs?["provider"] == .string(expectation.provider))
        }
    }

    @Test func applyingBaseSlashCommandsCreatesRawBaseNodes() {
        let expectations = [
            BaseCommandExpectation(command: .baseInline, previewText: "Base"),
            BaseCommandExpectation(command: .kanban, previewText: "Kanban")
        ]

        for expectation in expectations {
            let viewModel = viewModelAfterApplying(expectation.command)
            let block = viewModel.document.blocks[0]

            guard case .base(let base) = block.kind else {
                Issue.record("Expected base block")
                continue
            }

            let node = viewModel.document.proseMirrorDocument.content.first
            #expect(base.previewText == expectation.previewText)
            #expect(base.pageID == nil)
            #expect(node?.type == "base")
            #expect(node?.attrs?["pageId"] == .null)
        }
    }

    private func viewModelAfterApplying(_ command: NativeEditorCommand) -> NativeRichEditorViewModel {
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: AttributedString("/\(command.rawValue)"),
            alignment: .left
        )
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.applySlashCommand(command)

        return viewModel
    }
}

private struct ColumnCommandExpectation {
    let command: NativeEditorCommand
    let layout: String
    let columnCount: Int
}

private struct EmbedCommandExpectation {
    let command: NativeEditorCommand
    let title: String
    let provider: String
}

private struct BaseCommandExpectation {
    let command: NativeEditorCommand
    let previewText: String
}
