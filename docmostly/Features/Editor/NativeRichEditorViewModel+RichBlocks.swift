import Foundation

extension NativeRichEditorViewModel {
    func updateCallout(blockID: UUID, style: String, icon: String?, text: String) {
        updateRichBlock(blockID: blockID) { block in
            let trimmedIcon = icon?.trimmingCharacters(in: .whitespacesAndNewlines)
            let callout = NativeEditorCalloutBlock(
                style: style.isEmpty ? "info" : style,
                icon: trimmedIcon?.isEmpty == false ? trimmedIcon : nil,
                previewText: text
            )
            block.kind = .callout(callout)
            block.text = AttributedString(text)
            block.rawNode = NativeEditorRichBlockNodeFactory.calloutNode(from: callout)
        }
    }

    func updateDetails(blockID: UUID, summary: String, body: String, isOpen: Bool) {
        updateRichBlock(blockID: blockID) { block in
            let details = NativeEditorDetailsBlock(summary: summary, previewText: body, isOpen: isOpen)
            block.kind = .details(details)
            block.text = AttributedString(summary)
            block.rawNode = NativeEditorRichBlockNodeFactory.detailsNode(from: details)
        }
    }

    func updateEmbed(blockID: UUID, source: String, provider: String) {
        updateRichBlock(blockID: blockID) { block in
            guard case .embed(let currentEmbed) = block.kind else { return }

            let embed = NativeEditorEmbedBlock(
                source: source.trimmingCharacters(in: .whitespacesAndNewlines),
                provider: provider.trimmingCharacters(in: .whitespacesAndNewlines),
                alignment: currentEmbed.alignment,
                width: currentEmbed.width,
                height: currentEmbed.height
            )
            block.kind = .embed(embed)
            block.text = AttributedString(embed.source ?? "")
            block.rawNode = NativeEditorRichBlockNodeFactory.embedNode(from: embed)
        }
    }

    func updateDrawio(blockID: UUID, source: String, title: String, alternativeText: String) {
        updateDiagram(blockID: blockID, source: source, title: title, alternativeText: alternativeText) { diagram in
            .drawio(diagram)
        }
    }

    func updateExcalidraw(blockID: UUID, source: String, title: String, alternativeText: String) {
        updateDiagram(blockID: blockID, source: source, title: title, alternativeText: alternativeText) { diagram in
            .excalidraw(diagram)
        }
    }

    func updateMathBlock(blockID: UUID, text: String) {
        updateRichBlock(blockID: blockID) { block in
            let math = NativeEditorMathBlock(text: text)
            block.kind = .mathBlock(math)
            block.text = AttributedString(text)
            block.rawNode = NativeEditorRichBlockNodeFactory.mathBlockNode(from: math)
        }
    }

    private func updateDiagram(
        blockID: UUID,
        source: String,
        title: String,
        alternativeText: String,
        kind: (NativeEditorDiagramBlock) -> NativeEditorBlockKind
    ) {
        updateRichBlock(blockID: blockID) { block in
            guard let currentDiagram = block.kind.diagramBlock else { return }
            let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedAlternativeText = alternativeText.trimmingCharacters(in: .whitespacesAndNewlines)

            let diagram = NativeEditorDiagramBlock(
                source: trimmedSource.isEmpty ? nil : trimmedSource,
                title: trimmedTitle.isEmpty ? nil : trimmedTitle,
                alternativeText: trimmedAlternativeText.isEmpty ? nil : trimmedAlternativeText,
                attachmentID: currentDiagram.attachmentID,
                sizeInBytes: currentDiagram.sizeInBytes,
                width: currentDiagram.width,
                height: currentDiagram.height,
                aspectRatio: currentDiagram.aspectRatio,
                alignment: currentDiagram.alignment
            )
            block.kind = kind(diagram)
            block.text = AttributedString(diagram.title ?? diagram.source ?? "")
            block.rawNode = NativeEditorRichBlockNodeFactory.diagramNode(from: diagram, type: block.kind.nodeType)
        }
    }

