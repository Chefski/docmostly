import Foundation

extension NativeEditorMarkdownParser {
    static func htmlTableInlineGapContentMatches(
        from html: String,
        between preservedMatches: [HTMLTableContentMatch]
    ) -> [HTMLTableContentMatch] {
        guard preservedMatches.isEmpty == false else { return [] }

        var matches: [HTMLTableContentMatch] = []
        var currentLocation = 0
        let sortedRanges = preservedMatches.map(\.range).sorted { $0.location < $1.location }

        for range in sortedRanges {
            if range.location > currentLocation,
               let match = htmlTableInlineGapContentMatch(
                   from: html,
                   range: NSRange(location: currentLocation, length: range.location - currentLocation)
               ) {
                matches.append(match)
            }

            currentLocation = max(currentLocation, NSMaxRange(range))
        }

        let htmlRange = NSRange(html.startIndex..<html.endIndex, in: html)
        if currentLocation < NSMaxRange(htmlRange),
           let match = htmlTableInlineGapContentMatch(
               from: html,
               range: NSRange(location: currentLocation, length: NSMaxRange(htmlRange) - currentLocation)
           ) {
            matches.append(match)
        }

        return matches
    }

    private static func htmlTableInlineGapContentMatch(
        from html: String,
        range: NSRange
    ) -> HTMLTableContentMatch? {
        guard let textRange = Range(range, in: html) else { return nil }

        let body = String(html[textRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard htmlTableHasMeaningfulInlineText(body) else { return nil }

        return HTMLTableContentMatch(
            range: range,
            node: ProseMirrorNode(
                type: "paragraph",
                content: NativeEditorDocument.inlineNodes(from: htmlTableInlineAttributedText(from: body))
            )
        )
    }

    private static func htmlTableHasMeaningfulInlineText(_ html: String) -> Bool {
        let withoutTags = htmlTableRegexReplacing(pattern: #"<[^>]+>"#, in: html, with: "")
        return unescapedInlineHTMLText(withoutTags)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
    }

    private static func htmlTableRegexReplacing(
        pattern: String,
        in text: String,
        with replacement: String
    ) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }
}
