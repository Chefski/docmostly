import SwiftUI

extension PageReaderView {
    func showPageHistory() {
        guard editorViewModel != nil else { return }
        pageHistoryViewModel = PageHistoryViewModel()
        isShowingPageHistory = true
    }

    func showPageExport() {
        guard editorViewModel != nil else { return }
        pageExportViewModel = PageExportViewModel()
        isShowingPageExport = true
    }

    func showPageImport() {
        guard editorViewModel?.canEdit == true, editorViewModel?.currentSpaceID != nil else {
            pageActionErrorMessage = "Importing pages requires edit access to this space."
            return
        }

        pageImportViewModel = PageImportViewModel()
        isShowingPageImport = true
    }

    func handlePageImport(_ result: Result<[URL], any Error>) {
        guard let spaceID = editorViewModel?.currentSpaceID else {
            pageActionErrorMessage = "Importing pages requires an active space."
            return
        }

        do {
            let fileURLs = try result.get()
            guard fileURLs.isEmpty == false else { return }

            pageImportTask?.cancel()
            pageImportTask = Task {
                await pageImportViewModel.importFiles(fileURLs, spaceID: spaceID, appState: appState)
                if Task.isCancelled == false, pageImportViewModel.importedPages.isEmpty == false {
                    await appState.loadSpaces()
                    if let firstPage = pageImportViewModel.importedPages.first {
                        appState.selectPage(
                            id: firstPage.slugId,
                            spaceID: firstPage.spaceId,
                            revealSpaceInSidebar: true
                        )
                    }
                }
                pageImportTask = nil
            }
        } catch {
            pageActionErrorMessage = error.localizedDescription
        }
    }

    func cancelPageImport() {
        pageImportTask?.cancel()
        pageImportTask = nil
    }

    func restoreSelectedPageVersion() async -> Bool {
        guard let editorViewModel else { return false }

        editorFocusedField = nil
        editorViewModel.clearFocus()
        if editorViewModel.canSave, await editorViewModel.save(appState: appState) == false {
            pageActionErrorMessage = editorViewModel.saveErrorMessage ?? "Could not save current edits before restore."
            return false
        }

        let didRestore = await pageHistoryViewModel.restoreConfirmed(
            editorViewModel: editorViewModel,
            appState: appState
        )

        if didRestore {
            await viewModel.loadCompanions(pageID: editorViewModel.currentPageID, appState: appState)
            readerMode = .read
        } else if let errorMessage = pageHistoryViewModel.restoreErrorMessage {
            pageActionErrorMessage = errorMessage
        }

        return didRestore
    }
}
