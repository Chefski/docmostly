import Foundation
import Observation

@MainActor
@Observable
final class PageReaderViewModel {
    var comments: [DocmostComment] = [] {
        didSet {
            rebuildCommentBuckets()
        }
    }
    private(set) var openComments: [DocmostComment] = []
    private(set) var resolvedComments: [DocmostComment] = []
    var attachmentLinks: [DocmostAttachmentLink] = []
    var pageShare: DocmostPageShare?
    var pageRestrictionInfo: DocmostPageRestrictionInfo?
    var pagePermissionMembers: [DocmostPagePermissionMember] = []
    var isLoading = false
    var errorMessage: String?
    var commentErrorMessage: String?
    var sharingErrorMessage: String?
    var isLoadingSharingState = false
    var isUpdatingShare = false
    var draftComment = ""
    var replyDraftsByCommentID: [String: String] = [:]
    var editDraftsByCommentID: [String: String] = [:]
    var isPostingComment = false
    var postingReplyIDs: Set<String> = []
    var editingCommentIDs: Set<String> = []
    var updatingCommentIDs: Set<String> = []
    var deletingCommentIDs: Set<String> = []
    var resolvingCommentIDs: Set<String> = []
    var breadcrumbs: [DocmostPage] = []
    var labels: [DocmostLabel] = []
    var backlinkCounts = DocmostBacklinkCounts.empty
    var backlinkPagesByDirection: [DocmostBacklinkDirection: [DocmostBacklinkPage]] = [:]
    var backlinkNextCursorByDirection: [DocmostBacklinkDirection: String?] = [:]
    var backlinkHasNextPageByDirection: [DocmostBacklinkDirection: Bool] = [:]
    var loadingBacklinkDirections: Set<PageReaderBacklinkLoadKey> = []
    var backlinkPageID: String?
    var backlinkErrorMessage: String?
    var isFavoritePage = false
    var isWatchingPage: Bool?
    var isTogglingFavorite = false
    var isTogglingWatch = false
    var isUpdatingLabels = false
    var engagementErrorMessage: String?
    var labelEditorErrorMessage: String?

    var openCommentCount: Int {
        openComments.count
    }

    var resolvedCommentCount: Int {
        resolvedComments.count
    }

    func loadCompanions(pageID: String, appState: AppState) async {
        isLoading = true
        errorMessage = nil
        resetSharingState()
        defer { isLoading = false }

        async let cachedAttachmentLinks = appState.attachmentLinks(pageId: pageID)
        async let loadedComments = captureLoad {
            try await appState.loadComments(pageId: pageID)
        }
        async let loadedEngagement = fetchEngagement(pageID: pageID, appState: appState)

        let cachedLinks = await cachedAttachmentLinks
        attachmentLinks = await appState.loadAttachmentDetails(pageId: pageID, fallbackLinks: cachedLinks)
        let commentOutcome = await loadedComments
        comments = commentOutcome.value ?? []
        commentErrorMessage = commentOutcome.errorMessage
        apply(await loadedEngagement)
    }

    func loadEngagement(pageID: String, appState: AppState) async {
        apply(await fetchEngagement(pageID: pageID, appState: appState))
    }

    func toggleFavorite(pageID: String, appState: AppState) async {
        guard isTogglingFavorite == false else { return }

        isTogglingFavorite = true
        engagementErrorMessage = nil
        defer { isTogglingFavorite = false }

        do {
            if isFavoritePage {
                try await appState.removeFavorite(type: .page, pageId: pageID)
                isFavoritePage = false
            } else {
                try await appState.addFavorite(type: .page, pageId: pageID)
                isFavoritePage = true
            }
        } catch {
            engagementErrorMessage = error.localizedDescription
        }
    }

    func toggleWatch(pageID: String, appState: AppState) async {
        guard isTogglingWatch == false else { return }

        isTogglingWatch = true
        engagementErrorMessage = nil
        defer { isTogglingWatch = false }

        do {
            let response: WatchStatusResponse
            if isWatchingPage == true {
                response = try await appState.unwatchPage(pageId: pageID)
            } else {
                response = try await appState.watchPage(pageId: pageID)
            }
            isWatchingPage = response.watching
        } catch {
            engagementErrorMessage = error.localizedDescription
        }
    }

