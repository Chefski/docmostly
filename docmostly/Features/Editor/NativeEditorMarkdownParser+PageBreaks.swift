import Foundation

extension NativeEditorMarkdownParser {
    static func pageBreakHTMLBlock(from line: String) -> NativeEditorBlock? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercasedLine = trimmedLine.lowercased()
        guard lowercasedLine.hasPrefix("<div") else {
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
        guard isPageBreakHTML(attributes: attributes) else {
            return nil
        }

        return NativeEditorBlock(
            kind: .pageBreak,
            text: AttributedString(NativeEditorDocument.previewText(for: .pageBreak)),
            alignment: .left,
            rawNode: ProseMirrorNode(type: "pageBreak")
        )
    }

    private static func isPageBreakHTML(attributes: [String: String]) -> Bool {
        if attributes["data-type"]?.localizedCaseInsensitiveCompare("pageBreak") == .orderedSame {
            return true
        }

        let style = attributes["style"]?.lowercased() ?? ""
        return style.contains("page-break-after") && style.contains("always")
    }
}
