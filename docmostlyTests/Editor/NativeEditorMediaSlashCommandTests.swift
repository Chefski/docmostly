import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorMediaSlashCommandTests {
    @Test func applyingMediaSlashCommandsUseDocmostWebDefaultAttributes() throws {
        let expectations = [
            MediaCommandExpectation(
                command: .image,
                nodeType: "image",
                attrs: ["align": .string("center")]
            ),
            MediaCommandExpectation(
                command: .video,
                nodeType: "video",
                attrs: ["align": .string("center")]
            ),
            MediaCommandExpectation(
                command: .pdf,
                nodeType: "pdf",
                attrs: ["width": .int(800), "height": .int(600)]
            )
        ]

        for expectation in expectations {
            let viewModel = viewModelAfterApplying(expectation.command)
            let node = try #require(viewModel.document.proseMirrorDocument.content.first)

            #expect(node.type == expectation.nodeType)
            for (key, value) in expectation.attrs {
                #expect(node.attrs?[key] == value)
            }
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

private struct MediaCommandExpectation {
    let command: NativeEditorCommand
    let nodeType: String
    let attrs: [String: ProseMirrorJSONValue]
}
