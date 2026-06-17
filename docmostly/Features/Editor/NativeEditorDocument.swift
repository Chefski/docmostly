import Foundation

struct NativeEditorDocument: Equatable {
    var blocks: [NativeEditorBlock]

    init(blocks: [NativeEditorBlock] = [Self.emptyBlock()]) {
        self.blocks = blocks.isEmpty ? [Self.emptyBlock()] : blocks
    }

    init(proseMirrorJSONData data: Data) throws {
        let document = try JSONDecoder().decode(ProseMirrorDocument.self, from: data)
        self.init(proseMirrorDocument: document)
    }

    init(proseMirrorDocument: ProseMirrorDocument) {
        let decodedBlocks = proseMirrorDocument.content.flatMap(Self.blocks(from:))
        blocks = decodedBlocks.isEmpty ? [Self.emptyBlock()] : decodedBlocks
    }

    var proseMirrorDocument: ProseMirrorDocument {
        ProseMirrorDocument(content: Self.nodes(from: blocks))
    }

    func proseMirrorJSONData() throws -> Data {
        try JSONEncoder().encode(proseMirrorDocument)
    }

    private static func emptyBlock() -> NativeEditorBlock {
        NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
    }
}

private extension NativeEditorDocument {
    private static func blocks(from node: ProseMirrorNode) -> [NativeEditorBlock] {
        switch node.type {
        case "paragraph":
            [textBlock(kind: .paragraph, node: node)]
        case "heading":
            [textBlock(kind: .heading(level: node.attrs?["level"]?.intValue ?? 1), node: node)]
        case "blockquote":
            [textBlock(kind: .blockquote, node: firstTextContainer(in: node) ?? node)]
        case "codeBlock":
            [NativeEditorBlock(
                kind: .codeBlock(language: node.attrs?["language"]?.stringValue),
                text: AttributedString(plainText(in: node.content ?? [])),
                alignment: .left
            )]
        case "bulletList":
            (node.content ?? []).map { listItem in
                textBlock(kind: .bulletListItem, node: firstTextContainer(in: listItem) ?? listItem)
            }
        case "orderedList":
            orderedListBlocks(from: node)
        case "taskList":
            (node.content ?? []).map { taskItem in
                textBlock(
                    kind: .taskListItem(isChecked: taskItem.attrs?["checked"]?.boolValue ?? false),
                    node: firstTextContainer(in: taskItem) ?? taskItem
                )
            }
        default:
            [NativeEditorBlock(
                kind: .unsupported(type: node.type),
                text: AttributedString("Unsupported \(node.type) block"),
                alignment: .left,
                rawNode: node
            )]
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

    private static func textBlock(kind: NativeEditorBlockKind, node: ProseMirrorNode) -> NativeEditorBlock {
        NativeEditorBlock(
            kind: kind,
            text: attributedText(from: node.content ?? []),
            alignment: NativeEditorTextAlignment(attrs: node.attrs)
        )
    }

    private static func firstTextContainer(in node: ProseMirrorNode) -> ProseMirrorNode? {
        node.content?.first { child in
            child.type == "paragraph" || child.type == "heading" || child.type == "codeBlock"
        }
    }

    private static func attributedText(from nodes: [ProseMirrorNode]) -> AttributedString {
        var text = AttributedString("")

        for node in nodes {
            switch node.type {
            case "text":
                var segment = AttributedString(node.text ?? "")
                apply(node.marks ?? [], to: &segment)
                text += segment
            case "hardBreak":
                text += AttributedString("\n")
            default:
                text += attributedText(from: node.content ?? [])
            }
        }

        return text
    }

    private static func apply(_ marks: [ProseMirrorMark], to text: inout AttributedString) {
        for mark in marks {
            switch mark.type {
            case "bold":
                var intent = text.inlinePresentationIntent ?? []
                intent.insert(.stronglyEmphasized)
                text.inlinePresentationIntent = intent
            case "italic":
                var intent = text.inlinePresentationIntent ?? []
                intent.insert(.emphasized)
                text.inlinePresentationIntent = intent
            case "strike":
                var intent = text.inlinePresentationIntent ?? []
                intent.insert(.strikethrough)
                text.inlinePresentationIntent = intent
            case "code":
                var intent = text.inlinePresentationIntent ?? []
                intent.insert(.code)
                text.inlinePresentationIntent = intent
            case "link":
                if let href = mark.attrs?["href"]?.stringValue {
                    text.link = URL(string: href)
                }
            default:
                continue
            }
        }
    }

    private static func plainText(in nodes: [ProseMirrorNode]) -> String {
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
}

private extension NativeEditorDocument {
    private static func nodes(from blocks: [NativeEditorBlock]) -> [ProseMirrorNode] {
        var result: [ProseMirrorNode] = []
        var index = blocks.startIndex

        while index < blocks.endIndex {
            let block = blocks[index]

            switch block.kind {
            case .bulletListItem:
                let grouped = groupedListItems(from: blocks, startingAt: index) { kind in
                    if case .bulletListItem = kind { return true }
                    return false
                }
                result.append(ProseMirrorNode(type: "bulletList", content: grouped.items.map(listItemNode)))
                index = grouped.endIndex
            case .orderedListItem(let ordinal):
                let grouped = groupedListItems(from: blocks, startingAt: index) { kind in
                    if case .orderedListItem = kind { return true }
                    return false
                }
                result.append(ProseMirrorNode(
                    type: "orderedList",
                    attrs: ordinal == 1 ? nil : ["start": .int(ordinal)],
                    content: grouped.items.map(listItemNode)
                ))
                index = grouped.endIndex
            case .taskListItem:
                let grouped = groupedListItems(from: blocks, startingAt: index) { kind in
                    if case .taskListItem = kind { return true }
                    return false
                }
                result.append(ProseMirrorNode(type: "taskList", content: grouped.items.map(taskItemNode)))
                index = grouped.endIndex
            default:
                result.append(node(from: block))
                index = blocks.index(after: index)
            }
        }

        return result
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

    private static func node(from block: NativeEditorBlock) -> ProseMirrorNode {
        switch block.kind {
        case .paragraph:
            textContainerNode(type: "paragraph", block: block)
        case .heading(let level):
            textContainerNode(type: "heading", block: block, attrs: ["level": .int(level)])
        case .blockquote:
            ProseMirrorNode(type: "blockquote", content: [textContainerNode(type: "paragraph", block: block)])
        case .codeBlock(let language):
            ProseMirrorNode(
                type: "codeBlock",
                attrs: language.map { ["language": .string($0)] },
                content: plainTextNodes(from: String(block.text.characters))
            )
        case .unsupported:
            block.rawNode ?? textContainerNode(type: "paragraph", block: block)
        case .bulletListItem, .orderedListItem, .taskListItem:
            textContainerNode(type: "paragraph", block: block)
        }
    }

    private static func listItemNode(from block: NativeEditorBlock) -> ProseMirrorNode {
        ProseMirrorNode(type: "listItem", content: [textContainerNode(type: "paragraph", block: block)])
    }

    private static func taskItemNode(from block: NativeEditorBlock) -> ProseMirrorNode {
        let checked: Bool
        if case .taskListItem(let isChecked) = block.kind {
            checked = isChecked
        } else {
            checked = false
        }

        return ProseMirrorNode(
            type: "taskItem",
            attrs: ["checked": .bool(checked)],
            content: [textContainerNode(type: "paragraph", block: block)]
        )
    }

    private static func textContainerNode(
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
            content: inlineNodes(from: block.text)
        )
    }

    private static func inlineNodes(from attributedText: AttributedString) -> [ProseMirrorNode] {
        var nodes: [ProseMirrorNode] = []

        for run in attributedText.runs {
            let runText = String(attributedText.characters[run.range])
            let components = runText.split(separator: "\n", omittingEmptySubsequences: false)

            for offset in components.indices {
                if offset != components.startIndex {
                    nodes.append(ProseMirrorNode(type: "hardBreak"))
                }

                let value = String(components[offset])
                guard value.isEmpty == false else { continue }
                nodes.append(ProseMirrorNode(type: "text", marks: marks(from: run), text: value))
            }
        }

        return nodes
    }

    private static func plainTextNodes(from text: String) -> [ProseMirrorNode] {
        text.isEmpty ? [] : [ProseMirrorNode(type: "text", text: text)]
    }

    private static func marks(from run: AttributedString.Runs.Run) -> [ProseMirrorMark]? {
        var marks: [ProseMirrorMark] = []
        let intent = run.inlinePresentationIntent ?? []

        if intent.contains(.stronglyEmphasized) {
            marks.append(ProseMirrorMark(type: "bold"))
        }

        if intent.contains(.emphasized) {
            marks.append(ProseMirrorMark(type: "italic"))
        }

        if intent.contains(.strikethrough) {
            marks.append(ProseMirrorMark(type: "strike"))
        }

        if intent.contains(.code) {
            marks.append(ProseMirrorMark(type: "code"))
        }

        if let href = run.link?.absoluteString {
            marks.append(ProseMirrorMark(type: "link", attrs: ["href": .string(href)]))
        }

        return marks.isEmpty ? nil : marks
    }
}
