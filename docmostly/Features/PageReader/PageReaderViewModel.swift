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

    func loadCompanions(pageID: String, appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        attachmentLinks = appState.attachmentLinks(pageId: pageID)
        comments = (try? await appState.loadComments(pageId: pageID)) ?? []
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
            comments.insert(comment, at: 0)
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
            comments.insert(comment, at: 0)
        }
    }

    func applyUpdatedComment(_ comment: DocmostComment) {
        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[index] = comment
        } else {
            comments.insert(comment, at: 0)
        }
    }

    func removeComment(id: String) {
        comments.removeAll { $0.id == id }
        resolvingCommentIDs.remove(id)
    }
}
