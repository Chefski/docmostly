import Foundation

extension NativeEditorMarkdownParser {
    static func docmostInlineHTMLAttributes(from openingTag: String) -> [String: String] {
        var attrs = [String: String]()
        var index = openingTag.startIndex

        while index < openingTag.endIndex {
            guard let nameRange = nextDocmostInlineHTMLAttributeNameRange(in: openingTag, startingAt: index) else {
                break
            }

            let name = String(openingTag[nameRange]).lowercased()
            index = nameRange.upperBound
            skipDocmostInlineHTMLWhitespace(in: openingTag, index: &index)
            guard index < openingTag.endIndex, openingTag[index] == "=" else {
                if name != "span" {
                    attrs[name] = ""
                }
                continue
            }

            index = openingTag.index(after: index)
            skipDocmostInlineHTMLWhitespace(in: openingTag, index: &index)
            let value = docmostInlineHTMLAttributeValue(in: openingTag, startingAt: &index)
            attrs[name] = unescapedInlineHTMLText(value)
        }

        return attrs
    }

    static func matchingCloseSpanRange(
        in markdown: Substring,
        bodyStart: String.Index
    ) -> Range<String.Index>? {
        var depth = 1
        var searchStart = bodyStart

        while searchStart < markdown.endIndex,
              let closeRange = markdown[searchStart...].range(of: "</span>", options: .caseInsensitive) {
            if let nestedOpenRange = markdown[searchStart...].range(of: "<span", options: .caseInsensitive),
               nestedOpenRange.lowerBound < closeRange.lowerBound {
                depth += 1
                searchStart = nestedOpenRange.upperBound
                continue
            }

            depth -= 1
            if depth == 0 {
                return closeRange
            }
            searchStart = closeRange.upperBound
        }

        return nil
    }

    static func escapedInlineHTMLAttribute(_ text: String) -> String {
        escapedInlineHTMLText(text).replacing("\"", with: "&quot;")
    }

    static func escapedInlineHTMLText(_ text: String) -> String {
        text
            .replacing("&", with: "&amp;")
            .replacing("<", with: "&lt;")
            .replacing(">", with: "&gt;")
    }

    static func unescapedInlineHTMLText(_ text: String) -> String {
        text
            .replacing("&quot;", with: "\"")
            .replacing("&lt;", with: "<")
            .replacing("&gt;", with: ">")
            .replacing("&amp;", with: "&")
    }

    private static func nextDocmostInlineHTMLAttributeNameRange(
        in text: String,
        startingAt index: String.Index
    ) -> Range<String.Index>? {
        var nameStart = index
        while nameStart < text.endIndex, text[nameStart].isDocmostHTMLAttrNameChar == false {
            nameStart = text.index(after: nameStart)
        }

        guard nameStart < text.endIndex else { return nil }

        var nameEnd = nameStart
        while nameEnd < text.endIndex, text[nameEnd].isDocmostHTMLAttrNameChar {
            nameEnd = text.index(after: nameEnd)
        }

        return nameStart..<nameEnd
    }

    private static func docmostInlineHTMLAttributeValue(
        in text: String,
        startingAt index: inout String.Index
    ) -> String {
        guard index < text.endIndex else { return "" }

        if text[index] == "\"" || text[index] == "'" {
            let quote = text[index]
            let valueStart = text.index(after: index)
            guard let valueEnd = text[valueStart...].firstIndex(of: quote) else {
                index = text.endIndex
                return String(text[valueStart...])
            }

            index = text.index(after: valueEnd)
            return String(text[valueStart..<valueEnd])
        }

        let valueStart = index
        while index < text.endIndex, text[index].isWhitespace == false, text[index] != ">" {
            index = text.index(after: index)
        }

        return String(text[valueStart..<index])
    }

    private static func skipDocmostInlineHTMLWhitespace(in text: String, index: inout String.Index) {
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }
    }
}

private extension Character {
    var isDocmostHTMLAttrNameChar: Bool {
        isLetter || isNumber || self == "-" || self == "_" || self == ":"
    }
}
