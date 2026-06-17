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

    @Test func keepsAwarenessStateAcrossIncrementalUpdatesAndRemovals() {
        var store = NativeEditorAwarenessStateStore()
        let alice = NativeEditorAwarenessState(
            clientID: 42,
            clock: 1,
            payload: NativeEditorAwarenessPayload(
                user: NativeEditorAwarenessUser(id: "user-2", name: "Alice", color: "#2563EB"),
                cursor: nil
            )
        )
        let bob = NativeEditorAwarenessState(
            clientID: 43,
            clock: 1,
            payload: NativeEditorAwarenessPayload(
                user: NativeEditorAwarenessUser(id: "user-3", name: "Bob", color: "#059669"),
                cursor: nil
            )
        )

        #expect(store.apply([alice]).map(\.clientID) == [42])
        #expect(store.apply([bob]).map(\.clientID) == [42, 43])
        #expect(store.apply([
            NativeEditorAwarenessState(clientID: 42, clock: 2, payload: nil)
        ]).map(\.clientID) == [43])
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

    private func awarenessCursorPosition(client: Int, clock: Int) -> ProseMirrorJSONValue {
        .object([
            "type": .string("text"),
            "tname": .string("default"),
            "item": .object([
                "client": .int(client),
                "clock": .int(clock)
            ]),
            "assoc": .int(0)
        ])
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
