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
}
