import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct CRDTProjectionMergeTests {
    @Test func mergedProjectionKeepsLocalTextAndAddsCollaboratorTextWithoutApproval() {
        let engine = SnapshotCRDTDocumentEngine()
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Daily notes",
            crdtDocumentEngine: engine
        )
        viewModel.document = document(firstText: "First", secondText: "Second")
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        viewModel.document.blocks[0].text = AttributedString("First by me")
        viewModel.handleDocumentChanged()

        viewModel.applyCRDTDocumentSnapshot(NativeEditorCRDTDocumentSnapshot(
            document: document(firstText: "First by me", secondText: "Second by Alice"),
            updatedAt: Date(timeIntervalSince1970: 20)
        ))

        #expect(viewModel.document.blocks.map { String($0.text.characters) } == [
            "First by me",
            "Second by Alice"
        ])
        #expect(viewModel.pendingRemoteCRDTSnapshot == nil)
        #expect(viewModel.realtimeStatus == .connected)
        #expect(viewModel.isDirty)
    }

    @Test func mergedProjectionPreservesFocusedBlockAndMovesCaretAfterRemoteInsertion() throws {
        let engine = SnapshotCRDTDocumentEngine()
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Daily notes",
            crdtDocumentEngine: engine
        )
        viewModel.document = document(text: "World")
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        let blockID = viewModel.document.blocks[0].id
        let insertionPoint = viewModel.document.blocks[0].text.endIndex
        viewModel.document.blocks[0].selection = AttributedTextSelection(insertionPoint: insertionPoint)
        viewModel.activeBlockID = blockID

        viewModel.applyCRDTDocumentSnapshot(snapshot(text: "Hello World", updatedAt: 20))

        #expect(viewModel.document.blocks[0].id == blockID)
        #expect(viewModel.activeBlockID == blockID)
        #expect(try #require(viewModel.currentLocalTextSelection()).anchor.characterOffset == 11)
        #expect(viewModel.pendingRemoteCRDTSnapshot == nil)
        #expect(viewModel.realtimeStatus == .connected)
    }

    private func snapshot(
        text: String,
        updatedAt: TimeInterval
    ) -> NativeEditorCRDTDocumentSnapshot {
        NativeEditorCRDTDocumentSnapshot(
            title: "Daily notes",
            document: document(text: text),
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }

    private func document(text: String) -> NativeEditorDocument {
        NativeEditorDocument(proseMirrorDocument: ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "paragraph",
                attrs: ["id": .string("stable-test-anchor")],
                content: [ProseMirrorNode(type: "text", text: text)]
            )
        ]))
    }

    private func document(firstText: String, secondText: String) -> NativeEditorDocument {
        NativeEditorDocument(proseMirrorDocument: ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "paragraph",
                attrs: ["id": .string("first-stable-anchor")],
                content: [ProseMirrorNode(type: "text", text: firstText)]
            ),
            ProseMirrorNode(
                type: "paragraph",
                attrs: ["id": .string("second-stable-anchor")],
                content: [ProseMirrorNode(type: "text", text: secondText)]
            )
        ]))
    }
}
