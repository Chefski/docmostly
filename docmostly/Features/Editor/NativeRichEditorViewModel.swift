import Foundation
import Observation
import SwiftUI

// swiftlint:disable file_length

@MainActor
@Observable
final class NativeRichEditorViewModel {
    let pageID: String
    var title: String
    var icon: String?
    var document = NativeEditorDocument() {
        didSet {
            rebuildResolvedRemoteCursorIndex()
            refreshSearchMatches()
        }
    }
    var isLoading = false
    var isSaving = false
    var isResolvingConflict = false
    var isDirty = false
    var localEditRevision: UInt = 0
    var canEdit = true
    var hasPageRestriction = false
    var errorMessage: String?
    var saveErrorMessage: String?
    var activeBlockID: UUID?
    var focusedTextInputBlockID: UUID?
    var selectedBlockID: UUID?
    var visibleBlockControlsID: UUID?
    var isTitleFocused = false
    var canUndo = false
    var canRedo = false
    var searchQuery = "" {
        didSet {
            refreshSearchMatches()
        }
    }
    var replacementText = ""
    var currentSearchMatchIndex = 0
    var searchMatches: [NativeEditorSearchMatch] = []
    var realtimeStatus: NativeEditorRealtimeStatus = .disconnected
    var pendingRemoteUpdate: NativeEditorRemoteUpdate?
    var activeCollaborators: [NativeEditorCollaborator] = []
    var remoteCursors: [NativeEditorRemoteCursor] = []
    var resolvedRemoteCursors: [NativeEditorResolvedRemoteCursor] = [] {
        didSet {
            rebuildResolvedRemoteCursorIndex()
        }
    }
    var resolvedRemoteCursorsByBlockID: [UUID: [NativeEditorResolvedRemoteCursor]] = [:]
    var remotePresenceProjection = NativeEditorRemotePresenceProjection(
        document: NativeEditorDocument(),
        cursors: []
    )
    var creator: DocmostPagePerson?
    var lastUpdatedBy: DocmostPagePerson?
    var createdAt: Date?
    var updatedAt: Date?

    @ObservationIgnored private var editablePageID: String
    @ObservationIgnored private var editablePageSlugID: String
    @ObservationIgnored private var editablePageSpaceID: String?
    @ObservationIgnored var savedBaselineRevision: UInt = 0
    @ObservationIgnored var lastSavedTitle: String {
        didSet {
            savedBaselineRevision += 1
        }
    }
    @ObservationIgnored var lastSavedDocument = NativeEditorDocument() {
        didSet {
            savedBaselineRevision += 1
        }
    }
    @ObservationIgnored var lastRemoteUpdatedAt: Date?
    @ObservationIgnored var pendingRemotePage: DocmostEditablePage?
    @ObservationIgnored var pendingRemoteCRDTSnapshot: NativeEditorCRDTDocumentSnapshot?
    @ObservationIgnored var hasDurablyPersistedLocalCRDTDraft = false
    @ObservationIgnored var retainedReadOnlyDraftSnapshot: NativeEditorHistorySnapshot?
    @ObservationIgnored var isCRDTEngineReadyForLocalChanges = false
    @ObservationIgnored var crdtOperationGeneration: UInt = 0
    @ObservationIgnored private var pageAllowsEditing = true
    @ObservationIgnored private var collaborationAllowsEditing = true
    @ObservationIgnored var undoStack: [NativeEditorHistorySnapshot] = []
    @ObservationIgnored var redoStack: [NativeEditorHistorySnapshot] = []
    @ObservationIgnored var lastKnownSnapshot: NativeEditorHistorySnapshot?
    @ObservationIgnored var isApplyingHistory = false
    @ObservationIgnored var crdtDocumentEngine: (any NativeEditorCRDTDocumentEngine)?
    @ObservationIgnored var documentSession: DocumentSession?
    @ObservationIgnored var crdtSyncCoordinator: NativeEditorCRDTSyncCoordinator?
    @ObservationIgnored let crdtSessionAttachmentID = UUID()
    @ObservationIgnored var crdtLocalChangeTask: Task<Void, any Error>?
    @ObservationIgnored var activeSaveTask: Task<Bool, Never>?
    @ObservationIgnored let autosaveCoordinator = NativeEditorAutosaveCoordinator()
    @ObservationIgnored let localAwarenessUpdateStream: AsyncStream<Void>
    @ObservationIgnored let localAwarenessUpdateContinuation: AsyncStream<Void>.Continuation

