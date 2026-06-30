import Foundation

extension NativeEditorMarkdownParser {
    static func htmlTableMarkedInlineMarkdown(from node: ProseMirrorNode) -> String {
        (node.marks ?? []).reversed().reduce(escapedInlineHTMLText(node.text ?? "")) { body, mark in
            htmlTableMarkedInlineMarkdown(mark: NativeEditorDocument.textMark(from: mark), body: body)
        }
    }

    private static func htmlTableMarkedInlineMarkdown(mark: NativeEditorTextMark, body: String) -> String {
        if let presentationMarkdown = htmlTablePresentationInlineMarkdown(mark: mark, body: body) {
            return presentationMarkdown
        }

        return htmlTableRichInlineMarkdown(mark: mark, body: body)
    }

    private static func htmlTablePresentationInlineMarkdown(mark: NativeEditorTextMark, body: String) -> String? {
        switch mark {
        case .bold:
            "<strong>\(body)</strong>"
        case .italic:
            "<em>\(body)</em>"
        case .underline:
            "<u>\(body)</u>"
        case .strikethrough:
            "<s>\(body)</s>"
        case .code:
            "<code>\(body)</code>"
        case .subscript:
            "<sub>\(body)</sub>"
        case .superscript:
            "<sup>\(body)</sup>"
        default:
            nil
        }
    }

    private static func htmlTableRichInlineMarkdown(mark: NativeEditorTextMark, body: String) -> String {
        switch mark {
        case .link(let href, let isInternal):
            htmlTableMarkedInlineTag("a", body: body, attrs: [
                ("href", href),
                ("data-internal", isInternal ? "true" : nil)
            ])
        case .highlight(let color, let colorName):
            htmlTableMarkedInlineTag("mark", body: body, attrs: [
                ("data-color", color),
                ("data-color-name", colorName)
            ])
        case .textColor(let color):
            htmlTableMarkedInlineTag("span", body: body, attrs: [("style", "color: \(color)")])
        case .comment(let commentID, let isResolved):
            htmlTableMarkedInlineTag("span", body: body, attrs: [
                ("class", isResolved ? "comment-mark resolved" : "comment-mark"),
                ("data-comment-id", commentID),
                ("data-resolved", isResolved ? "true" : nil)
            ])
        default:
            body
        }
    }

    private static func htmlTableMarkedInlineTag(
        _ name: String,
        body: String,
        attrs: [(String, String?)]
    ) -> String {
        "\(htmlTableTag(name, attrs: attrs))\(body)</\(name)>"
    }
}
