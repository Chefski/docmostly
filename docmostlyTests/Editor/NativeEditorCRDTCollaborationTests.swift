import Foundation
import SwiftUI
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

    @Test func rejectsOversizedRemoteCRDTSyncUpdates() async throws {
        let engine = RecordingCRDTDocumentEngine()
        let coordinator = NativeEditorCRDTSyncCoordinator(documentEngine: engine)
        let update = Data(
            repeating: 0,
            count: NativeEditorCRDTSyncCoordinator.maximumRemoteSyncPayloadBytes + 1
        )

        do {
            _ = try await coordinator.receive(.update(update))
            Issue.record("Expected oversized remote update to be rejected")
        } catch let error as NativeEditorCRDTSyncCoordinatorError {
            #expect(error == .remotePayloadTooLarge)
        } catch {
            Issue.record("Expected CRDT sync size error, got \(error)")
        }
        #expect(engine.appliedRemoteUpdates == [])
    }

    @Test func rejectsCumulativeRemoteCRDTSyncUpdates() async throws {
        let engine = RecordingCRDTDocumentEngine()
        let coordinator = NativeEditorCRDTSyncCoordinator(documentEngine: engine)
        let firstUpdate = Data(
            repeating: 1,
            count: NativeEditorCRDTSyncCoordinator.maximumRemoteSyncSessionBytes / 2
        )
        let secondUpdate = Data(
            repeating: 2,
            count: NativeEditorCRDTSyncCoordinator.maximumRemoteSyncSessionBytes / 2 + 1
        )

        #expect(try await coordinator.receive(.update(firstUpdate)) == [])
        do {
            _ = try await coordinator.receive(.update(secondUpdate))
            Issue.record("Expected cumulative remote CRDT updates to be rejected")
        } catch let error as NativeEditorCRDTSyncCoordinatorError {
            #expect(error == .remotePayloadTooLarge)
        } catch {
            Issue.record("Expected CRDT sync size error, got \(error)")
        }
        #expect(engine.appliedRemoteUpdates == [firstUpdate])
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

    @Test func syncDriverExposesLocalCRDTUpdateStream() async throws {
        let engine = RecordingCRDTDocumentEngine()
        let streamPair = AsyncStream.makeStream(of: Data.self)
        engine.localUpdateStream = streamPair.stream
        let driver = NativeEditorCollaborationSyncDriver(
            documentName: "page.page-1",
            coordinator: NativeEditorCRDTSyncCoordinator(documentEngine: engine)
        )
        let updates = await driver.localUpdates()
        var iterator = updates.makeAsyncIterator()
        let update = Data([31, 32])

        streamPair.continuation.yield(update)
        streamPair.continuation.finish()

        #expect(await iterator.next() == update)
        let frame = await driver.outboundFrame(forLocalUpdate: update)
        let parsedFrame = try NativeEditorHocuspocusFrame.parse(frame)
        #expect(parsedFrame.message == .sync(.update(update)))
    }

    @Test func viewModelBuildsCollaborationSessionWithoutCRDTDriverWhenEngineIsMissing() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")

        let collaborationSession = viewModel.collaborationSession()

        #expect(collaborationSession.documentName == "page.page-1")
        #expect(collaborationSession.document.fragmentName == NativeEditorCollaborationDocument.yjsFragmentName)
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
        #expect(collaborationSession.document.fragmentName == NativeEditorCollaborationDocument.yjsFragmentName)
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

    @Test func viewModelBuildsLocalTextSelectionFromActiveBlockSelection() throws {
        let firstBlockID = UUID()
        let secondBlockID = UUID()
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(id: firstBlockID, kind: .paragraph, text: AttributedString("First"), alignment: .left),
            NativeEditorBlock(
                id: secondBlockID,
                kind: .paragraph,
                text: AttributedString("Second body"),
                alignment: .left
            )
        ])
        viewModel.focus(blockID: secondBlockID)
        let text = viewModel.document.blocks[1].text
        let start = try #require(text.characters.index(text.startIndex, offsetBy: 2, limitedBy: text.endIndex))
        let end = try #require(text.characters.index(text.startIndex, offsetBy: 8, limitedBy: text.endIndex))
        viewModel.document.blocks[1].selection = AttributedTextSelection(range: start..<end)

        #expect(viewModel.currentLocalTextSelection() == NativeEditorLocalTextSelection(
            anchor: NativeEditorRemoteTextPosition(blockIndex: 1, characterOffset: 2),
            head: NativeEditorRemoteTextPosition(blockIndex: 1, characterOffset: 8)
        ))
    }

    @Test func syncDriverResolvesLocalAwarenessCursorFromNativeSelection() async throws {
        let localSelection = NativeEditorLocalTextSelection(
            anchor: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 1),
            head: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 4)
        )
        let cursor = NativeEditorAwarenessCursor(
            anchor: NativeEditorYjsRelativePosition(
                type: .name("text"),
                targetName: "default",
                item: NativeEditorYjsID(client: 1, clock: 2),
                assoc: 0
            ),
            head: NativeEditorYjsRelativePosition(
                type: .name("text"),
                targetName: "default",
                item: NativeEditorYjsID(client: 1, clock: 4),
                assoc: 0
            )
        )
        let engine = RecordingCRDTDocumentEngine()
        engine.localAwarenessCursor = cursor
        let driver = NativeEditorCollaborationSyncDriver(
            documentName: "page.page-1",
            coordinator: NativeEditorCRDTSyncCoordinator(documentEngine: engine)
        )

        let resolvedCursor = try await driver.localAwarenessCursor(for: localSelection)

        #expect(engine.localAwarenessCursorRequests == [localSelection])
        #expect(resolvedCursor == cursor)
    }

    @Test func viewModelRoutesResolvedRemoteCursorsToAffectedBlocks() {
        let firstBlockID = UUID()
        let secondBlockID = UUID()
        let thirdBlockID = UUID()
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(id: firstBlockID, kind: .paragraph, text: AttributedString("One"), alignment: .left),
            NativeEditorBlock(id: secondBlockID, kind: .paragraph, text: AttributedString("Two"), alignment: .left),
            NativeEditorBlock(id: thirdBlockID, kind: .paragraph, text: AttributedString("Three"), alignment: .left)
        ])
        viewModel.resolvedRemoteCursors = [
            resolvedCursor(id: "user-2", blockIndex: 1),
            resolvedCursor(id: "user-3", anchorBlockIndex: 0, headBlockIndex: 2),
            resolvedCursor(id: "user-4", blockIndex: 4)
        ]

        #expect(viewModel.resolvedCursorsForBlock(id: secondBlockID).map(\.id) == ["user-2", "user-3"])
        #expect(viewModel.resolvedCursorsForBlock(id: thirdBlockID).map(\.id) == ["user-3"])
        #expect(viewModel.resolvedCursorsForBlock(id: UUID()) == [])
    }

    private func remoteCursor(id: String, name: String) -> NativeEditorRemoteCursor {
        NativeEditorRemoteCursor(
            id: id,
            name: name,
            colorName: "#2563EB",
            cursor: NativeEditorAwarenessCursor(anchor: nil, head: nil)
        )
    }

    private func resolvedCursor(
        id: String,
        blockIndex: Int
    ) -> NativeEditorResolvedRemoteCursor {
        resolvedCursor(id: id, anchorBlockIndex: blockIndex, headBlockIndex: blockIndex)
    }

    private func resolvedCursor(
        id: String,
        anchorBlockIndex: Int,
        headBlockIndex: Int
    ) -> NativeEditorResolvedRemoteCursor {
        NativeEditorResolvedRemoteCursor(
            id: id,
            name: id,
            colorName: "#2563EB",
            anchor: NativeEditorRemoteTextPosition(blockIndex: anchorBlockIndex, characterOffset: 0),
            head: NativeEditorRemoteTextPosition(blockIndex: headBlockIndex, characterOffset: 0)
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
    var localAwarenessCursor: NativeEditorAwarenessCursor?
    var localAwarenessCursorRequests: [NativeEditorLocalTextSelection] = []
    var localUpdateStream: AsyncStream<Data>?

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

    func encodeLocalAwarenessCursor(
        for selection: NativeEditorLocalTextSelection
    ) async throws -> NativeEditorAwarenessCursor? {
        localAwarenessCursorRequests.append(selection)
        return localAwarenessCursor
    }

    func flushPendingLocalChanges(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTSaveResult {
        NativeEditorCRDTSaveResult()
    }

    func localUpdates() async -> AsyncStream<Data> {
        if let localUpdateStream {
            return localUpdateStream
        }
        let (stream, continuation) = AsyncStream.makeStream(of: Data.self)
        continuation.finish()
        return stream
    }
}
