import Foundation

extension NativeEditorMarkdownParser {
    static func htmlTableBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard isHTMLTableStartLine(lines[index]),
              let htmlTable = htmlTableHTML(in: lines, startingAt: index) else {
            return nil
        }

        let rows = htmlTableRows(from: htmlTable.html)
        guard rows.isEmpty == false else { return nil }

        let table = NativeEditorTable(rows: rows)
        return (
            NativeEditorBlock(
                kind: .table(table),
                text: AttributedString(NativeEditorDocument.previewText(for: .table(table))),
                alignment: .left,
                rawNode: NativeEditorTableNodeFactory.node(from: table)
            ),
            htmlTable.endIndex
        )
    }

    private static func isHTMLTableStartLine(_ line: String) -> Bool {
        if htmlTagAttributes(from: line, tagName: "table") != nil {
            return true
        }

        guard let attrs = htmlTagAttributes(from: line, tagName: "div"),
              let className = attrs["class"] else {
            return false
        }

        return className.split(whereSeparator: \.isWhitespace).contains("tableWrapper")
    }

    private static func htmlTableHTML(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (html: String, endIndex: Array<String>.Index)? {
        let startsWithWrapper = htmlTagAttributes(from: lines[index], tagName: "div")?["class"]?
            .split(whereSeparator: \.isWhitespace)
            .contains("tableWrapper") ?? false
        var tableLines: [String] = []
        var sawTable = false
        var currentIndex = index

        while currentIndex < lines.endIndex {
            let line = lines[currentIndex]
            tableLines.append(line)

            if firstHTMLTagAttributes(in: line, tagName: "table") != nil {
                sawTable = true
            }

            if sawTable, containsHTMLClosingTag(in: line, tagName: "table") {
                var endIndex = lines.index(after: currentIndex)
                if startsWithWrapper,
                   endIndex < lines.endIndex,
                   containsHTMLClosingTag(in: lines[endIndex], tagName: "div") {
                    tableLines.append(lines[endIndex])
                    endIndex = lines.index(after: endIndex)
                }
                return (tableLines.joined(separator: "\n"), endIndex)
            }

            currentIndex = lines.index(after: currentIndex)
        }

        return nil
    }

    private static func htmlTableRows(from html: String) -> [NativeEditorTableRow] {
        htmlTableRowBodies(from: html).compactMap { rowHTML in
            let cells = htmlTableCells(from: rowHTML)
            return cells.isEmpty ? nil : NativeEditorTableRow(cells: cells)
        }
    }

    private static func htmlTableRowBodies(from html: String) -> [String] {
        htmlRegexMatches(pattern: #"<tr\b[^>]*>(.*?)</tr>"#, in: html).compactMap {
            htmlRegexString(match: $0, captureIndex: 1, in: html)
        }
    }

    private static func htmlTableCells(from rowHTML: String) -> [NativeEditorTableCell] {
        htmlRegexMatches(pattern: #"<(th|td)\b([^>]*)>(.*?)</\1>"#, in: rowHTML)
            .prefix(NativeEditorTable.maximumColumnCount)
            .compactMap { match in
                guard let tagName = htmlRegexString(match: match, captureIndex: 1, in: rowHTML),
                      let attributeText = htmlRegexString(match: match, captureIndex: 2, in: rowHTML),
                      let body = htmlRegexString(match: match, captureIndex: 3, in: rowHTML) else {
                    return nil
                }

                return htmlTableCell(tagName: tagName, attributeText: attributeText, body: body)
            }
    }

    private static func htmlTableCell(tagName: String, attributeText: String, body: String) -> NativeEditorTableCell {
        let attrs = docmostInlineHTMLAttributes(from: "<\(tagName)\(attributeText)>")
        let paragraphAttrs = htmlTableParagraphAttributes(in: body)
        let preservedContent = htmlTablePreservedContent(from: body)
        let inlineContent = preservedContent.map(NativeEditorDocument.inlineContent(from:)) ??
            htmlTableInlineContent(from: body)
        let plainText = inlineContent.plainText

        return NativeEditorTableCell(
            plainText: plainText,
            inlineContent: inlineContent.preservedForTableCell,
            preservedContent: preservedContent,
            isHeader: tagName.localizedCaseInsensitiveCompare("th") == .orderedSame,
            textAlignment: htmlTableTextAlignment(from: paragraphAttrs),
            backgroundColor: nonEmptyHTMLTableAttribute(attrs["data-background-color"]) ??
                htmlStyleValue(named: "background-color", in: attrs["style"]),
            backgroundColorName: nonEmptyHTMLTableAttribute(attrs["data-background-color-name"]),
            columnSpan: htmlTableSpan(from: attrs["colspan"]),
            rowSpan: htmlTableSpan(from: attrs["rowspan"]),
            columnWidths: htmlTableColumnWidths(from: attrs)
        )
    }

    private static func htmlTableParagraphAttributes(in html: String) -> [String: String] {
        guard let match = htmlRegexMatches(pattern: #"<p\b([^>]*)>"#, in: html).first,
              let attributeText = htmlRegexString(match: match, captureIndex: 1, in: html) else {
            return [:]
        }

        return docmostInlineHTMLAttributes(from: "<p\(attributeText)>")
    }

    private static func htmlTableTextAlignment(from attrs: [String: String]) -> NativeEditorTextAlignment? {
        let value = nonEmptyHTMLTableAttribute(attrs["align"]) ??
            htmlStyleValue(named: "text-align", in: attrs["style"])
        guard let value else { return nil }
        return NativeEditorTextAlignment(rawValue: value.lowercased())
    }

    private static func htmlTablePreservedContent(
        from html: String,
        dropsSinglePlainParagraph: Bool = true
    ) -> [ProseMirrorNode]? {
        let structuralMatches = htmlTableStructuralContentMatches(from: html, excluding: [])
        let structuralRanges = structuralMatches.map(\.range)
        let calloutMatches = htmlTableCalloutContentMatches(from: html, excluding: structuralRanges)
        let calloutRanges = calloutMatches.map(\.range)
        let listMatches = htmlTableListContentMatches(from: html, excluding: structuralRanges + calloutRanges)
        let containerRanges = structuralRanges + calloutRanges + listMatches.map(\.range)
        let textBlockMatches = htmlRegexMatches(pattern: #"<(p|h[1-6])\b([^>]*)>(.*?)</\1>"#, in: html)
            .compactMap { match -> HTMLTableContentMatch? in
                guard htmlTableRange(match.range, isNestedIn: containerRanges) == false else {
                    return nil
                }
                guard let tagName = htmlRegexString(match: match, captureIndex: 1, in: html),
                      let attributeText = htmlRegexString(match: match, captureIndex: 2, in: html),
                      let body = htmlRegexString(match: match, captureIndex: 3, in: html) else {
                    return nil
                }

                return HTMLTableContentMatch(
                    range: match.range,
                    node: htmlTableContentNode(tagName: tagName, attributeText: attributeText, body: body)
                )
            }
        let codeBlockMatches = htmlRegexMatches(
            pattern: #"<pre\b([^>]*)>\s*<code\b([^>]*)>(.*?)</code>\s*</pre>"#,
            in: html
        )
        .compactMap { match -> HTMLTableContentMatch? in
            guard htmlTableRange(match.range, isNestedIn: containerRanges) == false else {
                return nil
            }
            guard let preAttributeText = htmlRegexString(match: match, captureIndex: 1, in: html),
                  let codeAttributeText = htmlRegexString(match: match, captureIndex: 2, in: html),
                  let body = htmlRegexString(match: match, captureIndex: 3, in: html) else {
                return nil
            }

            return HTMLTableContentMatch(
                range: match.range,
                node: htmlTableCodeBlockNode(
                    preAttributeText: preAttributeText,
                    codeAttributeText: codeAttributeText,
                    body: body
                )
            )
        }
        let mediaMatches = htmlTableMediaContentMatches(from: html, excluding: containerRanges)
        let nodes = (
            textBlockMatches + codeBlockMatches + mediaMatches + listMatches + calloutMatches + structuralMatches
        )
            .sorted { $0.range.location < $1.range.location }
            .map(\.node)

        guard nodes.isEmpty == false else { return nil }
        if dropsSinglePlainParagraph,
           nodes.count == 1,
           nodes.first?.type == "paragraph",
           nodes.first?.attrs?.isEmpty != false {
            return nil
        }
        return nodes
    }

    private static func htmlTableCalloutContentMatches(
        from html: String,
        excluding excludedRanges: [NSRange]
    ) -> [HTMLTableContentMatch] {
        htmlRegexMatches(pattern: #"<div\b([^>]*)>(.*?)</div>"#, in: html)
            .compactMap { match -> HTMLTableContentMatch? in
                guard htmlTableRange(match.range, isNestedIn: excludedRanges) == false,
                      let attributeText = htmlRegexString(match: match, captureIndex: 1, in: html),
                      let body = htmlRegexString(match: match, captureIndex: 2, in: html) else {
                    return nil
                }

                let attrs = docmostInlineHTMLAttributes(from: "<div\(attributeText)>")
                guard attrs["data-type"]?.compare("callout", options: .caseInsensitive) == .orderedSame else {
                    return nil
                }

                return HTMLTableContentMatch(
                    range: match.range,
                    node: htmlTableCalloutNode(attrs: attrs, body: body)
                )
            }
    }

    private static func htmlTableListContentMatches(
        from html: String,
        excluding excludedRanges: [NSRange]
    ) -> [HTMLTableContentMatch] {
        htmlRegexMatches(pattern: #"<(ul|ol)\b([^>]*)>(.*?)</\1>"#, in: html)
            .compactMap { match -> HTMLTableContentMatch? in
                guard htmlTableRange(match.range, isNestedIn: excludedRanges) == false else {
                    return nil
                }
                guard let tagName = htmlRegexString(match: match, captureIndex: 1, in: html),
                      let attributeText = htmlRegexString(match: match, captureIndex: 2, in: html),
                      let body = htmlRegexString(match: match, captureIndex: 3, in: html) else {
                    return nil
                }

                return HTMLTableContentMatch(
                    range: match.range,
                    node: htmlTableListNode(tagName: tagName, attributeText: attributeText, body: body)
                )
            }
    }

    static func htmlTableRange(_ range: NSRange, isNestedIn ranges: [NSRange]) -> Bool {
        ranges.contains { container in
            range.location > container.location && NSMaxRange(range) <= NSMaxRange(container)
        }
    }

    private static func htmlTableContentNode(
        tagName: String,
        attributeText: String,
        body: String
    ) -> ProseMirrorNode {
        let attrs = docmostInlineHTMLAttributes(from: "<\(tagName)\(attributeText)>")
        let content = NativeEditorDocument.inlineNodes(from: inlineText(from: htmlTableInlineMarkdown(from: body)))

        if let headingLevel = htmlTableHeadingLevel(from: tagName) {
            return ProseMirrorNode(
                type: "heading",
                attrs: htmlTableContentAttrs(baseAttrs: ["level": .int(headingLevel)], htmlAttrs: attrs),
                content: content
            )
        }

        return ProseMirrorNode(
            type: "paragraph",
            attrs: htmlTableContentAttrs(baseAttrs: [:], htmlAttrs: attrs),
            content: content
        )
    }

    private static func htmlTableCalloutNode(
        attrs: [String: String],
        body: String
    ) -> ProseMirrorNode {
        var nodeAttrs: [String: ProseMirrorJSONValue] = [
            "type": .string(htmlTableSanitizedCalloutStyle(attrs["data-callout-type"] ?? "info"))
        ]
        if let icon = nonEmptyHTMLTableAttribute(attrs["data-callout-icon"]) {
            nodeAttrs["icon"] = .string(icon)
        }

        return ProseMirrorNode(
            type: "callout",
            attrs: nodeAttrs,
            content: htmlTableContainerContent(from: body)
        )
    }

    private static func htmlTableContainerContent(from html: String) -> [ProseMirrorNode] {
        if let preservedContent = htmlTablePreservedContent(from: html, dropsSinglePlainParagraph: false) {
            return preservedContent
        }

        return [
            ProseMirrorNode(
                type: "paragraph",
                content: NativeEditorDocument.inlineNodes(from: inlineText(from: htmlTableInlineMarkdown(from: html)))
            )
        ]
    }

    private static func htmlTableSanitizedCalloutStyle(_ value: String) -> String {
        let sanitizedScalars = value.lowercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }
        let sanitized = String(String.UnicodeScalarView(sanitizedScalars))
        return sanitized.isEmpty ? "info" : sanitized
    }

    private static func htmlTableListNode(
        tagName: String,
        attributeText: String,
        body: String
    ) -> ProseMirrorNode {
        let attrs = docmostInlineHTMLAttributes(from: "<\(tagName)\(attributeText)>")
        let isOrderedList = htmlTagNameMatches(tagName, "ol")
        let isTaskList = isOrderedList == false &&
            attrs["data-type"]?.compare("taskList", options: .caseInsensitive) == .orderedSame
        let nodeType = isOrderedList ? "orderedList" : (isTaskList ? "taskList" : "bulletList")
        var nodeAttrs = [String: ProseMirrorJSONValue]()

        if isOrderedList, let start = Int(attrs["start"] ?? ""), start != 1 {
            nodeAttrs["start"] = .int(start)
        }

        return ProseMirrorNode(
            type: nodeType,
            attrs: nodeAttrs.isEmpty ? nil : nodeAttrs,
            content: htmlTableListItems(from: body, itemType: isTaskList ? "taskItem" : "listItem")
        )
    }

    private static func htmlTableListItems(from html: String, itemType: String) -> [ProseMirrorNode] {
        htmlRegexMatches(pattern: #"<li\b([^>]*)>(.*?)</li>"#, in: html).compactMap { match in
            guard let attributeText = htmlRegexString(match: match, captureIndex: 1, in: html),
                  let body = htmlRegexString(match: match, captureIndex: 2, in: html) else {
                return nil
            }

            return htmlTableListItemNode(itemType: itemType, attributeText: attributeText, body: body)
        }
    }

    private static func htmlTableListItemNode(
        itemType: String,
        attributeText: String,
        body: String
    ) -> ProseMirrorNode {
        var attrs = [String: ProseMirrorJSONValue]()
        if itemType == "taskItem" {
            attrs["checked"] = .bool(htmlTableTaskItemIsChecked(attributeText: attributeText, body: body))
        }

        return ProseMirrorNode(
            type: itemType,
            attrs: attrs.isEmpty ? nil : attrs,
            content: htmlTableListItemContent(from: body)
        )
    }

    private static func htmlTableListItemContent(from html: String) -> [ProseMirrorNode] {
        htmlTableContainerContent(from: html)
    }

    private static func htmlTableTaskItemIsChecked(attributeText: String, body: String) -> Bool {
        let attrs = docmostInlineHTMLAttributes(from: "<li\(attributeText)>")
        if let value = attrs["data-checked"] ?? attrs["checked"] ?? attrs["aria-checked"] {
            return htmlTableBooleanAttributeIsTruthy(value)
        }

        return htmlRegexMatches(pattern: #"<input\b[^>]*\bchecked(?:\s*=\s*['"]?(?:checked|true|1)['"]?)?"#, in: body)
            .isEmpty == false
    }

    private static func htmlTableBooleanAttributeIsTruthy(_ value: String) -> Bool {
        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedValue == "" ||
            normalizedValue == "true" ||
            normalizedValue == "checked" ||
            normalizedValue == "1"
    }

    private static func htmlTableCodeBlockNode(
        preAttributeText: String,
        codeAttributeText: String,
        body: String
    ) -> ProseMirrorNode {
        let preAttrs = docmostInlineHTMLAttributes(from: "<pre\(preAttributeText)>")
        let codeAttrs = docmostInlineHTMLAttributes(from: "<code\(codeAttributeText)>")
        var attrs = [String: ProseMirrorJSONValue]()

        if let language = htmlTableCodeBlockLanguage(codeAttrs: codeAttrs, preAttrs: preAttrs) {
            attrs["language"] = .string(language)
        }

        let text = unescapedInlineHTMLText(body)
        return ProseMirrorNode(
            type: "codeBlock",
            attrs: attrs.isEmpty ? nil : attrs,
            content: text.isEmpty ? [] : [ProseMirrorNode(type: "text", text: text)]
        )
    }

    private static func htmlTableCodeBlockLanguage(
        codeAttrs: [String: String],
        preAttrs: [String: String]
    ) -> String? {
        nonEmptyHTMLTableAttribute(codeAttrs["data-language"]) ??
            nonEmptyHTMLTableAttribute(codeAttrs["language"]) ??
            htmlTableCodeBlockLanguage(fromClassName: codeAttrs["class"]) ??
            nonEmptyHTMLTableAttribute(preAttrs["data-language"]) ??
            nonEmptyHTMLTableAttribute(preAttrs["language"]) ??
            htmlTableCodeBlockLanguage(fromClassName: preAttrs["class"])
    }

    private static func htmlTableCodeBlockLanguage(fromClassName className: String?) -> String? {
        guard let className else { return nil }

        for component in className.split(whereSeparator: \.isWhitespace) {
            let lowercasedComponent = component.lowercased()
            if lowercasedComponent.hasPrefix("language-") {
                return nonEmptyHTMLTableAttribute(String(component.dropFirst("language-".count)))
            }
            if lowercasedComponent.hasPrefix("lang-") {
                return nonEmptyHTMLTableAttribute(String(component.dropFirst("lang-".count)))
            }
        }

        return nil
    }

    private static func htmlTableHeadingLevel(from tagName: String) -> Int? {
        guard tagName.count == 2,
              tagName.first?.lowercased() == "h",
              let level = Int(tagName.suffix(1)) else {
            return nil
        }
        return min(max(level, 1), 6)
    }

    private static func htmlTableContentAttrs(
        baseAttrs: [String: ProseMirrorJSONValue],
        htmlAttrs: [String: String]
    ) -> [String: ProseMirrorJSONValue]? {
        var attrs = baseAttrs
        if let textAlignment = htmlTableTextAlignment(from: htmlAttrs) {
            attrs["textAlign"] = .string(textAlignment.rawValue)
        }
        return attrs.isEmpty ? nil : attrs
    }

    private static func htmlTableInlineContent(from html: String) -> [NativeEditorInlineContent] {
        let inlineMarkdown = htmlTableInlineMarkdown(from: html)
        let attributedText = inlineText(from: inlineMarkdown)
        return NativeEditorDocument.inlineContent(from: NativeEditorDocument.inlineNodes(from: attributedText))
    }

    private static func htmlTableInlineMarkdown(from html: String) -> String {
        let paragraphSeparated = htmlRegexReplacing(
            pattern: #"</p>\s*<p\b[^>]*>"#,
            in: html,
            with: "\n"
        )
        let hardBreakSeparated = htmlRegexReplacing(
            pattern: #"<br\s*/?>"#,
            in: paragraphSeparated,
            with: "\n"
        )
        let withoutOpeningParagraphs = htmlRegexReplacing(
            pattern: #"<p\b[^>]*>"#,
            in: hardBreakSeparated,
            with: ""
        )
        return htmlRegexReplacing(pattern: #"</p>"#, in: withoutOpeningParagraphs, with: "")
    }

    private static func htmlTableSpan(from value: String?) -> Int {
        max(Int(value ?? "") ?? 1, 1)
    }

    private static func htmlTableColumnWidths(from attrs: [String: String]) -> [Int] {
        guard let value = nonEmptyHTMLTableAttribute(attrs["colwidth"] ?? attrs["data-colwidth"]) else {
            return []
        }

        return value.split { character in
            character == "," || character.isWhitespace
        }
        .compactMap { Int($0) }
    }

    private static func htmlStyleValue(named name: String, in style: String?) -> String? {
        guard let style else { return nil }
        let normalizedName = name.lowercased()

        for declaration in style.split(separator: ";") {
            let parts = declaration.split(separator: ":", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2, parts[0].lowercased() == normalizedName else {
                continue
            }

            return parts[1].isEmpty ? nil : parts[1]
        }

        return nil
    }

    static func htmlRegexMatches(pattern: String, in text: String) -> [NSTextCheckingResult] {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return []
        }

        return expression.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text))
    }

    static func htmlRegexString(
        match: NSTextCheckingResult,
        captureIndex: Int,
        in text: String
    ) -> String? {
        let range = match.range(at: captureIndex)
        guard range.location != NSNotFound,
              let textRange = Range(range, in: text) else {
            return nil
        }

        return String(text[textRange])
    }

    private static func htmlRegexReplacing(pattern: String, in text: String, with replacement: String) -> String {
        guard let expression = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    static func nonEmptyHTMLTableAttribute(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else { return nil }
        return value
    }
}

struct HTMLTableContentMatch {
    var range: NSRange
    var node: ProseMirrorNode
}
