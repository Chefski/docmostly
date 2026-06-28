import Foundation

extension NativeEditorMarkdownParser {
    static func pageBreakHTMLBlock(from line: String) -> NativeEditorBlock? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedLine = trimmedLine.lowercased()
        guard
            lowercasedLine.hasPrefix("<div"),
            lowercasedLine.contains("data-type")
        else {
            return nil
        }

        guard
            let tagEnd = trimmedLine.firstIndex(of: ">"),
            tagEnd > trimmedLine.startIndex
        else {
            return nil
        }

        let openingTag = String(trimmedLine[trimmedLine.startIndex..<tagEnd])
        let attributes = docmostInlineHTMLAttributes(from: openingTag)
        guard attributes["data-type"]?.localizedCaseInsensitiveCompare("pageBreak") == .orderedSame else {
            return nil
        }

        return NativeEditorBlock(
            kind: .pageBreak,
            text: AttributedString(NativeEditorDocument.previewText(for: .pageBreak)),
            alignment: .left,
            rawNode: ProseMirrorNode(type: "pageBreak")
        )
    }
}
