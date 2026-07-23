import Foundation
import SwiftUI
import SwiftData
import Testing
@testable import docmostly

@MainActor
struct NativeEditorSaveRaceTests {
    @Test func localEditActionsAdvanceAutosaveRevision() {
        let viewModel = makeViewModel(engine: SuspendingSaveCRDTDocumentEngine())

        viewModel.title = "Changed title"
        viewModel.handleTitleChanged()
        #expect(viewModel.localEditRevision == 1)

        viewModel.document.blocks[0].text = AttributedString("Changed body")
        viewModel.handleDocumentChanged()
        #expect(viewModel.localEditRevision == 2)

        viewModel.appendBlock()
        #expect(viewModel.localEditRevision == 3)

        viewModel.undo()
        #expect(viewModel.localEditRevision == 4)

        viewModel.redo()
        #expect(viewModel.localEditRevision == 5)
    }

    @Test func remoteDocumentSnapshotDoesNotAdvanceAutosaveRevision() {
        let viewModel = makeViewModel(engine: SuspendingSaveCRDTDocumentEngine())

        viewModel.applyCRDTDocumentSnapshot(NativeEditorCRDTDocumentSnapshot(
            title: "Remote title",
            document: document(text: "Remote body"),
            updatedAt: Date(timeIntervalSince1970: 50)
        ))

        #expect(viewModel.localEditRevision == 0)
        #expect(viewModel.isDirty == false)
    }

    @Test func saveCommitsOnlyCapturedSnapshotWhenNewerLocalEditsArrive() async {
        let engine = SuspendingSaveCRDTDocumentEngine()
        let viewModel = makeViewModel(engine: engine)

        viewModel.document.blocks[0].text = AttributedString("First local body")
        viewModel.handleDocumentChanged()
        let firstSnapshot = viewModel.document

        let saveTask = Task {
            await viewModel.save(appState: AppState())
        }
        await engine.waitUntilFlushSuspends()

        viewModel.title = "Second local title"
        viewModel.handleTitleChanged()
        viewModel.document.blocks[0].text = AttributedString("Second local body")
        viewModel.handleDocumentChanged()
        let secondSnapshot = viewModel.document

        #expect(engine.events == [
            .integrate("First local body"),
            .flush("First local body")
        ])

        engine.resumeFlush(with: NativeEditorCRDTSaveResult(title: "Draft"))
        let didSave = await saveTask.value
        try? await viewModel.waitForPendingCRDTLocalChange()

        #expect(didSave)
        #expect(engine.flushRequests.count == 1)
        #expect(engine.flushRequests.first?.title == "Draft")
        #expect(engine.flushRequests.first?.document == firstSnapshot)
        #expect(viewModel.title == "Second local title")
        #expect(viewModel.document == secondSnapshot)
        #expect(viewModel.lastSavedTitle == "Draft")
        #expect(viewModel.lastSavedDocument == firstSnapshot)
        #expect(viewModel.isDirty)
        #expect(viewModel.isSaving == false)
        #expect(engine.events == [
            .integrate("First local body"),
            .flush("First local body"),
            .integrate("First local body"),
            .integrate("Second local body")
        ])
    }

    @Test func saveCompletionDoesNotOverwriteNewerRemoteBaseline() async {
        let engine = SuspendingSaveCRDTDocumentEngine()
        let viewModel = makeViewModel(engine: engine)

        viewModel.document.blocks[0].text = AttributedString("Local body")
        viewModel.handleDocumentChanged()

        let saveTask = Task {
            await viewModel.save(appState: AppState())
        }
        await engine.waitUntilFlushSuspends()

        let remoteDocument = document(text: "Remote body")
        viewModel.title = "Remote title"
        viewModel.document = remoteDocument
        viewModel.lastSavedTitle = "Remote title"
        viewModel.lastSavedDocument = remoteDocument
        viewModel.markRemoteBaseline(updatedAt: Date(timeIntervalSince1970: 50))
        viewModel.resetEditingHistory()
        viewModel.recalculateDirty()

        engine.resumeFlush(with: NativeEditorCRDTSaveResult(
            title: "Draft",
            updatedAt: Date(timeIntervalSince1970: 20)
        ))
        let didSave = await saveTask.value

        #expect(didSave)
        #expect(viewModel.title == "Remote title")
        #expect(viewModel.document == remoteDocument)
        #expect(viewModel.lastSavedTitle == "Remote title")
        #expect(viewModel.lastSavedDocument == remoteDocument)
        #expect(viewModel.lastRemoteUpdatedAt == Date(timeIntervalSince1970: 50))
        #expect(viewModel.isDirty == false)
    }

    @Test func divergentRemoteCRDTSnapshotDuringSaveCannotReplaceLocalDraftOrBaseline() async {
        let engine = SuspendingSaveCRDTDocumentEngine()
        let viewModel = makeViewModel(engine: engine)

        viewModel.document.blocks[0].text = AttributedString("Local body")
        viewModel.handleDocumentChanged()

        let saveTask = Task {
            await viewModel.save(appState: AppState())
        }
        await engine.waitUntilFlushSuspends()

        let remoteDocument = document(text: "Remote merged body")
        viewModel.applyCRDTDocumentSnapshot(NativeEditorCRDTDocumentSnapshot(
            title: "Remote title",
            document: remoteDocument,
            updatedAt: Date(timeIntervalSince1970: 50)
        ))

        engine.resumeFlush(with: NativeEditorCRDTSaveResult(
            title: "Draft",
            updatedAt: Date(timeIntervalSince1970: 20)
        ))
        let didSave = await saveTask.value

        #expect(didSave)
        #expect(viewModel.title == "Draft")
        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Local body"])
        #expect(viewModel.lastSavedTitle == "Draft")
        #expect(viewModel.lastSavedDocument.blocks.map { String($0.text.characters) } == ["Original body"])
        #expect(viewModel.pendingRemoteCRDTSnapshot?.document == remoteDocument)
        #expect(viewModel.pendingRemoteUpdate?.title == "Remote title")
        #expect(viewModel.realtimeStatus == .conflict)
        #expect(viewModel.isDirty)
    }

    @Test func deferredConflictAutosaveQueuesLocalDraftWithoutFlushingYjsOrLoopingHandoff() async throws {
        let engine = SuspendingSaveCRDTDocumentEngine()
        let viewModel = makeViewModel(engine: engine)
        viewModel.document.blocks[0].text = AttributedString("Local durable draft")
        viewModel.handleDocumentChanged()
        try await viewModel.waitForPendingCRDTLocalChange()
        let eventsBeforeConflict = engine.events
        viewModel.applyCRDTDocumentSnapshot(NativeEditorCRDTDocumentSnapshot(
            title: "Remote title",
            document: document(text: "Remote divergent body"),
            updatedAt: Date(timeIntervalSince1970: 50)
        ))
        viewModel.document.blocks[0].text = AttributedString("Local draft after conflict")
        viewModel.handleDocumentChanged()
        try await viewModel.waitForPendingCRDTLocalChange()

        let scope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let cacheRepository = CacheRepository(context: context)
        try cacheRepository.saveEditablePage(
            DocmostEditablePage(
                id: "page-1",
                slugId: "page-1",
                title: "Draft",
                content: document(text: "Original body").proseMirrorDocument,
                icon: nil,
                spaceId: "space-1",
                updatedAt: Date(timeIntervalSince1970: 10),
                permissions: nil,
                lastUpdatedBy: nil
            ),
            scope: scope
        )
        let appState = AppState()
        appState.configure(modelContext: context)
        appState.configurePreviewCacheScope(scope)

        let didSave = await viewModel.save(appState: appState)

        #expect(didSave)
        #expect(engine.flushRequests.isEmpty)
        #expect(engine.events == eventsBeforeConflict)
        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Local draft after conflict"])
        #expect(viewModel.pendingRemoteCRDTSnapshot != nil)
        #expect(viewModel.realtimeStatus == .conflict)
        #expect(viewModel.isDirty)
        #expect(viewModel.hasDurablyPersistedLocalCRDTDraft)
        #expect(viewModel.hasOutgoingChangesRequiringPersistence == false)
        let offlineQueue = try #require(appState.offlineQueue)
        #expect(try offlineQueue.pending(scope: scope).map(\.payload) == [
            .updatePageMetadata(
                pageId: "page-1",
                title: "Draft",
                baseTitle: "Draft"
            )
        ])
    }

    private func makeViewModel(
        engine: SuspendingSaveCRDTDocumentEngine
    ) -> NativeRichEditorViewModel {
        let initialDocument = document(text: "Original body")
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Draft",
            crdtDocumentEngine: engine
        )
        viewModel.document = initialDocument
        viewModel.lastSavedDocument = initialDocument
        viewModel.isCRDTEngineReadyForLocalChanges = true
        viewModel.resetEditingHistory()
        return viewModel
    }

    private func document(text: String) -> NativeEditorDocument {
        NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString(text), alignment: .left)
        ])
    }
}

