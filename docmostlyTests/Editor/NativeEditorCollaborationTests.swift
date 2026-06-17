import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCollaborationTests {
    @Test func collaborationDocumentMatchesDocmostPageYjsContract() {
        let document = NativeEditorCollaborationDocument(pageID: "page-1")

        #expect(document.name == "page.page-1")
        #expect(document.fragmentName == "default")
        #expect(NativeEditorCollaborationDocument.yjsFragmentName == "default")
        #expect(NativeEditorCollaborationDocument.statelessPageUpdatedType == "page.updated")
        #expect(NativeEditorCollaborationDocument(documentName: document.name)?.pageID == "page-1")
        #expect(NativeEditorCollaborationDocument(documentName: "space.page-1") == nil)
        #expect(NativeEditorCollaborationDocument(documentName: "page.") == nil)
        #expect(NativeEditorCollaborationDocument(documentName: "page.page-1.extra") == nil)
    }

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

    @Test func updatesActiveCollaboratorsFromAwarenessAndIgnoresLocalClient() {
        let viewModel = configuredViewModel()
        let states = [
            NativeEditorAwarenessState(
                clientID: 10,
                clock: 1,
                payload: NativeEditorAwarenessPayload(
                    user: NativeEditorAwarenessUser(id: "user-1", name: "Chefling", color: "#111827"),
                    cursor: nil
                )
            ),
            NativeEditorAwarenessState(
                clientID: 11,
                clock: 1,
                payload: NativeEditorAwarenessPayload(
                    user: NativeEditorAwarenessUser(id: "user-2", name: "Alice", color: "#2563EB"),
                    cursor: nil
                )
            ),
            NativeEditorAwarenessState(clientID: 12, clock: 1, payload: nil)
        ]

        viewModel.applyAwarenessStates(states, localClientID: 10)

        #expect(viewModel.activeCollaborators == [
            NativeEditorCollaborator(id: "user-2", name: "Alice", colorName: "#2563EB")
        ])
        #expect(viewModel.realtimeStatus == .connected)
    }

    @Test func updatesRemoteCursorsFromAwarenessAndIgnoresLocalClient() {
        let viewModel = configuredViewModel()
        let localCursor = awarenessCursor(client: 1, anchorClock: 1, headClock: 1)
        let aliceCursor = awarenessCursor(client: 2, anchorClock: 3, headClock: 5)
        let states = [
            NativeEditorAwarenessState(
                clientID: 10,
                clock: 1,
                payload: NativeEditorAwarenessPayload(
                    user: NativeEditorAwarenessUser(id: "user-1", name: "Chefling", color: "#111827"),
                    cursor: localCursor
                )
            ),
            NativeEditorAwarenessState(
                clientID: 11,
                clock: 1,
                payload: NativeEditorAwarenessPayload(
                    user: NativeEditorAwarenessUser(id: "user-2", name: "Alice", color: "#2563EB"),
                    cursor: aliceCursor
                )
            ),
            NativeEditorAwarenessState(
                clientID: 12,
                clock: 1,
                payload: NativeEditorAwarenessPayload(
                    user: NativeEditorAwarenessUser(id: "user-3", name: "Bob", color: "#059669"),
                    cursor: nil
                )
            )
        ]

        viewModel.applyAwarenessStates(states, localClientID: 10)

        #expect(viewModel.remoteCursors == [
            NativeEditorRemoteCursor(
                id: "user-2",
                name: "Alice",
                colorName: "#2563EB",
                cursor: aliceCursor
            )
        ])
    }

    @Test func ignoresAwarenessCursorsOutsideDocmostDefaultFragment() {
        let state = NativeEditorAwarenessState(
            clientID: 11,
            clock: 1,
            payload: NativeEditorAwarenessPayload(
                user: NativeEditorAwarenessUser(id: "user-2", name: "Alice", color: "#2563EB"),
                cursor: NativeEditorAwarenessCursor(
                    anchor: awarenessCursorPosition(client: 2, clock: 3, targetName: "other"),
                    head: awarenessCursorPosition(client: 2, clock: 5, targetName: "other")
                )
            )
        )

        #expect(NativeEditorRemoteCursor(awarenessState: state) == nil)
    }

    @Test func summarizesPresenceEditingStatusText() {
        let alice = NativeEditorCollaborator(id: "user-2", name: "Alice", colorName: "#2563EB")
        let bob = NativeEditorCollaborator(id: "user-3", name: "Bob", colorName: "#059669")
        let remoteEditor = NativeEditorCollaborator(
            id: "user-4",
            name: "Recent Editor",
            colorName: "orange",
            source: .recentEditor
        )

        #expect(NativeEditorPresenceStatusText.editingTitle(for: [alice]) == "Alice is editing")
        #expect(NativeEditorPresenceStatusText.editingTitle(for: [alice, bob]) == "Alice and Bob are editing")
        #expect(
            NativeEditorPresenceStatusText.editingTitle(for: [alice, bob, remoteEditor]) ==
                "Alice and Bob are editing"
        )
        #expect(NativeEditorPresenceStatusText.editingTitle(for: [remoteEditor]) == nil)
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
        #expect(viewModel.activeCollaborators.map(\.name) == ["Remote Editor"])
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
        #expect(viewModel.pendingRemoteUpdate?.lastUpdatedBy?.name == "Remote Editor")
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

    private func awarenessCursor(
        client: Int,
        anchorClock: Int,
        headClock: Int
    ) -> NativeEditorAwarenessCursor {
        NativeEditorAwarenessCursor(
            anchor: awarenessCursorPosition(client: client, clock: anchorClock),
            head: awarenessCursorPosition(client: client, clock: headClock)
        )
    }

    private func awarenessCursorPosition(
        client: Int,
        clock: Int,
        targetName: String = NativeEditorCollaborationDocument.yjsFragmentName
    ) -> NativeEditorYjsRelativePosition {
        NativeEditorYjsRelativePosition(
            type: .name("text"),
            targetName: targetName,
            item: NativeEditorYjsID(client: client, clock: clock),
            assoc: 0
        )
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
            permissions: nil,
            lastUpdatedBy: DocmostPagePerson(id: "user-2", name: "Remote Editor", avatarUrl: nil)
        )
    }

}