    func addLabel(named draftName: String, pageID: String, appState: AppState) async {
        guard isUpdatingLabels == false else { return }

        let normalizedName = DocmostLabelNameValidator.normalized(draftName)
        if let validationMessage = DocmostLabelNameValidator.validationMessage(
            for: normalizedName,
            existingLabels: labels
        ) {
            labelEditorErrorMessage = validationMessage
            return
        }

        isUpdatingLabels = true
        labelEditorErrorMessage = nil
        defer { isUpdatingLabels = false }

        do {
            labels = try await appState.addPageLabels(pageId: pageID, names: [normalizedName])
        } catch {
            labelEditorErrorMessage = error.localizedDescription
        }
    }

    func removeLabel(_ label: DocmostLabel, pageID: String, appState: AppState) async {
        guard isUpdatingLabels == false else { return }

        isUpdatingLabels = true
        labelEditorErrorMessage = nil
        defer { isUpdatingLabels = false }

        do {
            try await appState.removePageLabel(pageId: pageID, labelId: label.id)
            labels.removeAll { $0.id == label.id }
        } catch {
            labelEditorErrorMessage = error.localizedDescription
        }
    }

    func postComment(pageID: String, appState: AppState) async {
        guard draftComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return
        }

        isPostingComment = true
        commentErrorMessage = nil
        defer { isPostingComment = false }

