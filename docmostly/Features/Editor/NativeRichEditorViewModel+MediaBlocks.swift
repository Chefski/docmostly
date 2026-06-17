import Foundation

extension NativeRichEditorViewModel {
    func updateMediaBlock(
        blockID: UUID,
        update: NativeEditorMediaBlockUpdate
    ) {
        updateMediaRichBlock(blockID: blockID) { block in
            guard let currentMedia = block.kind.mediaBlock else { return }
            let media = NativeEditorMediaBlock(
                source: Self.trimmedOptional(update.source),
                alternativeText: Self.trimmedOptional(update.alternativeText),
                attachmentID: currentMedia.attachmentID,
                sizeInBytes: currentMedia.sizeInBytes,
                width: Self.trimmedOptional(update.width),
                height: Self.trimmedOptional(update.height),
                aspectRatio: Self.aspectRatio(width: update.width, height: update.height) ?? currentMedia.aspectRatio,
                alignment: Self.trimmedOptional(update.alignment)
            )
            block.kind = block.kind.replacingMediaBlock(with: media)
            block.text = AttributedString(NativeEditorDocument.previewText(for: block.kind))
            block.rawNode = NativeEditorRichBlockNodeFactory.mediaNode(from: media, type: block.kind.mediaNodeType)
        }
    }

    func updatePDFBlock(blockID: UUID, source: String, name: String, width: String, height: String) {
        updateMediaRichBlock(blockID: blockID) { block in
            guard case .pdf(let currentPDF) = block.kind else { return }
            let pdf = NativeEditorPDFBlock(
                source: Self.trimmedOptional(source),
                name: Self.trimmedOptional(name),
                attachmentID: currentPDF.attachmentID,
                sizeInBytes: currentPDF.sizeInBytes,
                width: Self.trimmedOptional(width),
                height: Self.trimmedOptional(height)
            )
            block.kind = .pdf(pdf)
            block.text = AttributedString(NativeEditorDocument.previewText(for: block.kind))
            block.rawNode = NativeEditorRichBlockNodeFactory.pdfNode(from: pdf)
        }
    }

    func updateAttachmentBlock(blockID: UUID, url: String, name: String, mimeType: String) {
        updateMediaRichBlock(blockID: blockID) { block in
            guard case .attachment(let currentAttachment) = block.kind else { return }
            let attachment = NativeEditorAttachmentBlock(
                url: Self.trimmedOptional(url),
                name: Self.trimmedOptional(name),
                mimeType: Self.trimmedOptional(mimeType),
                sizeInBytes: currentAttachment.sizeInBytes,
                attachmentID: currentAttachment.attachmentID
            )
            block.kind = .attachment(attachment)
            block.text = AttributedString(NativeEditorDocument.previewText(for: block.kind))
            block.rawNode = NativeEditorRichBlockNodeFactory.attachmentNode(from: attachment)
        }
    }

    private func updateMediaRichBlock(blockID: UUID, edit: (inout NativeEditorBlock) -> Void) {
        performUndoableEdit {
            guard let index = document.blocks.firstIndex(where: { $0.id == blockID }) else {
                return
            }

            edit(&document.blocks[index])
        }
    }

    private static func trimmedOptional(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static func aspectRatio(width: String, height: String) -> String? {
        guard
            let widthValue = Double(width.trimmingCharacters(in: .whitespacesAndNewlines)),
            let heightValue = Double(height.trimmingCharacters(in: .whitespacesAndNewlines)),
            heightValue > 0
        else {
            return nil
        }
        return (widthValue / heightValue).description
    }
}

private extension NativeEditorBlockKind {
    var mediaBlock: NativeEditorMediaBlock? {
        switch self {
        case .image(let media), .video(let media), .audio(let media):
            media
        default:
            nil
        }
    }

    var mediaNodeType: String {
        switch self {
        case .image:
            "image"
        case .video:
            "video"
        case .audio:
            "audio"
        default:
            "image"
        }
    }

    func replacingMediaBlock(with media: NativeEditorMediaBlock) -> NativeEditorBlockKind {
        switch self {
        case .image:
            .image(media)
        case .video:
            .video(media)
        case .audio:
            .audio(media)
        default:
            self
        }
    }
}

extension NativeEditorRichBlockNodeFactory {
    static func mediaNode(from media: NativeEditorMediaBlock, type: String) -> ProseMirrorNode {
        var attrs = sourceAttrs(
            sourceKey: "src",
            source: media.source,
            attachmentID: media.attachmentID,
            sizeInBytes: media.sizeInBytes
        )
        if let alternativeText = media.alternativeText {
            attrs["alt"] = .string(alternativeText)
        }
        appendDimensions(width: media.width, height: media.height, aspectRatio: media.aspectRatio, to: &attrs)
        if let alignment = media.alignment {
            attrs["align"] = .string(alignment)
        }
        return ProseMirrorNode(type: type, attrs: attrs.isEmpty ? nil : attrs)
    }

    static func pdfNode(from pdf: NativeEditorPDFBlock) -> ProseMirrorNode {
        var attrs = sourceAttrs(
            sourceKey: "src",
            source: pdf.source,
            attachmentID: pdf.attachmentID,
            sizeInBytes: pdf.sizeInBytes
        )
        if let name = pdf.name {
            attrs["name"] = .string(name)
        }
        appendDimensions(width: pdf.width, height: pdf.height, aspectRatio: nil, to: &attrs)
        return ProseMirrorNode(type: "pdf", attrs: attrs.isEmpty ? nil : attrs)
    }

    static func attachmentNode(from attachment: NativeEditorAttachmentBlock) -> ProseMirrorNode {
        var attrs = sourceAttrs(
            sourceKey: "url",
            source: attachment.url,
            attachmentID: attachment.attachmentID,
            sizeInBytes: attachment.sizeInBytes
        )
        if let name = attachment.name {
            attrs["name"] = .string(name)
        }
        if let mimeType = attachment.mimeType {
            attrs["mime"] = .string(mimeType)
        }
        return ProseMirrorNode(type: "attachment", attrs: attrs.isEmpty ? nil : attrs)
    }

    private static func sourceAttrs(
        sourceKey: String,
        source: String?,
        attachmentID: String?,
        sizeInBytes: Int?
    ) -> [String: ProseMirrorJSONValue] {
        var attrs = [String: ProseMirrorJSONValue]()
        if let source {
            attrs[sourceKey] = .string(source)
        }
        if let attachmentID {
            attrs["attachmentId"] = .string(attachmentID)
        }
        if let sizeInBytes {
            attrs["size"] = .int(sizeInBytes)
        }
        return attrs
    }

    private static func appendDimensions(
        width: String?,
        height: String?,
        aspectRatio: String?,
        to attrs: inout [String: ProseMirrorJSONValue]
    ) {
        if let width = width.flatMap(Int.init) {
            attrs["width"] = .int(width)
        }
        if let height = height.flatMap(Int.init) {
            attrs["height"] = .int(height)
        }
        if let aspectRatio = aspectRatio.flatMap(Double.init) {
            attrs["aspectRatio"] = .double(aspectRatio)
        }
    }
}
