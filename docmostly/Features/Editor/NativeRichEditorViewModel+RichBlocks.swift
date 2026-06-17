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

    func updateMathBlock(blockID: UUID, text: String) {
        updateRichBlock(blockID: blockID) { block in
            let math = NativeEditorMathBlock(text: text)
            block.kind = .mathBlock(math)
            block.text = AttributedString(text)
            block.rawNode = NativeEditorRichBlockNodeFactory.mathBlockNode(from: math)
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

    private static func paragraphNode(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "paragraph",
            content: NativeEditorDocument.inlineNodes(from: AttributedString(text))
        )
    }
}
