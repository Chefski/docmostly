import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorLocalAwarenessUpdateTests {
    @Test func viewModelPublishesLocalAwarenessUpdatesForFocusAndDocumentChanges() async {
        let blockID = UUID()
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(id: blockID, kind: .paragraph, text: AttributedString("Body"), alignment: .left)
        ])
        var iterator = viewModel.localAwarenessUpdates().makeAsyncIterator()

        viewModel.focus(blockID: blockID)
        #expect(await iterator.next() != nil)

        viewModel.document.blocks[0].text = AttributedString("Body updated")
        viewModel.handleDocumentChanged()
        #expect(await iterator.next() != nil)

        viewModel.clearFocus()
        #expect(await iterator.next() != nil)
    }

    @Test func collaborationSessionExposesLocalAwarenessUpdateStream() async {
        let blockID = UUID()
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(id: blockID, kind: .paragraph, text: AttributedString("Body"), alignment: .left)
        ])
        let session = viewModel.collaborationSession()
        var iterator = session.localAwarenessUpdates?.makeAsyncIterator()

        viewModel.focus(blockID: blockID)

        #expect(await iterator?.next() != nil)
    }
}
