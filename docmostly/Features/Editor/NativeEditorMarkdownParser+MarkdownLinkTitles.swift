import Foundation

extension NativeEditorMarkdownParser {
    static func markdownLinkTitle(from destination: String) -> String? {
        let destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let titleRange = destination.range(of: " \""),
            destination.hasSuffix("\"")
        else {
            return nil
        }

        let titleStart = titleRange.upperBound
        let titleEnd = destination.index(before: destination.endIndex)
        let title = unescapedMarkdownLinkTitle(String(destination[titleStart..<titleEnd]))
        return title.isEmpty ? nil : title
    }

    static func markdownLinkTitlePart(from title: String?) -> String {
        guard let title, title.isEmpty == false else { return "" }
        return " \"\(escapedMarkdownLinkTitle(title))\""
    }

    private static func escapedMarkdownLinkTitle(_ text: String) -> String {
        text.replacing("\\", with: "\\\\")
            .replacing("\"", with: "\\\"")
            .replacing("\r", with: " ")
            .replacing("\n", with: " ")
    }

    private static func unescapedMarkdownLinkTitle(_ text: String) -> String {
        var result = ""
        var isEscaped = false

        for character in text {
            if isEscaped {
                result.append(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else {
                result.append(character)
            }
        }

        if isEscaped {
            result.append("\\")
        }

        return result
    }
}