    init(
        pageID: String,
        initialTitle: String = "",
        crdtDocumentEngine: (any NativeEditorCRDTDocumentEngine)? = nil
    ) {
        self.pageID = pageID
        title = initialTitle
        icon = nil
        editablePageID = pageID
        editablePageSlugID = pageID
        lastSavedTitle = initialTitle
        let awarenessUpdates = AsyncStream.makeStream(of: Void.self, bufferingPolicy: .bufferingNewest(1))
        localAwarenessUpdateStream = awarenessUpdates.stream
        localAwarenessUpdateContinuation = awarenessUpdates.continuation
        lastKnownSnapshot = makeHistorySnapshot()
        self.crdtDocumentEngine = crdtDocumentEngine
        isCRDTEngineReadyForLocalChanges = crdtDocumentEngine?
            .requiresInitialRemoteSnapshot == false
        crdtSyncCoordinator = crdtDocumentEngine.map(makeCRDTSyncCoordinator)
    }

    deinit {
        crdtLocalChangeTask?.cancel()
        localAwarenessUpdateContinuation.finish()
    }

    var isEditing: Bool {
        isTitleFocused || focusedTextInputBlockID != nil
    }

    var currentPageID: String {
        editablePageID
    }

    var currentPageSlugID: String {
        editablePageSlugID
    }

    var currentSpaceID: String? {
        editablePageSpaceID
    }

    var isShowingSlashCommands: Bool {
        activeSlashCommandQuery != nil
    }

    var slashCommandQuery: String {
        activeSlashCommandQuery ?? ""
    }

