import Foundation

extension NativeEditorMarkdownParser {
    static func blockquoteBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        var quoteLines: [String] = []
        var currentIndex = index

        while currentIndex < lines.endIndex,
              let text = blockquoteLineText(from: lines[currentIndex]) {
            quoteLines.append(text)
            currentIndex = lines.index(after: currentIndex)
        }

        guard quoteLines.count > 1 else { return nil }

        return (
            NativeEditorBlock(
                kind: .blockquote,
                text: multilineParagraphText(from: quoteLines),
                alignment: .left
            ),
            currentIndex
        )
    }

    static func blockquoteMarkdown(from text: String) -> String {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> \($0)" }
            .joined(separator: "\n")
    }

    private static func blockquoteLineText(from line: String) -> String? {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        if trimmedLine == ">" {
            return ""
        }

        guard trimmedLine.hasPrefix("> ") else { return nil }
        return String(trimmedLine.dropFirst(2))
    }
}