        do {
            let comment = try await appState.addPageComment(pageId: pageID, text: draftComment)
            applyCreatedComment(comment)
            draftComment = ""
        } catch {
            commentErrorMessage = error.localizedDescription
        }
    }

    func postReply(to parentComment: DocmostComment, pageID: String, appState: AppState) async {
        let draft = replyDraftsByCommentID[parentComment.id] ?? ""
        guard canSubmitReply(to: parentComment, draft: draft) else {
            return
        }

        postingReplyIDs.insert(parentComment.id)
        commentErrorMessage = nil
        defer { postingReplyIDs.remove(parentComment.id) }

        do {
            let reply = try await appState.addCommentReply(
                pageId: pageID,
                parentCommentId: parentComment.id,
                text: draft
            )
            applyCreatedReply(reply, parentCommentID: parentComment.id)
        } catch {
            commentErrorMessage = error.localizedDescription
        }
    }

    func isResolvingComment(id: String) -> Bool {
        resolvingCommentIDs.contains(id)
    }

    func isPostingReply(to commentID: String) -> Bool {
        postingReplyIDs.contains(commentID)
    }

    func isEditingComment(id: String) -> Bool {
        editingCommentIDs.contains(id)
    }

    func isUpdatingComment(id: String) -> Bool {
        updatingCommentIDs.contains(id)
    }

    func isDeletingComment(id: String) -> Bool {
        deletingCommentIDs.contains(id)
    }

    func canSubmitReply(to parentComment: DocmostComment, draft: String? = nil) -> Bool {
        let replyDraft = draft ?? replyDraftsByCommentID[parentComment.id] ?? ""
        return parentComment.parentCommentId == nil
            && parentComment.isLocallyQueued == false
            && postingReplyIDs.contains(parentComment.id) == false
            && replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func replies(for parentCommentID: String) -> [DocmostComment] {
        comments.filter { $0.parentCommentId == parentCommentID }
    }

    func beginEditing(_ comment: DocmostComment) {
        guard comment.isNativelyEditable else { return }
        editDraftsByCommentID[comment.id] = comment.content ?? ""
        editingCommentIDs.insert(comment.id)
    }

    func cancelEditing(commentID: String) {
        editDraftsByCommentID[commentID] = nil
        editingCommentIDs.remove(commentID)
    }

    func updateComment(_ comment: DocmostComment, appState: AppState) async {
        guard comment.isNativelyEditable else { return }
        let draft = editDraftsByCommentID[comment.id] ?? ""
        guard draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return
        }
        guard updatingCommentIDs.contains(comment.id) == false else { return }

        updatingCommentIDs.insert(comment.id)
        commentErrorMessage = nil
        defer { updatingCommentIDs.remove(comment.id) }

        do {
            let updatedComment = try await appState.updateComment(comment, text: draft)
            applyEditedComment(updatedComment)
        } catch {
            commentErrorMessage = error.localizedDescription
        }
    }

    func deleteComment(
        _ comment: DocmostComment,
        appState: AppState,
        removeInlineComment: ((String) async -> Void)? = nil
    ) async {
        guard deletingCommentIDs.contains(comment.id) == false else { return }

        deletingCommentIDs.insert(comment.id)
        commentErrorMessage = nil
        defer { deletingCommentIDs.remove(comment.id) }

        do {
            try await appState.deleteComment(commentId: comment.id)
            removeComment(id: comment.id)
            if comment.type == DocmostCommentType.inline.rawValue {
                await removeInlineComment?(comment.id)
            }
        } catch {
            commentErrorMessage = error.localizedDescription
        }
    }

    func toggleResolved(
        _ comment: DocmostComment,
        pageID: String,
        appState: AppState,
        markInlineCommentResolved: ((String, Bool) async -> Void)? = nil
    ) async {
        guard resolvingCommentIDs.contains(comment.id) == false else { return }

        let targetResolvedState = comment.isResolved == false
        resolvingCommentIDs.insert(comment.id)
        commentErrorMessage = nil
        defer {
            resolvingCommentIDs.remove(comment.id)
        }

        do {
            let updatedComment = try await appState.resolveComment(
                commentId: comment.id,
                pageId: pageID,
                resolved: targetResolvedState
            )
            applyUpdatedComment(updatedComment)
            await markInlineCommentResolved?(comment.id, targetResolvedState)
        } catch {
            commentErrorMessage = error.localizedDescription
        }
    }

    func applyCreatedComment(_ comment: DocmostComment) {
        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[index] = comment
        } else {
            comments.append(comment)
        }
    }

    func applyCreatedReply(_ reply: DocmostComment, parentCommentID: String) {
        applyCreatedComment(reply)
        replyDraftsByCommentID[parentCommentID] = nil
    }

    func applyUpdatedComment(_ comment: DocmostComment) {
        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[index] = comment
        }
    }

    func applyEditedComment(_ comment: DocmostComment) {
        applyUpdatedComment(comment)
        editDraftsByCommentID[comment.id] = nil
        editingCommentIDs.remove(comment.id)
    }

    func removeComment(id: String) {
        let idsToRemove = Set(commentThreadIDs(rootID: id))
        comments.removeAll { idsToRemove.contains($0.id) }
        for commentID in idsToRemove {
            resolvingCommentIDs.remove(commentID)
            postingReplyIDs.remove(commentID)
            editingCommentIDs.remove(commentID)
            updatingCommentIDs.remove(commentID)
            deletingCommentIDs.remove(commentID)
            replyDraftsByCommentID[commentID] = nil
            editDraftsByCommentID[commentID] = nil
        }
    }

    private func rebuildCommentBuckets() {
        let topLevelComments = comments.filter { $0.parentCommentId == nil }
        openComments = topLevelComments.filter { $0.isResolved == false }
        resolvedComments = topLevelComments.filter(\.isResolved)
    }

    private func commentThreadIDs(rootID: String) -> [String] {
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

    func isLoadingBacklinks(pageID: String, direction: DocmostBacklinkDirection) -> Bool {
        loadingBacklinkDirections.contains(PageReaderBacklinkLoadKey(pageID: pageID, direction: direction))
    }

    private func fetchEngagement(pageID: String, appState: AppState) async -> PageReaderEngagementSnapshot {
        async let loadedBreadcrumbs = captureLoad {
            try await appState.loadPageBreadcrumbs(pageId: pageID)
        }
        async let loadedLabels = captureLoad {
            try await appState.loadPageLabels(pageId: pageID)
        }
        async let loadedBacklinkCounts = captureLoad {
            try await appState.loadPageBacklinkCounts(pageId: pageID)
        }
        async let loadedFavoriteIDs = captureLoad {
            try await appState.loadFavoriteIds(type: .page)
        }
        async let loadedWatchStatus = captureLoad {
            try await appState.loadPageWatchStatus(pageId: pageID)
        }

        let breadcrumbsOutcome = await loadedBreadcrumbs
        let labelsOutcome = await loadedLabels
        let backlinkCountsOutcome = await loadedBacklinkCounts
        let favoriteIDsOutcome = await loadedFavoriteIDs
        let watchStatusOutcome = await loadedWatchStatus

        return PageReaderEngagementSnapshot(
            pageID: pageID,
            breadcrumbs: breadcrumbsOutcome.value ?? [],
            labels: labelsOutcome.value ?? [],
            backlinkCounts: backlinkCountsOutcome.value ?? .empty,
            isFavoritePage: favoriteIDsOutcome.value?.contains(pageID) ?? false,
            isWatchingPage: watchStatusOutcome.value?.watching,
            errorMessage: [
                breadcrumbsOutcome.errorMessage,
                labelsOutcome.errorMessage,
                backlinkCountsOutcome.errorMessage,
                favoriteIDsOutcome.errorMessage,
                watchStatusOutcome.errorMessage
            ].compactMap(\.self).first
        )
    }

    private func apply(_ snapshot: PageReaderEngagementSnapshot) {
        breadcrumbs = snapshot.breadcrumbs
        labels = snapshot.labels
        backlinkCounts = snapshot.backlinkCounts
        backlinkPageID = snapshot.pageID
        backlinkPagesByDirection = [:]
        backlinkNextCursorByDirection = [:]
        backlinkHasNextPageByDirection = [:]
        loadingBacklinkDirections = []
        backlinkErrorMessage = nil
        isFavoritePage = snapshot.isFavoritePage
        isWatchingPage = snapshot.isWatchingPage
        engagementErrorMessage = snapshot.errorMessage
    }

    private func captureLoad<Value: Sendable>(
        _ operation: () async throws -> Value
    ) async -> PageReaderLoadOutcome<Value> {
        do {
            return PageReaderLoadOutcome(value: try await operation(), errorMessage: nil)
        } catch {
            return PageReaderLoadOutcome(value: nil, errorMessage: error.localizedDescription)
        }
    }
}

