import Foundation

enum NativeEditorInlineCommentCreationError: LocalizedError, Sendable {
    case noSelection
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSelection:
            "Select text before adding an inline comment."
        case .saveFailed(let message):
            message
        }
    }
}
