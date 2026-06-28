import Foundation

extension AppState {
    func canQueueOfflineMutation(after error: Error) -> Bool {
        if error is CancellationError {
            return false
        }

        guard let apiError = error as? APIError else {
            return true
        }

        switch apiError {
        case .connectionFailed, .invalidResponse:
            return true
        case .httpStatus(let status, _):
            return status == 408 || status == 429 || status >= 500
        case .missingData, .decodingFailed, .responseTooLarge:
            return false
        }
    }

    @discardableResult
    func queueOfflineMutation(_ payload: OfflineMutationPayload) async throws -> OfflineMutationRecord {
        let scope = try requireCacheScope(message: "Offline changes are unavailable until you sign in.")
        let record: OfflineMutationRecord
        if let offlineQueueRepository {
            record = try await offlineQueueRepository.enqueue(payload, scope: scope)
        } else if let offlineQueue {
            record = try offlineQueue.enqueue(payload, scope: scope)
        } else {
            throw APIError.connectionFailed("Offline changes are unavailable until local storage is configured.")
        }
        await refreshOfflineMutationCount()
        statusMessage = "Queued offline change. It will sync when the workspace is reachable."
        return record
    }

    func refreshOfflineMutationCount() async {
        guard let cacheScope else {
            pendingOfflineMutationCount = 0
            return
        }

        do {
            let records = try await pendingOfflineMutations(scope: cacheScope)
            pendingOfflineMutationCount = records.count
            applyOfflineProjections(from: records)
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func scheduleOfflineQueueReconciliation() {
        guard pendingOfflineMutationCount > 0, offlineReplayTask == nil else { return }

        offlineReplayTask = Task { [weak self] in
            await self?.reconcileOfflineMutations()
        }
    }

    func saveLocalEditableDraft(
        pageId: String,
        title: String,
        document: ProseMirrorDocument
    ) async throws -> DocmostEditablePage {
        let scope = try requireCacheScope(message: "This page is not cached for offline editing.")
        if let cacheWriter {
            return try await cacheWriter.saveLocalEditableDraft(
                pageId: pageId,
                title: title,
                document: document,
                scope: scope
            )
        }

        guard let cacheRepository else {
            throw APIError.connectionFailed("This page is not cached for offline editing.")
        }
        return try cacheRepository.saveLocalEditableDraft(
            pageId: pageId,
            title: title,
            document: document,
            scope: scope
        )
    }

    func queuePageUpdate(
        pageId: String,
        title: String,
        document: ProseMirrorDocument
    ) async throws -> DocmostEditablePage {
        try await queueOfflineMutation(.updatePage(pageId: pageId, title: title, document: document))
        return try await saveLocalEditableDraft(pageId: pageId, title: title, document: document)
    }

    func setProjectedFavorite(
        type: FavoriteType,
        pageId: String?,
        spaceId: String?,
        templateId: String?,
        isFavorite: Bool
    ) {
        guard let targetID = pageId ?? spaceId ?? templateId else { return }
        var favoriteIDs = favoriteIDsByType[type] ?? []
        if isFavorite {
            favoriteIDs.insert(targetID)
        } else {
            favoriteIDs.remove(targetID)
        }
        favoriteIDsByType[type] = favoriteIDs
    }

    func cancelOfflineReplay() {
        offlineReplayTask?.cancel()
        offlineReplayTask = nil
    }

    func clearOfflineProjections() {
        pageCommentsByID.removeAll(keepingCapacity: true)
        pageLabelsByID.removeAll(keepingCapacity: true)
        favoriteIDsByType.removeAll(keepingCapacity: true)
        pageWatchStatusByID.removeAll(keepingCapacity: true)
        spaceWatchStatusByID.removeAll(keepingCapacity: true)
    }

    private func reconcileOfflineMutations() async {
        defer {
            offlineReplayTask = nil
        }

        guard let apiClient, let cacheScope else { return }

        var inlineCommentIDMappings: [String: String] = [:]

        do {
            while true {
                let records = try await pendingOfflineMutations(scope: cacheScope, limit: 25)
                guard records.isEmpty == false else {
                    pendingOfflineMutationCount = 0
                    return
                }

                for record in records {
                    do {
                        let payload = record.payload.replacingCommentIDs(inlineCommentIDMappings)
                        if let mapping = try await replay(record, payload: payload, using: apiClient) {
                            inlineCommentIDMappings[mapping.localID] = mapping.serverID
                        }
                        try await removeOfflineMutation(id: record.id, scope: cacheScope)
                        await refreshOfflineMutationCount()
                    } catch {
                        if canQueueOfflineMutation(after: error) {
                            try? await markOfflineMutationFailed(
                                id: record.id,
                                scope: cacheScope,
                                message: error.localizedDescription
                            )
                            await refreshOfflineMutationCount()
                            isOffline = true
                            statusMessage = "Could not sync queued offline change: \(error.localizedDescription)"
                            return
                        }

                        try? await removeOfflineMutation(id: record.id, scope: cacheScope)
                        await refreshOfflineMutationCount()
                        statusMessage = "Dropped queued offline change: \(error.localizedDescription)"
                    }
                }
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func replay(
        _ record: OfflineMutationRecord,
        payload: OfflineMutationPayload,
        using apiClient: DocmostAPIClient
    ) async throws -> (localID: String, serverID: String)? {
        switch payload {
        case .updatePage(let pageId, let title, let document):
            try await replayPageUpdate(
                pageId: pageId,
                title: title,
                document: document,
                scope: record.scope,
                using: apiClient
            )
            return nil
        case .createComment:
            return try await replayCommentCreation(payload, scope: record.scope, using: apiClient)
        case .resolveComment(let commentId, let pageId, let resolved):
            try await replayCommentResolution(
                commentId: commentId,
                pageId: pageId,
                resolved: resolved,
                using: apiClient
            )
            return nil
        case .addPageLabels(let pageId, let labels):
            try await replayPageLabelAddition(pageId: pageId, labels: labels, using: apiClient)
            return nil
        case .removePageLabel(let pageId, let labelId):
            try await apiClient.sendVoid(.removePageLabel(pageId: pageId, labelId: labelId))
            pageLabelsByID[pageId]?.removeAll { $0.id == labelId }
            return nil
        case .addFavorite, .removeFavorite:
            try await replayFavorite(payload, using: apiClient)
            return nil
        case .watchPage, .unwatchPage, .watchSpace, .unwatchSpace:
            try await replayWatch(payload, using: apiClient)
            return nil
        case .movePage(let pageId, let parentPageId, let position):
            try await apiClient.sendVoid(.movePage(pageId: pageId, parentPageId: parentPageId, position: position))
            return nil
        case .movePageToSpace(let pageId, let spaceId):
            try await apiClient.sendVoid(.movePageToSpace(pageId: pageId, spaceId: spaceId))
            return nil
        }
    }

    private func replayPageUpdate(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        scope: CacheScope,
        using apiClient: DocmostAPIClient
    ) async throws {
        let page: DocmostEditablePage = try await apiClient.send(.updatePage(
            pageId: pageId,
            title: title,
            content: document,
            format: .json,
            operation: .replace
        ))
        scheduleCacheWrite(.saveEditablePage(page, scope: scope))
    }

    private func replayCommentCreation(
        _ payload: OfflineMutationPayload,
        scope: CacheScope,
        using apiClient: DocmostAPIClient
    ) async throws -> (localID: String, serverID: String)? {
        guard case .createComment(
            let localId,
            let pageId,
            let content,
            _,
            let type,
            let selection,
            let yjsSelection
        ) = payload else {
            return nil
        }

        let comment: DocmostComment = try await apiClient.send(.createComment(
            pageId: pageId,
            content: content,
            type: type,
            selection: selection,
            yjsSelection: yjsSelection
        ))
        applyReplayedComment(comment, replacingLocalID: localId)
        guard type == .inline, comment.id != localId else { return nil }

        do {
            try await replaceQueuedInlineCommentID(localId: localId, serverId: comment.id, scope: scope)
        } catch {
            statusMessage = error.localizedDescription
        }
        return (localId, comment.id)
    }

    private func replayFavorite(_ payload: OfflineMutationPayload, using apiClient: DocmostAPIClient) async throws {
        switch payload {
        case .addFavorite(let type, let pageId, let spaceId, let templateId):
            try await apiClient.sendVoid(.addFavorite(
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId
            ))
            setProjectedFavorite(
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId,
                isFavorite: true
            )
        case .removeFavorite(let type, let pageId, let spaceId, let templateId):
            try await apiClient.sendVoid(.removeFavorite(
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId
            ))
            setProjectedFavorite(
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId,
                isFavorite: false
            )
        default:
            return
        }
    }

    private func replayWatch(_ payload: OfflineMutationPayload, using apiClient: DocmostAPIClient) async throws {
        switch payload {
        case .watchPage(let pageId):
            let response: WatchStatusResponse = try await apiClient.send(.watchPage(pageId: pageId))
            pageWatchStatusByID[pageId] = response.watching
        case .unwatchPage(let pageId):
            let response: WatchStatusResponse = try await apiClient.send(.unwatchPage(pageId: pageId))
            pageWatchStatusByID[pageId] = response.watching
        case .watchSpace(let spaceId):
            let response: WatchStatusResponse = try await apiClient.send(.watchSpace(spaceId: spaceId))
            spaceWatchStatusByID[spaceId] = response.watching
        case .unwatchSpace(let spaceId):
            let response: WatchStatusResponse = try await apiClient.send(.unwatchSpace(spaceId: spaceId))
            spaceWatchStatusByID[spaceId] = response.watching
        default:
            return
        }
    }

    private func replayCommentResolution(
        commentId: String,
        pageId: String,
        resolved: Bool,
        using apiClient: DocmostAPIClient
    ) async throws {
        let comment: DocmostComment = try await apiClient.send(.resolveComment(
            commentId: commentId,
            pageId: pageId,
            resolved: resolved
        ))
        applyReplayedComment(comment)
    }

    private func replayPageLabelAddition(
        pageId: String,
        labels: [OfflinePageLabel],
        using apiClient: DocmostAPIClient
    ) async throws {
        let labels: [DocmostLabel] = try await apiClient.send(.addPageLabels(
            pageId: pageId,
            names: labels.map(\.name)
        ))
        pageLabelsByID[pageId] = labels
    }

    private func pendingOfflineMutations(scope: CacheScope, limit: Int? = nil) async throws -> [OfflineMutationRecord] {
        if let offlineQueueRepository {
            return try await offlineQueueRepository.pending(scope: scope, limit: limit)
        }
        return try offlineQueue?.pending(scope: scope, limit: limit) ?? []
    }

    private func removeOfflineMutation(id: String, scope: CacheScope) async throws {
        if let offlineQueueRepository {
            try await offlineQueueRepository.remove(id: id, scope: scope)
            return
        }
        try offlineQueue?.remove(id: id, scope: scope)
    }

    private func removeCoalescedOfflineMutations(for payload: OfflineMutationPayload, scope: CacheScope) async throws {
        if let offlineQueueRepository {
            try await offlineQueueRepository.removeCoalescedMutations(for: payload, scope: scope)
            return
        }
        try offlineQueue?.removeCoalescedMutations(for: payload, scope: scope)
    }

    private func removePendingOfflinePageLabel(pageId: String, localId: String, scope: CacheScope) async throws {
        if let offlineQueueRepository {
            try await offlineQueueRepository.removePendingPageLabel(pageId: pageId, localId: localId, scope: scope)
            return
        }
        try offlineQueue?.removePendingPageLabel(pageId: pageId, localId: localId, scope: scope)
    }

    private func replaceQueuedInlineCommentID(localId: String, serverId: String, scope: CacheScope) async throws {
        if let offlineQueueRepository {
            try await offlineQueueRepository.replaceQueuedInlineCommentID(
                localId: localId,
                serverId: serverId,
                scope: scope
            )
            return
        }
        try offlineQueue?.replaceQueuedInlineCommentID(localId: localId, serverId: serverId, scope: scope)
    }

    private func markOfflineMutationFailed(id: String, scope: CacheScope, message: String) async throws {
        if let offlineQueueRepository {
            try await offlineQueueRepository.markFailed(id: id, scope: scope, message: message)
            return
        }
        try offlineQueue?.markFailed(id: id, scope: scope, message: message)
    }

    func clearPendingPageUpdate(pageId: String, title: String, document: ProseMirrorDocument) async throws {
        guard let cacheScope else { return }
        try await removeCoalescedOfflineMutations(
            for: .updatePage(pageId: pageId, title: title, document: document),
            scope: cacheScope
        )
        await refreshOfflineMutationCount()
    }

    func removePendingOfflineLabelProjection(pageId: String, labelId: String) async throws {
        guard let cacheScope else { return }
        try await removePendingOfflinePageLabel(pageId: pageId, localId: labelId, scope: cacheScope)
        await refreshOfflineMutationCount()
    }

    private func applyOfflineProjections(from records: [OfflineMutationRecord]) {
        for record in records {
            applyOfflineProjection(record.payload)
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private func applyOfflineProjection(_ payload: OfflineMutationPayload) {
        switch payload {
        case .createComment(let localId, let pageId, _, let plainText, let type, let selection, _):
            applyProjectedCommentCreation(
                localId: localId,
                pageId: pageId,
                plainText: plainText,
                type: type,
                selection: selection
            )
        case .resolveComment(let commentId, let pageId, let resolved):
            applyProjectedCommentResolution(commentId: commentId, pageId: pageId, resolved: resolved)
        case .addPageLabels(let pageId, let labels):
            applyProjectedPageLabels(pageId: pageId, labels: labels)
        case .removePageLabel(let pageId, let labelId):
            pageLabelsByID[pageId]?.removeAll { $0.id == labelId }
        case .addFavorite(let type, let pageId, let spaceId, let templateId):
            setProjectedFavorite(
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId,
                isFavorite: true
            )
        case .removeFavorite(let type, let pageId, let spaceId, let templateId):
            setProjectedFavorite(
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId,
                isFavorite: false
            )
        case .watchPage(let pageId):
            pageWatchStatusByID[pageId] = true
        case .unwatchPage(let pageId):
            pageWatchStatusByID[pageId] = false
        case .watchSpace(let spaceId):
            spaceWatchStatusByID[spaceId] = true
        case .unwatchSpace(let spaceId):
            spaceWatchStatusByID[spaceId] = false
        case .updatePage, .movePage, .movePageToSpace:
            break
        }
    }
    // swiftlint:enable cyclomatic_complexity

    private func applyProjectedCommentCreation(
        localId: String,
        pageId: String,
        plainText: String,
        type: DocmostCommentType,
        selection: String?
    ) {
        let comment = DocmostComment(
            id: localId,
            content: plainText,
            selection: selection,
            type: type.rawValue,
            creatorId: currentUser?.user.id ?? "offline",
            pageId: pageId,
            workspaceId: currentUser?.workspace.id,
            createdAt: Date.now,
            creator: currentUser?.user
        )
        applyReplayedComment(comment)
    }

    private func applyProjectedPageLabels(pageId: String, labels: [OfflinePageLabel]) {
        var projectedLabels = pageLabelsByID[pageId] ?? []
        var existingIDs = Set(projectedLabels.map(\.id))
        var existingNames = Set(projectedLabels.map(\.name))
        let now = Date.now
        for label in labels {
            guard existingIDs.contains(label.id) == false, existingNames.contains(label.name) == false else {
                continue
            }

            projectedLabels.append(DocmostLabel(
                id: label.id,
                name: label.name,
                type: .page,
                workspaceId: currentUser?.workspace.id,
                createdAt: now,
                updatedAt: now
            ))
            existingIDs.insert(label.id)
            existingNames.insert(label.name)
        }
        pageLabelsByID[pageId] = projectedLabels
    }

    private func applyProjectedCommentResolution(commentId: String, pageId: String, resolved: Bool) {
        if var comments = pageCommentsByID[pageId],
           let index = comments.firstIndex(where: { $0.id == commentId }) {
            let existing = comments[index]
            comments[index] = DocmostComment(
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
            pageCommentsByID[pageId] = comments
        }
    }

    private func applyReplayedComment(_ comment: DocmostComment, replacingLocalID localID: String? = nil) {
        var comments = pageCommentsByID[comment.pageId] ?? []
        if let localID, let index = comments.firstIndex(where: { $0.id == localID }) {
            comments[index] = comment
        } else if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[index] = comment
        } else {
            comments.append(comment)
        }
        pageCommentsByID[comment.pageId] = comments
    }

}