    var filteredSlashCommands: [NativeEditorCommand] {
        guard let slashCommandQuery = activeSlashCommandQuery else { return [] }

        let matches = NativeEditorCommand.slashMenuCases.enumerated().compactMap { index, command in
            command.matchPriority(query: slashCommandQuery).map { priority in
                (command: command, priority: priority, index: index)
            }
        }

        return matches.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
            return lhs.index < rhs.index
        }.map(\.command)
    }

    var canSave: Bool {
        canEdit &&
        isDirty &&
        isLoading == false &&
        isSaving == false
    }

    var hasOutgoingChangesRequiringPersistence: Bool {
        isSaving || (isDirty && hasDurablyPersistedLocalCRDTDraft == false)
    }

    @discardableResult
    func load(appState: AppState) async -> Bool {
        isLoading = true
        errorMessage = nil
        pendingRemotePage = nil
        pendingRemoteUpdate = nil
        pendingRemoteCRDTSnapshot = nil
        hasDurablyPersistedLocalCRDTDraft = false
        retainedReadOnlyDraftSnapshot = nil
        isCRDTEngineReadyForLocalChanges = crdtDocumentEngine?
            .requiresInitialRemoteSnapshot == false
        defer { isLoading = false }

        do {
            let page = try await appState.loadEditablePage(idOrSlugId: pageID)
            editablePageID = page.id
            editablePageSlugID = page.slugId
            editablePageSpaceID = page.spaceId
            title = page.title
            document = NativeEditorDocument(proseMirrorDocument: page.content ?? ProseMirrorDocument())
            applyPageDetails(page)
            lastSavedTitle = title
            lastSavedDocument = document
            resetEditingHistory()
            markRemoteBaseline(updatedAt: page.updatedAt)
            applyPagePermissions(page.permissions)
            isDirty = false
            return true
        } catch {
            guard Self.isCancelledLoadError(error) == false else {
                return false
            }
            errorMessage = error.localizedDescription
            return false
        }
    }

    func save(appState: AppState) async -> Bool {
        if let activeSaveTask {
            let didSave = await activeSaveTask.value
            guard canEdit, isDirty, isLoading == false else {
                return didSave
            }
            return await save(appState: appState)
        }

        guard canSave else { return false }

        let snapshot = makeSaveSnapshot()
        isSaving = true
        saveErrorMessage = nil

        let saveTask = Task { [self, appState] in
            let didSave = await persist(snapshot: snapshot, appState: appState)
            activeSaveTask = nil
            isSaving = false
            return didSave
        }
        activeSaveTask = saveTask
        return await saveTask.value
    }

    func persistRetainedReadOnlyDraft(appState: AppState) async -> Bool {
        if let activeSaveTask {
            _ = await activeSaveTask.value
        }

        guard canEdit == false, isDirty else { return true }

        let snapshotTitle = title
        let snapshotDocument = document
        let snapshotBaseTitle = lastSavedTitle
        saveErrorMessage = nil

        do {
            try await retainCurrentDocumentDraft(
                title: snapshotTitle,
                document: snapshotDocument.proseMirrorDocument
            )
            let persistence = try await appState.persistDeferredCollaborativeDraft(
                pageId: editablePageID,
                title: snapshotTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                documentSnapshot: snapshotDocument.proseMirrorDocument,
                baseTitle: snapshotBaseTitle
            )
            if let page = persistence.page {
                editablePageID = page.id
                editablePageSlugID = page.slugId
            }

            hasDurablyPersistedLocalCRDTDraft = canEdit == false &&
                isDirty &&
                title == snapshotTitle &&
                document == snapshotDocument
            return true
        } catch {
            saveErrorMessage = error.localizedDescription
            hasDurablyPersistedLocalCRDTDraft = false
            return false
        }
    }

    func retryLoad(appState: AppState) {
        Task {
            await load(appState: appState)
        }
    }

    static func isCancelledLoadError(_ error: any Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }

        return false
    }

    func focusTitle() {
        guard canEdit else {
            clearAuthoringState()
            return
        }
        isTitleFocused = true
        activeBlockID = nil
        focusedTextInputBlockID = nil
        selectedBlockID = nil
        visibleBlockControlsID = nil
        notifyLocalAwarenessChanged()
    }

    func focus(blockID: UUID) {
        guard canEdit else {
            clearAuthoringState()
            return
        }
        guard document.blocks.contains(where: { $0.id == blockID && $0.isEditable }) else { return }
        guard
            isTitleFocused || activeBlockID != blockID || selectedBlockID != nil || visibleBlockControlsID != nil
        else {
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
        focusedTextInputBlockID = nil
        notifyLocalAwarenessChanged()
    }

    func selectBlock(_ blockID: UUID) {
        guard canEdit else { return }
        guard document.blocks.contains(where: { $0.id == blockID }) else { return }
        isTitleFocused = false
        activeBlockID = nil
        focusedTextInputBlockID = nil
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
        focusedTextInputBlockID = nil
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
        hasPageRestriction = permissions?.hasRestriction ?? false
        updateEditAccess()
    }

    func applyCollaborationAuthenticationScope(_ scope: NativeEditorCollaborationScope) {
        collaborationAllowsEditing = scope.allowsLocalDocumentUpdates
        updateEditAccess()
    }

    func markCollaborationUnavailable(_ message: String) {
        collaborationAllowsEditing = false
        activeCollaborators = []
        remoteCursors = []
        resolvedRemoteCursors = []
        updateEditAccess()
        if realtimeStatus != .conflict {
            realtimeStatus = .failed(message)
        }
    }

    func markCollaborationAuthenticationFailed(_ message: String) {
        collaborationAllowsEditing = false
        activeCollaborators = []
        remoteCursors = []
        resolvedRemoteCursors = []
        updateEditAccess()
        if realtimeStatus != .conflict {
            realtimeStatus = .authenticationFailed(message)
        }
    }

    func handleRemotePageDeleted() {
        let message = "This page was deleted in Docmost."
        pageAllowsEditing = false
        canEdit = false
        errorMessage = message
        saveErrorMessage = nil
        realtimeStatus = .failed(message)
        activeCollaborators = []
        remoteCursors = []
        resolvedRemoteCursors = []
        freezeAuthoringForReadOnlyAccess()
    }

    func clearAuthoringState() {
        isTitleFocused = false
        activeBlockID = nil
        focusedTextInputBlockID = nil
        selectedBlockID = nil
        visibleBlockControlsID = nil
    }

    func updateEditAccess() {
        let crdtAllowsEditing = crdtDocumentEngine == nil || isCRDTEngineReadyForLocalChanges
        let nextCanEdit = pageAllowsEditing && collaborationAllowsEditing && crdtAllowsEditing
        guard canEdit != nextCanEdit else { return }

        canEdit = nextCanEdit

        if canEdit == false {
            freezeAuthoringForReadOnlyAccess()
        } else {
            resumeAuthoringAfterReadOnlyAccess()
        }
    }

}

