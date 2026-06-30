import Foundation

enum NativeEditorHighlightColorAttribute: CodableAttributedStringKey {
    typealias Value = String
    static let name = "docmostly.highlightColor"
}

enum NativeEditorHighlightColorNameAttribute: CodableAttributedStringKey {
    typealias Value = String
    static let name = "docmostly.highlightColorName"
}

enum NativeEditorTextColorAttribute: CodableAttributedStringKey {
    typealias Value = String
    static let name = "docmostly.textColor"
}

nonisolated struct NativeEditorLink: Equatable, Hashable, Sendable, Codable {
    var href: String
    var isInternal: Bool
}

enum NativeEditorLinkAttribute: CodableAttributedStringKey {
    typealias Value = NativeEditorLink
    static let name = "docmostly.link"
}

enum NativeEditorCommentIDAttribute: CodableAttributedStringKey {
    typealias Value = String
    static let name = "docmostly.commentID"
}

enum NativeEditorCommentResolvedAttribute: CodableAttributedStringKey {
    typealias Value = Bool
    static let name = "docmostly.commentResolved"
}

nonisolated struct NativeEditorInlineCommentMark: Equatable, Hashable, Sendable, Codable {
    var commentID: String
    var isResolved: Bool
}

enum NativeEditorCommentMarksAttribute: CodableAttributedStringKey {
    typealias Value = [NativeEditorInlineCommentMark]
    static let name = "docmostly.commentMarks"
}

enum NativeEditorMentionAttribute: CodableAttributedStringKey {
    typealias Value = NativeEditorMention
    static let name = "docmostly.mention"
}

enum NativeEditorStatusAttribute: CodableAttributedStringKey {
    typealias Value = NativeEditorStatusBadge
    static let name = "docmostly.status"
}

enum NativeEditorMathInlineAttribute: CodableAttributedStringKey {
    typealias Value = NativeEditorMathInline
    static let name = "docmostly.mathInline"
}

nonisolated extension AttributedString {
    var nativeEditorInlineComments: [NativeEditorInlineCommentMark] {
        if let comments = self[NativeEditorCommentMarksAttribute.self], comments.isEmpty == false {
            return comments.normalizedNativeEditorInlineComments
        }

        guard let commentID = self[NativeEditorCommentIDAttribute.self], commentID.isEmpty == false else {
            return []
        }

        return [
            NativeEditorInlineCommentMark(
                commentID: commentID,
                isResolved: self[NativeEditorCommentResolvedAttribute.self] ?? false
            )
        ]
    }

    mutating func addNativeEditorInlineComment(_ comment: NativeEditorInlineCommentMark) {
        setNativeEditorInlineComments(
            nativeEditorInlineComments.updatingNativeEditorInlineComment(comment)
        )
    }

    mutating func setNativeEditorInlineComments(_ comments: [NativeEditorInlineCommentMark]) {
        let normalizedComments = comments.normalizedNativeEditorInlineComments
        self[NativeEditorCommentMarksAttribute.self] = normalizedComments.isEmpty ? nil : normalizedComments
        self[NativeEditorCommentIDAttribute.self] = normalizedComments.first?.commentID
        self[NativeEditorCommentResolvedAttribute.self] = normalizedComments.first?.isResolved
    }
}

nonisolated extension AttributedString.Runs.Run {
    var nativeEditorInlineComments: [NativeEditorInlineCommentMark] {
        if let comments = self[NativeEditorCommentMarksAttribute.self], comments.isEmpty == false {
            return comments.normalizedNativeEditorInlineComments
        }

        guard let commentID = self[NativeEditorCommentIDAttribute.self], commentID.isEmpty == false else {
            return []
        }

        return [
            NativeEditorInlineCommentMark(
                commentID: commentID,
                isResolved: self[NativeEditorCommentResolvedAttribute.self] ?? false
            )
        ]
    }

    func hasNativeEditorInlineComment(commentID: String) -> Bool {
        nativeEditorInlineComments.contains { $0.commentID == commentID }
    }
}

nonisolated extension AttributedSubstring {
    var nativeEditorInlineComments: [NativeEditorInlineCommentMark] {
        if let comments = self[NativeEditorCommentMarksAttribute.self], comments.isEmpty == false {
            return comments.normalizedNativeEditorInlineComments
        }

        guard let commentID = self[NativeEditorCommentIDAttribute.self], commentID.isEmpty == false else {
            return []
        }

        return [
            NativeEditorInlineCommentMark(
                commentID: commentID,
                isResolved: self[NativeEditorCommentResolvedAttribute.self] ?? false
            )
        ]
    }
}

nonisolated extension AttributeContainer {
    mutating func addNativeEditorInlineComment(_ comment: NativeEditorInlineCommentMark) {
        setNativeEditorInlineComments(
            nativeEditorInlineComments.updatingNativeEditorInlineComment(comment)
        )
    }

    var nativeEditorInlineComments: [NativeEditorInlineCommentMark] {
        if let comments = self[NativeEditorCommentMarksAttribute.self], comments.isEmpty == false {
            return comments.normalizedNativeEditorInlineComments
        }

        guard let commentID = self[NativeEditorCommentIDAttribute.self], commentID.isEmpty == false else {
            return []
        }

        return [
            NativeEditorInlineCommentMark(
                commentID: commentID,
                isResolved: self[NativeEditorCommentResolvedAttribute.self] ?? false
            )
        ]
    }

    mutating func setNativeEditorInlineComments(_ comments: [NativeEditorInlineCommentMark]) {
        let normalizedComments = comments.normalizedNativeEditorInlineComments
        self[NativeEditorCommentMarksAttribute.self] = normalizedComments.isEmpty ? nil : normalizedComments
        self[NativeEditorCommentIDAttribute.self] = normalizedComments.first?.commentID
        self[NativeEditorCommentResolvedAttribute.self] = normalizedComments.first?.isResolved
    }
}

nonisolated extension Array where Element == NativeEditorInlineCommentMark {
    var normalizedNativeEditorInlineComments: [NativeEditorInlineCommentMark] {
        var seenCommentIDs: Set<String> = []
        return filter { comment in
            let commentID = comment.commentID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard commentID.isEmpty == false, seenCommentIDs.contains(commentID) == false else {
                return false
            }
            seenCommentIDs.insert(commentID)
            return true
        }
    }

    func updatingNativeEditorInlineComment(
        _ updatedComment: NativeEditorInlineCommentMark
    ) -> [NativeEditorInlineCommentMark] {
        let normalizedUpdatedComment = NativeEditorInlineCommentMark(
            commentID: updatedComment.commentID.trimmingCharacters(in: .whitespacesAndNewlines),
            isResolved: updatedComment.isResolved
        )
        guard normalizedUpdatedComment.commentID.isEmpty == false else { return self }

        var comments = normalizedNativeEditorInlineComments
        if let index = comments.firstIndex(where: { $0.commentID == normalizedUpdatedComment.commentID }) {
            comments[index] = normalizedUpdatedComment
        } else {
            comments.append(normalizedUpdatedComment)
        }
        return comments
    }

    func removingNativeEditorInlineComment(commentID: String) -> [NativeEditorInlineCommentMark] {
        let trimmedCommentID = commentID.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedNativeEditorInlineComments.filter { $0.commentID != trimmedCommentID }
    }
}
