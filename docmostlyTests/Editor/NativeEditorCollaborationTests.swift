import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCollaborationTests {
    @Test func buildsCollaborationWebSocketURLFromServerURL() throws {
        let secureURL = try NativeEditorCollaborationEndpoint.webSocketURL(
            serverBaseURL: #require(URL(string: "https://docs.example.com"))
        )
        let insecureURL = try NativeEditorCollaborationEndpoint.webSocketURL(
            serverBaseURL: #require(URL(string: "http://localhost:3000/api"))
        )

        #expect(secureURL.absoluteString == "wss://docs.example.com/collab")
        #expect(insecureURL.absoluteString == "ws://localhost:3000/collab")
    }

    @Test func appliesRemoteSnapshotWhenEditorIsClean() {
        let viewModel = configuredViewModel()
        let remotePage = editablePage(
            title: "Remote",
            text: "Remote body",
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        viewModel.handleRemotePageSnapshot(remotePage)

        #expect(viewModel.title == "Remote")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Remote body")
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.realtimeStatus == .connected)
    }

    @Test func defersRemoteSnapshotWhenLocalEditorIsDirty() {
        let viewModel = configuredViewModel()
        viewModel.document.blocks[0].text = AttributedString("Local draft")
        viewModel.handleDocumentChanged()

        let remotePage = editablePage(
            title: "Remote",
            text: "Remote body",
            updatedAt: Date(timeIntervalSince1970: 20)
        )
        viewModel.handleRemotePageSnapshot(remotePage)

        #expect(viewModel.title == "Local")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Local draft")
        #expect(viewModel.pendingRemoteUpdate?.updatedAt == remotePage.updatedAt)
        #expect(viewModel.realtimeStatus == .conflict)
    }

    @Test func acceptsPendingRemoteSnapshotAfterConflict() {
        let viewModel = configuredViewModel()
        viewModel.document.blocks[0].text = AttributedString("Local draft")
        viewModel.handleDocumentChanged()

        viewModel.handleRemotePageSnapshot(editablePage(
            title: "Remote",
            text: "Remote body",
            updatedAt: Date(timeIntervalSince1970: 20)
        ))
        viewModel.acceptPendingRemoteUpdate()

        #expect(viewModel.title == "Remote")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Remote body")
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.isDirty == false)
    }

    private func configuredViewModel() -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Local")
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Local body"), alignment: .left)
        ])
        viewModel.markRemoteBaseline(updatedAt: Date(timeIntervalSince1970: 10))
        viewModel.resetEditingHistory()
        return viewModel
    }

    private func editablePage(title: String, text: String, updatedAt: Date) -> DocmostEditablePage {
        DocmostEditablePage(
            id: "page-1",
            slugId: "slug-1",
            title: title,
            content: ProseMirrorDocument(content: [
                ProseMirrorNode(type: "paragraph", content: [
                    ProseMirrorNode(type: "text", text: text)
                ])
            ]),
            icon: nil,
            spaceId: "space-1",
            updatedAt: updatedAt,
            permissions: nil
        )
    }
}
