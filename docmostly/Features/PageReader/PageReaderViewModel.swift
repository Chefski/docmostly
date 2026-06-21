import Foundation
import Observation

@MainActor
@Observable
final class PageReaderViewModel {
    var comments: [DocmostComment] = []
    var attachmentLinks: [DocmostAttachmentLink] = []
    var isLoading = false
    var errorMessage: String?
    var commentErrorMessage: String?
    var draftComment = ""
    var isPostingComment = false
    var resolvingCommentIDs: Set<String> = []
    var breadcrumbs: [DocmostPage] = []
    var labels: [DocmostLabel] = []
    var isFavoritePage = false
    var isWatchingPage: Bool?
    var isTogglingFavorite = false
    var isTogglingWatch = false
    var isUpdatingLabels = false
    var engagementErrorMessage: String?
    var labelEditorErrorMessage: String?

    var openComments: [DocmostComment] {
        topLevelComments.filter { $0.isResolved == false }
    }

    var resolvedComments: [DocmostComment] {
        topLevelComments.filter(\.isResolved)
    }

    var openCommentCount: Int {
        openComments.count
    }

    var resolvedCommentCount: Int {
        resolvedComments.count
    }

    func loadCompanions(pageID: String, appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        attachmentLinks = appState.attachmentLinks(pageId: pageID)
        comments = (try? await appState.loadComments(pageId: pageID)) ?? []
        await loadEngagement(pageID: pageID, appState: appState)
    }

    func loadEngagement(pageID: String, appState: AppState) async {
        engagementErrorMessage = nil

        do {
            breadcrumbs = try await appState.loadPageBreadcrumbs(pageId: pageID)
        } catch {
            breadcrumbs = []
            engagementErrorMessage = error.localizedDescription
        }

        do {
            labels = try await appState.loadPageLabels(pageId: pageID)
        } catch {
            labels = []
            engagementErrorMessage = engagementErrorMessage ?? error.localizedDescription
        }

        do {
            let favoriteIDs = try await appState.loadFavoriteIds(type: .page)
            isFavoritePage = favoriteIDs.contains(pageID)
        } catch {
            isFavoritePage = false
            engagementErrorMessage = engagementErrorMessage ?? error.localizedDescription
        }

        do {
            isWatchingPage = try await appState.loadPageWatchStatus(pageId: pageID).watching
        } catch {
            isWatchingPage = nil
            engagementErrorMessage = engagementErrorMessage ?? error.localizedDescription
        }
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

    func isResolvingComment(id: String) -> Bool {
        resolvingCommentIDs.contains(id)
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

    func applyUpdatedComment(_ comment: DocmostComment) {
        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[index] = comment
        }
    }

    func removeComment(id: String) {
        comments.removeAll { $0.id == id }
        resolvingCommentIDs.remove(id)
    }

    private var topLevelComments: [DocmostComment] {
        comments.filter { $0.parentCommentId == nil }
    }
}
