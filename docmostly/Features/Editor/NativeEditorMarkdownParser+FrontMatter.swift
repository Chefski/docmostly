import Foundation

extension NativeEditorMarkdownParser {
    static func removingLeadingYAMLFrontMatter(from markdown: String) -> String {
        var start = markdown.startIndex
        while start < markdown.endIndex, markdown[start].isWhitespace {
            start = markdown.index(after: start)
        }

        let lines = markdown[start...].split(separator: "\n", omittingEmptySubsequences: false)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---",
              let closingIndex = lines.dropFirst().firstIndex(where: {
                  $0.trimmingCharacters(in: .whitespacesAndNewlines) == "---"
              }) else {
            return markdown
        }

        let content = lines[lines.index(after: closingIndex)...].joined(separator: "\n")
        guard let contentStart = content.firstIndex(where: { $0.isWhitespace == false }) else { return "" }
        return String(content[contentStart...])
    }
}
