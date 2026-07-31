import Foundation
import SwiftData
import Testing
@testable import docmostly

@MainActor
struct DocumentSessionRemoteOrderingTests {
    @Test func remoteUpdateWaitsForAttachedEditorLocalIntegration() async throws {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let peer = DocumentLocalPersistencePeer(modelContainer: container)
        let factory = SessionTestDocumentEngineFactory()
        let key = DocumentStoreKey(
            serverBaseURL: "https://docs.example.com",
            userID: "user-1",
            workspaceID: "workspace-1",
            pageID: "page-1"
        )
        let registry = DocumentSessionRegistry(localPeer: peer, engineFactory: factory)
        let session = try await registry.session(
            for: key,
            title: "Page",
            document: NativeEditorDocument()
        )
        let viewModel = NativeRichEditorViewModel(pageID: key.pageID, initialTitle: "Page")
        viewModel.configureDocumentSession(session, restoredLocalState: true)
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(
                kind: .paragraph,
                text: AttributedString("Baseline"),
                alignment: .left
            )
        ])
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        viewModel.document.blocks[0].text = AttributedString("Typed before remote")
        viewModel.handleDocumentChanged()

        _ = try await #require(session.syncCoordinator).receive(
            .update(Data("remote-after-local".utf8))
        )

        #expect(factory.engines.last?.events == ["local", "remote"])
        #expect(viewModel.pendingRemoteCRDTSnapshot == nil)
        #expect(viewModel.realtimeStatus == .connected)
    }
}
