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

    @Test func startsCRDTSyncWithCurrentStateVector() async throws {
        let engine = RecordingCRDTDocumentEngine()
        engine.encodedStateVector = Data([1, 2, 3])
        let coordinator = NativeEditorCRDTSyncCoordinator(documentEngine: engine)

        let message = try await coordinator.makeInitialSyncMessage()

        #expect(message == .stepOne(Data([1, 2, 3])))
    }

    @Test func repliesToRemoteCRDTSyncStepOneWithStateUpdate() async throws {
        let engine = RecordingCRDTDocumentEngine()
        engine.stateUpdatesByVector = [
            Data([4, 5]): Data([9, 8, 7])
        ]
        let coordinator = NativeEditorCRDTSyncCoordinator(documentEngine: engine)

        let outgoing = try await coordinator.receive(.stepOne(Data([4, 5])))

        #expect(engine.requestedStateVectors == [Data([4, 5])])
        #expect(outgoing == [.stepTwo(Data([9, 8, 7]))])
    }

    @Test func appliesRemoteCRDTSyncUpdatesToDocumentEngine() async throws {
        let engine = RecordingCRDTDocumentEngine()
        let coordinator = NativeEditorCRDTSyncCoordinator(documentEngine: engine)

        #expect(try await coordinator.receive(.stepTwo(Data([6, 7]))) == [])
        #expect(try await coordinator.receive(.update(Data([8, 9]))) == [])

        #expect(engine.appliedRemoteUpdates == [Data([6, 7]), Data([8, 9])])
    }

    @Test func skipsOneMatchingCRDTUpdateEchoAfterLocalBroadcast() async throws {
        let engine = RecordingCRDTDocumentEngine()
        let coordinator = NativeEditorCRDTSyncCoordinator(documentEngine: engine)
        let update = Data([10, 11, 12])

        let outgoing = await coordinator.broadcastLocalUpdate(update)
        #expect(outgoing == .update(update))

        #expect(try await coordinator.receive(.update(update)) == [])
        #expect(engine.appliedRemoteUpdates == [])

        #expect(try await coordinator.receive(.update(update)) == [])
        #expect(engine.appliedRemoteUpdates == [update])
    }

    @Test func syncDriverFramesInitialCRDTSyncMessage() async throws {
        let engine = RecordingCRDTDocumentEngine()
        engine.encodedStateVector = Data([1, 2, 3])
        let driver = NativeEditorCollaborationSyncDriver(
            documentName: "page.page-1",
            coordinator: NativeEditorCRDTSyncCoordinator(documentEngine: engine)
        )

        let frames = try await driver.outboundFramesAfterAuthentication()

        let frame = try NativeEditorHocuspocusFrame.parse(try #require(frames.first))
        #expect(frames.count == 1)
        #expect(frame.documentName == "page.page-1")
        #expect(frame.message == .sync(.stepOne(Data([1, 2, 3]))))
    }

    @Test func syncDriverFramesRepliesToRemoteCRDTSyncMessages() async throws {
        let engine = RecordingCRDTDocumentEngine()
        engine.stateUpdatesByVector = [
            Data([4, 5]): Data([9, 8, 7])
        ]
        let driver = NativeEditorCollaborationSyncDriver(
            documentName: "page.page-1",
            coordinator: NativeEditorCRDTSyncCoordinator(documentEngine: engine)
        )

        let frames = try await driver.outboundFrames(for: .stepOne(Data([4, 5])))

        let frame = try NativeEditorHocuspocusFrame.parse(try #require(frames.first))
        #expect(frames.count == 1)
        #expect(frame.message == .sync(.stepTwo(Data([9, 8, 7]))))
    }

    @Test func syncDriverFramesLocalUpdatesAndSkipsMatchingEcho() async throws {
        let engine = RecordingCRDTDocumentEngine()
        let driver = NativeEditorCollaborationSyncDriver(
            documentName: "page.page-1",
            coordinator: NativeEditorCRDTSyncCoordinator(documentEngine: engine)
        )
        let update = Data([13, 14])

        let localFrame = await driver.outboundFrame(forLocalUpdate: update)
        let parsedLocalFrame = try NativeEditorHocuspocusFrame.parse(localFrame)
        #expect(parsedLocalFrame.message == .sync(.update(update)))

        let echoFrames = try await driver.outboundFrames(for: .update(update))
        #expect(echoFrames == [])
        #expect(engine.appliedRemoteUpdates == [])
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
            permissions: nil,
            lastUpdatedBy: DocmostPagePerson(id: "user-2", name: "Remote Editor", avatarUrl: nil)
        )
    }

}

@MainActor
private final class RecordingCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    var encodedStateVector = Data()
    var stateUpdatesByVector: [Data: Data] = [:]
    var requestedStateVectors: [Data] = []
    var appliedRemoteUpdates: [Data] = []

    func encodeStateVector() async throws -> Data {
        encodedStateVector
    }

    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data {
        requestedStateVectors.append(stateVector)
        return stateUpdatesByVector[stateVector] ?? Data()
    }

    func applyRemoteUpdate(_ update: Data) async throws {
        appliedRemoteUpdates.append(update)
    }
}
