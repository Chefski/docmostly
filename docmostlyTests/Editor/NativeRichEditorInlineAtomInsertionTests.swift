import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorInlineAtomInsertionTests {
    @Test func insertMentionAddsDocmostTrailingSpaceTextNode() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("State "), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.insertStatusBadge(text: "Ship", color: "green")
        viewModel.insertMention(NativeEditorMention(
            identifier: "mention-1",
            label: "Roadmap",
            entityType: "page",
            entityID: "page-2",
            slugID: "roadmap-abc"
        ))

        let inlineNodes = proseMirrorInlineNodes(from: viewModel)
        #expect(String(viewModel.document.blocks[0].text.characters) == "State ShipRoadmap ")
        #expect(inlineNodes.map(\.type) == ["text", "status", "mention", "text"])
        #expect(inlineNodes[1].attrs?["text"] == .string("Ship"))
        #expect(inlineNodes[1].attrs?["color"] == .string("green"))
        #expect(inlineNodes[2].attrs?["label"] == .string("Roadmap"))
        #expect(inlineNodes[2].attrs?["entityType"] == .string("page"))
        #expect(inlineNodes[2].attrs?["slugId"] == .string("roadmap-abc"))
        #expect(inlineNodes[3].text == " ")
    }

    private func proseMirrorInlineNodes(from viewModel: NativeRichEditorViewModel) -> [ProseMirrorNode] {
        viewModel.document.proseMirrorDocument.content.first?.content ?? []
    }
}
