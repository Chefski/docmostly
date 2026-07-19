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
        try await addPageComment(pageId: pageId, body: CommentBody(plainText: text))
    }

    func addPageComment(pageId: String, body: CommentBody) async throws -> DocmostComment {
        let content = body.jsonString
        guard let apiClient else {
            return try await queueComment(pageId: pageId, body: body, content: content, type: .page)
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
            return try await queueComment(pageId: pageId, body: body, content: content, type: .page)
        }
    }

    func addCommentReply(pageId: String, parentCommentId: String, text: String) async throws -> DocmostComment {
        try await addCommentReply(
            pageId: pageId,
            parentCommentId: parentCommentId,
            body: CommentBody(plainText: text)
        )
    }

    func addCommentReply(
        pageId: String,
        parentCommentId: String,
        body: CommentBody
    ) async throws -> DocmostComment {
        let content = body.jsonString
        guard let apiClient else {
            throw CommentMutationAvailabilityError.onlineRequired
        }

        do {
            let comment: DocmostComment = try await apiClient.send(.createComment(
                pageId: pageId,
                content: content,
                type: .page,
                parentCommentId: parentCommentId
            ))
            applyLocalComment(comment)
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return comment
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            throw CommentMutationAvailabilityError.onlineRequired
        }
    }

    func addInlineComment(
        pageId: String,
        text: String,
        selectedText: String,
        yjsSelection: NativeEditorYjsSelection? = nil
    ) async throws -> DocmostComment {
        try await addInlineComment(
            pageId: pageId,
            body: CommentBody(plainText: text),
            selectedText: selectedText,
            yjsSelection: yjsSelection
        )
    }

    func addInlineComment(
        pageId: String,
        body: CommentBody,
        selectedText: String,
        yjsSelection: NativeEditorYjsSelection? = nil
    ) async throws -> DocmostComment {
        let content = body.jsonString
        guard let apiClient else {
            return try await queueComment(
                pageId: pageId,
                body: body,
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
                body: body,
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

    func updateComment(_ existingComment: DocmostComment, text: String) async throws -> DocmostComment {
        try await updateComment(existingComment, body: CommentBody(plainText: text))
    }

    func updateComment(_ existingComment: DocmostComment, body: CommentBody) async throws -> DocmostComment {
        guard existingComment.isNativelyEditable else {
            throw CommentMutationAvailabilityError.unsupportedRichContentEdit
        }

        let content = body.jsonString
        guard let apiClient else {
            throw CommentMutationAvailabilityError.onlineRequired
        }

        do {
            let comment: DocmostComment = try await apiClient.send(.updateComment(
                commentId: existingComment.id,
                content: content
            ))
            applyLocalComment(comment)
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return comment
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            throw CommentMutationAvailabilityError.onlineRequired
        }
    }

    func deleteComment(commentId: String) async throws {
        guard let apiClient else {
            throw CommentMutationAvailabilityError.onlineRequired
        }

        do {
            try await apiClient.sendVoid(.deleteComment(commentId: commentId))
            removeLocalCommentThread(id: commentId)
            isOffline = false
            scheduleOfflineQueueReconciliation()
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            throw CommentMutationAvailabilityError.onlineRequired
        }
    }

    func currentUserCanDeleteComment(_ comment: DocmostComment) -> Bool {
        if currentUser?.user.id == comment.creatorId {
            return true
        }

        guard let spaceId = comment.spaceId else {
            return false
        }

        return spaces.first { $0.id == spaceId }?.membership?.role == "admin"
    }

    private func queueComment(
        pageId: String,
        body: CommentBody,
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
            plainText: body.plainText,
            type: type,
            selection: selection,
            yjsSelection: yjsSelection
        ))

        let comment = DocmostComment(
            id: localId,
            content: body.plainText,
            selection: selection,
            type: type.rawValue,
            creatorId: currentUser?.user.id ?? "offline",
            pageId: pageId,
            workspaceId: currentUser?.workspace.id,
            createdAt: Date.now,
            creator: currentUser?.user,
            body: body
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

    private func removeLocalCommentThread(id commentId: String) {
        for pageId in pageCommentsByID.keys {
            guard var comments = pageCommentsByID[pageId] else { continue }
            let idsToRemove = Set(commentThreadIDs(rootID: commentId, in: comments))
            guard idsToRemove.isEmpty == false else { continue }
            comments.removeAll { idsToRemove.contains($0.id) }
            pageCommentsByID[pageId] = comments
        }
    }

    private func commentThreadIDs(rootID: String, in comments: [DocmostComment]) -> [String] {
        var ids = [rootID]
        var pending = [rootID]

        while let parentID = pending.popLast() {
            let childIDs = comments
                .filter { $0.parentCommentId == parentID }
                .map(\.id)
            ids.append(contentsOf: childIDs)
            pending.append(contentsOf: childIDs)
        }

        return ids
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
                resolvedBy: resolved ? currentUser?.user : nil,
                body: existing.body,
                isNativelyEditable: existing.isNativelyEditable
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

private enum CommentMutationAvailabilityError: LocalizedError {
    case onlineRequired
    case unsupportedRichContentEdit

    var errorDescription: String? {
        switch self {
        case .onlineRequired:
            "This comment action requires an active connection."
        case .unsupportedRichContentEdit:
            "This comment contains formatting that native editing cannot preserve."
        }
    }
}
