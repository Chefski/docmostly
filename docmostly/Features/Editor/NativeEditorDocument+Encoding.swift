import Foundation

nonisolated extension NativeEditorDocument {
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
        guard listKind(for: block.kind) != nil else { return nil }
        return encodedList(from: blocks, startingAt: index)
    }

    private static func encodedList(
        from blocks: [NativeEditorBlock],
        startingAt index: Array<NativeEditorBlock>.Index
    ) -> (node: ProseMirrorNode, endIndex: Array<NativeEditorBlock>.Index) {
        let baseBlock = blocks[index]
        let baseIndentLevel = baseBlock.indentLevel
        let baseKind = listKind(for: baseBlock.kind) ?? .bullet
        var itemNodes: [ProseMirrorNode] = []
        var currentIndex = index

        while currentIndex < blocks.endIndex {
            let block = blocks[currentIndex]
            guard let currentKind = listKind(for: block.kind), block.indentLevel >= baseIndentLevel else {
                break
            }

            if block.indentLevel > baseIndentLevel {
                let nested = encodedList(from: blocks, startingAt: currentIndex)
                append(nested.node, toLastItemIn: &itemNodes)
                currentIndex = nested.endIndex
                continue
            }

            guard currentKind == baseKind else { break }
            itemNodes.append(listItemNode(for: block))
            currentIndex = blocks.index(after: currentIndex)
        }

        let node = ProseMirrorNode(
            type: baseKind.nodeType,
            attrs: baseKind.attrs(from: baseBlock),
            content: itemNodes
        )
        return (node, currentIndex)
    }

    private static func append(_ nestedList: ProseMirrorNode, toLastItemIn itemNodes: inout [ProseMirrorNode]) {
        guard var lastItem = itemNodes.popLast() else { return }
        var content = lastItem.content ?? []
        content.append(nestedList)
        lastItem.content = content
        itemNodes.append(lastItem)
    }

    private static func listItemNode(for block: NativeEditorBlock) -> ProseMirrorNode {
        if case .taskListItem = block.kind {
            return taskItemNode(from: block)
        }

        return listItemNode(from: block)
    }

    private static func listKind(for kind: NativeEditorBlockKind) -> NativeEditorListKind? {
        switch kind {
        case .bulletListItem:
            .bullet
        case .orderedListItem:
            .ordered
        case .taskListItem:
            .task
        default:
            nil
        }
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
        case .table(let table):
            NativeEditorTableNodeFactory.node(from: table)
        case .image(let media):
            NativeEditorRichBlockNodeFactory.mediaNode(from: media, type: "image")
        case .video(let media):
            NativeEditorRichBlockNodeFactory.mediaNode(from: media, type: "video")
        case .audio(let media):
            NativeEditorRichBlockNodeFactory.mediaNode(from: media, type: "audio")
        case .pdf(let pdf):
            NativeEditorRichBlockNodeFactory.pdfNode(from: pdf)
        case .attachment(let attachment):
            NativeEditorRichBlockNodeFactory.attachmentNode(from: attachment)
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
        case .columns(let columns):
            NativeEditorRichBlockNodeFactory.columnsNode(from: columns)
        case .subpages:
            ProseMirrorNode(type: "subpages")
        case .transclusionSource(let source):
            NativeEditorRichBlockNodeFactory.transclusionSourceNode(from: source)
        case .transclusionReference(let reference):
            NativeEditorRichBlockNodeFactory.transclusionReferenceNode(from: reference)
        case .base(let base):
            NativeEditorRichBlockNodeFactory.baseNode(from: base)
        default:
            nil
        }
    }

    private static func embeddedFallbackNode(from block: NativeEditorBlock) -> ProseMirrorNode {
        switch block.kind {
        case .embed(let embed):
            NativeEditorRichBlockNodeFactory.embedNode(from: embed)
        case .drawio(let diagram):
            NativeEditorRichBlockNodeFactory.diagramNode(from: diagram, type: "drawio")
        case .excalidraw(let diagram):
            NativeEditorRichBlockNodeFactory.diagramNode(from: diagram, type: "excalidraw")
        case .mathBlock(let math):
            NativeEditorRichBlockNodeFactory.mathBlockNode(from: math)
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

        if let atom = inlineAtom(from: run) {
            return inlineNodes(from: atom, runText: runText, run: run)
        }

        return textNodes(from: runText, marks: marks(from: run))
    }

    private struct InlineAtomEncoding {
        var displayText: String
        var node: ProseMirrorNode
        var presentationMarkType: String?

        init(
            displayText: String,
            node: ProseMirrorNode,
            presentationMarkType: String? = nil
        ) {
            self.displayText = displayText
            self.node = node
            self.presentationMarkType = presentationMarkType
        }
    }

    private static func inlineNodes(
        from atom: InlineAtomEncoding,
        runText: String,
        run: AttributedString.Runs.Run
    ) -> [ProseMirrorNode] {
        guard
            runText != atom.displayText,
            atom.displayText.isEmpty == false,
            let atomRange = runText.range(of: atom.displayText)
        else {
            return [atom.node]
        }

        let prefix = String(runText[..<atomRange.lowerBound])
        let suffix = String(runText[atomRange.upperBound...])
        let textMarks = marksForTextSurroundingAtom(from: run, atom: atom)
        return textNodes(from: prefix, marks: textMarks) +
            [atom.node] +
            textNodes(from: suffix, marks: textMarks)
    }

    private static func textNodes(from text: String, marks: [ProseMirrorMark]?) -> [ProseMirrorNode] {
        let components = text.split(separator: "\n", omittingEmptySubsequences: false)
        var nodes: [ProseMirrorNode] = []

        for offset in components.indices {
            if offset != components.startIndex {
                nodes.append(ProseMirrorNode(type: "hardBreak"))
            }

            let value = String(components[offset])
            guard value.isEmpty == false else { continue }
            nodes.append(ProseMirrorNode(type: "text", marks: marks, text: value))
        }

        return nodes
    }

    private static func inlineAtom(from run: AttributedString.Runs.Run) -> InlineAtomEncoding? {
        if let mention = run[NativeEditorMentionAttribute.self] {
            return InlineAtomEncoding(
                displayText: mention.displayText,
                node: ProseMirrorNode(type: "mention", attrs: attrs(from: mention))
            )
        }

        if let status = run[NativeEditorStatusAttribute.self] {
            return InlineAtomEncoding(
                displayText: status.text,
                node: ProseMirrorNode(type: "status", attrs: statusAttrs(from: status)),
                presentationMarkType: "bold"
            )
        }

        if let math = run[NativeEditorMathInlineAttribute.self] {
            return InlineAtomEncoding(
                displayText: math.text,
                node: ProseMirrorNode(type: "mathInline", attrs: ["text": .string(math.text)]),
                presentationMarkType: "code"
            )
        }

        return nil
    }

    private static func marksForTextSurroundingAtom(
        from run: AttributedString.Runs.Run,
        atom: InlineAtomEncoding
    ) -> [ProseMirrorMark]? {
        guard var marks = marks(from: run) else { return nil }

        if let presentationMarkType = atom.presentationMarkType {
            marks.removeAll { $0.type == presentationMarkType }
        }

        return marks.isEmpty ? nil : marks
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