private extension NativeRichEditorViewModel {
    struct SaveSnapshot {
        let pageID: String
        let title: String
        let document: NativeEditorDocument
        let baseTitle: String
        let baseDocument: NativeEditorDocument
        let localEditRevision: UInt
        let savedBaselineRevision: UInt
        let requiresLocalOnlyCRDTPersistence: Bool
        let crdtFlushTask: Task<NativeEditorCRDTSaveResult, any Error>?

        var trimmedTitle: String {
            title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    func makeSaveSnapshot() -> SaveSnapshot {
        let snapshotTitle = title
        let snapshotDocument = document
        let requiresLocalOnlyCRDTPersistence = crdtDocumentEngine != nil &&
            (pendingRemoteCRDTSnapshot != nil || isCRDTEngineReadyForLocalChanges == false)
        return SaveSnapshot(
            pageID: editablePageID,
            title: snapshotTitle,
            document: snapshotDocument,
            baseTitle: lastSavedTitle,
            baseDocument: lastSavedDocument,
            localEditRevision: localEditRevision,
            savedBaselineRevision: savedBaselineRevision,
            requiresLocalOnlyCRDTPersistence: requiresLocalOnlyCRDTPersistence,
            crdtFlushTask: requiresLocalOnlyCRDTPersistence ? nil : enqueueCRDTSnapshotFlush(
                title: snapshotTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                document: snapshotDocument
            )
        )
    }

    func persist(snapshot: SaveSnapshot, appState: AppState) async -> Bool {
        do {
            if snapshot.requiresLocalOnlyCRDTPersistence {
                try await retainCurrentDocumentDraft(
                    title: snapshot.trimmedTitle,
                    document: snapshot.document.proseMirrorDocument
                )
                let persistence = try await appState.persistDeferredCollaborativeDraft(
                    pageId: snapshot.pageID,
                    title: snapshot.trimmedTitle,
                    documentSnapshot: snapshot.document.proseMirrorDocument,
                    baseTitle: snapshot.baseTitle
                )
                if let page = persistence.page {
                    editablePageID = page.id
                    editablePageSlugID = page.slugId
                }
                completeLocalOnlyCRDTDraftPersistence(snapshot: snapshot)
                return true
            }

            if crdtDocumentEngine != nil {
                guard let crdtFlushTask = snapshot.crdtFlushTask else {
                    throw APIError.connectionFailed("Collaborative save preparation failed.")
                }
                let result = try await crdtFlushTask.value
                let flushedTitle = result.title ?? snapshot.trimmedTitle

                if appState.hasPageUpdatePersistence {
                    let persistence = try await appState.updateCollaborativePageTitle(
                        pageId: snapshot.pageID,
                        title: flushedTitle,
                        documentSnapshot: snapshot.document.proseMirrorDocument,
                        baseTitle: snapshot.baseTitle
                    )
                    if let page = persistence.page {
                        editablePageID = page.id
                        editablePageSlugID = page.slugId
                    }
                    completeSuccessfulSave(
                        snapshot: snapshot,
                        persistedTitle: persistence.persistedTitle,
                        updatedAt: persistence.updatedAt ?? result.updatedAt,
                        page: persistence.page
                    )
                } else {
                    completeSuccessfulSave(
                        snapshot: snapshot,
                        persistedTitle: flushedTitle,
                        updatedAt: result.updatedAt,
                        page: nil
                    )
                }
                return true
            }

            let page = try await appState.updatePage(
                pageId: snapshot.pageID,
                title: snapshot.trimmedTitle,
                document: snapshot.document.proseMirrorDocument,
                baseTitle: snapshot.baseTitle,
                baseDocument: snapshot.baseDocument.proseMirrorDocument
            )
            editablePageID = page.id
            editablePageSlugID = page.slugId
            completeSuccessfulSave(
                snapshot: snapshot,
                persistedTitle: page.title,
                updatedAt: page.updatedAt,
                page: page
            )
            return true
        } catch {
            saveErrorMessage = error.localizedDescription
            return false
        }
    }

    func completeLocalOnlyCRDTDraftPersistence(snapshot: SaveSnapshot) {
        let stillRequiresLocalOnlyPersistence = pendingRemoteCRDTSnapshot != nil ||
            isCRDTEngineReadyForLocalChanges == false
        guard stillRequiresLocalOnlyPersistence else {
            hasDurablyPersistedLocalCRDTDraft = false
            return
        }

        let hasNewerLocalEdits = localEditRevision != snapshot.localEditRevision
        let currentContentMatchesSnapshot = title == snapshot.title && document == snapshot.document
        hasDurablyPersistedLocalCRDTDraft = hasNewerLocalEdits == false && currentContentMatchesSnapshot
        lastKnownSnapshot = makeHistorySnapshot()
        recalculateDirty()
    }

    func completeSuccessfulSave(
        snapshot: SaveSnapshot,
        persistedTitle: String,
        updatedAt: Date?,
        page: DocmostEditablePage?
    ) {
        let baselineChangedWhileSaving = savedBaselineRevision != snapshot.savedBaselineRevision
        let receivedConflictingRemoteUpdate = pendingRemotePage != nil ||
            pendingRemoteUpdate != nil ||
            pendingRemoteCRDTSnapshot != nil

        guard baselineChangedWhileSaving == false, receivedConflictingRemoteUpdate == false else {
            lastKnownSnapshot = makeHistorySnapshot()
            recalculateDirty()
            return
        }

        let hasNewerLocalEdits = localEditRevision != snapshot.localEditRevision
        let currentContentMatchesSnapshot = title == snapshot.title && document == snapshot.document

        if hasNewerLocalEdits == false, currentContentMatchesSnapshot == false {
            lastSavedTitle = title
            lastSavedDocument = document
        } else {
            if title == snapshot.title {
                title = persistedTitle
            }
            lastSavedTitle = persistedTitle
            lastSavedDocument = snapshot.document
        }

        if let page {
            applyPageDetails(page)
        }
        markRemoteBaseline(updatedAt: latestRemoteUpdateDate(updatedAt))
        lastKnownSnapshot = makeHistorySnapshot()
        recalculateDirty()
    }

    func latestRemoteUpdateDate(_ candidate: Date?) -> Date? {
        switch (lastRemoteUpdatedAt, candidate) {
        case (.none, .none):
            nil
        case (.some(let existing), .none):
            existing
        case (.none, .some(let candidate)):
            candidate
        case (.some(let existing), .some(let candidate)):
            max(existing, candidate)
        }
    }
}
