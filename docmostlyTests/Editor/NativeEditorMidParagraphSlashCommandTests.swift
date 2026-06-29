import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorSlashRangeTests {
    @Test func applyingInlineSlashCommandAfterTextReplacesOnlySlashToken() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Ship /status"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        #expect(viewModel.slashCommandQuery == "status")
        #expect(viewModel.filteredSlashCommands.map(\.title).contains("Status"))

        viewModel.applySlashCommand(.status)

        let inlineNodes = proseMirrorInlineNodes(from: viewModel)
        #expect(String(viewModel.document.blocks[0].text.characters) == "Ship Status")
        #expect(inlineNodes.map(\.type) == ["text", "status"])
        #expect(inlineNodes.first?.text == "Ship ")
        #expect(inlineNodes[1].attrs?["text"] == .string("Status"))
        #expect(inlineNodes[1].attrs?["color"] == .string("gray"))
    }

    private func proseMirrorInlineNodes(from viewModel: NativeRichEditorViewModel) -> [ProseMirrorNode] {
        viewModel.document.proseMirrorDocument.content.first?.content ?? []
    }
}
