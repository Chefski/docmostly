import Foundation

extension AppState {
    func uploadAttachment(fileURL: URL, pageId: String, attachmentId: String? = nil) async throws -> DocmostAttachment {
        guard let apiClient else {
            throw APIError.connectionFailed("Attachments require a network connection.")
        }

        guard fileURL.hasDirectoryPath == false else {
            throw APIError.connectionFailed("Folders cannot be uploaded as page attachments.")
        }

        let didStartScopedAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartScopedAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let attachment = try await apiClient.uploadFile(
            fileURL: fileURL,
            pageId: pageId,
            attachmentId: attachmentId
        )
        isOffline = false
        return attachment
    }
}
