import UniformTypeIdentifiers

enum NativeEditorAttachmentImportKind: String, CaseIterable, Identifiable, Sendable {
    case image
    case video
    case audio
    case pdf
    case file

    var id: String { rawValue }

    var title: String {
        switch self {
        case .image:
            "Image"
        case .video:
            "Video"
        case .audio:
            "Audio"
        case .pdf:
            "PDF"
        case .file:
            "File"
        }
    }

    var systemImage: String {
        switch self {
        case .image:
            "photo"
        case .video:
            "play.rectangle"
        case .audio:
            "waveform"
        case .pdf:
            "doc.richtext"
        case .file:
            "paperclip"
        }
    }

    var allowedContentTypes: [UTType] {
        switch self {
        case .image:
            [.image]
        case .video:
            [.movie]
        case .audio:
            [.audio]
        case .pdf:
            [.pdf]
        case .file:
            [.item]
        }
    }
}
