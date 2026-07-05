import Foundation

nonisolated struct CommentPayload: Encodable, Sendable {
    let type: String
    let content: [CommentParagraph]

    static func plainText(_ text: String) -> CommentPayload {
        let paragraphs = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                CommentParagraph(
                    type: "paragraph",
                    content: line.isEmpty ? [] : [CommentText(type: "text", text: String(line))]
                )
            }
        return CommentPayload(
            type: "doc",
            content: paragraphs.isEmpty ? [CommentParagraph(type: "paragraph", content: [])] : paragraphs
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

nonisolated struct CommentParagraph: Encodable, Sendable {
    let type: String
    let content: [CommentText]
}

nonisolated struct CommentText: Encodable, Sendable {
    let type: String
    let text: String
}
