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

    static func htmlTagAttributes(from line: String, tagName: String) -> [String: String]? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = openingHTMLTagRange(in: trimmedLine, tagName: tagName),
              range.lowerBound == trimmedLine.startIndex else {
            return nil
        }

        return docmostInlineHTMLAttributes(from: String(trimmedLine[range]))
    }

    static func firstHTMLTagAttributes(in line: String, tagName: String) -> [String: String]? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = openingHTMLTagRange(in: trimmedLine, tagName: tagName) else {
            return nil
        }

        return docmostInlineHTMLAttributes(from: String(trimmedLine[range]))
    }

    static func containsHTMLClosingTag(in line: String, tagName: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        var searchStart = trimmedLine.startIndex

        while searchStart < trimmedLine.endIndex,
              let openIndex = trimmedLine[searchStart...].firstIndex(of: "<") {
            var nameStart = trimmedLine.index(after: openIndex)
            guard nameStart < trimmedLine.endIndex, trimmedLine[nameStart] == "/" else {
                searchStart = nameStart
                continue
            }

            nameStart = trimmedLine.index(after: nameStart)
            let nameEnd = htmlTagNameEnd(in: trimmedLine, startingAt: nameStart)
            let name = String(trimmedLine[nameStart..<nameEnd])
            if htmlTagNameMatches(name, tagName),
               isHTMLTagBoundary(at: nameEnd, in: trimmedLine) {
                return true
            }
            searchStart = nameEnd
        }

        return false
    }

    static func htmlTagDepthDelta(in line: String, tagName: String) -> Int {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        var delta = 0
        var searchStart = trimmedLine.startIndex

        while searchStart < trimmedLine.endIndex,
              let openIndex = trimmedLine[searchStart...].firstIndex(of: "<") {
            var nameStart = trimmedLine.index(after: openIndex)
            guard nameStart < trimmedLine.endIndex else { break }

            let isClosingTag = trimmedLine[nameStart] == "/"
            if isClosingTag {
                nameStart = trimmedLine.index(after: nameStart)
            }

            let nameEnd = htmlTagNameEnd(in: trimmedLine, startingAt: nameStart)
            let name = String(trimmedLine[nameStart..<nameEnd])
            guard isHTMLTagBoundary(at: nameEnd, in: trimmedLine),
                  let closeIndex = htmlOpeningTagCloseIndex(in: trimmedLine, startingAt: nameEnd) else {
                searchStart = nameEnd
                continue
            }

            guard htmlTagNameMatches(name, tagName) else {
                searchStart = trimmedLine.index(after: closeIndex)
                continue
            }

            if isClosingTag {
                delta -= 1
            } else if isSelfClosingHTMLTag(in: trimmedLine, closeIndex: closeIndex) == false {
                delta += 1
            }

            searchStart = trimmedLine.index(after: closeIndex)
        }

        return delta
    }

    static func matchingCloseSpanRange(
        in markdown: Substring,
        bodyStart: String.Index
    ) -> Range<String.Index>? {
        let codeSpanRanges = markdownCodeSpanRanges(in: markdown, bodyStart: bodyStart)
        var depth = 1
        var searchStart = bodyStart

        while searchStart < markdown.endIndex,
              let closeRange = markdown[searchStart...].range(of: "</span>", options: .caseInsensitive) {
            if isInsideMarkdownCodeSpan(closeRange.lowerBound, ranges: codeSpanRanges) {
                searchStart = closeRange.upperBound
                continue
            }

            if let nestedOpenRange = nextOpeningSpanRange(
                in: markdown,
                startingAt: searchStart,
                before: closeRange.lowerBound,
                codeSpanRanges: codeSpanRanges
            ) {
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

    private static func nextOpeningSpanRange(
        in markdown: Substring,
        startingAt searchStart: String.Index,
        before upperBound: String.Index,
        codeSpanRanges: [Range<String.Index>]
    ) -> Range<String.Index>? {
        var currentSearchStart = searchStart

        while currentSearchStart < upperBound,
              let openRange = markdown[currentSearchStart..<upperBound].range(of: "<span", options: .caseInsensitive) {
            if isInsideMarkdownCodeSpan(openRange.lowerBound, ranges: codeSpanRanges) {
                currentSearchStart = openRange.upperBound
                continue
            }

            let nameStart = markdown.index(after: openRange.lowerBound)
            let nameEnd = htmlTagNameEnd(in: markdown, startingAt: nameStart)
            let name = String(markdown[nameStart..<nameEnd])
            guard htmlTagNameMatches(name, "span"),
                  isHTMLTagBoundary(at: nameEnd, in: markdown),
                  let closeIndex = htmlOpeningTagCloseIndex(in: markdown, startingAt: nameEnd) else {
                currentSearchStart = openRange.upperBound
                continue
            }

            return openRange.lowerBound..<markdown.index(after: closeIndex)
        }

        return nil
    }

    static func markdownCodeSpanRanges(
        in markdown: Substring,
        bodyStart: String.Index
    ) -> [Range<String.Index>] {
        var ranges = [Range<String.Index>]()
        var activeBacktickRunStart: String.Index?
        var activeBacktickRunLength: Int?
        var currentIndex = bodyStart

        while currentIndex < markdown.endIndex {
            guard markdown[currentIndex] == "`" else {
                currentIndex = markdown.index(after: currentIndex)
                continue
            }

            let runStart = currentIndex
            var runLength = 0
            while currentIndex < markdown.endIndex, markdown[currentIndex] == "`" {
                runLength += 1
                currentIndex = markdown.index(after: currentIndex)
            }

            if let activeLength = activeBacktickRunLength {
                if activeLength == runLength {
                    if let activeBacktickRunStart {
                        ranges.append(activeBacktickRunStart..<currentIndex)
                    }
                    activeBacktickRunStart = nil
                    activeBacktickRunLength = nil
                }
            } else {
                activeBacktickRunStart = runStart
                activeBacktickRunLength = runLength
            }
        }

        if let activeBacktickRunStart {
            ranges.append(activeBacktickRunStart..<markdown.endIndex)
        }

        return ranges
    }

    static func isInsideMarkdownCodeSpan(
        _ index: String.Index,
        ranges: [Range<String.Index>]
    ) -> Bool {
        var low = ranges.startIndex
        var high = ranges.endIndex

        while low < high {
            let mid = low + (high - low) / 2
            let range = ranges[mid]

            if index < range.lowerBound {
                high = mid
            } else if index >= range.upperBound {
                low = mid + 1
            } else {
                return true
            }
        }

        return false
    }

    private static func openingHTMLTagRange(in text: String, tagName: String) -> Range<String.Index>? {
        var searchStart = text.startIndex

        while searchStart < text.endIndex,
              let openIndex = text[searchStart...].firstIndex(of: "<") {
            let nameStart = text.index(after: openIndex)
            guard nameStart < text.endIndex, text[nameStart] != "/" else {
                searchStart = nameStart
                continue
            }

            let nameEnd = htmlTagNameEnd(in: text, startingAt: nameStart)
            let name = String(text[nameStart..<nameEnd])
            guard htmlTagNameMatches(name, tagName),
                  isHTMLTagBoundary(at: nameEnd, in: text),
                  let closeIndex = htmlOpeningTagCloseIndex(in: text, startingAt: nameEnd) else {
                searchStart = nameEnd
                continue
            }

            return openIndex..<closeIndex
        }

        return nil
    }

    nonisolated static func htmlTagNameMatches(_ name: String, _ tagName: String, locale _: Locale? = nil) -> Bool {
        name.compare(tagName, options: .caseInsensitive) == .orderedSame
    }

    private static func htmlTagNameEnd(in text: String, startingAt index: String.Index) -> String.Index {
        var currentIndex = index
        while currentIndex < text.endIndex, text[currentIndex].isDocmostHTMLTagNameChar {
            currentIndex = text.index(after: currentIndex)
        }
        return currentIndex
    }

    private static func htmlTagNameEnd(in text: Substring, startingAt index: String.Index) -> String.Index {
        var currentIndex = index
        while currentIndex < text.endIndex, text[currentIndex].isDocmostHTMLTagNameChar {
            currentIndex = text.index(after: currentIndex)
        }
        return currentIndex
    }

    private static func isHTMLTagBoundary(at index: String.Index, in text: String) -> Bool {
        index == text.endIndex || text[index].isWhitespace || text[index] == ">" || text[index] == "/"
    }

    private static func isHTMLTagBoundary(at index: String.Index, in text: Substring) -> Bool {
        index == text.endIndex || text[index].isWhitespace || text[index] == ">" || text[index] == "/"
    }

    private static func htmlOpeningTagCloseIndex(in text: String, startingAt index: String.Index) -> String.Index? {
        var currentIndex = index
        var quote: Character?

        while currentIndex < text.endIndex {
            let character = text[currentIndex]
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ">" {
                return currentIndex
            }

            currentIndex = text.index(after: currentIndex)
        }

        return nil
    }

    private static func htmlOpeningTagCloseIndex(in text: Substring, startingAt index: String.Index) -> String.Index? {
        var currentIndex = index
        var quote: Character?

        while currentIndex < text.endIndex {
            let character = text[currentIndex]
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ">" {
                return currentIndex
            }

            currentIndex = text.index(after: currentIndex)
        }

        return nil
    }

    private static func isSelfClosingHTMLTag(in text: String, closeIndex: String.Index) -> Bool {
        guard closeIndex > text.startIndex else { return false }

        var currentIndex = text.index(before: closeIndex)
        while currentIndex > text.startIndex, text[currentIndex].isWhitespace {
            currentIndex = text.index(before: currentIndex)
        }

        return text[currentIndex] == "/"
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

    var isDocmostHTMLTagNameChar: Bool {
        isLetter || isNumber || self == "-"
    }
}
