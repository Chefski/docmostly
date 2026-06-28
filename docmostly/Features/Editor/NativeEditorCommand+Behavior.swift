import Foundation

extension NativeEditorCommand {
    var attachmentImportKind: NativeEditorAttachmentImportKind? {
        switch self {
        case .image:
            .image
        case .video:
            .video
        case .audio:
            .audio
        case .pdf:
            .pdf
        case .fileAttachment:
            .file
        default:
            nil
        }
    }

    func matches(query: String) -> Bool {
        guard query.isEmpty == false else { return true }

        return title.localizedStandardContains(query) ||
            subtitle.localizedStandardContains(query) ||
            rawValue.localizedStandardContains(query)
    }
}
