import SwiftUI

nonisolated extension NativeEditorDocument {
    static func inlineContent(from node: ProseMirrorNode) -> [NativeEditorInlineContent] {
        switch node.type {
        case "text":
            [.text(node.text ?? "", marks: textMarks(from: node.marks ?? []))]
        case "hardBreak":
            [.hardBreak]
        case "mention":
            [.mention(mention(from: node), marks: textMarks(from: node.marks ?? []))]
        case "status":
            [.status(statusBadge(from: node), marks: textMarks(from: node.marks ?? []))]
        case "mathInline":
            [.mathInline(
                NativeEditorMathInline(text: node.attrs?["text"]?.stringValue ?? ""),
                marks: textMarks(from: node.marks ?? [])
            )]
        default:
            nestedInlineContent(from: node)
        }
    }

    static func nestedInlineContent(from node: ProseMirrorNode) -> [NativeEditorInlineContent] {
        guard let children = node.content, children.isEmpty == false else {
            return [.unsupported(node)]
        }

        return inlineContent(from: children)
    }

    static func attributedText(from item: NativeEditorInlineContent) -> AttributedString {
        switch item {
        case .text(let value, let marks):
            var segment = AttributedString(value)
            apply(marks, to: &segment)
            return segment
        case .hardBreak:
            return AttributedString("\n")
        case .mention(let mention, let marks):
            var segment = AttributedString(mention.displayText)
            segment[NativeEditorMentionAttribute.self] = mention
            segment.foregroundColor = DocmostlyTheme.primary
            apply(marks, to: &segment)
            return segment
        case .status(let status, let marks):
            var segment = AttributedString(status.text)
            segment[NativeEditorStatusAttribute.self] = status
            apply(marks, to: &segment)
            return segment
        case .mathInline(let math, let marks):
            var segment = AttributedString(math.text)
            segment[NativeEditorMathInlineAttribute.self] = math
            segment.inlinePresentationIntent = .code
            apply(marks, to: &segment)
            return segment
        case .unsupported(let node):
            return AttributedString(node.text ?? "")
        }
    }

    static func textMarks(from marks: [ProseMirrorMark]) -> [NativeEditorTextMark] {
        marks.map(textMark(from:))
    }

    static func textMark(from mark: ProseMirrorMark) -> NativeEditorTextMark {
        if let simpleMark = simpleTextMark(from: mark) {
            return simpleMark
        }

        return richTextMark(from: mark)
    }

    static func simpleTextMark(from mark: ProseMirrorMark) -> NativeEditorTextMark? {
        switch mark.type {
        case "bold":
            .bold
        case "italic":
            .italic
        case "underline":
            .underline
        case "strike":
            .strikethrough
        case "code":
            .code
        case "subscript":
            .subscript
        case "superscript":
            .superscript
        default:
            nil
        }
    }

    static func richTextMark(from mark: ProseMirrorMark) -> NativeEditorTextMark {
        switch mark.type {
        case "link":
            .link(
                href: mark.attrs?["href"]?.stringValue ?? "",
                isInternal: mark.attrs?["internal"]?.boolValue ?? false
            )
        case "highlight":
            .highlight(
                color: mark.attrs?["color"]?.stringValue,
                colorName: mark.attrs?["colorName"]?.stringValue
            )
        case "textStyle":
            colorTextMark(from: mark)
        case "comment":
            .comment(
                commentID: mark.attrs?["commentId"]?.stringValue ?? "",
                isResolved: mark.attrs?["resolved"]?.boolValue ?? false
            )
        default:
            .unknown(mark)
        }
    }

    static func colorTextMark(from mark: ProseMirrorMark) -> NativeEditorTextMark {
        if let color = mark.attrs?["color"]?.stringValue {
            .textColor(color)
        } else {
            .unknown(mark)
        }
    }
}

nonisolated extension NativeEditorDocument {
    static func apply(_ marks: [NativeEditorTextMark], to text: inout AttributedString) {
        for mark in marks {
            if applyPresentationMark(mark, to: &text) {
                continue
            }

            applyVisualMark(mark, to: &text)
        }
    }

    static func applyPresentationMark(_ mark: NativeEditorTextMark, to text: inout AttributedString) -> Bool {
        switch mark {
        case .bold:
            insertPresentationIntent(.stronglyEmphasized, into: &text)
        case .italic:
            insertPresentationIntent(.emphasized, into: &text)
        case .strikethrough:
            insertPresentationIntent(.strikethrough, into: &text)
        case .code:
            insertPresentationIntent(.code, into: &text)
        default:
            return false
        }

        return true
    }

    static func applyVisualMark(_ mark: NativeEditorTextMark, to text: inout AttributedString) {
        switch mark {
        case .underline:
            text.underlineStyle = .single
        case .link(let href, let isInternal):
            applyLinkMark(href: href, isInternal: isInternal, to: &text)
        case .highlight(let color, let colorName):
            if let color {
                text[NativeEditorHighlightColorAttribute.self] = color
            }
            if let colorName {
                text[NativeEditorHighlightColorNameAttribute.self] = colorName
            }
            applyBackgroundColor(color, to: &text)
        case .textColor(let color):
            text[NativeEditorTextColorAttribute.self] = color
            applyForegroundColor(color, to: &text)
        case .subscript:
            text.baselineOffset = -4
        case .superscript:
            text.baselineOffset = 4
        case .comment(let commentID, let isResolved):
            text.addNativeEditorInlineComment(NativeEditorInlineCommentMark(
                commentID: commentID,
                isResolved: isResolved
            ))
            text.backgroundColor = text.nativeEditorInlineComments.contains { $0.isResolved == false }
                ? .yellow.opacity(0.28)
                : .gray.opacity(0.16)
        case .bold, .italic, .strikethrough, .code, .unknown:
            return
        }
    }

    static func applyLinkMark(href: String, isInternal: Bool, to text: inout AttributedString) {
        guard let link = preservedLink(href: href, isInternal: isInternal) else { return }
        text[NativeEditorLinkAttribute.self] = link
        text.link = safeLinkURL(from: href)
    }

    static func safeLinkURL(from href: String) -> URL? {
        guard let url = URL(string: href) else { return nil }
        let allowedSchemes = ["https", "http", "mailto"]
        guard let scheme = url.scheme?.lowercased() else { return nil }
        return allowedSchemes.contains(scheme) ? url : nil
    }

    static func preservedLink(href: String, isInternal: Bool = false) -> NativeEditorLink? {
        guard href.isEmpty == false else { return nil }

        if safeLinkURL(from: href) != nil || href.hasPrefix("/") || href.hasPrefix("#") {
            return NativeEditorLink(href: href, isInternal: isInternal)
        }

        return nil
    }

    static func insertPresentationIntent(
        _ presentationIntent: InlinePresentationIntent,
        into text: inout AttributedString
    ) {
        var intent = text.inlinePresentationIntent ?? []
        intent.insert(presentationIntent)
        text.inlinePresentationIntent = intent
    }

    static func applyBackgroundColor(_ color: String?, to text: inout AttributedString) {
        if let color, let swiftUIColor = Color(docmostlyHex: color) {
            text.backgroundColor = swiftUIColor
        }
    }

    static func applyForegroundColor(_ color: String, to text: inout AttributedString) {
        if let swiftUIColor = Color(docmostlyHex: color) {
            text.foregroundColor = swiftUIColor
        }
    }
}
