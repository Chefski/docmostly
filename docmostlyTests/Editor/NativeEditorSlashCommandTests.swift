import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorSlashCommandTests {
    @Test func slashCommandMenuExposesGenericEmbedCommand() {
        #expect(NativeEditorCommand.slashMenuCases.contains(.embed))
        #expect(slashCommandTitles(for: "embed").contains("Embed"))
    }

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

    @Test func slashCommandInventoryUsesDocmostWebCommandTitles() {
        let titles = NativeEditorCommand.allCases.map(\.title)
        let expectedTitles = [
            "Text",
            "To-do list",
            "Heading 1",
            "Heading 2",
            "Heading 3",
            "Bullet list",
            "Numbered list",
            "Quote",
            "Code",
            "Divider",
            "Page break",
            "Image",
            "Video",
            "Audio",
            "Embed PDF",
            "File attachment",
            "Table",
            "Base (Inline)",
            "Kanban",
            "Toggle block",
            "Callout",
            "Math inline",
            "Math block",
            "Mermaid diagram",
            "Draw.io (diagrams.net)",
            "Excalidraw (Whiteboard)",
            "Date",
            "Time",
            "Status",
            "Emoji",
            "Subpages (Child pages)",
            "Synced block",
            "2 Columns",
            "3 Columns",
            "4 Columns",
            "5 Columns",
            "Embed",
            "Iframe embed",
            "Airtable",
            "Loom",
            "Figma",
            "Typeform",
            "Miro",
            "YouTube",
            "Vimeo",
            "Framer",
            "Google Drive",
            "Google Sheets"
        ]

        for expectedTitle in expectedTitles {
            #expect(titles.contains(expectedTitle))
        }
    }

    @Test func slashCommandInventoryFollowsDocmostWebMenuOrder() {
        #expect(slashCommandTitles(for: "") == [
            "Text",
            "To-do list",
            "Heading 1",
            "Heading 2",
            "Heading 3",
            "Bullet list",
            "Numbered list",
            "Quote",
            "Code",
            "Divider",
            "Page break",
            "Image",
            "Video",
            "Audio",
            "Embed PDF",
            "File attachment",
            "Table",
            "Base (Inline)",
            "Kanban",
            "Toggle block",
            "Callout",
            "Math inline",
            "Math block",
            "Mermaid diagram",
            "Draw.io (diagrams.net)",
            "Excalidraw (Whiteboard)",
            "Date",
            "Time",
            "Status",
            "Emoji",
            "Subpages (Child pages)",
            "Synced block",
            "2 Columns",
            "3 Columns",
            "4 Columns",
            "5 Columns",
            "Embed",
            "Iframe embed",
            "Airtable",
            "Loom",
            "Figma",
            "Typeform",
            "Miro",
            "YouTube",
            "Vimeo",
            "Framer",
            "Google Drive",
            "Google Sheets"
        ])
    }

    @Test func slashCommandFilteringUsesDocmostSearchTerms() {
        let expectations = [
            SlashCommandFilterExpectation(query: "today", title: "Date"),
            SlashCommandFilterExpectation(query: "now", title: "Time"),
            SlashCommandFilterExpectation(query: "checkbox", title: "To-do list"),
            SlashCommandFilterExpectation(query: "hr", title: "Divider"),
            SlashCommandFilterExpectation(query: "pagebreak", title: "Page break"),
            SlashCommandFilterExpectation(query: "latex", title: "Math inline"),
            SlashCommandFilterExpectation(query: "lozenge", title: "Status"),
            SlashCommandFilterExpectation(query: "reaction", title: "Emoji")
        ]

        for expectation in expectations {
            let titles = slashCommandTitles(for: expectation.query)
            #expect(titles.contains(expectation.title))
        }
    }

    @Test func slashCommandFilteringUsesDocmostFuzzyTitleMatching() {
        let expectations = [
            SlashCommandFilterExpectation(query: "tdl", title: "To-do list"),
            SlashCommandFilterExpectation(query: "nb", title: "Numbered list"),
            SlashCommandFilterExpectation(query: "pgb", title: "Page break")
        ]

        for expectation in expectations {
            let titles = slashCommandTitles(for: expectation.query)
            #expect(titles.contains(expectation.title))
        }
    }

    @Test func slashCommandTitleWordStartPriorityScansPastMidWordMatches() {
        #expect(NativeEditorCommand.iframeEmbed.matchPriority(query: "e") == 0)
    }

    @Test func slashCommandMenuIsDisabledInsideCodeBlocks() {
        let block = NativeEditorBlock(
            kind: .codeBlock(language: nil),
            text: AttributedString("/table"),
            alignment: .left
        )
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        #expect(viewModel.isShowingSlashCommands == false)
        #expect(viewModel.filteredSlashCommands.isEmpty)
    }

    @Test func applyingCodeBlockSlashCommandClearsSlashToken() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/code"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.applySlashCommand(.codeBlock)

        #expect(viewModel.document.blocks[0].kind == .codeBlock(language: nil))
        #expect(String(viewModel.document.blocks[0].text.characters).isEmpty)
        #expect(viewModel.isShowingSlashCommands == false)
        #expect(viewModel.isDirty == true)
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

    @Test func applyingSyncedBlockSlashCommandCreatesDocmostNodeID() throws {
        let viewModel = viewModelAfterApplying(.syncedBlock)
        let block = viewModel.document.blocks[0]

        guard case .transclusionSource(let source) = block.kind else {
            Issue.record("Expected synced block slash command to create a transclusion source")
            return
        }

        let identifier = try #require(source.identifier)
        let node = try #require(viewModel.document.proseMirrorDocument.content.first)

        #expect(identifier.count == 12)
        #expect(identifier.unicodeScalars.allSatisfy { (97...122).contains(Int($0.value)) })
        #expect(node.type == "transclusionSource")
        #expect(node.attrs?["id"] == .string(identifier))
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

    private func slashCommandTitles(for query: String) -> [String] {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/\(query)"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        return viewModel.filteredSlashCommands.map(\.title)
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

private struct SlashCommandFilterExpectation {
    let query: String
    let title: String
}
