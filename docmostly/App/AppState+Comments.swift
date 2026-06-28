import Foundation

extension AppState {
    func loadComments(pageId: String) async throws -> [DocmostComment] {
        guard let apiClient else {
            return pageCommentsByID[pageId] ?? []
        }

        do {
            let response: PaginatedResponse<DocmostComment> = try await apiClient.send(.comments(pageId: pageId))
            pageCommentsByID[pageId] = response.items
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return response.items
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return pageCommentsByID[pageId] ?? []
        }
    }

    func addPageComment(pageId: String, text: String) async throws -> DocmostComment {
        let content = CommentPayload.plainText(text).jsonString
        guard let apiClient else {
            return try await queueComment(pageId: pageId, text: text, content: content, type: .page)
        }

        do {
            let comment: DocmostComment = try await apiClient.send(.createComment(
                pageId: pageId,
                content: content,
                type: .page
            ))
            applyLocalComment(comment)
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return comment
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return try await queueComment(pageId: pageId, text: text, content: content, type: .page)
        }
    }

    func addInlineComment(
        pageId: String,
        text: String,
        selectedText: String,
        yjsSelection: NativeEditorYjsSelection? = nil
    ) async throws -> DocmostComment {
        let content = CommentPayload.plainText(text).jsonString
        guard let apiClient else {
            return try await queueComment(
                pageId: pageId,
                text: text,
                content: content,
                type: .inline,
                selection: selectedText,
                yjsSelection: yjsSelection
            )
        }

        do {
            let comment: DocmostComment = try await apiClient.send(.createComment(
                pageId: pageId,
                content: content,
                type: .inline,
                selection: selectedText,
                yjsSelection: yjsSelection
            ))
            applyLocalComment(comment)
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return comment
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return try await queueComment(
                pageId: pageId,
                text: text,
                content: content,
                type: .inline,
                selection: selectedText,
                yjsSelection: yjsSelection
            )
        }
    }

    func resolveComment(commentId: String, pageId: String, resolved: Bool) async throws -> DocmostComment {
        guard let apiClient else {
            return try await queueCommentResolution(commentId: commentId, pageId: pageId, resolved: resolved)
        }

        do {
            let comment: DocmostComment = try await apiClient.send(.resolveComment(
                commentId: commentId,
                pageId: pageId,
                resolved: resolved
            ))
            applyLocalComment(comment)
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return comment
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return try await queueCommentResolution(commentId: commentId, pageId: pageId, resolved: resolved)
        }
    }

    private func queueComment(
        pageId: String,
        text: String,
        content: String,
        type: DocmostCommentType,
        selection: String? = nil,
        yjsSelection: NativeEditorYjsSelection? = nil
    ) async throws -> DocmostComment {
        let localId = "offline-comment-\(UUID().uuidString)"
        try await queueOfflineMutation(.createComment(
            localId: localId,
            pageId: pageId,
            content: content,
            plainText: text,
            type: type,
            selection: selection,
            yjsSelection: yjsSelection
        ))

        let comment = DocmostComment(
            id: localId,
            content: text,
            selection: selection,
            type: type.rawValue,
            creatorId: currentUser?.user.id ?? "offline",
            pageId: pageId,
            workspaceId: currentUser?.workspace.id,
            createdAt: Date.now,
            creator: currentUser?.user
        )
        applyLocalComment(comment)
        return comment
    }

    private func queueCommentResolution(
        commentId: String,
        pageId: String,
        resolved: Bool
    ) async throws -> DocmostComment {
        try await queueOfflineMutation(.resolveComment(commentId: commentId, pageId: pageId, resolved: resolved))

        let updatedComment = projectedResolvedComment(commentId: commentId, pageId: pageId, resolved: resolved)
        applyLocalComment(updatedComment)
        return updatedComment
    }

    private func applyLocalComment(_ comment: DocmostComment) {
        var comments = pageCommentsByID[comment.pageId] ?? []
        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[index] = comment
        } else {
            comments.append(comment)
        }
        pageCommentsByID[comment.pageId] = comments
    }

    private func projectedResolvedComment(commentId: String, pageId: String, resolved: Bool) -> DocmostComment {
        if let comments = pageCommentsByID[pageId],
           let existing = comments.first(where: { $0.id == commentId }) {
            return DocmostComment(
                id: existing.id,
                content: existing.content,
                selection: existing.selection,
                type: existing.type,
                creatorId: existing.creatorId,
                pageId: existing.pageId,
                parentCommentId: existing.parentCommentId,
                resolvedById: resolved ? currentUser?.user.id : nil,
                resolvedAt: resolved ? Date.now : nil,
                workspaceId: existing.workspaceId,
                createdAt: existing.createdAt,
                editedAt: existing.editedAt,
                deletedAt: existing.deletedAt,
                creator: existing.creator,
                resolvedBy: resolved ? currentUser?.user : nil
            )
        }

        return DocmostComment(
            id: commentId,
            content: nil,
            selection: nil,
            type: nil,
            creatorId: currentUser?.user.id ?? "offline",
            pageId: pageId,
            resolvedById: resolved ? currentUser?.user.id : nil,
            resolvedAt: resolved ? Date.now : nil,
            workspaceId: currentUser?.workspace.id,
            resolvedBy: resolved ? currentUser?.user : nil
        )
    }
}
