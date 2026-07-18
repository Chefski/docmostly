import Foundation

extension PageReaderViewModel {
    func replies(for parentCommentID: String) -> [DocmostComment] {
        comments.filter { $0.parentCommentId == parentCommentID }
    }

    func rootComment(containing commentID: String) -> DocmostComment? {
        guard let comment = comments.first(where: { $0.id == commentID }) else { return nil }
        guard let parentCommentID = comment.parentCommentId else { return comment }
        return comments.first { $0.id == parentCommentID }
    }
}
