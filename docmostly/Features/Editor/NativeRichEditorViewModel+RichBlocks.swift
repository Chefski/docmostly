import Foundation

extension NativeRichEditorViewModel {
    func updateCallout(blockID: UUID, style: String, icon: String?, text: String) {
        updateRichBlock(blockID: blockID) { block in
            let trimmedIcon = icon?.trimmingCharacters(in: .whitespacesAndNewlines)
            var node = block.rawNode?.type == "callout" ? block.rawNode ?? ProseMirrorNode(type: "callout") :
                ProseMirrorNode(type: "callout")
            var attrs = node.attrs ?? [:]
            attrs["type"] = .string(style.isEmpty ? "info" : style)
            if let trimmedIcon, trimmedIcon.isEmpty == false {
                attrs["icon"] = .string(trimmedIcon)
            } else {
                attrs.removeValue(forKey: "icon")
            }
            node.attrs = attrs

            let currentText = NativeEditorDocument.plainText(in: node.content ?? [])
            if currentText != text {
                node.content = Self.replacingPlainBlockContent(node.content, with: text)
            }

            let callout = NativeEditorDocument.calloutBlock(from: node)
            block.kind = .callout(callout)
            block.text = AttributedString(callout.previewText)
            block.rawNode = node
        }
    }

    func updateDetails(blockID: UUID, summary: String, body: String, isOpen: Bool) {
        updateRichBlock(blockID: blockID) { block in
            var node = block.rawNode?.type == "details" ? block.rawNode ?? ProseMirrorNode(type: "details") :
                ProseMirrorNode(type: "details")
            var attrs = node.attrs ?? [:]
            attrs["open"] = .bool(isOpen)
            node.attrs = attrs

            var content = node.content ?? []
            if let summaryIndex = content.firstIndex(where: { $0.type == "detailsSummary" }) {
                let currentSummary = NativeEditorDocument.plainText(in: content[summaryIndex].content ?? [])
                if currentSummary != summary {
                    content[summaryIndex].content = Self.replacingPlainInlineContent(
                        content[summaryIndex].content,
                        with: summary
                    )
                }
            } else {
                content.insert(Self.detailsSummaryNode(summary), at: 0)
            }

            if let detailsIndex = content.firstIndex(where: { $0.type == "detailsContent" }) {
                let currentBody = NativeEditorDocument.plainText(in: content[detailsIndex].content ?? [])
                if currentBody != body {
                    content[detailsIndex].content = Self.replacingPlainBlockContent(
                        content[detailsIndex].content,
                        with: body
                    )
                }
            } else {
                content.append(Self.detailsContentNode(body))
            }
            node.content = content

            let details = NativeEditorDocument.detailsBlock(from: node)
            block.kind = .details(details)
            block.text = AttributedString(details.summary)
            block.rawNode = node
        }
    }

    func updateColumns(blockID: UUID, layout: String, widthMode: String, columnTexts: [String]) {
        updateRichBlock(blockID: blockID) { block in
            let normalizedColumnTexts = Self.normalizedColumnTexts(columnTexts)
            var node = block.rawNode?.type == "columns" ? block.rawNode ?? ProseMirrorNode(type: "columns") :
                ProseMirrorNode(type: "columns")
            var attrs = node.attrs ?? [:]
            attrs["layout"] = .string(
                layout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "two_equal" : layout
            )
            attrs["widthMode"] = .string(Self.normalizedColumnsWidthMode(widthMode))
            node.attrs = attrs

            let existingColumns = (node.content ?? []).filter { $0.type == "column" }
            node.content = normalizedColumnTexts.enumerated().map { index, text in
                guard existingColumns.indices.contains(index) else {
                    return Self.columnNode(text: text, width: nil)
                }

                var column = existingColumns[index]
                let currentText = NativeEditorDocument.plainText(in: column.content ?? [])
                if currentText != text {
                    column.content = Self.replacingPlainBlockContent(column.content, with: text)
                }
                return column
            }

            let columns = NativeEditorDocument.columnsBlock(from: node)
            block.kind = .columns(columns)
            block.text = AttributedString(columns.previewText)
            block.rawNode = node
        }
    }

