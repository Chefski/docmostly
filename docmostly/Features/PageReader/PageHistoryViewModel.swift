import Foundation
import Observation

@MainActor
@Observable
final class PageHistoryViewModel {
    private(set) var versions: [DocmostPageHistory] = []
    private(set) var selectedVersion: DocmostPageHistory?
    private(set) var selectedDocument = NativeEditorDocument()
    private(set) var isLoadingList = false
    private(set) var isLoadingSelection = false
    private(set) var isRestoring = false
    private(set) var hasMoreVersions = false
    private(set) var nextCursor: String?
    var errorMessage: String?
    var restoreErrorMessage: String?
    var pendingRestoreVersion: DocmostPageHistory?

    var canRequestRestoreConfirmation: Bool {
        selectedVersion?.content != nil && isRestoring == false
    }

    func loadInitial(pageID: String, appState: AppState) async {
        versions = []
        selectedVersion = nil
        selectedDocument = NativeEditorDocument()
        nextCursor = nil
        hasMoreVersions = false
        await loadNextPage(pageID: pageID, appState: appState)
    }

    func loadNextPage(pageID: String, appState: AppState) async {
        guard isLoadingList == false else { return }
        guard versions.isEmpty || hasMoreVersions else { return }

        isLoadingList = true
        errorMessage = nil
        defer { isLoadingList = false }

        do {
            let response = try await appState.loadPageHistory(pageId: pageID, cursor: nextCursor)
            let existingIDs = Set(versions.map(\.id))
            versions.append(contentsOf: response.items.filter { existingIDs.contains($0.id) == false })
            nextCursor = response.meta.nextCursor
            hasMoreVersions = response.meta.hasNextPage

            if selectedVersion == nil, let firstVersion = versions.first {
                await selectVersion(firstVersion.id, appState: appState)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectVersion(_ versionID: String, appState: AppState) async {
        guard selectedVersion?.id != versionID else { return }
        guard let summary = versions.first(where: { $0.id == versionID }) else { return }

        selectedVersion = summary
        selectedDocument = NativeEditorDocument(proseMirrorDocument: summary.content ?? ProseMirrorDocument())
        isLoadingSelection = true
        errorMessage = nil
        defer { isLoadingSelection = false }

        do {
            let detail = try await appState.loadPageHistoryInfo(historyId: versionID)
            guard selectedVersion?.id == versionID else { return }
            selectedVersion = detail
            selectedDocument = NativeEditorDocument(proseMirrorDocument: detail.content ?? ProseMirrorDocument())
            if let index = versions.firstIndex(where: { $0.id == detail.id }) {
                versions[index] = detail
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestRestoreConfirmation() {
        pendingRestoreVersion = selectedVersion
    }

    func cancelRestoreConfirmation() {
        pendingRestoreVersion = nil
    }

    func restoreConfirmed(
        editorViewModel: NativeRichEditorViewModel,
        appState: AppState
    ) async -> Bool {
        guard let version = pendingRestoreVersion, let content = version.content else {
            return false
        }
        guard editorViewModel.canEdit else {
            restoreErrorMessage = "You do not have permission to restore this page."
            pendingRestoreVersion = nil
            return false
        }
        guard isRestoring == false else { return false }

        isRestoring = true
        restoreErrorMessage = nil
        defer {
            isRestoring = false
            pendingRestoreVersion = nil
        }

        do {
            try await editorViewModel.waitForPendingCRDTLocalChange()
            editorViewModel.applyServerHistorySnapshot(title: version.title, document: content)
            if editorViewModel.canSave {
                guard await editorViewModel.save(appState: appState) else {
                    restoreErrorMessage = editorViewModel.saveErrorMessage ?? "Could not restore this version."
                    return false
                }
            } else if editorViewModel.title != editorViewModel.lastSavedTitle ||
                        editorViewModel.document != editorViewModel.lastSavedDocument {
                restoreErrorMessage = "Could not restore this version because it is not currently saveable."
                return false
            }
            return true
        } catch {
            restoreErrorMessage = error.localizedDescription
            return false
        }
    }
}
