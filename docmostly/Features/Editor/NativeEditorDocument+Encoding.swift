import Foundation

extension NativeEditorDocument {
    static func nodes(from blocks: [NativeEditorBlock]) -> [ProseMirrorNode] {
        var result: [ProseMirrorNode] = []
        var index = blocks.startIndex

        while index < blocks.endIndex {
            let encodedGroup = encodedNodeGroup(from: blocks, startingAt: index)
            result.append(encodedGroup.node)
            index = encodedGroup.endIndex
        }

        return result
    }

    static func node(from block: NativeEditorBlock) -> ProseMirrorNode {
        if let editableNode = editableNode(from: block) {
            return editableNode
        }

        if let rawNode = block.rawNode {
            return rawNode
        }

        return richFallbackNode(from: block)
    }

    static func textContainerNode(
        type: String,
        block: NativeEditorBlock,
        attrs: [String: ProseMirrorJSONValue] = [:]
    ) -> ProseMirrorNode {
        var mergedAttrs = attrs
        if let alignment = block.alignment.proseMirrorValue {
            mergedAttrs["textAlign"] = alignment
        }

        return ProseMirrorNode(
            type: type,
            attrs: mergedAttrs.isEmpty ? nil : mergedAttrs,
            content: block.inlineContent.map(inlineNodes(from:)) ?? inlineNodes(from: block.text)
        )
    }

    static func inlineNodes(from attributedText: AttributedString) -> [ProseMirrorNode] {
        var nodes: [ProseMirrorNode] = []

        for run in attributedText.runs {
            nodes.append(contentsOf: inlineNodes(from: run, in: attributedText))
        }

        return nodes
    }

    static func inlineNodes(from inlineContent: [NativeEditorInlineContent]) -> [ProseMirrorNode] {
        inlineContent.map(inlineNode(from:))
    }

    static func proseMirrorMarks(from marks: [NativeEditorTextMark]) -> [ProseMirrorMark]? {
        let proseMirrorMarks = marks.map(proseMirrorMark(from:))
        return proseMirrorMarks.isEmpty ? nil : proseMirrorMarks
    }

    static func optionalAttrs(_ values: [String: String?]) -> [String: ProseMirrorJSONValue]? {
        let attrs = values.reduce(into: [String: ProseMirrorJSONValue]()) { result, item in
            if let value = item.value {
                result[item.key] = .string(value)
            }
        }

        return attrs.isEmpty ? nil : attrs
    }

    private static func encodedNodeGroup(
        from blocks: [NativeEditorBlock],
        startingAt index: Array<NativeEditorBlock>.Index
    ) -> (node: ProseMirrorNode, endIndex: Array<NativeEditorBlock>.Index) {
        let block = blocks[index]

        if let groupedList = encodedListGroup(from: blocks, startingAt: index, block: block) {
            return groupedList
        }

        return (node(from: block), blocks.index(after: index))
    }

    private static func encodedListGroup(
        from blocks: [NativeEditorBlock],
        startingAt index: Array<NativeEditorBlock>.Index,
        block: NativeEditorBlock
    ) -> (node: ProseMirrorNode, endIndex: Array<NativeEditorBlock>.Index)? {
        switch block.kind {
        case .bulletListItem:
            return bulletListGroup(from: blocks, startingAt: index)
        case .orderedListItem(let ordinal):
            return orderedListGroup(from: blocks, startingAt: index, ordinal: ordinal)
        case .taskListItem:
            return taskListGroup(from: blocks, startingAt: index)
        default:
            return nil
        }
    }

    private static func bulletListGroup(
        from blocks: [NativeEditorBlock],
        startingAt index: Array<NativeEditorBlock>.Index
    ) -> (node: ProseMirrorNode, endIndex: Array<NativeEditorBlock>.Index) {
        let grouped = groupedListItems(from: blocks, startingAt: index) { kind in
            if case .bulletListItem = kind { return true }
            return false
        }
        return (ProseMirrorNode(type: "bulletList", content: grouped.items.map(listItemNode)), grouped.endIndex)
    }

    private static func orderedListGroup(
        from blocks: [NativeEditorBlock],
        startingAt index: Array<NativeEditorBlock>.Index,
        ordinal: Int
    ) -> (node: ProseMirrorNode, endIndex: Array<NativeEditorBlock>.Index) {
        let grouped = groupedListItems(from: blocks, startingAt: index) { kind in
            if case .orderedListItem = kind { return true }
            return false
        }
        let node = ProseMirrorNode(
            type: "orderedList",
            attrs: ordinal == 1 ? nil : ["start": .int(ordinal)],
            content: grouped.items.map(listItemNode)
        )

        return (node, grouped.endIndex)
    }

    private static func taskListGroup(
        from blocks: [NativeEditorBlock],
        startingAt index: Array<NativeEditorBlock>.Index
    ) -> (node: ProseMirrorNode, endIndex: Array<NativeEditorBlock>.Index) {
        let grouped = groupedListItems(from: blocks, startingAt: index) { kind in
            if case .taskListItem = kind { return true }
            return false
        }
        return (ProseMirrorNode(type: "taskList", content: grouped.items.map(taskItemNode)), grouped.endIndex)
    }

    private static func groupedListItems(
        from blocks: [NativeEditorBlock],
        startingAt index: Array<NativeEditorBlock>.Index,
        matches: (NativeEditorBlockKind) -> Bool
    ) -> (items: [NativeEditorBlock], endIndex: Array<NativeEditorBlock>.Index) {
        var items: [NativeEditorBlock] = []
        var currentIndex = index

        while currentIndex < blocks.endIndex, matches(blocks[currentIndex].kind) {
            items.append(blocks[currentIndex])
            currentIndex = blocks.index(after: currentIndex)
        }

        return (items, currentIndex)
    }

