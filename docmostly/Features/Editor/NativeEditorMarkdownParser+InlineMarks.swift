import Foundation

extension NativeEditorMarkdownParser {
    static func inlineMarkdownInputRuleText(from text: String) -> AttributedString? {
        if let inlineMathText = inlineMathInputRuleText(from: text) {
            return inlineMathText
        }

        let attributedText = attributedInlineMarkdown(from: text)
        guard String(attributedText.characters) != text else { return nil }
        return attributedText
    }

    static func attributedInlineMarkdown(from markdown: String) -> AttributedString {
        var output = AttributedString("")
        var remaining = markdown[...]

        while let match = nextInlineMarkdownMatch(in: remaining) {
            output += AttributedString(String(remaining[..<match.range.lowerBound]))
            output += match.text
            remaining = remaining[match.range.upperBound...]
        }

        output += AttributedString(String(remaining))
        return output
    }

    static func inlineRunMarkdown(from run: AttributedString.Runs.Run, text: String) -> String {
        var output = text
        let intent = run.inlinePresentationIntent ?? []

        if intent.contains(.code) {
            output = codeMarkdown(from: output)
        } else {
            if intent.contains(.stronglyEmphasized) {
                output = "**\(output)**"
            }

            if intent.contains(.emphasized) {
                output = "*\(output)*"
            }

            if intent.contains(.strikethrough) {
                output = "~~\(output)~~"
            }
        }

        if let href = run[NativeEditorLinkAttribute.self]?.href ?? run.link?.absoluteString {
            output = "[\(escapedMarkdownLinkLabel(output))](\(href))"
        }

        return output
    }

    static func scriptUnderlineMarkdown(
        from run: AttributedString.Runs.Run,
        body: String
    ) -> String {
        var output = body

        if let baselineOffset = run.baselineOffset, baselineOffset != 0 {
            let tagName = baselineOffset > 0 ? "sup" : "sub"
            output = "<\(tagName)>\(output)</\(tagName)>"
        }

        if run.underlineStyle != nil {
            output = "<u>\(output)</u>"
        }

        return output
    }

    private static func codeMarkdown(from text: String) -> String {
        let delimiter = text.contains("`") ? "``" : "`"
        return "\(delimiter)\(text)\(delimiter)"
    }

    private static func escapedMarkdownLinkLabel(_ text: String) -> String {
        text
            .replacing("\\", with: "\\\\")
            .replacing("[", with: "\\[")
            .replacing("]", with: "\\]")
    }

    private struct InlineMarkdownMatch {
        var range: Range<String.Index>
        var text: AttributedString
        var priority: Int
    }

    private static func nextInlineMarkdownMatch(in markdown: Substring) -> InlineMarkdownMatch? {
        [
            codeInlineMarkdownMatch(in: markdown),
            linkedInlineMarkdownMatch(in: markdown),
            delimitedInlineMarkdownMatch(
                in: markdown,
                delimiter: "**",
                intent: .stronglyEmphasized,
                priority: 2
            ),
            delimitedInlineMarkdownMatch(
                in: markdown,
                delimiter: "__",
                intent: .stronglyEmphasized,
                priority: 2
            ),
            delimitedInlineMarkdownMatch(
                in: markdown,
                delimiter: "~~",
                intent: .strikethrough,
                priority: 3
            ),
            delimitedInlineMarkdownMatch(
                in: markdown,
                delimiter: "*",
                intent: .emphasized,
                priority: 4
            ),
            delimitedInlineMarkdownMatch(
                in: markdown,
                delimiter: "_",
                intent: .emphasized,
                priority: 4
            )
        ]
        .compactMap { $0 }
        .min { lhs, rhs in
            if lhs.range.lowerBound == rhs.range.lowerBound {
                return lhs.priority < rhs.priority
            }

            return lhs.range.lowerBound < rhs.range.lowerBound
        }
    }

