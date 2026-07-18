import Foundation

extension NativeRichEditorViewModel {
    func freezeAuthoringForReadOnlyAccess() {
        crdtLocalChangeTask?.cancel()
        crdtLocalChangeTask = nil
        crdtOperationGeneration += 1
        clearAuthoringState()
        if isDirty, retainedReadOnlyDraftSnapshot == nil {
            retainedReadOnlyDraftSnapshot = makeHistorySnapshot()
        }
        lastKnownSnapshot = makeHistorySnapshot()
        hasDurablyPersistedLocalCRDTDraft = false
        notifyLocalAwarenessChanged()
    }

    func resumeAuthoringAfterReadOnlyAccess() {
        guard retainedReadOnlyDraftSnapshot != nil else { return }

        retainedReadOnlyDraftSnapshot = nil
        if isDirty {
            localEditRevision += 1
            hasDurablyPersistedLocalCRDTDraft = false
        }
    }
}
