import Foundation

struct CommentPayload: Encodable, Sendable {
    let type: String
    let content: [CommentParagraph]

    static func plainText(_ text: String) -> CommentPayload {
        CommentPayload(
            type: "doc",
            content: [
                CommentParagraph(
                    type: "paragraph",
                    content: [CommentText(type: "text", text: text)]
                )
            ]
        )
    }

    var jsonString: String {
        let encoder = JSONEncoder()
        guard
            let data = try? encoder.encode(self),
            let string = String(data: data, encoding: .utf8)
        else {
            return #"{"type":"doc","content":[]}"#
        }
        return string
    }
}

struct CommentParagraph: Encodable, Sendable {
    let type: String
    let content: [CommentText]
}

struct CommentText: Encodable, Sendable {
    let type: String
    let text: String
}