    private static func codeInlineMarkdownMatch(in markdown: Substring) -> InlineMarkdownMatch? {
        guard let openingRun = nextBacktickRun(in: markdown, startingAt: markdown.startIndex),
              let closingRun = nextMatchingBacktickRun(in: markdown, after: openingRun) else { return nil }

        let content = String(markdown[openingRun.upperBound..<closingRun.lowerBound])
        guard content.isEmpty == false else { return nil }

        var text = AttributedString(content)
        text.inlinePresentationIntent = .code
        return InlineMarkdownMatch(
            range: openingRun.lowerBound..<closingRun.upperBound,
            text: text,
            priority: 0
        )
    }

    private static func nextMatchingBacktickRun(
        in markdown: Substring,
        after openingRun: Range<String.Index>
    ) -> Range<String.Index>? {
        var searchStart = openingRun.upperBound

        while let run = nextBacktickRun(in: markdown, startingAt: searchStart) {
            if markdown.distance(from: run.lowerBound, to: run.upperBound) ==
                markdown.distance(from: openingRun.lowerBound, to: openingRun.upperBound) {
                return run
            }

            searchStart = run.upperBound
        }

        return nil
    }

    private static func nextBacktickRun(
        in markdown: Substring,
        startingAt searchStart: String.Index
    ) -> Range<String.Index>? {
        guard searchStart < markdown.endIndex,
              let runStart = markdown[searchStart...].firstIndex(of: "`") else { return nil }

        var runEnd = runStart
        while runEnd < markdown.endIndex, markdown[runEnd] == "`" {
            runEnd = markdown.index(after: runEnd)
        }

        return runStart..<runEnd
    }

    private static func linkedInlineMarkdownMatch(in markdown: Substring) -> InlineMarkdownMatch? {
        var searchStart = markdown.startIndex

        while searchStart < markdown.endIndex,
              let openLabelIndex = markdown[searchStart...].firstIndex(of: "[") {
            if isImageMarker(before: openLabelIndex, in: markdown) {
                searchStart = markdown.index(after: openLabelIndex)
                continue
            }

            guard
                let closeLabelIndex = markdown[markdown.index(after: openLabelIndex)...].firstIndex(of: "]"),
                markdown.index(after: closeLabelIndex) < markdown.endIndex,
                markdown[markdown.index(after: closeLabelIndex)] == "(",
                let closeDestinationIndex = closingMarkdownLinkDestinationIndex(
                    in: markdown,
                    startingAt: markdown.index(after: markdown.index(after: closeLabelIndex))
                )
            else {
                return nil
            }

            let labelStartIndex = markdown.index(after: openLabelIndex)
            let destinationStartIndex = markdown.index(after: markdown.index(after: closeLabelIndex))
            let label = String(markdown[labelStartIndex..<closeLabelIndex])
            let destination = markdownLinkSource(
                from: String(markdown[destinationStartIndex..<closeDestinationIndex])
            )

            guard label.isEmpty == false, let url = URL(string: destination) else {
                searchStart = markdown.index(after: closeDestinationIndex)
                continue
            }

            var text = attributedInlineMarkdown(from: label)
            text.link = url
            if let link = NativeEditorDocument.preservedLink(href: destination) {
                text[NativeEditorLinkAttribute.self] = link
            }
            return InlineMarkdownMatch(
                range: openLabelIndex..<markdown.index(after: closeDestinationIndex),
                text: text,
                priority: 1
            )
        }

        return nil
    }

    private static func delimitedInlineMarkdownMatch(
        in markdown: Substring,
        delimiter: String,
        intent: InlinePresentationIntent,
        priority: Int
    ) -> InlineMarkdownMatch? {
        guard
            let openRange = markdown.range(of: delimiter),
            let closeRange = markdown[openRange.upperBound...].range(of: delimiter)
        else {
            return nil
        }

        if delimiter.count == 1, isPartOfRepeatedDelimiter(openRange, delimiter: delimiter, in: markdown) {
            return nil
        }

        let content = String(markdown[openRange.upperBound..<closeRange.lowerBound])
        guard content.isEmpty == false else { return nil }

        var text = attributedInlineMarkdown(from: content)
        text.inlinePresentationIntent = (text.inlinePresentationIntent ?? []).union(intent)
        return InlineMarkdownMatch(
            range: openRange.lowerBound..<closeRange.upperBound,
            text: text,
            priority: priority
        )
    }