@MainActor
private final class SuspendingSaveCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    enum Event: Equatable {
        case integrate(String)
        case flush(String)
    }

    struct FlushRequest {
        let title: String
        let document: NativeEditorDocument
    }

    private(set) var flushRequests: [FlushRequest] = []
    private(set) var events: [Event] = []
    private var flushContinuation: CheckedContinuation<NativeEditorCRDTSaveResult, Never>?

    func encodeStateVector() async throws -> Data {
        Data()
    }

    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data {
        Data()
    }

    func applyRemoteUpdate(_ update: Data) async throws { }

    func integrateLocalChange(_ change: NativeEditorCRDTLocalChange) async throws {
        events.append(.integrate(Self.bodyText(in: change.after.document)))
    }

    func flushPendingLocalChanges(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTSaveResult {
        events.append(.flush(Self.bodyText(in: document)))
        flushRequests.append(FlushRequest(title: title, document: document))
        return await withCheckedContinuation { continuation in
            flushContinuation = continuation
        }
    }

    func waitUntilFlushSuspends() async {
        for _ in 0..<100 where flushContinuation == nil {
            await Task.yield()
        }
    }

    func resumeFlush(with result: NativeEditorCRDTSaveResult) {
        flushContinuation?.resume(returning: result)
        flushContinuation = nil
    }

    private static func bodyText(in document: NativeEditorDocument) -> String {
        document.blocks.first.map { String($0.text.characters) } ?? ""
    }
}
