import Foundation

// swiftlint:disable file_length

private enum OfflineReplayFailureOutcome {
    case stop
    case continueProcessing
    case quarantineForCurrentPass
}

private struct PendingOfflinePageDraft {
    let pageID: String
    let title: String
    let document: ProseMirrorDocument
}

extension AppState {
    func canQueueOfflineMutation(after error: Error) -> Bool {
        if error is CancellationError {
            return false
        }
        if error is OfflinePageUpdateReplayConflict {
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

    func overlayPendingPageUpdate(on page: DocmostEditablePage) async throws -> DocmostEditablePage {
        guard let cacheScope else { return page }
        let pendingRecords = try await pendingOfflineMutations(scope: cacheScope)
        guard let draft = pendingRecords.reversed().compactMap({ record -> PendingOfflinePageDraft? in
            let update: PendingOfflinePageDraft? = switch record.payload {
            case .updatePage(let pageID, let title, let document, _, _):
                PendingOfflinePageDraft(pageID: pageID, title: title, document: document)
            case .updatePageCRDT(let pageID, let title, let document, _, _):
                PendingOfflinePageDraft(pageID: pageID, title: title, document: document)
            case .updatePageMetadata(let pageID, let title, _):
                PendingOfflinePageDraft(
                    pageID: pageID,
                    title: title,
                    document: page.content ?? ProseMirrorDocument()
                )
            default:
                nil
            }
            guard let update, update.pageID == page.id || update.pageID == page.slugId else { return nil }
            return update
        }).first else {
            return page
        }

        return DocmostEditablePage(
            id: page.id,
            slugId: page.slugId,
            title: draft.title,
            content: draft.document,
            icon: page.icon,
            spaceId: page.spaceId,
            createdAt: page.createdAt,
            updatedAt: page.updatedAt,
            permissions: page.permissions,
            creator: page.creator,
            lastUpdatedBy: page.lastUpdatedBy
        )
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

    // swiftlint:disable:next cyclomatic_complexity
    private func reconcileOfflineMutations() async {
        defer {
            offlineReplayTask = nil
        }

        guard let apiClient, let cacheScope else { return }

        var inlineCommentIDMappings: [String: String] = [:]
        var quarantinedRecordIDs: Set<String> = []

        do {
            while true {
                let pendingRecords = try await pendingOfflineMutations(scope: cacheScope)
                guard pendingRecords.isEmpty == false else {
                    pendingOfflineMutationCount = 0
                    return
                }
                let records = pendingRecords
                    .filter { quarantinedRecordIDs.contains($0.id) == false }
                    .prefix(25)
                guard records.isEmpty == false else {
                    pendingOfflineMutationCount = pendingRecords.count
                    return
                }

                for record in records {
                    let payload = record.payload.replacingCommentIDs(inlineCommentIDMappings)
                    do {
                        if let mapping = try await replay(record, payload: payload, using: apiClient) {
                            inlineCommentIDMappings[mapping.localID] = mapping.serverID
                        }
                        try await removeOfflineMutation(id: record.id, scope: cacheScope)
                        await refreshOfflineMutationCount()
                    } catch {
                        switch await handleOfflineReplayFailure(
                            error,
                            record: record,
                            payload: payload,
                            scope: cacheScope
                        ) {
                        case .stop:
                            return
                        case .continueProcessing:
                            continue
                        case .quarantineForCurrentPass:
                            quarantinedRecordIDs.insert(record.id)
                            continue
                        }
                    }
                }
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func handleOfflineReplayFailure(
        _ error: any Error,
        record: OfflineMutationRecord,
        payload: OfflineMutationPayload,
        scope: CacheScope
    ) async -> OfflineReplayFailureOutcome {
        switch OfflineMutationReplayFailureDisposition(error: error, payload: payload) {
        case .stopWithoutMutation:
            return .stop
        case .dropRecord:
            try? await removeOfflineMutation(id: record.id, scope: scope)
            await refreshOfflineMutationCount()
            statusMessage = "Dropped queued offline change: \(error.localizedDescription)"
            return .continueProcessing
        case .retainForRetry:
            try? await markOfflineMutationFailed(
                id: record.id,
                scope: scope,
                message: error.localizedDescription
            )
            await refreshOfflineMutationCount()
            if canQueueOfflineMutation(after: error) {
                isOffline = true
            }
            statusMessage = "Could not sync queued offline change: \(error.localizedDescription)"
            return shouldQuarantineForCurrentPass(error: error, payload: payload) ?
                .quarantineForCurrentPass : .stop
        }
    }

    private func shouldQuarantineForCurrentPass(
        error: any Error,
        payload: OfflineMutationPayload
    ) -> Bool {
        if error is OfflinePageUpdateReplayConflict {
            return true
        }
        guard payload.canDropAfterPermanentClientFailure == false,
              let apiError = error as? APIError,
              case .httpStatus(let status, _) = apiError else {
            return false
        }
        return status >= 400 && status < 500 && status != 401 && status != 403 && status != 408 && status != 429
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func replay(
        _ record: OfflineMutationRecord,
        payload: OfflineMutationPayload,
        using apiClient: DocmostAPIClient
    ) async throws -> (localID: String, serverID: String)? {
        switch payload {
        case .updatePageMetadata(let pageId, let title, let baseTitle):
            try await synchronizeExistingQueuedDocument(
                record: record,
                pageId: pageId,
                using: apiClient
            )
            try await replayPageMetadata(
                pageId: pageId,
                title: title,
                baseTitle: baseTitle,
                using: apiClient
            )
            return nil
        case .updatePageCRDT(let pageId, let title, let document, _, let baseTitle):
            try await synchronizeQueuedDocument(
                record: record,
                pageId: pageId,
                title: title,
                document: document,
                using: apiClient
            )
            try await replayPageMetadata(pageId: pageId, title: title, baseTitle: baseTitle, using: apiClient)
            return nil
        case .updatePage(let pageId, let title, let document, let baseTitle, _):
            try await synchronizeQueuedDocument(
                record: record,
                pageId: pageId,
                title: title,
                document: document,
                using: apiClient
            )
            try await replayPageMetadata(pageId: pageId, title: title, baseTitle: baseTitle, using: apiClient)
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

    private func synchronizeQueuedDocument(
        record: OfflineMutationRecord,
        pageId: String,
        title: String,
        document: ProseMirrorDocument?,
        using apiClient: DocmostAPIClient
    ) async throws {
        guard let documentSessionRegistry, let workspaceID = currentUser?.workspace.id else {
            throw APIError.connectionFailed("The local document session is unavailable until you sign in.")
        }
        let key = DocumentStoreKey(
            serverBaseURL: record.scope.serverBaseURL,
            userID: record.scope.userID,
            workspaceID: workspaceID,
            pageID: pageId
        )
        let seedDocument: ProseMirrorDocument
        if let document {
            seedDocument = document
        } else if let cacheReader,
                  let page = try await cacheReader.loadEditablePage(idOrSlugId: pageId, scope: record.scope) {
            seedDocument = page.content ?? ProseMirrorDocument()
        } else if let cacheRepository,
                  let page = try cacheRepository.loadEditablePage(idOrSlugId: pageId, scope: record.scope) {
            seedDocument = page.content ?? ProseMirrorDocument()
        } else {
            let page: DocmostEditablePage = try await apiClient.send(.pageInfo(pageId: pageId, format: .json))
            seedDocument = page.content ?? ProseMirrorDocument()
        }
        let session = try await documentSessionRegistry.session(
            for: key,
            title: title,
            document: NativeEditorDocument(proseMirrorDocument: seedDocument)
        )
        guard try await session.hasPendingSynchronization() else { return }
        let collaborationToken: CollaborationTokenResponse = try await apiClient.send(.collabToken)
        guard let token = collaborationToken.token else {
            throw APIError.connectionFailed("Realtime collaboration token is missing.")
        }
        try await offlineCRDTSynchronizer.synchronize(
            pageID: pageId,
            session: session,
            url: try collaborationWebSocketURL(),
            token: token,
            user: currentUser?.user
        )
    }

    private func synchronizeExistingQueuedDocument(
        record: OfflineMutationRecord,
        pageId: String,
        using apiClient: DocmostAPIClient
    ) async throws {
        guard let documentSessionRegistry, let workspaceID = currentUser?.workspace.id else { return }
        let key = DocumentStoreKey(
            serverBaseURL: record.scope.serverBaseURL,
            userID: record.scope.userID,
            workspaceID: workspaceID,
            pageID: pageId
        )
        guard let session = documentSessionRegistry.existingSession(for: key),
              try await session.hasPendingSynchronization() else { return }
        let collaborationToken: CollaborationTokenResponse = try await apiClient.send(.collabToken)
        guard let token = collaborationToken.token else {
            throw APIError.connectionFailed("Realtime collaboration token is missing.")
        }
        try await offlineCRDTSynchronizer.synchronize(
            pageID: pageId,
            session: session,
            url: try collaborationWebSocketURL(),
            token: token,
            user: currentUser?.user
        )
    }

    private func replayPageMetadata(
        pageId: String,
        title: String,
        baseTitle: String?,
        using apiClient: DocmostAPIClient
    ) async throws {
        guard title != baseTitle else { return }
        let serverPage: DocmostEditablePage = try await apiClient.send(.pageInfo(pageId: pageId, format: .json))
        switch OfflinePageTitleReplayDecision.resolve(
            serverTitle: serverPage.title,
            queuedTitle: title,
            baseTitle: baseTitle
        ) {
        case .alreadySynchronized:
            return
        case .updateTitle:
            let _: DocmostEditablePage = try await apiClient.send(.updatePage(pageId: pageId, title: title))
        case .keepRemoteTitle:
            return
        case .conflict:
            throw OfflinePageUpdateReplayConflict(pageID: pageId)
        }
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

    func removeQueuedOfflineMutation(_ record: OfflineMutationRecord) async throws {
        try await removeOfflineMutation(id: record.id, scope: record.scope)
        await refreshOfflineMutationCount()
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
        case .createComment(let localId, let pageId, let content, let plainText, let type, let selection, _):
            applyProjectedCommentCreation(
                localId: localId,
                pageId: pageId,
                body: CommentBody(jsonString: content) ?? CommentBody(plainText: plainText),
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
        case .updatePage, .updatePageCRDT, .updatePageMetadata, .movePage, .movePageToSpace:
            break
        }
    }
    // swiftlint:enable cyclomatic_complexity

    private func applyProjectedCommentCreation(
        localId: String,
        pageId: String,
        body: CommentBody,
        type: DocmostCommentType,
        selection: String?
    ) {
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
