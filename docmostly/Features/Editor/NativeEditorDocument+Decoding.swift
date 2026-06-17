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

        if node.isListContainer {
            return listBlocks(from: node, indentLevel: 0)
        }

        return nil
    }

    private static func listBlocks(from node: ProseMirrorNode, indentLevel: Int) -> [NativeEditorBlock] {
        switch node.type {
        case "bulletList":
            return bulletListBlocks(from: node, indentLevel: indentLevel)
        case "orderedList":
            return orderedListBlocks(from: node, indentLevel: indentLevel)
        case "taskList":
            return taskListBlocks(from: node, indentLevel: indentLevel)
        default:
            return []
        }
    }

    private static func bulletListBlocks(from node: ProseMirrorNode, indentLevel: Int) -> [NativeEditorBlock] {
        (node.content ?? []).flatMap { listItem in
            listItemBlocks(kind: .bulletListItem, item: listItem, indentLevel: indentLevel)
        }
    }

    private static func orderedListBlocks(from node: ProseMirrorNode, indentLevel: Int) -> [NativeEditorBlock] {
        let start = node.attrs?["start"]?.intValue ?? 1
        return (node.content ?? []).enumerated().flatMap { offset, listItem in
            listItemBlocks(
                kind: .orderedListItem(ordinal: start + offset),
                item: listItem,
                indentLevel: indentLevel
            )
        }
    }

    private static func taskListBlocks(from node: ProseMirrorNode, indentLevel: Int) -> [NativeEditorBlock] {
        (node.content ?? []).flatMap { taskItem in
            listItemBlocks(
                kind: .taskListItem(isChecked: taskItem.attrs?["checked"]?.boolValue ?? false),
                item: taskItem,
                indentLevel: indentLevel
            )
        }
    }

    private static func listItemBlocks(
        kind: NativeEditorBlockKind,
        item: ProseMirrorNode,
        indentLevel: Int
    ) -> [NativeEditorBlock] {
        var block = textBlock(kind: kind, node: firstTextContainer(in: item) ?? item)
        block.indentLevel = indentLevel

        let nestedBlocks: [NativeEditorBlock] = (item.content ?? []).flatMap { child in
            if child.isListContainer {
                listBlocks(from: child, indentLevel: indentLevel + 1)
            } else {
                [NativeEditorBlock]()
            }
        }

        return [block] + nestedBlocks
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
