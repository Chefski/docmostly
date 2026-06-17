import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCRDTCollaborationTests {
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

    @Test func viewModelBuildsCollaborationSessionWithoutCRDTDriverWhenEngineIsMissing() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")

        let collaborationSession = viewModel.collaborationSession()

        #expect(collaborationSession.documentName == "page.page-1")
        #expect(collaborationSession.syncDriver == nil)
    }

    @Test func viewModelBuildsCollaborationSessionWithCRDTDriverWhenEngineIsConfigured() async throws {
        let engine = RecordingCRDTDocumentEngine()
        engine.encodedStateVector = Data([21, 22])
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page",
            crdtDocumentEngine: engine
        )

        let collaborationSession = viewModel.collaborationSession()
        let driver = try #require(collaborationSession.syncDriver)

        let frames = try await driver.outboundFramesAfterAuthentication()
        let frame = try NativeEditorHocuspocusFrame.parse(try #require(frames.first))
        #expect(frame.documentName == "page.page-1")
        #expect(frame.message == .sync(.stepOne(Data([21, 22]))))
    }

    @Test func viewModelResolvesRemoteCursorsThroughCRDTEngine() async throws {
        let remoteCursor = remoteCursor(id: "user-2", name: "Alice")
        let resolvedCursor = NativeEditorResolvedRemoteCursor(
            id: "user-2",
            name: "Alice",
            colorName: "#2563EB",
            anchor: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 1),
            head: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 5)
        )
        let engine = RecordingCRDTDocumentEngine()
        engine.resolvedRemoteCursorsByID = ["user-2": resolvedCursor]
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page",
            crdtDocumentEngine: engine
        )
        viewModel.remoteCursors = [remoteCursor]

        await viewModel.refreshResolvedRemoteCursors()

        #expect(engine.remoteCursorResolutionRequests == [remoteCursor])
        #expect(viewModel.resolvedRemoteCursors == [resolvedCursor])
    }

    @Test func viewModelClearsResolvedRemoteCursorsWithoutCRDTEngine() async {
        let resolvedCursor = NativeEditorResolvedRemoteCursor(
            id: "user-2",
            name: "Alice",
            colorName: "#2563EB",
            anchor: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 1),
            head: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 5)
        )
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.resolvedRemoteCursors = [resolvedCursor]
        viewModel.remoteCursors = [remoteCursor(id: "user-2", name: "Alice")]

        await viewModel.refreshResolvedRemoteCursors()

        #expect(viewModel.resolvedRemoteCursors == [])
    }

    private func remoteCursor(id: String, name: String) -> NativeEditorRemoteCursor {
        NativeEditorRemoteCursor(
            id: id,
            name: name,
            colorName: "#2563EB",
            cursor: NativeEditorAwarenessCursor(anchor: nil, head: nil)
        )
    }
}

@MainActor
private final class RecordingCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    var encodedStateVector = Data()
    var stateUpdatesByVector: [Data: Data] = [:]
    var requestedStateVectors: [Data] = []
    var appliedRemoteUpdates: [Data] = []
    var resolvedRemoteCursorsByID: [String: NativeEditorResolvedRemoteCursor] = [:]
    var remoteCursorResolutionRequests: [NativeEditorRemoteCursor] = []

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

    func resolveRemoteCursor(_ cursor: NativeEditorRemoteCursor) async throws -> NativeEditorResolvedRemoteCursor? {
        remoteCursorResolutionRequests.append(cursor)
        return resolvedRemoteCursorsByID[cursor.id]
    }
}