extension PageReaderViewModel {
    func resetSharingState() {
        pageShare = nil
        pageRestrictionInfo = nil
        pagePermissionMembers = []
        sharingErrorMessage = nil
        isLoadingSharingState = false
        isUpdatingShare = false
    }

    func loadSharingState(pageID: String, appState: AppState) async {
        isLoadingSharingState = true
        sharingErrorMessage = nil
        defer { isLoadingSharingState = false }

        async let loadedShare = captureLoad {
            try await appState.loadPageShare(pageId: pageID)
        }
        async let loadedRestriction = captureLoad {
            try await appState.loadPageRestrictionInfo(pageId: pageID)
        }

        let shareOutcome = await loadedShare
        pageShare = shareOutcome.value ?? nil

        let restrictionOutcome = await loadedRestriction
        pageRestrictionInfo = restrictionOutcome.value ?? nil

        if let info = pageRestrictionInfo, info.hasDirectRestriction {
            let membersOutcome = await captureLoad {
                try await appState.loadPagePermissionMembers(pageId: pageID)
            }
            pagePermissionMembers = membersOutcome.value ?? []
            sharingErrorMessage = membersOutcome.errorMessage
        } else {
            pagePermissionMembers = []
        }

        sharingErrorMessage = sharingErrorMessage ??
            shareOutcome.errorMessage ??
            restrictionOutcome.errorMessage
    }

    func setPublicSharing(_ isEnabled: Bool, pageID: String, appState: AppState) async {
        guard isUpdatingShare == false else { return }

        isUpdatingShare = true
        sharingErrorMessage = nil
        defer { isUpdatingShare = false }

        do {
            if isEnabled {
                pageShare = try await appState.createPageShare(pageId: pageID)
            } else if let shareID = pageShare?.id {
                try await appState.deletePageShare(shareId: shareID)
                pageShare = nil
            }
        } catch {
            sharingErrorMessage = error.localizedDescription
        }
    }

    func updateShareOptions(
        pageID: String,
        includeSubPages: Bool? = nil,
        searchIndexing: Bool? = nil,
        appState: AppState
    ) async {
        guard isUpdatingShare == false, let shareID = pageShare?.id else { return }

        isUpdatingShare = true
        sharingErrorMessage = nil
        defer { isUpdatingShare = false }

        do {
            pageShare = try await appState.updatePageShare(
                shareId: shareID,
                includeSubPages: includeSubPages,
                searchIndexing: searchIndexing
            )
        } catch {
            sharingErrorMessage = error.localizedDescription
            await loadSharingState(pageID: pageID, appState: appState)
        }
    }
}

nonisolated struct PageReaderBacklinkLoadKey: Hashable, Sendable {
    let pageID: String
    let direction: DocmostBacklinkDirection
}

private struct PageReaderEngagementSnapshot: Sendable {
    let pageID: String
    let breadcrumbs: [DocmostPage]
    let labels: [DocmostLabel]
    let backlinkCounts: DocmostBacklinkCounts
    let isFavoritePage: Bool
    let isWatchingPage: Bool?
    let errorMessage: String?
}

private struct PageReaderLoadOutcome<Value: Sendable>: Sendable {
    let value: Value?
    let errorMessage: String?
}
