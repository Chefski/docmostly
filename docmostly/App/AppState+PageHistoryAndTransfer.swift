import Foundation

extension AppState {
    func loadPageHistory(pageId: String, cursor: String? = nil) async throws -> PaginatedResponse<DocmostPageHistory> {
        guard let apiClient else {
            throw APIError.connectionFailed("Page history requires a network connection.")
        }

        let response: PaginatedResponse<DocmostPageHistory> = try await apiClient.send(.pageHistory(
            pageId: pageId,
            cursor: cursor
        ))
        isOffline = false
        return response
    }

    func loadPageHistoryInfo(historyId: String) async throws -> DocmostPageHistory {
        guard let apiClient else {
            throw APIError.connectionFailed("Page history requires a network connection.")
        }

        let history: DocmostPageHistory = try await apiClient.send(.pageHistoryInfo(historyId: historyId))
        isOffline = false
        return history
    }

    func exportPage(
        pageId: String,
        format: DocmostPageExportFormat,
        includeChildren: Bool = false
    ) async throws -> DocmostPageExportFile {
        guard let apiClient else {
            throw APIError.connectionFailed("Exporting pages requires a network connection.")
        }

        let export = try await apiClient.exportPage(
            pageId: pageId,
            format: format,
            includeChildren: includeChildren,
            includeAttachments: false
        )
        isOffline = false
        return export
    }

    func importPage(fileURL: URL, spaceId: String) async throws -> DocmostPage {
        guard let apiClient else {
            throw APIError.connectionFailed("Importing pages requires a network connection.")
        }

        guard fileURL.hasDirectoryPath == false else {
            throw APIError.connectionFailed("Folders cannot be imported as pages.")
        }

        let didStartScopedAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartScopedAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let page = try await apiClient.importPage(fileURL: fileURL, spaceId: spaceId)
        isOffline = false
        return page
    }
}
