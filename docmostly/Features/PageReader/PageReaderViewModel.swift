import Foundation
import Observation

@MainActor
@Observable
final class PageReaderViewModel {
    var page: DocmostPage?
    var html = ""
    var comments: [DocmostComment] = []
    var attachmentLinks: [DocmostAttachmentLink] = []
    var isLoading = false
    var isFromCache = false
    var errorMessage: String?
    var commentErrorMessage: String?
    var draftComment = ""
    var isPostingComment = false

    func load(pageID: String, appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await appState.loadPage(idOrSlugId: pageID)
            page = result.page
            html = result.html
            isFromCache = result.isFromCache
            attachmentLinks = appState.attachmentLinks(pageId: result.page.id)
            comments = (try? await appState.loadComments(pageId: result.page.id)) ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func postComment(appState: AppState) async {
        guard let page, draftComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return
        }

        isPostingComment = true
        commentErrorMessage = nil
        defer { isPostingComment = false }

        do {
            let comment = try await appState.addPageComment(pageId: page.id, text: draftComment)
            comments.insert(comment, at: 0)
            draftComment = ""
        } catch {
            commentErrorMessage = error.localizedDescription
        }
    }
}
