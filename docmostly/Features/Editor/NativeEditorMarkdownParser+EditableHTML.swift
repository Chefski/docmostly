import Foundation

extension NativeEditorMarkdownParser {
    static func editableHTMLMarkdown(from block: NativeEditorBlock) -> String? {
        guard let tagName = editableHTMLTagName(from: block),
              let attrs = editableHTMLAttributes(from: block) else {
            return nil
        }

        let attrText = attrs.map { name, value in
            #"\#(name)="\#(escapedInlineHTMLAttribute(value))""#
        }
        .joined(separator: " ")
        let body = editableHTMLBody(from: block.text)

        return "<\(tagName) \(attrText)>\(body)</\(tagName)>"
    }

    private struct EditableHTMLMatch {
        var tagName: String
        var attrs: [String: String]
        var body: String
    }

    static func editableHTMLBlock(from line: String) -> NativeEditorBlock? {
        guard let match = editableHTMLMatch(from: line) else { return nil }

        let text = inlineText(from: match.body)
        let rawNode = editableHTMLNode(tagName: match.tagName, attrs: match.attrs, text: text)
        return NativeEditorBlock(
            kind: editableHTMLBlockKind(from: match.tagName),
            text: text,
            alignment: NativeEditorTextAlignment(attrs: rawNode.attrs),
            indentLevel: editableHTMLIndentLevel(from: rawNode.attrs),
            rawNode: rawNode
        )
    }

    private static func editableHTMLMatch(from line: String) -> EditableHTMLMatch? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = htmlRegexMatches(pattern: #"^<(p|h[1-6])\b([^>]*)>(.*?)</\1>\s*$"#, in: trimmedLine)
        guard let match = matches.first,
              match.range == NSRange(trimmedLine.startIndex..<trimmedLine.endIndex, in: trimmedLine),
              let tagName = htmlRegexString(match: match, captureIndex: 1, in: trimmedLine),
              let attributeText = htmlRegexString(match: match, captureIndex: 2, in: trimmedLine),
              let body = htmlRegexString(match: match, captureIndex: 3, in: trimmedLine) else {
            return nil
        }

        return EditableHTMLMatch(
            tagName: tagName.lowercased(),
            attrs: docmostInlineHTMLAttributes(from: "<\(tagName)\(attributeText)>"),
            body: body
        )
    }

    private static func editableHTMLNode(
        tagName: String,
        attrs htmlAttrs: [String: String],
        text: AttributedString
    ) -> ProseMirrorNode {
        let kind = editableHTMLBlockKind(from: tagName)
        let content = NativeEditorDocument.inlineNodes(from: text)
        let attrs = editableHTMLNodeAttrs(kind: kind, htmlAttrs: htmlAttrs)

        return ProseMirrorNode(
            type: editableHTMLNodeType(from: kind),
            attrs: attrs.isEmpty ? nil : attrs,
            content: content
        )
    }

    private static func editableHTMLNodeAttrs(
        kind: NativeEditorBlockKind,
        htmlAttrs: [String: String]
    ) -> [String: ProseMirrorJSONValue] {
        var attrs = [String: ProseMirrorJSONValue]()

        if case .heading(let level) = kind {
            attrs["level"] = .int(level)
        }
        if let id = editableHTMLNonEmptyValue(htmlAttrs["id"]) {
            attrs["id"] = .string(id)
        }
        if let indent = editableHTMLIndent(from: htmlAttrs), indent > 0 {
            attrs["indent"] = .int(indent)
        }
        if let alignment = editableHTMLAlignment(from: htmlAttrs), alignment != .left {
            attrs["textAlign"] = .string(alignment.rawValue)
        }

        return attrs
    }

    private static func editableHTMLBlockKind(from tagName: String) -> NativeEditorBlockKind {
        guard tagName.hasPrefix("h"),
              let level = Int(tagName.dropFirst()) else {
            return .paragraph
        }

        return .heading(level: min(max(level, 1), 6))
    }

    private static func editableHTMLNodeType(from kind: NativeEditorBlockKind) -> String {
        if case .heading = kind {
            return "heading"
        }
        return "paragraph"
    }

    private static func editableHTMLTagName(from block: NativeEditorBlock) -> String? {
        switch block.kind {
        case .heading(let level):
            "h\(min(max(level, 1), 6))"
        case .paragraph:
            "p"
        default:
            nil
        }
    }

    private static func editableHTMLAttributes(from block: NativeEditorBlock) -> [(String, String)]? {
        var attrs: [(String, String)] = []
        let rawAttrs = block.rawNode?.attrs

        if let id = rawAttrs?["id"]?.stringValue, id.isEmpty == false {
            attrs.append(("id", id))
        }
        let indent = min(max(block.indentLevel, 0), 8)
        if indent > 0 {
            attrs.append(("data-indent", String(indent)))
        }
        if block.alignment != .left {
            attrs.append(("style", "text-align: \(block.alignment.rawValue)"))
        }

        return attrs.isEmpty ? nil : attrs
    }

