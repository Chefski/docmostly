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
        matchPriority(query: query) != nil
    }

    func matchPriority(query: String) -> Int? {
        guard query.isEmpty == false else { return 0 }

        if title.localizedStandardContains(query) || rawValue.localizedStandardContains(query) {
            return 0
        }

        if subtitle.localizedStandardContains(query) {
            return 1
        }

        return nil
    }
}
