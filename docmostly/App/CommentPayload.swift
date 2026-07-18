import Foundation

nonisolated struct CommentPayload: Sendable {
    let body: CommentBody

    static func plainText(_ text: String) -> CommentPayload {
        CommentPayload(body: CommentBody(plainText: text))
    }

    static func richText(_ text: AttributedString) -> CommentPayload {
        CommentPayload(body: CommentBody(attributedText: text))
    }

    var jsonString: String {
        body.jsonString
    }
}
