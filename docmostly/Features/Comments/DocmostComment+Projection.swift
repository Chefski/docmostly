import Foundation

nonisolated extension DocmostComment {
    func projectingResolution(
        resolved: Bool,
        resolvedBy user: DocmostUser?,
        resolvedAt date: Date = .now
    ) -> DocmostComment {
        DocmostComment(
            id: id,
            content: content,
            selection: selection,
            type: type,
            creatorId: creatorId,
            pageId: pageId,
            parentCommentId: parentCommentId,
            resolvedById: resolved ? user?.id : nil,
            resolvedAt: resolved ? date : nil,
            workspaceId: workspaceId,
            spaceId: spaceId,
            createdAt: createdAt,
            editedAt: editedAt,
            deletedAt: deletedAt,
            creator: creator,
            resolvedBy: resolved ? user : nil,
            body: body,
            isNativelyEditable: isNativelyEditable
        )
    }
}
