import Foundation

nonisolated enum DocmostPageExportFormat: String, CaseIterable, Identifiable, Sendable {
    case markdown
    case html

    var id: String { rawValue }

    var title: String {
        switch self {
        case .markdown:
            "Markdown"
        case .html:
            "HTML"
        }
    }

    var defaultFilenameExtension: String {
        switch self {
        case .markdown:
            "md"
        case .html:
            "html"
        }
    }
}