    private static func isImageMarker(before index: String.Index, in markdown: Substring) -> Bool {
        guard index > markdown.startIndex else { return false }
        return markdown[markdown.index(before: index)] == "!"
    }

    static func closingMarkdownLinkDestinationIndex(
        in markdown: Substring,
        startingAt destinationStartIndex: String.Index
    ) -> String.Index? {
        var scanner = MarkdownLinkDestinationScanner(
            markdown: markdown,
            destinationStartIndex: destinationStartIndex
        )
        return scanner.closingIndex()
    }

    private static func isPartOfRepeatedDelimiter(
        _ range: Range<String.Index>,
        delimiter: String,
        in markdown: Substring
    ) -> Bool {
        guard let delimiterCharacter = delimiter.first else { return false }

        if range.lowerBound > markdown.startIndex,
           markdown[markdown.index(before: range.lowerBound)] == delimiterCharacter {
            return true
        }

        return range.upperBound < markdown.endIndex && markdown[range.upperBound] == delimiterCharacter
    }

}

private struct MarkdownLinkDestinationScanner {
    var markdown: Substring
    var index: String.Index
    var nestedParenthesisCount = 0
    var quoteDelimiter: Character?
    var isInsideAngleDestination = false
    var hasReadNonWhitespaceDestinationCharacter = false

    init(markdown: Substring, destinationStartIndex: String.Index) {
        self.markdown = markdown
        index = destinationStartIndex
    }

    mutating func closingIndex() -> String.Index? {
        while index < markdown.endIndex {
            let character = markdown[index]
            defer { index = markdown.index(after: index) }

            if consumesEscapedCharacter(character) || consumesQuotedCharacter(character) ||
                consumesAngleDestinationCharacter(character) || consumesOpeningAngleDestination(character) ||
                consumesTitleQuote(character) {
                continue
            }

            if let closingIndex = consumeParenthesis(character) {
                return closingIndex
            }

            markDestinationCharacter(character)
        }

        return nil
    }

    mutating private func consumesEscapedCharacter(_ character: Character) -> Bool {
        guard isEscapedCharacter(at: index) else { return false }
        markDestinationCharacter(character)
        return true
    }

    mutating private func consumesQuotedCharacter(_ character: Character) -> Bool {
        guard let delimiter = quoteDelimiter else { return false }
        if character == delimiter {
            quoteDelimiter = nil
        }
        return true
    }

    mutating private func consumesAngleDestinationCharacter(_ character: Character) -> Bool {
        guard isInsideAngleDestination else { return false }
        if character == ">" {
            isInsideAngleDestination = false
        }
        return true
    }

    mutating private func consumesOpeningAngleDestination(_ character: Character) -> Bool {
        guard character == "<", hasReadNonWhitespaceDestinationCharacter == false else { return false }
        isInsideAngleDestination = true
        hasReadNonWhitespaceDestinationCharacter = true
        return true
    }

    mutating private func consumesTitleQuote(_ character: Character) -> Bool {
        guard isMarkdownLinkTitleQuote(character) else { return false }
        quoteDelimiter = character
        return true
    }

    mutating private func consumeParenthesis(_ character: Character) -> String.Index? {
        switch character {
        case "(":
            nestedParenthesisCount += 1
            return nil
        case ")":
            guard nestedParenthesisCount > 0 else { return index }
            nestedParenthesisCount -= 1
            return nil
        default:
            return nil
        }
    }

    mutating private func markDestinationCharacter(_ character: Character) {
        if character.isWhitespace == false {
            hasReadNonWhitespaceDestinationCharacter = true
        }
    }

    private func isMarkdownLinkTitleQuote(_ character: Character) -> Bool {
        guard character == "\"" || character == "'",
              index > markdown.startIndex else {
            return false
        }

        return markdown[markdown.index(before: index)].isWhitespace
    }

    private func isEscapedCharacter(at index: String.Index) -> Bool {
        var backslashCount = 0
        var currentIndex = index

        while currentIndex > markdown.startIndex {
            let previousIndex = markdown.index(before: currentIndex)
            guard markdown[previousIndex] == "\\" else { break }

            backslashCount += 1
            currentIndex = previousIndex
        }

        return backslashCount.isMultiple(of: 2) == false
    }
}
