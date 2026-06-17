import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCollaborationSyncStatusTests {
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
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
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
}