    func updateTransclusionSource(blockID: UUID, identifier: String, text: String) {
        updateRichBlock(blockID: blockID) { block in
            let trimmedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
            var node = block.rawNode?.type == "transclusionSource" ?
                block.rawNode ?? ProseMirrorNode(type: "transclusionSource") :
                ProseMirrorNode(type: "transclusionSource")
            var attrs = node.attrs ?? [:]
            if trimmedIdentifier.isEmpty {
                attrs.removeValue(forKey: "id")
            } else {
                attrs["id"] = .string(trimmedIdentifier)
            }
            node.attrs = attrs.isEmpty ? nil : attrs

            let currentText = NativeEditorDocument.plainText(in: node.content ?? [])
            if currentText != text {
                node.content = Self.replacingPlainBlockContent(node.content, with: text)
            }

            let source = NativeEditorDocument.transclusionSourceBlock(from: node)
            block.kind = .transclusionSource(source)
            block.text = AttributedString(source.previewText)
            block.rawNode = node
        }
    }

    func updateTransclusionReference(blockID: UUID, sourcePageID: String, transclusionID: String) {
        updateRichBlock(blockID: blockID) { block in
            let trimmedSourcePageID = sourcePageID.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedTransclusionID = transclusionID.trimmingCharacters(in: .whitespacesAndNewlines)
            let reference = NativeEditorTransclusionReferenceBlock(
                sourcePageID: trimmedSourcePageID.isEmpty ? nil : trimmedSourcePageID,
                transclusionID: trimmedTransclusionID.isEmpty ? nil : trimmedTransclusionID
            )
            block.kind = .transclusionReference(reference)
            block.text = AttributedString(reference.transclusionID ?? reference.sourcePageID ?? "")
            block.rawNode = NativeEditorRichBlockNodeFactory.transclusionReferenceNode(from: reference)
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

    func updateRichBlock(blockID: UUID, edit: (inout NativeEditorBlock) -> Void) {
        performUndoableEdit {
            guard let index = document.blocks.firstIndex(where: { $0.id == blockID }) else {
                return
            }

            edit(&document.blocks[index])
        }
    }

    private static func normalizedColumnTexts(_ columnTexts: [String]) -> [String] {
        let limitedTexts = Array(columnTexts.prefix(NativeEditorColumnsBlock.maximumColumnCount))
        return limitedTexts.isEmpty ? [""] : limitedTexts
    }

    private static func normalizedColumnsWidthMode(_ widthMode: String) -> String {
        let trimmedWidthMode = widthMode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard NativeEditorColumnsBlock.supportedWidthModes.contains(trimmedWidthMode) else {
            return NativeEditorColumnsBlock.defaultWidthMode
        }
        return trimmedWidthMode
    }

    private static func replacingPlainBlockContent(
        _ existingContent: [ProseMirrorNode]?,
        with text: String
    ) -> [ProseMirrorNode] {
        guard plainBlockContentCanBeReplaced(existingContent) else {
            return existingContent ?? []
        }

        if let existingContent,
           existingContent.count == 1,
           var paragraph = existingContent.first {
            paragraph.content = NativeEditorDocument.inlineNodes(from: AttributedString(text))
            return [paragraph]
        }

        return [paragraphNode(text)]
    }

    private static func replacingPlainInlineContent(
        _ existingContent: [ProseMirrorNode]?,
        with text: String
    ) -> [ProseMirrorNode] {
        guard plainInlineContentCanBeReplaced(existingContent) else {
            return existingContent ?? []
        }
        return NativeEditorDocument.inlineNodes(from: AttributedString(text))
    }

    private static func plainBlockContentCanBeReplaced(_ content: [ProseMirrorNode]?) -> Bool {
        NativeEditorSimpleContentSafety.plainBlockText(in: content ?? []) != nil
    }

    private static func plainInlineContentCanBeReplaced(_ content: [ProseMirrorNode]?) -> Bool {
        NativeEditorSimpleContentSafety.plainInlineText(in: content ?? []) != nil
    }

    private static func paragraphNode(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "paragraph",
            content: NativeEditorDocument.inlineNodes(from: AttributedString(text))
        )
    }

    private static func detailsSummaryNode(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "detailsSummary",
            content: NativeEditorDocument.inlineNodes(from: AttributedString(text))
        )
    }

    private static func detailsContentNode(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(type: "detailsContent", content: [paragraphNode(text)])
    }

    private static func columnNode(text: String, width: Double?) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "column",
            attrs: ["width": width.map(ProseMirrorJSONValue.double) ?? .null],
            content: [paragraphNode(text)]
        )
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

