import Foundation

enum NativeEditorRemoteConflictResolution {
    case applyRemote
    case keepLocal
}

extension PageReaderView {
    func resolvePendingRemoteUpdate(_ resolution: NativeEditorRemoteConflictResolution) {
        guard let editorViewModel else { return }
        guard editorViewModel.pendingRemoteCRDTSnapshot != nil else {
            resolveLegacyPendingRemoteUpdate(resolution, editorViewModel: editorViewModel)
            return
        }
        guard editorViewModel.isResolvingConflict == false else { return }

        editorViewModel.isResolvingConflict = true
        editorViewModel.clearFocus()

        Task { @MainActor in
            await performPendingRemoteResolution(resolution, editorViewModel: editorViewModel)
        }
    }

    private func performPendingRemoteResolution(
        _ resolution: NativeEditorRemoteConflictResolution,
        editorViewModel: NativeRichEditorViewModel
    ) async {
        await appState.pauseOfflineReplayForCollaborativeResolution()
        defer {
            editorViewModel.isResolvingConflict = false
            appState.scheduleOfflineQueueReconciliation()
        }

        autosaveInlineEdits(reloadCompanions: false)
        let didFinishPersistence = await editorViewModel.autosaveCoordinator
            .waitForCurrentPersistence(timeout: .seconds(15))
        guard didFinishPersistence, editorViewModel.hasDurablyPersistedLocalCRDTDraft else {
            editorViewModel.saveErrorMessage = editorViewModel.saveErrorMessage ??
                "The local draft could not be secured before resolving this conflict. Try again."
            return
        }

        guard let remoteSnapshot = editorViewModel.pendingRemoteCRDTSnapshot else { return }
        let remoteTitle = editorViewModel.pendingRemoteUpdate?.title ??
            remoteSnapshot.title ??
            editorViewModel.title
        let cutoff = Date.now

        do {
            switch resolution {
            case .applyRemote:
                let acknowledgement = try await appState.discardPendingCollaborativeDraft(
                    pageId: editorViewModel.currentPageID,
                    through: cutoff
                )
                guard acknowledgement != .newerPendingUpdatePreserved else {
                    editorViewModel.saveErrorMessage =
                        "A newer local draft appeared while resolving this conflict. Review it and try again."
                    return
                }
                _ = try await appState.saveLocalEditableDraft(
                    pageId: editorViewModel.currentPageID,
                    title: remoteTitle,
                    document: remoteSnapshot.document.proseMirrorDocument
                )
                editorViewModel.acceptPendingRemoteUpdate()
            case .keepLocal:
                let result = try await appState.keepPendingCollaborativeDraft(
                    pageId: editorViewModel.currentPageID,
                    title: editorViewModel.title,
                    document: editorViewModel.document.proseMirrorDocument,
                    remoteBaseDocument: remoteSnapshot.document.proseMirrorDocument,
                    replacingThrough: cutoff
                )
                guard result != .newerPendingUpdatePreserved else {
                    editorViewModel.saveErrorMessage =
                        "A newer local draft appeared while resolving this conflict. Review it and try again."
                    return
                }
                editorViewModel.rejectPendingRemoteUpdate()
            }

            editorViewModel.saveErrorMessage = nil
        } catch {
            editorViewModel.saveErrorMessage =
                "The conflict could not be resolved safely: " + error.localizedDescription
        }
    }

    private func resolveLegacyPendingRemoteUpdate(
        _ resolution: NativeEditorRemoteConflictResolution,
        editorViewModel: NativeRichEditorViewModel
    ) {
        switch resolution {
        case .applyRemote:
            editorViewModel.acceptPendingRemoteUpdate()
        case .keepLocal:
            editorViewModel.rejectPendingRemoteUpdate()
        }
    }
}
