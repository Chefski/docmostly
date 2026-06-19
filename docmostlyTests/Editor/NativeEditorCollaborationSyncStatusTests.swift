import Foundation
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

    @Test func readOnlyCollaborationScopeDiscardsPendingNativeEdits() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Saved"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Saved title")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.lastSavedDocument = viewModel.document
        viewModel.resetEditingHistory()
        viewModel.focus(blockID: block.id)

        viewModel.document.blocks[0].text = AttributedString("Local draft")
        viewModel.handleDocumentChanged()
        #expect(viewModel.isDirty == true)

        viewModel.applyCollaborationAuthenticationScope(.readonly)

        #expect(viewModel.canEdit == false)
        #expect(viewModel.canSave == false)
        #expect(String(viewModel.document.blocks[0].text.characters) == "Saved")
        #expect(viewModel.isDirty == false)
        #expect(viewModel.activeBlockID == nil)
    }

    @Test func readWriteCollaborationScopeDoesNotOverrideRestrictedPagePermissions() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")

        viewModel.applyPagePermissions(DocmostPagePermissions(canEdit: false, hasRestriction: true))
        viewModel.applyCollaborationAuthenticationScope(.readWrite)

        #expect(viewModel.canEdit == false)
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

    @Test func pageReaderTreatsUnknownCollaborationScopeAsUnsupported() async {
        let view = PageReaderView(pageID: "page-1")
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")

        await view.handleCollaborationPresenceEvent(.authenticated(.unknown), editorViewModel: viewModel)

        #expect(viewModel.canEdit == false)
        #expect(viewModel.realtimeStatus == .unsupported("Unsupported collaboration permission scope."))
    }

    @Test func pageReaderReportsLimitedSyncWhenCRDTEngineIsMissing() async {
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

        #expect(viewModel.canEdit == true)
        #expect(viewModel.realtimeStatus == .unsupported("Native CRDT runtime is unavailable."))

        await view.handleCollaborationPresenceEvent(
            .awareness(states: [awarenessState], localClientID: 1),
            editorViewModel: viewModel
        )
        await view.handleCollaborationPresenceEvent(.syncStatus(true), editorViewModel: viewModel)

        #expect(viewModel.activeCollaborators.map(\.name) == ["Alice"])
        #expect(viewModel.realtimeStatus == .unsupported("Native CRDT runtime is unavailable."))
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
        #expect(viewModel.isDirty == false)
        #expect(viewModel.errorMessage == "This page was deleted in Docmost.")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Saved")
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
