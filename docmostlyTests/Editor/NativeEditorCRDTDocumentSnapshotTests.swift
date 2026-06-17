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

    @Test func preservesLocalDirtyStateWhenApplyingCRDTDocumentSnapshot() {
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

        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Merged draft"])
        #expect(viewModel.isDirty == true)
        #expect(viewModel.pendingRemoteUpdate == nil)
        #expect(viewModel.realtimeStatus == .connected)
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
}

@MainActor
private final class SnapshotCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    var snapshotStream: AsyncStream<NativeEditorCRDTDocumentSnapshot>?

    func encodeStateVector() async throws -> Data {
        Data()
    }

    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data {
        Data()
    }

    func applyRemoteUpdate(_ update: Data) async throws { }

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
