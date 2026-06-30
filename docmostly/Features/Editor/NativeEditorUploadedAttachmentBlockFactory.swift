import Foundation
import AVFoundation
import ImageIO

enum NativeEditorAttachmentBlockFactory {
    static func block(
        for attachment: DocmostAttachment,
        importKind: NativeEditorAttachmentImportKind,
        replacing id: UUID = UUID(),
        sourceFileURL: URL? = nil
    ) -> NativeEditorBlock {
        let context = NativeEditorAttachmentContext(
            attachment: attachment,
            source: "/api/files/\(attachment.id)/\(attachment.fileName)",
            size: attachment.fileSize ?? localFileSize(for: sourceFileURL),
            mediaDimensions: mediaDimensions(for: sourceFileURL, importKind: importKind)
        )

        switch importKind {
        case .image:
            return imageBlock(id: id, context: context)
        case .video:
            return videoBlock(id: id, context: context)
        case .audio:
            return audioBlock(id: id, context: context)
        case .pdf:
            return pdfBlock(id: id, context: context)
        case .file:
            return attachmentBlock(id: id, context: context)
        }
    }

    private static func imageBlock(id: UUID, context: NativeEditorAttachmentContext) -> NativeEditorBlock {
        mediaBlock(
            id: id,
            kind: .image(context.mediaPayload(alignment: NativeEditorMediaBlock.defaultAlignment)),
            type: "image",
            context: context,
            alignment: NativeEditorMediaBlock.defaultAlignment,
            dimensions: context.mediaDimensions
        )
    }

    private static func videoBlock(id: UUID, context: NativeEditorAttachmentContext) -> NativeEditorBlock {
        mediaBlock(
            id: id,
            kind: .video(
                context.mediaPayload(
                    title: context.attachment.fileName,
                    alignment: NativeEditorMediaBlock.defaultAlignment
                )
            ),
            type: "video",
            context: context,
            title: context.attachment.fileName,
            alignment: NativeEditorMediaBlock.defaultAlignment,
            dimensions: context.mediaDimensions
        )
    }

    private static func audioBlock(id: UUID, context: NativeEditorAttachmentContext) -> NativeEditorBlock {
        mediaBlock(id: id, kind: .audio(context.mediaPayload), type: "audio", context: context)
    }

    private static func mediaBlock(
        id: UUID,
        kind: NativeEditorBlockKind,
        type: String,
        context: NativeEditorAttachmentContext,
        title: String? = nil,
        alignment: String? = nil,
        dimensions: NativeEditorMediaDimensions? = nil
    ) -> NativeEditorBlock {
        var attrs = context.sourceAttrs
        if let title {
            attrs["title"] = .string(title)
        }
        if let alignment {
            attrs["align"] = .string(alignment)
        }
        if let dimensions {
            attrs["width"] = .int(dimensions.width)
            attrs["height"] = .int(dimensions.height)
            attrs["aspectRatio"] = .double(dimensions.aspectRatio)
        }

        return rawBlock(id: id, kind: kind, type: type, attrs: attrs)
    }

    private static func pdfBlock(id: UUID, context: NativeEditorAttachmentContext) -> NativeEditorBlock {
        var attrs = context.sourceAttrs
        attrs["name"] = .string(context.attachment.fileName)

        let kind = NativeEditorBlockKind.pdf(NativeEditorPDFBlock(
            source: context.source,
            name: context.attachment.fileName,
            attachmentID: context.attachment.id,
            sizeInBytes: context.size,
            width: nil,
            height: nil
        ))

        return rawBlock(id: id, kind: kind, type: "pdf", attrs: attrs)
    }

    private static func attachmentBlock(id: UUID, context: NativeEditorAttachmentContext) -> NativeEditorBlock {
        let attrs = context.attachmentAttrs

        let kind = NativeEditorBlockKind.attachment(NativeEditorAttachmentBlock(
            url: context.source,
            name: context.attachment.fileName,
            mimeType: context.attachment.mimeType,
            sizeInBytes: context.size,
            attachmentID: context.attachment.id
        ))

        return rawBlock(id: id, kind: kind, type: "attachment", attrs: attrs)
    }

