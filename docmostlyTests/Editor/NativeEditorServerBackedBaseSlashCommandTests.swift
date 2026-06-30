import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorBaseCommandServerTests {
    @Test func applyingKanbanCommandStoresCreatedBasePageID() async throws {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/kanban"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "parent-page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        await viewModel.applyServerBackedBaseSlashCommand(.kanban) { parentPageID, template in
            #expect(parentPageID == "parent-page-1")
            #expect(template == .kanban)
            return "base-page-1"
        }

        let insertedBlock = try #require(viewModel.document.blocks.first)
        let node = try #require(viewModel.document.proseMirrorDocument.content.first)

        guard case .base(let base) = insertedBlock.kind else {
            Issue.record("Expected a base block after applying the kanban command.")
            return
        }

        #expect(base.previewText == "Kanban")
        #expect(base.pageID == "base-page-1")
        #expect(base.pendingKey == nil)
        #expect(node.type == "base")
        #expect(node.attrs?["pageId"] == .string("base-page-1"))
        #expect(node.attrs?["pendingKey"] == nil)
    }
}
