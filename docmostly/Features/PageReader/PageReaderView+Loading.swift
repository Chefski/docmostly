import SwiftUI

extension PageReaderView {
    func retry() {
        Task {
            await loadNativePage()
        }
    }

    func loadNativePage() async {
        let requestedPageID = pageID
        let requestedInitialTitle = initialTitle
        let outgoingEditorViewModel = editorViewModel
        var didRequestOutgoingPersistence = false

        let outcome = await PageReaderPageSwitchHandoff.perform(
            requiresInitialOutgoingFlush: outgoingEditorViewModel != nil,
            hasOutgoingChanges: {
                guard let outgoingEditorViewModel else { return false }
                return outgoingEditorViewModel.hasOutgoingChangesRequiringPersistence
            },
            flushOutgoing: {
                guard
                    let outgoingEditorViewModel,
                    let attachedEditorViewModel = self.editorViewModel,
                    attachedEditorViewModel === outgoingEditorViewModel
                else {
                    return .failed
                }

                if didRequestOutgoingPersistence == false {
                    autosaveInlineEdits(reloadCompanions: false)
                    didRequestOutgoingPersistence = true
                }
                let didFinishPersistence = await outgoingEditorViewModel.autosaveCoordinator
                    .waitForCurrentPersistence(timeout: .seconds(2))
                guard Task.isCancelled == false else { return .retry }
                guard didFinishPersistence else { return .retry }

                didRequestOutgoingPersistence = false
                return outgoingEditorViewModel.saveErrorMessage == nil ? .completed : .failed
            },
            detachOutgoing: {
                if let outgoingEditorViewModel {
                    guard
                        let attachedEditorViewModel = self.editorViewModel,
                        attachedEditorViewModel === outgoingEditorViewModel
                    else {
                        return false
                    }
                } else {
                    guard self.editorViewModel == nil else { return false }
                }

                editorFocusedField = nil
                realtimePageID = nil
                editorViewModel = nil
                return true
            },
            loadIncoming: {
                await loadNativePage(
                    requestedPageID: requestedPageID,
                    initialTitle: requestedInitialTitle
                )
            }
        )

        if outcome == .outgoingFlushFailed,
           Task.isCancelled == false,
           let outgoingEditorViewModel,
           let attachedEditorViewModel = self.editorViewModel,
           attachedEditorViewModel === outgoingEditorViewModel {
            pageActionErrorMessage = outgoingEditorViewModel.saveErrorMessage ??
                "Could not finish saving this page. The page switch was paused to keep your edits safe."
        }
    }

    private func loadNativePage(requestedPageID: String, initialTitle: String?) async {
        for attempt in 0..<2 {
            let editorViewModel = NativeRichEditorViewModel(
                pageID: requestedPageID,
                initialTitle: initialTitle ?? ""
            )
            let didLoadPage = await editorViewModel.load(appState: appState)
            guard Task.isCancelled == false else { return }

            if didLoadPage {
                await finishNativePageLoad(editorViewModel)
                return
            }

            if editorViewModel.errorMessage != nil {
                self.editorViewModel = editorViewModel
                return
            }

            guard attempt == 0 else {
                editorViewModel.errorMessage = "Page loading was interrupted."
                self.editorViewModel = editorViewModel
                return
            }

            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
        }
    }

    private func finishNativePageLoad(_ editorViewModel: NativeRichEditorViewModel) async {
        async let loadCompanions: Void = viewModel.loadCompanions(
            pageID: editorViewModel.currentPageID,
            appState: appState
        )

        await NativeEditorCRDTDocumentEngineAttachment.attachIfAvailable(
            to: editorViewModel,
            appState: appState
        )
        guard Task.isCancelled == false else {
            await loadCompanions
            return
        }

        self.editorViewModel = editorViewModel
        if let currentSpaceID = editorViewModel.currentSpaceID {
            pageLoaded(editorViewModel.currentPageSlugID, currentSpaceID, editorViewModel.title)
        }
        if editorViewModel.canEdit == false {
            readerMode = .read
        }
        if focusesEditorOnLoad, editorViewModel.canEdit {
            await Task.yield()
            editorFocusedField = .title
            editorViewModel.focusTitle()
        }

        realtimePageID = editorViewModel.currentPageID
        await loadCompanions
    }
}