    private func updateRichBlock(blockID: UUID, edit: (inout NativeEditorBlock) -> Void) {
        performUndoableEdit {
            guard let index = document.blocks.firstIndex(where: { $0.id == blockID }) else {
                return
            }

            edit(&document.blocks[index])
        }
    }
}

private extension NativeEditorBlockKind {
    var diagramBlock: NativeEditorDiagramBlock? {
        switch self {
        case .drawio(let diagram), .excalidraw(let diagram):
            diagram
        default:
            nil
        }
    }

    var nodeType: String {
        switch self {
        case .drawio:
            "drawio"
        case .excalidraw:
            "excalidraw"
        default:
            "paragraph"
        }
    }
}

private enum NativeEditorRichBlockNodeFactory {
    static func calloutNode(from callout: NativeEditorCalloutBlock) -> ProseMirrorNode {
        var attrs: [String: ProseMirrorJSONValue] = ["type": .string(callout.style)]
        if let icon = callout.icon {
            attrs["icon"] = .string(icon)
        }

        return ProseMirrorNode(
            type: "callout",
            attrs: attrs,
            content: [paragraphNode(callout.previewText)]
        )
    }

    static func detailsNode(from details: NativeEditorDetailsBlock) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "details",
            attrs: ["open": .bool(details.isOpen)],
            content: [
                ProseMirrorNode(
                    type: "detailsSummary",
                    content: NativeEditorDocument.inlineNodes(from: AttributedString(details.summary))
                ),
                ProseMirrorNode(
                    type: "detailsContent",
                    content: [paragraphNode(details.previewText)]
                )
            ]
        )
    }

    static func embedNode(from embed: NativeEditorEmbedBlock) -> ProseMirrorNode {
        var attrs: [String: ProseMirrorJSONValue] = [
            "src": .string(embed.source ?? ""),
            "provider": .string(embed.provider ?? "")
        ]
        if let alignment = embed.alignment {
            attrs["align"] = .string(alignment)
        }
        if let width = embed.width.flatMap(Int.init) {
            attrs["width"] = .int(width)
        }
        if let height = embed.height.flatMap(Int.init) {
            attrs["height"] = .int(height)
        }

        return ProseMirrorNode(type: "embed", attrs: attrs)
    }

    static func mathBlockNode(from math: NativeEditorMathBlock) -> ProseMirrorNode {
        ProseMirrorNode(type: "mathBlock", attrs: ["text": .string(math.text)])
    }

    static func diagramNode(from diagram: NativeEditorDiagramBlock, type: String) -> ProseMirrorNode {
        var attrs = [String: ProseMirrorJSONValue]()
        if let source = diagram.source, source.isEmpty == false {
            attrs["src"] = .string(source)
        }
        if let title = diagram.title, title.isEmpty == false {
            attrs["title"] = .string(title)
        }
        if let alternativeText = diagram.alternativeText, alternativeText.isEmpty == false {
            attrs["alt"] = .string(alternativeText)
        }
        if let attachmentID = diagram.attachmentID {
            attrs["attachmentId"] = .string(attachmentID)
        }
        if let sizeInBytes = diagram.sizeInBytes {
            attrs["size"] = .int(sizeInBytes)
        }
        if let width = diagram.width.flatMap(Int.init) {
            attrs["width"] = .int(width)
        }
        if let height = diagram.height.flatMap(Int.init) {
            attrs["height"] = .int(height)
        }
        if let aspectRatio = diagram.aspectRatio.flatMap(Double.init) {
            attrs["aspectRatio"] = .double(aspectRatio)
        }
        if let alignment = diagram.alignment {
            attrs["align"] = .string(alignment)
        }

        return ProseMirrorNode(type: type, attrs: attrs.isEmpty ? nil : attrs)
    }

    private static func paragraphNode(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "paragraph",
            content: NativeEditorDocument.inlineNodes(from: AttributedString(text))
        )
    }
}
