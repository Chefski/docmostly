import SwiftUI

extension NativeEditorDocument {
    static func blocks(from node: ProseMirrorNode) -> [NativeEditorBlock] {
        if let editableBlocks = editableBlocks(from: node) {
            return editableBlocks
        }

        if let richBlock = richBlock(from: node) {
            return [richBlock]
        }

        return [unsupportedBlock(from: node)]
    }

    static func textBlock(kind: NativeEditorBlockKind, node: ProseMirrorNode) -> NativeEditorBlock {
        let inlineContent = inlineContent(from: node.content ?? [])
        let needsRawPreservation = inlineContent.contains(where: \.requiresRawPreservation)

        return NativeEditorBlock(
            kind: kind,
            text: attributedText(from: inlineContent),
            alignment: NativeEditorTextAlignment(attrs: node.attrs),
            inlineContent: needsRawPreservation ? inlineContent : nil,
            rawNode: needsRawPreservation ? node : nil
        )
    }

    static func firstTextContainer(in node: ProseMirrorNode) -> ProseMirrorNode? {
        node.content?.first { child in
            child.type == "paragraph" || child.type == "heading" || child.type == "codeBlock"
        }
    }

    static func inlineContent(from nodes: [ProseMirrorNode]) -> [NativeEditorInlineContent] {
        var content: [NativeEditorInlineContent] = []

        for node in nodes {
            content.append(contentsOf: inlineContent(from: node))
        }

        return content
    }

    static func attributedText(from inlineContent: [NativeEditorInlineContent]) -> AttributedString {
        inlineContent.reduce(into: AttributedString("")) { result, item in
            result += attributedText(from: item)
        }
    }

    static func plainText(in nodes: [ProseMirrorNode]) -> String {
        nodes.reduce(into: "") { result, node in
            if node.type == "text" {
                result += node.text ?? ""
            } else if node.type == "hardBreak" {
                result += "\n"
            } else {
                result += plainText(in: node.content ?? [])
            }
        }
    }

    private static func editableBlocks(from node: ProseMirrorNode) -> [NativeEditorBlock]? {
        if let singleBlock = singleEditableBlock(from: node) {
            return [singleBlock]
        }

        if node.type == "bulletList" {
            return (node.content ?? []).map { listItem in
                textBlock(kind: .bulletListItem, node: firstTextContainer(in: listItem) ?? listItem)
            }
        }

        if node.type == "orderedList" {
            return orderedListBlocks(from: node)
        }

        if node.type == "taskList" {
            return (node.content ?? []).map { taskItem in
                textBlock(
                    kind: .taskListItem(isChecked: taskItem.attrs?["checked"]?.boolValue ?? false),
                    node: firstTextContainer(in: taskItem) ?? taskItem
                )
            }
        }

        return nil
    }

    private static func singleEditableBlock(from node: ProseMirrorNode) -> NativeEditorBlock? {
        switch node.type {
        case "paragraph":
            textBlock(kind: .paragraph, node: node)
        case "heading":
            textBlock(kind: .heading(level: node.attrs?["level"]?.intValue ?? 1), node: node)
        case "blockquote":
            textBlock(kind: .blockquote, node: firstTextContainer(in: node) ?? node)
        case "codeBlock":
            NativeEditorBlock(
                kind: .codeBlock(language: node.attrs?["language"]?.stringValue),
                text: AttributedString(plainText(in: node.content ?? [])),
                alignment: .left
            )
        default:
            nil
        }
    }

    private static func orderedListBlocks(from node: ProseMirrorNode) -> [NativeEditorBlock] {
        let start = node.attrs?["start"]?.intValue ?? 1
        return (node.content ?? []).enumerated().map { offset, listItem in
            textBlock(
                kind: .orderedListItem(ordinal: start + offset),
                node: firstTextContainer(in: listItem) ?? listItem
            )
        }
    }

    private static func richBlock(from node: ProseMirrorNode) -> NativeEditorBlock? {
        if let mediaBlock = mediaRichBlock(from: node) {
            return mediaBlock
        }

        if let structuralBlock = structuralRichBlock(from: node) {
            return structuralBlock
        }

        return embeddedRichBlock(from: node)
    }