    private static func rawBlock(
        id: UUID,
        kind: NativeEditorBlockKind,
        type: String,
        attrs: [String: ProseMirrorJSONValue]
    ) -> NativeEditorBlock {
        NativeEditorBlock(
            id: id,
            kind: kind,
            text: AttributedString(NativeEditorDocument.previewText(for: kind)),
            alignment: .left,
            rawNode: ProseMirrorNode(type: type, attrs: attrs)
        )
    }

    private static func localFileSize(for fileURL: URL?) -> Int? {
        guard let fileURL else { return nil }
        return try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize
    }

    private static func imageDimensions(for fileURL: URL?) -> NativeEditorMediaDimensions? {
        guard
            let fileURL,
            let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = intValue(properties[kCGImagePropertyPixelWidth]),
            let height = intValue(properties[kCGImagePropertyPixelHeight]),
            height > 0
        else {
            return nil
        }

        return NativeEditorMediaDimensions(
            width: width,
            height: height,
            aspectRatio: Double(width) / Double(height)
        )
    }

    private static func mediaDimensions(
        for fileURL: URL?,
        importKind: NativeEditorAttachmentImportKind
    ) -> NativeEditorMediaDimensions? {
        switch importKind {
        case .image:
            imageDimensions(for: fileURL)
        case .video:
            videoDimensions(for: fileURL)
        case .audio, .pdf, .file:
            nil
        }
    }

    private static func videoDimensions(for fileURL: URL?) -> NativeEditorMediaDimensions? {
        guard let fileURL else { return nil }

        let asset = AVURLAsset(url: fileURL)
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            return nil
        }

        let displaySize = videoTrack.naturalSize.applying(videoTrack.preferredTransform)
        let width = Int(abs(displaySize.width).rounded())
        let height = Int(abs(displaySize.height).rounded())
        guard height > 0, width > 0 else {
            return nil
        }

        return NativeEditorMediaDimensions(
            width: width,
            height: height,
            aspectRatio: Double(width) / Double(height)
        )
    }

    private static func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }

        if let number = value as? NSNumber {
            return Int(truncating: number)
        }

        return nil
    }
}

private struct NativeEditorAttachmentContext {
    let attachment: DocmostAttachment
    let source: String
    let size: Int?
    let mediaDimensions: NativeEditorMediaDimensions?

    var mediaPayload: NativeEditorMediaBlock {
        mediaPayload()
    }

    func mediaPayload(
        title: String? = nil,
        alignment: String? = nil
    ) -> NativeEditorMediaBlock {
        NativeEditorMediaBlock(
            source: source,
            alternativeText: nil,
            title: title,
            attachmentID: attachment.id,
            sizeInBytes: size,
            width: mediaDimensions?.width.description,
            height: mediaDimensions?.height.description,
            aspectRatio: mediaDimensions?.aspectRatio.description,
            alignment: alignment
        )
    }

    var sourceAttrs: [String: ProseMirrorJSONValue] {
        var attrs: [String: ProseMirrorJSONValue] = [
            "src": .string(source),
            "attachmentId": .string(attachment.id)
        ]
        if let size {
            attrs["size"] = .int(size)
        }
        return attrs
    }

    var attachmentAttrs: [String: ProseMirrorJSONValue] {
        var attrs: [String: ProseMirrorJSONValue] = [
            "url": .string(source),
            "name": .string(attachment.fileName),
            "attachmentId": .string(attachment.id)
        ]
        if let mimeType = attachment.mimeType {
            attrs["mime"] = .string(mimeType)
        }
        if let size {
            attrs["size"] = .int(size)
        }
        return attrs
    }
}

struct NativeEditorMediaDimensions: Equatable, Hashable, Sendable {
    let width: Int
    let height: Int
    let aspectRatio: Double
}