    private static func editableHTMLIndent(from attrs: [String: String]) -> Int? {
        guard let value = attrs["data-indent"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              let indent = Int(value) else {
            return nil
        }

        return min(max(indent, 0), 8)
    }

    private static func editableHTMLIndentLevel(from attrs: [String: ProseMirrorJSONValue]?) -> Int {
        min(max(attrs?["indent"]?.intValue ?? 0, 0), 8)
    }

    private static func editableHTMLAlignment(from attrs: [String: String]) -> NativeEditorTextAlignment? {
        let value = editableHTMLNonEmptyValue(attrs["align"]) ??
            editableHTMLStyleValue(named: "text-align", in: attrs["style"])
        guard let value else { return nil }

        return NativeEditorTextAlignment(rawValue: value.lowercased())
    }

    private static func editableHTMLStyleValue(named name: String, in style: String?) -> String? {
        guard let style else { return nil }
        let normalizedName = name.lowercased()

        for declaration in style.split(separator: ";") {
            let parts = declaration.split(separator: ":", maxSplits: 1).map {
                String($0).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2, parts[0].lowercased() == normalizedName else {
                continue
            }

            return editableHTMLNonEmptyValue(parts[1])
        }

        return nil
    }

    private static func editableHTMLBody(from text: AttributedString) -> String {
        text.runs.reduce(into: "") { output, run in
            let runText = String(text[run.range].characters)
            output += editableHTMLRunBody(from: run, text: runText)
        }
    }

    private static func editableHTMLRunBody(
        from run: AttributedString.Runs.Run,
        text: String
    ) -> String {
        let body: String
        if let status = run[NativeEditorStatusAttribute.self] {
            body = statusMarkdown(from: status)
        } else if let mention = run[NativeEditorMentionAttribute.self] {
            body = editableHTMLMention(from: mention, fallbackText: text)
        } else if let math = run[NativeEditorMathInlineAttribute.self] {
            body = "$\(escapedInlineHTMLText(math.text.replacing("$", with: "\\$")))$"
        } else {
            body = editableHTMLMarkedBody(from: run, text: text)
        }

        return commentMarkdown(from: run.nativeEditorInlineComments, body: body)
    }

    private static func editableHTMLMarkedBody(
        from run: AttributedString.Runs.Run,
        text: String
    ) -> String {
        var body = escapedInlineHTMLText(text)
        let intent = run.inlinePresentationIntent ?? []

        if intent.contains(.code) {
            body = "<code>\(body)</code>"
        } else {
            if intent.contains(.stronglyEmphasized) {
                body = "<strong>\(body)</strong>"
            }
            if intent.contains(.emphasized) {
                body = "<em>\(body)</em>"
            }
            if intent.contains(.strikethrough) {
                body = "<s>\(body)</s>"
            }
        }

        if let link = run[NativeEditorLinkAttribute.self] {
            body = editableHTMLAnchor(from: link, body: body)
        } else if let href = run.link?.absoluteString {
            body = editableHTMLAnchor(from: NativeEditorLink(href: href, isInternal: false), body: body)
        }

        body = scriptUnderlineMarkdown(from: run, body: body)
        body = textColorMarkdown(from: run, body: body)
        return highlightMarkdown(from: run, body: body)
    }

    private static func editableHTMLAnchor(from link: NativeEditorLink, body: String) -> String {
        let internalAttr = link.isInternal ? #" data-internal="true""# : ""
        let href = escapedInlineHTMLAttribute(link.href)
        return #"<a href="\#(href)"\#(internalAttr)>\#(body)</a>"#
    }

    private static func editableHTMLMention(from mention: NativeEditorMention, fallbackText: String) -> String {
        let attrs: [(String, String?)] = [
            ("data-type", "mention"),
            ("data-id", mention.identifier),
            ("data-label", mention.label),
            ("data-entity-type", mention.entityType),
            ("data-entity-id", mention.entityID),
            ("data-slug-id", mention.slugID),
            ("data-creator-id", mention.creatorID),
            ("data-anchor-id", mention.anchorID)
        ]
        let attrText = attrs.compactMap { name, value in
            editableHTMLNonEmptyValue(value).map { #"\#(name)="\#(escapedInlineHTMLAttribute($0))""# }
        }
        .joined(separator: " ")
        let displayText = editableHTMLMentionDisplayText(from: mention, fallbackText: fallbackText)

        return "<span \(attrText)>\(escapedInlineHTMLText(displayText))</span>"
    }

    private static func editableHTMLMentionDisplayText(
        from mention: NativeEditorMention,
        fallbackText: String
    ) -> String {
        if mention.entityType == "user" {
            let label = mention.label ?? editableHTMLNonEmptyValue(editableHTMLRemovingMentionTrigger(fallbackText)) ??
                mention.entityID ?? mention.identifier ?? "Mention"
            return "@\(label)"
        }

        return mention.label ?? editableHTMLNonEmptyValue(fallbackText) ??
            mention.entityID ?? mention.identifier ?? "Mention"
    }

    private static func editableHTMLNonEmptyValue(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func editableHTMLRemovingMentionTrigger(_ value: String) -> String {
        value.hasPrefix("@") ? String(value.dropFirst()) : value
    }
}
