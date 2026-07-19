import SwiftUI

extension PageReaderView {
    func autosaveInlineEdits(reloadCompanions: Bool = true) {
        guard let editorViewModel else { return }
        guard editorViewModel.isDirty || editorViewModel.isSaving else { return }

        editorViewModel.autosaveCoordinator.flush(
            editorSaveOperation(for: editorViewModel, reloadCompanions: reloadCompanions)
        )
    }

    func scheduleInlineAutosave() {
        guard let editorViewModel, editorViewModel.canEdit else { return }
        guard editorViewModel.isLoading == false, editorViewModel.isDirty else { return }

        editorViewModel.autosaveCoordinator.schedule(
            editorSaveOperation(for: editorViewModel, reloadCompanions: false)
        )
    }

    private func editorSaveOperation(
        for editorViewModel: NativeRichEditorViewModel,
        reloadCompanions: Bool
    ) -> NativeEditorAutosaveCoordinator.Operation {
        let appState = appState
        let pageCompanionViewModel = viewModel

        return { [editorViewModel, appState, weak pageCompanionViewModel] in
            let didSave: Bool
            if editorViewModel.canEdit, editorViewModel.isDirty || editorViewModel.isSaving {
                didSave = await editorViewModel.save(appState: appState)
            } else if editorViewModel.canEdit == false, editorViewModel.isDirty {
                didSave = await editorViewModel.persistRetainedReadOnlyDraft(appState: appState)
            } else {
                didSave = true
            }

            if didSave, reloadCompanions, let pageCompanionViewModel {
                await pageCompanionViewModel.loadCompanions(
                    pageID: editorViewModel.currentPageID,
                    appState: appState
                )
            }
        }
    }
}
