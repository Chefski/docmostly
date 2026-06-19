import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class NativeRichEditorViewModel {
    let pageID: String
    var title: String
    var document = NativeEditorDocument()
    var isLoading = false
    var isSaving = false
    var isDirty = false
    var canEdit = true
    var errorMessage: String?
    var saveErrorMessage: String?
    var activeBlockID: UUID?
    var selectedBlockID: UUID?
    var visibleBlockControlsID: UUID?
    var isTitleFocused = false
    var canUndo = false
    var canRedo = false
    var searchQuery = ""
    var replacementText = ""
    var currentSearchMatchIndex = 0
    var realtimeStatus: NativeEditorRealtimeStatus = .disconnected
    var pendingRemoteUpdate: NativeEditorRemoteUpdate?
    var activeCollaborators: [NativeEditorCollaborator] = []
    var remoteCursors: [NativeEditorRemoteCursor] = []
    var resolvedRemoteCursors: [NativeEditorResolvedRemoteCursor] = []

    @ObservationIgnored private var editablePageID: String
    @ObservationIgnored var lastSavedTitle: String
    @ObservationIgnored var lastSavedDocument = NativeEditorDocument()
    @ObservationIgnored var lastRemoteUpdatedAt: Date?
    @ObservationIgnored var pendingRemotePage: DocmostEditablePage?
    @ObservationIgnored private var pageAllowsEditing = true
    @ObservationIgnored private var collaborationAllowsEditing = true
    @ObservationIgnored var undoStack: [NativeEditorHistorySnapshot] = []
    @ObservationIgnored var redoStack: [NativeEditorHistorySnapshot] = []
    @ObservationIgnored var lastKnownSnapshot: NativeEditorHistorySnapshot?
    @ObservationIgnored var isApplyingHistory = false
    @ObservationIgnored var crdtDocumentEngine: (any NativeEditorCRDTDocumentEngine)?
    @ObservationIgnored var crdtSyncCoordinator: NativeEditorCRDTSyncCoordinator?
    @ObservationIgnored var crdtLocalChangeTask: Task<Void, any Error>?
    @ObservationIgnored let localAwarenessUpdateStream: AsyncStream<Void>
    @ObservationIgnored let localAwarenessUpdateContinuation: AsyncStream<Void>.Continuation

    init(
        pageID: String,
        initialTitle: String = "",
        crdtDocumentEngine: (any NativeEditorCRDTDocumentEngine)? = nil
    ) {
        self.pageID = pageID
        title = initialTitle
        editablePageID = pageID
        lastSavedTitle = initialTitle
        let awarenessUpdates = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        localAwarenessUpdateStream = awarenessUpdates.stream
        localAwarenessUpdateContinuation = awarenessUpdates.continuation
        lastKnownSnapshot = makeHistorySnapshot()
        self.crdtDocumentEngine = crdtDocumentEngine
        crdtSyncCoordinator = crdtDocumentEngine.map {
            NativeEditorCRDTSyncCoordinator(documentEngine: $0)
        }
    }

    deinit {
        crdtLocalChangeTask?.cancel()
        localAwarenessUpdateContinuation.finish()
    }

    var isEditing: Bool {
        isTitleFocused || activeBlockID != nil
    }

    var currentPageID: String {
        editablePageID
    }

    var isShowingSlashCommands: Bool {
        activeSlashCommandQuery != nil
    }

    var slashCommandQuery: String {
        activeSlashCommandQuery ?? ""
    }

    var filteredSlashCommands: [NativeEditorCommand] {
        NativeEditorCommand.allCases.filter { command in
            command.matches(query: slashCommandQuery)
        }
    }

    var canSave: Bool {
        canEdit &&
        isDirty &&
        isLoading == false &&
        isSaving == false &&
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func load(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page = try await appState.loadEditablePage(idOrSlugId: pageID)
            editablePageID = page.id
            title = page.title
            document = NativeEditorDocument(proseMirrorDocument: page.content ?? ProseMirrorDocument())
            lastSavedTitle = title
            lastSavedDocument = document
            resetEditingHistory()
            markRemoteBaseline(updatedAt: page.updatedAt)
            applyPagePermissions(page.permissions)
            isDirty = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(appState: AppState) async -> Bool {
        guard canSave else { return false }

        isSaving = true
        saveErrorMessage = nil
        defer { isSaving = false }

        do {
            if let crdtDocumentEngine {
                try await waitForPendingCRDTLocalChange()
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let result = try await crdtDocumentEngine.flushPendingLocalChanges(
                    title: trimmedTitle,
                    document: document
                )
                title = result.title ?? trimmedTitle
                lastSavedTitle = title
                lastSavedDocument = document
                markRemoteBaseline(updatedAt: result.updatedAt ?? lastRemoteUpdatedAt)
                lastKnownSnapshot = makeHistorySnapshot()
                isDirty = false
                return true
            }

            let page = try await appState.updatePage(
                pageId: editablePageID,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                document: document.proseMirrorDocument
            )
            editablePageID = page.id
            title = page.title
            lastSavedTitle = title
            lastSavedDocument = document
            markRemoteBaseline(updatedAt: page.updatedAt)
            lastKnownSnapshot = makeHistorySnapshot()
            isDirty = false
            return true
        } catch {
            saveErrorMessage = error.localizedDescription
            return false
        }
    }

    func retryLoad(appState: AppState) {
        Task {
            await load(appState: appState)
        }
    }

    func focusTitle() {
        guard canEdit else {
            clearAuthoringState()
            return
        }
        isTitleFocused = true
        activeBlockID = nil
        selectedBlockID = nil
        visibleBlockControlsID = nil
        notifyLocalAwarenessChanged()
    }

    func focus(blockID: UUID) {
        guard canEdit else {
            clearAuthoringState()
            return
        }
        isTitleFocused = false
        activeBlockID = blockID
        selectedBlockID = nil
        visibleBlockControlsID = nil
        notifyLocalAwarenessChanged()
    }

    func clearFocus() {
        isTitleFocused = false
        activeBlockID = nil
        notifyLocalAwarenessChanged()
    }

    func selectBlock(_ blockID: UUID) {
        guard canEdit else { return }
        guard document.blocks.contains(where: { $0.id == blockID }) else { return }
        isTitleFocused = false
        activeBlockID = nil
        visibleBlockControlsID = blockID
        selectedBlockID = selectedBlockID == blockID ? nil : blockID
        notifyLocalAwarenessChanged()
    }

    func clearBlockSelection() {
        selectedBlockID = nil
    }

    func showBlockControls(for blockID: UUID) {
        guard canEdit else { return }
        guard document.blocks.contains(where: { $0.id == blockID }) else { return }
        isTitleFocused = false
        activeBlockID = nil
        visibleBlockControlsID = blockID
        notifyLocalAwarenessChanged()
    }

    func hideBlockControls() {
        visibleBlockControlsID = nil
        selectedBlockID = nil
    }

    func recalculateDirty() {
        isDirty = title != lastSavedTitle || document != lastSavedDocument
    }

    func applyPagePermissions(_ permissions: DocmostPagePermissions?) {
        pageAllowsEditing = permissions?.canEdit ?? true
        updateEditAccess()
    }

    func applyCollaborationAuthenticationScope(_ scope: NativeEditorCollaborationScope) {
        collaborationAllowsEditing = scope.allowsLocalDocumentUpdates
        updateEditAccess()
    }

    func handleRemotePageDeleted() {
        let message = "This page was deleted in Docmost."
        pageAllowsEditing = false
        canEdit = false
        errorMessage = message
        saveErrorMessage = nil
        pendingRemotePage = nil
        pendingRemoteUpdate = nil
        realtimeStatus = .failed(message)
        activeCollaborators = []
        remoteCursors = []
        resolvedRemoteCursors = []
        discardUnsavedEditsForReadOnlyAccess()
    }

    func clearAuthoringState() {
        isTitleFocused = false
        activeBlockID = nil
        selectedBlockID = nil
        visibleBlockControlsID = nil
    }

    private func updateEditAccess() {
        let nextCanEdit = pageAllowsEditing && collaborationAllowsEditing
        guard canEdit != nextCanEdit else { return }

        canEdit = nextCanEdit

        if canEdit == false {
            discardUnsavedEditsForReadOnlyAccess()
        }
    }

    private func discardUnsavedEditsForReadOnlyAccess() {
        crdtLocalChangeTask?.cancel()
        crdtLocalChangeTask = nil
        title = lastSavedTitle
        document = lastSavedDocument
        isDirty = false
        clearAuthoringState()
        resetEditingHistory()
        notifyLocalAwarenessChanged()
    }

}
