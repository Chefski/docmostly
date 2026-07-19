import Foundation
import SwiftData
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCollaborationSyncStatusTests {
    @Test func pagePermissionsDisableNativeEditingAndSaving() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Saved"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Saved title")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()

        viewModel.applyPagePermissions(DocmostPagePermissions(canEdit: false, hasRestriction: true))

        #expect(viewModel.canEdit == false)
        #expect(viewModel.canSave == false)
        viewModel.focus(blockID: block.id)
        #expect(viewModel.activeBlockID == nil)

        viewModel.toggleInlineMark(.bold)
        #expect(viewModel.document == viewModel.lastSavedDocument)
        #expect(viewModel.isDirty == false)
    }

    @Test func readOnlyCollaborationScopeFreezesPendingNativeEditsAndHistory() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Saved"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Saved title")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        viewModel.focus(blockID: block.id)

        viewModel.title = "Local title"
        viewModel.handleTitleChanged()
        viewModel.document.blocks[0].text = AttributedString("Local draft")
        viewModel.handleDocumentChanged()
        #expect(viewModel.isDirty == true)
        let undoHistory = viewModel.undoStack
        let redoHistory = viewModel.redoStack

        viewModel.applyCollaborationAuthenticationScope(.readonly)

        #expect(viewModel.canEdit == false)
        #expect(viewModel.canSave == false)
        #expect(viewModel.title == "Local title")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Local draft")
        #expect(viewModel.isDirty)
        #expect(viewModel.activeBlockID == nil)
        #expect(viewModel.undoStack == undoHistory)
        #expect(viewModel.redoStack == redoHistory)

        viewModel.title = "Late title binding"
        viewModel.handleTitleChanged()
        viewModel.document.blocks[0].text = AttributedString("Late document binding")
        viewModel.handleDocumentChanged()

        #expect(viewModel.title == "Local title")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Local draft")
        #expect(viewModel.undoStack == undoHistory)
        #expect(viewModel.redoStack == redoHistory)

        let revisionBeforeRestoringAccess = viewModel.localEditRevision
        viewModel.applyCollaborationAuthenticationScope(.readWrite)

        #expect(viewModel.canEdit)
        #expect(viewModel.isDirty)
        #expect(viewModel.title == "Local title")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Local draft")
        #expect(viewModel.localEditRevision == revisionBeforeRestoringAccess + 1)
        #expect(viewModel.undoStack == undoHistory)
        #expect(viewModel.redoStack == redoHistory)
    }

    @Test func readWriteCollaborationScopeDoesNotOverrideRestrictedPagePermissions() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")

        viewModel.applyPagePermissions(DocmostPagePermissions(canEdit: false, hasRestriction: true))
        viewModel.applyCollaborationAuthenticationScope(.readWrite)

        #expect(viewModel.canEdit == false)
    }

    @Test func failedCollaborationAuthenticationDisablesEditingAndKeepsExplicitStatus() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Saved"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Saved title")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        viewModel.focus(blockID: block.id)
        viewModel.title = "Local title"
        viewModel.handleTitleChanged()
        viewModel.document.blocks[0].text = AttributedString("Local draft")
        viewModel.handleDocumentChanged()

        viewModel.markCollaborationAuthenticationFailed("Invalid collab token")

        #expect(viewModel.canEdit == false)
        #expect(viewModel.canSave == false)
        #expect(viewModel.title == "Local title")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Local draft")
        #expect(viewModel.isDirty)
        #expect(viewModel.realtimeStatus == .authenticationFailed("Invalid collab token"))
    }

    @Test func unavailableCollaborationRuntimeRetainsDirtyNativeDraft() {
        let viewModel = dirtyViewModel()

        viewModel.markCollaborationUnavailable("Native CRDT runtime is unavailable.")

        #expect(viewModel.canEdit == false)
        #expect(viewModel.title == "Local title")
        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Local draft"])
        #expect(viewModel.isDirty)
        #expect(viewModel.hasOutgoingChangesRequiringPersistence)
        #expect(viewModel.realtimeStatus == .failed("Native CRDT runtime is unavailable."))
    }

    @Test func revokedPagePermissionRetainsDirtyNativeDraft() {
        let viewModel = dirtyViewModel()

        viewModel.applyPagePermissions(DocmostPagePermissions(canEdit: false, hasRestriction: true))

        #expect(viewModel.canEdit == false)
        #expect(viewModel.title == "Local title")
        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Local draft"])
        #expect(viewModel.isDirty)
        #expect(viewModel.hasOutgoingChangesRequiringPersistence)
    }

    @Test func frozenDraftCanBeMadeDurableWithoutAReadOnlyServerWrite() async throws {
        let scope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let cacheRepository = CacheRepository(context: context)
        try cacheRepository.saveEditablePage(
            DocmostEditablePage(
                id: "page-1",
                slugId: "page-1",
                title: "Saved title",
                content: NativeEditorDocument(
                    blocks: [NativeEditorBlock(
                        kind: .paragraph,
                        text: AttributedString("Saved"),
                        alignment: .left
                    )]
                ).proseMirrorDocument,
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
        let viewModel = dirtyViewModel()
        let savedBaseline = viewModel.lastSavedDocument.proseMirrorDocument
        viewModel.applyCollaborationAuthenticationScope(.readonly)

        let didPersist = await viewModel.persistRetainedReadOnlyDraft(appState: appState)

        #expect(didPersist)
        #expect(viewModel.canEdit == false)
        #expect(viewModel.isDirty)
        #expect(viewModel.hasDurablyPersistedLocalCRDTDraft)
        #expect(viewModel.hasOutgoingChangesRequiringPersistence == false)
        let offlineQueue = try #require(appState.offlineQueue)
        #expect(try offlineQueue.pending(scope: scope).map(\.payload) == [
            .updatePage(
                pageId: "page-1",
                title: "Local title",
                document: viewModel.document.proseMirrorDocument,
                baseTitle: "Saved title",
                baseDocument: savedBaseline
            )
        ])
    }

    @Test func unsyncedCollaborationStatusClearsTransientPresenceAndCursors() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        let recentEditor = NativeEditorCollaborator(
            id: "user-3",
            name: "Recent Editor",
            colorName: "orange",
            source: .recentEditor
        )
        let remoteCursor = NativeEditorRemoteCursor(
            id: "user-2",
            name: "Alice",
            colorName: "#2563EB",
            cursor: NativeEditorAwarenessCursor(anchor: nil, head: nil)
        )
        viewModel.realtimeStatus = .connected
        viewModel.activeCollaborators = [
            NativeEditorCollaborator(id: "user-2", name: "Alice", colorName: "#2563EB"),
            recentEditor
        ]
        viewModel.remoteCursors = [remoteCursor]
        viewModel.resolvedRemoteCursors = [
            NativeEditorResolvedRemoteCursor(
                id: "user-2",
                name: "Alice",
                colorName: "#2563EB",
                anchor: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 0),
                head: NativeEditorRemoteTextPosition(blockIndex: 0, characterOffset: 1)
            )
        ]

        viewModel.applyCollaborationSyncStatus(isSynced: false)

        #expect(viewModel.realtimeStatus == .connecting)
        #expect(viewModel.activeCollaborators == [recentEditor])
        #expect(viewModel.remoteCursors == [])
        #expect(viewModel.resolvedRemoteCursors == [])
    }

    @Test func collaborationSyncStatusPreservesConflictState() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.realtimeStatus = .conflict
        viewModel.activeCollaborators = [
            NativeEditorCollaborator(id: "user-2", name: "Alice", colorName: "#2563EB")
        ]

        viewModel.applyCollaborationSyncStatus(isSynced: false)
        #expect(viewModel.realtimeStatus == .conflict)
        #expect(viewModel.activeCollaborators == [])

        viewModel.applyCollaborationSyncStatus(isSynced: true)
        #expect(viewModel.realtimeStatus == .conflict)
    }

    @Test func pageReaderRoutesCollaborationSyncStatusEvents() async {
        let view = PageReaderView(pageID: "page-1")
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page",
            crdtDocumentEngine: SyncStatusCRDTDocumentEngine()
        )
        viewModel.realtimeStatus = .connecting

        await view.handleCollaborationPresenceEvent(.syncStatus(true), editorViewModel: viewModel)
        #expect(viewModel.realtimeStatus == .connected)

        viewModel.activeCollaborators = [
            NativeEditorCollaborator(id: "user-2", name: "Alice", colorName: "#2563EB")
        ]
        await view.handleCollaborationPresenceEvent(.syncStatus(false), editorViewModel: viewModel)

        #expect(viewModel.realtimeStatus == .connecting)
        #expect(viewModel.activeCollaborators == [])
    }

    @Test func pageReaderRoutesCollaborationAuthenticationScope() async {
        let view = PageReaderView(pageID: "page-1")
        let viewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page",
            crdtDocumentEngine: SyncStatusCRDTDocumentEngine()
        )

        await view.handleCollaborationPresenceEvent(.authenticated(.readonly), editorViewModel: viewModel)

        #expect(viewModel.canEdit == false)
        #expect(viewModel.realtimeStatus == .connected)

        viewModel.applyPagePermissions(DocmostPagePermissions(canEdit: true, hasRestriction: false))
        await view.handleCollaborationPresenceEvent(.authenticated(.readWrite), editorViewModel: viewModel)

        #expect(viewModel.canEdit == true)
        #expect(viewModel.realtimeStatus == .connected)
    }

    @Test func pageReaderTreatsUnknownCollaborationScopeAsCollaborationFailure() async {
        let view = PageReaderView(pageID: "page-1")
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")

        await view.handleCollaborationPresenceEvent(.authenticated(.unknown), editorViewModel: viewModel)

        #expect(viewModel.canEdit == false)
        #expect(viewModel.realtimeStatus == .failed("Unsupported collaboration permission scope."))
    }

    @Test func pageReaderDisablesEditingWhenCRDTEngineIsMissing() async {
        let view = PageReaderView(pageID: "page-1")
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        let awarenessState = NativeEditorAwarenessState(
            clientID: 2,
            clock: 1,
            payload: NativeEditorAwarenessPayload(
                user: NativeEditorAwarenessUser(id: "user-2", name: "Alice", color: "#2563EB"),
                cursor: nil
            )
        )

        await view.handleCollaborationPresenceEvent(.authenticated(.readWrite), editorViewModel: viewModel)

        #expect(viewModel.canEdit == false)
        #expect(viewModel.realtimeStatus == .failed("Native CRDT runtime is unavailable."))

        await view.handleCollaborationPresenceEvent(
            .awareness(states: [awarenessState], localClientID: 1),
            editorViewModel: viewModel
        )
        await view.handleCollaborationPresenceEvent(.syncStatus(true), editorViewModel: viewModel)

        #expect(viewModel.activeCollaborators.isEmpty)
        #expect(viewModel.realtimeStatus == .failed("Native CRDT runtime is unavailable."))
    }

    @Test func pageReaderRoutesActivePageDeletionAsUnavailableReadOnlyState() async {
        let view = PageReaderView(pageID: "page-1")
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Saved"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Saved title")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        viewModel.focus(blockID: block.id)
        viewModel.document.blocks[0].text = AttributedString("Local draft")
        viewModel.handleDocumentChanged()

        await view.handleRealtimeEvent(
            .pageDeleted(NativeEditorRealtimePageDeletedEvent(pageID: "page-1", spaceID: "space-1")),
            editorViewModel: viewModel
        )

        #expect(viewModel.canEdit == false)
        #expect(viewModel.canSave == false)
        #expect(viewModel.activeBlockID == nil)
        #expect(viewModel.isDirty)
        #expect(viewModel.errorMessage == "This page was deleted in Docmost.")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Local draft")
    }

    private func dirtyViewModel() -> NativeRichEditorViewModel {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Saved"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Saved title")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        viewModel.title = "Local title"
        viewModel.handleTitleChanged()
        viewModel.document.blocks[0].text = AttributedString("Local draft")
        viewModel.handleDocumentChanged()
        return viewModel
    }
}

@MainActor
private final class SyncStatusCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
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
}