nonisolated enum NativeEditorRichBlockNodeFactory {
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

    static func columnsNode(from columns: NativeEditorColumnsBlock) -> ProseMirrorNode {
        let columnTexts = columns.normalizedColumnTexts
        let columnWidths = columns.normalizedColumnWidths
        return ProseMirrorNode(
            type: "columns",
            attrs: [
                "layout": .string(columns.layout),
                "widthMode": .string(columns.widthMode)
            ],
            content: zip(columnTexts, columnWidths).map { columnNode(text: $0.0, width: $0.1) }
        )
    }

    static func transclusionSourceNode(from source: NativeEditorTransclusionSourceBlock) -> ProseMirrorNode {
        var attrs = [String: ProseMirrorJSONValue]()
        if let identifier = source.identifier, identifier.isEmpty == false {
            attrs["id"] = .string(identifier)
        }

        return ProseMirrorNode(
            type: "transclusionSource",
            attrs: attrs.isEmpty ? nil : attrs,
            content: [paragraphNode(source.previewText)]
        )
    }

    static func transclusionReferenceNode(from reference: NativeEditorTransclusionReferenceBlock) -> ProseMirrorNode {
        var attrs = [String: ProseMirrorJSONValue]()
        if let sourcePageID = reference.sourcePageID, sourcePageID.isEmpty == false {
            attrs["sourcePageId"] = .string(sourcePageID)
        }
        if let transclusionID = reference.transclusionID, transclusionID.isEmpty == false {
            attrs["transclusionId"] = .string(transclusionID)
        }

        return ProseMirrorNode(
            type: "transclusionReference",
            attrs: attrs.isEmpty ? nil : attrs
        )
    }

    static func baseNode(from base: NativeEditorBaseBlock) -> ProseMirrorNode {
        var attrs: [String: ProseMirrorJSONValue] = ["pageId": base.pageID.map(ProseMirrorJSONValue.string) ?? .null]
        if let pendingKey = base.pendingKey, pendingKey.isEmpty == false {
            attrs["pendingKey"] = .string(pendingKey)
        }

        return ProseMirrorNode(type: "base", attrs: attrs)
    }

    static func embedNode(from embed: NativeEditorEmbedBlock) -> ProseMirrorNode {
        let attrs: [String: ProseMirrorJSONValue] = [
            "src": .string(embed.source ?? ""),
            "provider": .string(embed.provider ?? ""),
            "align": .string(embed.alignment ?? NativeEditorEmbedBlock.defaultAlignment),
            "width": .int(embed.width.flatMap(Int.init) ?? NativeEditorEmbedBlock.defaultWidthValue),
            "height": .int(embed.height.flatMap(Int.init) ?? NativeEditorEmbedBlock.defaultHeightValue)
        ]

        return ProseMirrorNode(type: "embed", attrs: attrs)
    }

    static func mathBlockNode(from math: NativeEditorMathBlock) -> ProseMirrorNode {
        ProseMirrorNode(type: "mathBlock", attrs: ["text": .string(math.text)])
    }

    static func diagramNode(from diagram: NativeEditorDiagramBlock, type: String) -> ProseMirrorNode {
        var attrs: [String: ProseMirrorJSONValue] = [
            "src": .string(diagram.source ?? ""),
            "width": .null,
            "height": .null,
            "size": .null,
            "aspectRatio": .null,
            "align": .string(diagram.alignment ?? "center")
        ]
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
        if let width = diagram.width.flatMap(proseMirrorDiagramDimension(from:)) {
            attrs["width"] = width
        }
        if let height = diagram.height.flatMap(proseMirrorDiagramDimension(from:)) {
            attrs["height"] = height
        }
        if let aspectRatio = diagram.aspectRatio.flatMap(Double.init) {
            attrs["aspectRatio"] = .double(aspectRatio)
        }
        if let alignment = diagram.alignment {
            attrs["align"] = .string(alignment)
        }

        return ProseMirrorNode(type: type, attrs: attrs)
    }

    private static func paragraphNode(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "paragraph",
            content: NativeEditorDocument.inlineNodes(from: AttributedString(text))
        )
    }

    private static func columnNode(text: String, width: Double?) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "column",
            attrs: ["width": width.map { proseMirrorNumber(from: $0) } ?? .null],
            content: [paragraphNode(text)]
        )
    }

    private static func proseMirrorNumber(from value: Double) -> ProseMirrorJSONValue {
        if value.rounded() == value, let intValue = Int(exactly: value) {
            return .int(intValue)
        }

        return .double(value)
    }

    private static func proseMirrorDiagramDimension(from value: String) -> ProseMirrorJSONValue? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return nil }
        if let number = Double(trimmedValue) {
            return proseMirrorNumber(from: number)
        }
        return .string(trimmedValue)
    }
}
