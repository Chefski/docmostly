import Foundation

extension NativeEditorMarkdownParser {
    static func removingLeadingYAMLFrontMatter(from markdown: String) -> String {
        var start = markdown.startIndex
        while start < markdown.endIndex, markdown[start].isWhitespace {
            start = markdown.index(after: start)
        }

        guard start < markdown.endIndex, markdown[start...].hasPrefix("---") else { return markdown }

        let bodyStart = markdown.index(start, offsetBy: 3)
        guard let closeRange = markdown[bodyStart...].range(of: "---") else { return markdown }

        var contentStart = closeRange.upperBound
        while contentStart < markdown.endIndex, markdown[contentStart].isWhitespace {
            contentStart = markdown.index(after: contentStart)
        }

        return String(markdown[contentStart...])
    }
}
