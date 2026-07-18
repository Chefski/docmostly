import Foundation

nonisolated enum CommentPermissionPolicy {
    static func canCreate(pageCanEdit: Bool, allowViewerComments: Bool) -> Bool {
        pageCanEdit || allowViewerComments
    }

    static func canEdit(
        _ comment: DocmostComment,
        currentUserID: String?,
        canComment: Bool,
        isOnline: Bool
    ) -> Bool {
        isOnline
            && canComment
            && comment.creatorId == currentUserID
            && comment.isNativelyEditable
            && comment.isLocallyQueued == false
    }

    static func canDelete(
        _ comment: DocmostComment,
        currentUserID: String?,
        isSpaceAdmin: Bool,
        isOnline: Bool
    ) -> Bool {
        isOnline
            && comment.isLocallyQueued == false
            && (comment.creatorId == currentUserID || isSpaceAdmin)
    }

    static func canResolve(
        _ comment: DocmostComment,
        canComment: Bool,
        isOnline: Bool
    ) -> Bool {
        isOnline
            && canComment
            && comment.parentCommentId == nil
            && comment.isLocallyQueued == false
    }
}
