import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCRDTDocumentSnapshotTests {
    @Test func appliesCRDTDocumentSnapshotWithoutCreatingConflict() {
        let engine = SnapshotCRDTDocumentEngine()
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Local",
            crdtDocumentEngine: engine
        )
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Local"), alignment: .left)
        ])
        viewModel.markRemoteBaseline(updatedAt: Date(timeIntervalSince1970: 10))
        let snapshot = NativeEditorCRDTDocumentSnapshot(
            title: "Merged",
            document: NativeEditorDocument(blocks: [
                NativeEditorBlock(kind: .paragraph, text: AttributedString("Merged body"), alignment: .left)
            ]),
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        viewModel.applyCRDTDocumentSnapshot(snapshot)

        #expect(viewModel.title == "Merged")
        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Merged body"])
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.realtimeStatus == .connected)
        #expect(viewModel.lastRemoteUpdatedAt == snapshot.updatedAt)
        #expect(viewModel.isDirty == false)
    }

    @Test func defersDivergentCRDTSnapshotWithoutReplacingDirtyLocalDocument() {
        let engine = SnapshotCRDTDocumentEngine()
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Local",
            crdtDocumentEngine: engine
        )
        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Local draft"), alignment: .left)
        ])
        viewModel.handleDocumentChanged()
        let snapshot = NativeEditorCRDTDocumentSnapshot(
            title: "Local",
            document: NativeEditorDocument(blocks: [
                NativeEditorBlock(kind: .paragraph, text: AttributedString("Merged draft"), alignment: .left)
            ]),
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        viewModel.applyCRDTDocumentSnapshot(snapshot)

        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Local draft"])
        #expect(viewModel.isDirty == true)
        #expect(viewModel.pendingRemoteUpdate?.title == "Local")
        #expect(
            viewModel.pendingRemoteCRDTSnapshot?.document.proseMirrorDocument ==
                snapshot.document.proseMirrorDocument
        )
        #expect(viewModel.realtimeStatus == .conflict)
    }

    @Test func laterMatchingOrPartialSnapshotCannotClearEarlierDeferredConflict() {
        let engine = SnapshotCRDTDocumentEngine()
        let localText = "Second line survives autosave — merged after Backspace"
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Daily notes",
            crdtDocumentEngine: engine
        )
        viewModel.document = document(text: "Original")
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        viewModel.document.blocks[0].text = AttributedString(localText)
        viewModel.handleDocumentChanged()

        viewModel.applyCRDTDocumentSnapshot(snapshot(text: "Second line survives autosav", updatedAt: 20))
        viewModel.applyCRDTDocumentSnapshot(snapshot(text: localText, updatedAt: 21))
        viewModel.applyCRDTDocumentSnapshot(snapshot(text: "Second line survives autosave", updatedAt: 22))

        #expect(viewModel.document.blocks.map { String($0.text.characters) } == [localText])
        #expect(viewModel.lastSavedDocument.blocks.map { String($0.text.characters) } == ["Original"])
        #expect(viewModel.pendingRemoteCRDTSnapshot?.updatedAt == Date(timeIntervalSince1970: 22))
        #expect(viewModel.pendingRemoteUpdate != nil)
        #expect(viewModel.realtimeStatus == .conflict)
        #expect(viewModel.isDirty)
    }

    @Test func matchingSnapshotPreservesDirtyAutosaveWithoutReplacingLiveDocumentOrHistory() {
        let engine = SnapshotCRDTDocumentEngine()
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Daily notes",
            crdtDocumentEngine: engine
        )
        viewModel.document = document(text: "Original")
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        viewModel.document.blocks[0].text = AttributedString("Current draft")
        viewModel.handleDocumentChanged()
        let liveBlockID = viewModel.document.blocks[0].id
        #expect(viewModel.canUndo)

        let matchingSnapshot = snapshot(text: "Current draft", updatedAt: 20)
        #expect(matchingSnapshot.document.proseMirrorDocument.isCollaborationEquivalent(
            to: viewModel.document.proseMirrorDocument
        ))
        viewModel.applyCRDTDocumentSnapshot(matchingSnapshot)

        #expect(viewModel.document.blocks[0].id == liveBlockID)
        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Current draft"])
        #expect(viewModel.lastSavedDocument.blocks.map { String($0.text.characters) } == ["Original"])
        #expect(viewModel.pendingRemoteCRDTSnapshot == nil)
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.realtimeStatus == .connected)
        #expect(viewModel.canUndo)
        #expect(viewModel.isDirty)
        #expect(viewModel.hasOutgoingChangesRequiringPersistence)
    }

    @Test func orderedMatchingSelfEchoDoesNotShowConflictOrCancelAutosave() {
        let engine = SnapshotCRDTDocumentEngine()
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Daily notes",
            crdtDocumentEngine: engine
        )
        viewModel.document = document(text: "Original")
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        viewModel.applyCRDTDocumentSnapshot(snapshot(text: "Original", updatedAt: 10))
        viewModel.document.blocks[0].text = AttributedString("ABCDE")
        viewModel.handleDocumentChanged()

        let matchingSnapshot = snapshot(text: "ABCDE", updatedAt: 20)
        #expect(matchingSnapshot.document.proseMirrorDocument.isCollaborationEquivalent(
            to: viewModel.document.proseMirrorDocument
        ))
        viewModel.applyCRDTDocumentSnapshot(matchingSnapshot)

        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["ABCDE"])
        #expect(viewModel.pendingRemoteCRDTSnapshot == nil)
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.realtimeStatus == .connected)
        #expect(viewModel.isDirty)
    }

    @Test func paragraphIDChangeIsNotTreatedAsMatchingSelfEcho() {
        let local = ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "paragraph",
                attrs: ["id": .string("local-anchor")],
                content: [ProseMirrorNode(type: "text", text: "Same text")]
            )
        ])
        let remote = ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "paragraph",
                attrs: ["id": .string("remote-anchor")],
                content: [ProseMirrorNode(type: "text", text: "Same text")]
            )
        ])

        #expect(local.isCollaborationEquivalent(to: remote) == false)
    }

    @Test func immediateEditBeforeInitialSyncIsBufferedThenPublishedOverAuthoritativeBaseline() async throws {
        let engine = SnapshotCRDTDocumentEngine(requiresInitialRemoteSnapshot: true)
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Daily notes",
            crdtDocumentEngine: engine
        )
        viewModel.document = document(text: "REST baseline")
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()

        viewModel.document.blocks[0].text = AttributedString("Typed immediately")
        viewModel.handleDocumentChanged()
        try await viewModel.waitForPendingCRDTLocalChange()
        #expect(engine.integratedDocuments.isEmpty)

        viewModel.applyCRDTDocumentSnapshot(snapshot(text: "REST baseline", updatedAt: 20))
        try await viewModel.waitForPendingCRDTLocalChange()

        #expect(engine.integratedDocuments.map { $0.blocks.map { String($0.text.characters) } } == [
            ["Typed immediately"]
        ])
        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Typed immediately"])
        #expect(viewModel.pendingRemoteCRDTSnapshot == nil)
        #expect(viewModel.realtimeStatus == .connected)
        #expect(viewModel.isDirty)
    }

    @Test func coordinatorAppliesRemoteUpdateOnlyAfterQueuedLocalIntegration() async throws {
        let engine = SnapshotCRDTDocumentEngine()
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Daily notes",
            crdtDocumentEngine: engine
        )
        viewModel.document = document(text: "Baseline")
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        viewModel.applyCRDTDocumentSnapshot(snapshot(text: "Baseline", updatedAt: 10))
        viewModel.document.blocks[0].text = AttributedString("Local before remote")
        viewModel.handleDocumentChanged()
        let coordinator = try #require(viewModel.crdtSyncCoordinator)

        _ = try await coordinator.receive(.update(Data([9])))

        #expect(engine.events == ["local", "remote"])
    }

    @Test func applyInstallsDeferredCRDTSnapshotAndClearsLocalHistory() {
        let engine = SnapshotCRDTDocumentEngine()
        let viewModel = makeDirtyViewModel(engine: engine)
        let remoteSnapshot = snapshot(text: "Remote body", title: "Remote title", updatedAt: 20)
        viewModel.applyCRDTDocumentSnapshot(remoteSnapshot)

        viewModel.acceptPendingRemoteUpdate()

        #expect(viewModel.title == "Remote title")
        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Remote body"])
        #expect(viewModel.lastSavedDocument == viewModel.document)
        #expect(viewModel.pendingRemoteCRDTSnapshot == nil)
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.canUndo == false)
        #expect(viewModel.isDirty == false)
        #expect(viewModel.realtimeStatus == .connected)
    }

    @Test func keepMineRebasesToRemoteAndPublishesRetainedLocalDocument() async throws {
        let engine = SnapshotCRDTDocumentEngine()
        let viewModel = makeDirtyViewModel(engine: engine)
        viewModel.applyCRDTDocumentSnapshot(snapshot(text: "Remote body", updatedAt: 20))

        viewModel.rejectPendingRemoteUpdate()
        try await viewModel.waitForPendingCRDTLocalChange()

        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Local draft"])
        #expect(viewModel.lastSavedDocument.blocks.map { String($0.text.characters) } == ["Remote body"])
        #expect(engine.integratedDocuments.last?.blocks.map { String($0.text.characters) } == ["Local draft"])
        #expect(viewModel.pendingRemoteCRDTSnapshot == nil)
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.hasOutgoingChangesRequiringPersistence)
        #expect(viewModel.isDirty)
        #expect(viewModel.realtimeStatus == .connected)
    }

    @Test func capturedConflictCannotAcceptNewerPendingSnapshot() {
        let engine = SnapshotCRDTDocumentEngine()
        let viewModel = makeDirtyViewModel(engine: engine)
        let capturedSnapshot = snapshot(text: "First remote body", updatedAt: 20)
        let newerSnapshot = snapshot(text: "Newer remote body", updatedAt: 21)
        viewModel.applyCRDTDocumentSnapshot(capturedSnapshot)
        let capturedUpdate = viewModel.pendingRemoteUpdate
        viewModel.applyCRDTDocumentSnapshot(newerSnapshot)

        #expect(viewModel.acceptPendingRemoteUpdate(
            matching: capturedSnapshot,
            remoteUpdate: capturedUpdate
        ) == false)
        #expect(viewModel.pendingRemoteCRDTSnapshot == newerSnapshot)
        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Local draft"])
    }

    @Test func capturedConflictCannotRejectNewerPendingSnapshot() {
        let engine = SnapshotCRDTDocumentEngine()
        let viewModel = makeDirtyViewModel(engine: engine)
        let capturedSnapshot = snapshot(text: "First remote body", updatedAt: 20)
        let newerSnapshot = snapshot(text: "Newer remote body", updatedAt: 21)
        viewModel.applyCRDTDocumentSnapshot(capturedSnapshot)
        let capturedUpdate = viewModel.pendingRemoteUpdate
        viewModel.applyCRDTDocumentSnapshot(newerSnapshot)

        #expect(viewModel.rejectPendingRemoteUpdate(
            matching: capturedSnapshot,
            remoteUpdate: capturedUpdate
        ) == false)
        #expect(viewModel.pendingRemoteCRDTSnapshot == newerSnapshot)
        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Local draft"])
    }

    @Test func exposesCRDTDocumentSnapshotStreamFromEngine() async {
        let engine = SnapshotCRDTDocumentEngine()
        let streamPair = AsyncStream.makeStream(of: NativeEditorCRDTDocumentSnapshot.self)
        engine.snapshotStream = streamPair.stream
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page",
            crdtDocumentEngine: engine
        )
        let snapshots = await viewModel.crdtDocumentSnapshots()
        var iterator = snapshots.makeAsyncIterator()
        let snapshot = NativeEditorCRDTDocumentSnapshot(
            title: "Remote",
            document: NativeEditorDocument(blocks: [
                NativeEditorBlock(kind: .paragraph, text: AttributedString("Remote body"), alignment: .left)
            ]),
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        streamPair.continuation.yield(snapshot)
        streamPair.continuation.finish()

        let emittedSnapshot = await iterator.next()
        #expect(emittedSnapshot?.title == snapshot.title)
        #expect(emittedSnapshot?.document == snapshot.document)
        #expect(emittedSnapshot?.updatedAt == snapshot.updatedAt)
    }

    private func makeDirtyViewModel(engine: SnapshotCRDTDocumentEngine) -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Local",
            crdtDocumentEngine: engine
        )
        viewModel.document = document(text: "Original")
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        viewModel.document.blocks[0].text = AttributedString("Local draft")
        viewModel.handleDocumentChanged()
        return viewModel
    }

    private func snapshot(
        text: String,
        title: String? = "Daily notes",
        updatedAt: TimeInterval
    ) -> NativeEditorCRDTDocumentSnapshot {
        NativeEditorCRDTDocumentSnapshot(
            title: title,
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
}

@MainActor
private final class SnapshotCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    nonisolated let requiresInitialRemoteSnapshot: Bool
    var snapshotStream: AsyncStream<NativeEditorCRDTDocumentSnapshot>?
    private(set) var integratedDocuments: [NativeEditorDocument] = []
    private(set) var events: [String] = []

    init(requiresInitialRemoteSnapshot: Bool = false) {
        self.requiresInitialRemoteSnapshot = requiresInitialRemoteSnapshot
    }

    func encodeStateVector() async throws -> Data {
        Data()
    }

    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data {
        Data()
    }

    func applyRemoteUpdate(_ update: Data) async throws {
        events.append("remote")
    }

    func integrateLocalChange(_ change: NativeEditorCRDTLocalChange) async throws {
        integratedDocuments.append(change.after.document)
        events.append("local")
    }

    func flushPendingLocalChanges(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTSaveResult {
        NativeEditorCRDTSaveResult()
    }

    func documentSnapshots() async -> AsyncStream<NativeEditorCRDTDocumentSnapshot> {
        if let snapshotStream {
            return snapshotStream
        }
        let (stream, continuation) = AsyncStream.makeStream(of: NativeEditorCRDTDocumentSnapshot.self)
        continuation.finish()
        return stream
    }
}