    private static func mediaRichBlock(from node: ProseMirrorNode) -> NativeEditorBlock? {
        switch node.type {
        case "table":
            richBlock(kind: .table(table(from: node)), node: node)
        case "image":
            richBlock(kind: .image(mediaBlock(from: node)), node: node)
        case "video":
            richBlock(kind: .video(mediaBlock(from: node)), node: node)
        case "audio":
            richBlock(kind: .audio(mediaBlock(from: node)), node: node)
        case "pdf":
            richBlock(kind: .pdf(pdfBlock(from: node)), node: node)
        case "attachment":
            richBlock(kind: .attachment(attachmentBlock(from: node)), node: node)
        default:
            nil
        }
    }

    private static func structuralRichBlock(from node: ProseMirrorNode) -> NativeEditorBlock? {
        switch node.type {
        case "callout":
            richBlock(kind: .callout(calloutBlock(from: node)), node: node)
        case "details":
            richBlock(kind: .details(detailsBlock(from: node)), node: node)
        case "pageBreak":
            richBlock(kind: .pageBreak, node: node)
        case "horizontalRule":
            richBlock(kind: .divider, node: node)
        case "columns":
            richBlock(kind: .columns(columnsBlock(from: node)), node: node)
        case "subpages":
            richBlock(kind: .subpages, node: node)
        case "transclusionSource":
            richBlock(kind: .transclusionSource(transclusionSourceBlock(from: node)), node: node)
        case "transclusionReference":
            richBlock(kind: .transclusionReference(transclusionReferenceBlock(from: node)), node: node)
        default:
            nil
        }
    }

    private static func embeddedRichBlock(from node: ProseMirrorNode) -> NativeEditorBlock? {
        switch node.type {
        case "embed", "youtube":
            richBlock(kind: .embed(embedBlock(from: node)), node: node)
        case "drawio":
            richBlock(kind: .drawio(diagramBlock(from: node)), node: node)
        case "excalidraw":
            richBlock(kind: .excalidraw(diagramBlock(from: node)), node: node)
        case "mathBlock":
            richBlock(kind: .mathBlock(mathBlock(from: node)), node: node)
        default:
            nil
        }
    }

    private static func richBlock(kind: NativeEditorBlockKind, node: ProseMirrorNode) -> NativeEditorBlock {
        NativeEditorBlock(
            kind: kind,
            text: AttributedString(previewText(for: kind)),
            alignment: .left,
            rawNode: node
        )
    }

    private static func unsupportedBlock(from node: ProseMirrorNode) -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .unsupported(type: node.type),
            text: AttributedString("Unsupported \(node.type) block"),
            alignment: .left,
            rawNode: node
        )
    }
}

private extension NativeEditorDocument {
    static func inlineContent(from node: ProseMirrorNode) -> [NativeEditorInlineContent] {
        switch node.type {
        case "text":
            [.text(node.text ?? "", marks: textMarks(from: node.marks ?? []))]
        case "hardBreak":
            [.hardBreak]
        case "mention":
            [.mention(mention(from: node))]
        case "status":
            [.status(statusBadge(from: node))]
        case "mathInline":
            [.mathInline(NativeEditorMathInline(text: node.attrs?["text"]?.stringValue ?? ""))]
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
        case .mention(let mention):
            var segment = AttributedString(mention.displayText)
            segment.foregroundColor = DocmostlyTheme.primary
            return segment
        case .status(let status):
            return AttributedString(status.text)
        case .mathInline(let math):
            var segment = AttributedString(math.text)
            segment.inlinePresentationIntent = .code
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
            .link(href: mark.attrs?["href"]?.stringValue ?? "")
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
        case .link(let href):
            text.link = URL(string: href)
        case .highlight(let color, _):
            applyBackgroundColor(color, to: &text)
        case .textColor(let color):
            applyForegroundColor(color, to: &text)
        case .subscript:
            text.baselineOffset = -4
        case .superscript:
            text.baselineOffset = 4
        case .comment:
            text.backgroundColor = .yellow.opacity(0.28)
        case .bold, .italic, .strikethrough, .code, .unknown:
            return
        }
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
