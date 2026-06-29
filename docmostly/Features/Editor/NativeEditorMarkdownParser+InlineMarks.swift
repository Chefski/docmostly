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

        if let href = run.link?.absoluteString {
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
        guard
            let openIndex = markdown.firstIndex(of: "`"),
            let closeIndex = markdown[markdown.index(after: openIndex)...].firstIndex(of: "`")
        else {
            return nil
        }

        let contentStart = markdown.index(after: openIndex)
        let content = String(markdown[contentStart..<closeIndex])
        guard content.isEmpty == false else { return nil }

        var text = AttributedString(content)
        text.inlinePresentationIntent = .code
        return InlineMarkdownMatch(
            range: openIndex..<markdown.index(after: closeIndex),
            text: text,
            priority: 0
        )
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
                let closeDestinationIndex = markdown[
                    markdown.index(after: markdown.index(after: closeLabelIndex))...
                ].firstIndex(of: ")")
            else {
                return nil
            }

            let labelStartIndex = markdown.index(after: openLabelIndex)
            let destinationStartIndex = markdown.index(after: markdown.index(after: closeLabelIndex))
            let label = String(markdown[labelStartIndex..<closeLabelIndex])
            let destination = markdownLinkDestination(
                from: String(markdown[destinationStartIndex..<closeDestinationIndex])
            )

            guard label.isEmpty == false, let url = URL(string: destination) else {
                searchStart = markdown.index(after: closeDestinationIndex)
                continue
            }

            var text = attributedInlineMarkdown(from: label)
            text.link = url
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

    private static func markdownLinkDestination(from destination: String) -> String {
        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedDestination.hasPrefix("<"),
           let closeIndex = trimmedDestination.firstIndex(of: ">") {
            let sourceStartIndex = trimmedDestination.index(after: trimmedDestination.startIndex)
            return String(trimmedDestination[sourceStartIndex..<closeIndex])
        }

        return trimmedDestination.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
    }
}