    private static func editableNode(from block: NativeEditorBlock) -> ProseMirrorNode? {
        switch block.kind {
        case .paragraph:
            textContainerNode(type: "paragraph", block: block)
        case .heading(let level):
            textContainerNode(type: "heading", block: block, attrs: ["level": .int(level)])
        case .blockquote:
            ProseMirrorNode(type: "blockquote", content: [textContainerNode(type: "paragraph", block: block)])
        case .codeBlock(let language):
            codeBlockNode(language: language, block: block)
        case .bulletListItem, .orderedListItem, .taskListItem:
            textContainerNode(type: "paragraph", block: block)
        default:
            nil
        }
    }

    private static func codeBlockNode(language: String?, block: NativeEditorBlock) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "codeBlock",
            attrs: language.map { ["language": .string($0)] },
            content: plainTextNodes(from: String(block.text.characters))
        )
    }

    private static func richFallbackNode(from block: NativeEditorBlock) -> ProseMirrorNode {
        if let mediaNode = mediaFallbackNode(from: block) {
            return mediaNode
        }

        if let structuralNode = structuralFallbackNode(from: block) {
            return structuralNode
        }

        return embeddedFallbackNode(from: block)
    }

    private static func mediaFallbackNode(from block: NativeEditorBlock) -> ProseMirrorNode? {
        switch block.kind {
        case .table:
            ProseMirrorNode(type: "table")
        case .image:
            ProseMirrorNode(type: "image")
        case .video:
            ProseMirrorNode(type: "video")
        case .audio:
            ProseMirrorNode(type: "audio")
        case .pdf:
            ProseMirrorNode(type: "pdf")
        case .attachment:
            ProseMirrorNode(type: "attachment")
        default:
            nil
        }
    }

    private static func structuralFallbackNode(from block: NativeEditorBlock) -> ProseMirrorNode? {
        switch block.kind {
        case .callout:
            ProseMirrorNode(type: "callout", content: [textContainerNode(type: "paragraph", block: block)])
        case .details:
            ProseMirrorNode(type: "details")
        case .pageBreak:
            ProseMirrorNode(type: "pageBreak")
        case .divider:
            ProseMirrorNode(type: "horizontalRule")
        case .columns:
            ProseMirrorNode(type: "columns")
        case .subpages:
            ProseMirrorNode(type: "subpages")
        case .transclusionSource:
            ProseMirrorNode(
                type: "transclusionSource",
                content: [textContainerNode(type: "paragraph", block: block)]
            )
        case .transclusionReference:
            ProseMirrorNode(type: "transclusionReference")
        default:
            nil
        }
    }

    private static func embeddedFallbackNode(from block: NativeEditorBlock) -> ProseMirrorNode {
        switch block.kind {
        case .embed:
            ProseMirrorNode(type: "embed")
        case .drawio:
            ProseMirrorNode(type: "drawio")
        case .excalidraw:
            ProseMirrorNode(type: "excalidraw")
        case .mathBlock:
            ProseMirrorNode(type: "mathBlock")
        case .unsupported:
            textContainerNode(type: "paragraph", block: block)
        default:
            textContainerNode(type: "paragraph", block: block)
        }
    }

    private static func listItemNode(from block: NativeEditorBlock) -> ProseMirrorNode {
        ProseMirrorNode(type: "listItem", content: [textContainerNode(type: "paragraph", block: block)])
    }

    private static func taskItemNode(from block: NativeEditorBlock) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "taskItem",
            attrs: ["checked": .bool(taskItemCheckedState(from: block))],
            content: [textContainerNode(type: "paragraph", block: block)]
        )
    }

    private static func taskItemCheckedState(from block: NativeEditorBlock) -> Bool {
        if case .taskListItem(let isChecked) = block.kind {
            return isChecked
        }

        return false
    }

    private static func inlineNodes(
        from run: AttributedString.Runs.Run,
        in attributedText: AttributedString
    ) -> [ProseMirrorNode] {
        let runText = String(attributedText.characters[run.range])
        let components = runText.split(separator: "\n", omittingEmptySubsequences: false)
        var nodes: [ProseMirrorNode] = []

        for offset in components.indices {
            if offset != components.startIndex {
                nodes.append(ProseMirrorNode(type: "hardBreak"))
            }

            let value = String(components[offset])
            guard value.isEmpty == false else { continue }
            nodes.append(ProseMirrorNode(type: "text", marks: marks(from: run), text: value))
        }

        return nodes
    }

    private static func inlineNode(from item: NativeEditorInlineContent) -> ProseMirrorNode {
        switch item {
        case .text(let text, let marks):
            ProseMirrorNode(type: "text", marks: proseMirrorMarks(from: marks), text: text)
        case .hardBreak:
            ProseMirrorNode(type: "hardBreak")
        case .mention(let mention):
            ProseMirrorNode(type: "mention", attrs: attrs(from: mention))
        case .status(let status):
            ProseMirrorNode(type: "status", attrs: statusAttrs(from: status))
        case .mathInline(let math):
            ProseMirrorNode(type: "mathInline", attrs: ["text": .string(math.text)])
        case .unsupported(let node):
            node
        }
    }

    private static func statusAttrs(from status: NativeEditorStatusBadge) -> [String: ProseMirrorJSONValue] {
        [
            "text": .string(status.text),
            "color": .string(status.color)
        ]
    }

    private static func plainTextNodes(from text: String) -> [ProseMirrorNode] {
        text.isEmpty ? [] : [ProseMirrorNode(type: "text", text: text)]
    }
}
