import Foundation

extension AppState {
    func loadComments(pageId: String) async throws -> [DocmostComment] {
        guard let apiClient else { return [] }
        let response: PaginatedResponse<DocmostComment> = try await apiClient.send(.comments(pageId: pageId))
        return response.items
    }

    func addPageComment(pageId: String, text: String) async throws -> DocmostComment {
        guard let apiClient else {
            throw APIError.connectionFailed("Comments require a network connection.")
        }
        let content = CommentPayload.plainText(text).jsonString
        return try await apiClient.send(.createComment(pageId: pageId, content: content, type: .page))
    }

    func addInlineComment(pageId: String, text: String, selectedText: String) async throws -> DocmostComment {
        guard let apiClient else {
            throw APIError.connectionFailed("Comments require a network connection.")
        }
        let content = CommentPayload.plainText(text).jsonString
        return try await apiClient.send(.createComment(
            pageId: pageId,
            content: content,
            type: .inline,
            selection: selectedText
        ))
    }
}
