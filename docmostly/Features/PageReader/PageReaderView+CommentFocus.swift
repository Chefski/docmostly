import SwiftUI

extension PageReaderView {
    func focusRequestedCommentIfAvailable() {
        guard let commentID = requestedCommentID,
              let comment = viewModel.comments.first(where: { $0.id == commentID }),
              viewModel.rootComment(containing: commentID) != nil else {
            return
        }

        focusedCommentID = commentID
        if comment.type == DocmostCommentType.inline.rawValue {
            scrollToInlineComment(commentID)
        }
        activePanel = .comments
    }

    func focusInlineComment(_ commentID: String) {
        focusedCommentID = commentID
        #if !os(macOS)
        closeSupplementaryPanel()
        #endif
        scrollToInlineComment(commentID)
    }

    private var requestedCommentID: String? {
        let selectedPageIDs = [
            pageID,
            editorViewModel?.currentPageID,
            editorViewModel?.currentPageSlugID
        ].compactMap(\.self)

        if let selectedPageID = appState.selectedPageID {
            guard selectedPageIDs.contains(selectedPageID) else { return nil }
            return appState.selectedCommentID ?? initialCommentID
        }
        return initialCommentID
    }

    private func scrollToInlineComment(_ commentID: String) {
        guard let blockID = editorViewModel?.blockID(containingInlineComment: commentID) else { return }
        scrollPosition.scrollTo(id: blockID, anchor: .center)
    }
}
