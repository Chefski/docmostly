import Foundation

nonisolated struct DocmostPageHistory: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let pageId: String
    let title: String
    let content: ProseMirrorDocument?
    let slug: String?
    let icon: String?
    let coverPhoto: String?
    let version: Int?
    let lastUpdatedById: String?
    let workspaceId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let lastUpdatedBy: DocmostPagePerson?
    let contributors: [DocmostPagePerson]?
}

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

nonisolated struct DocmostPageExportFile: Equatable, Sendable {
    let data: Data
    let fileName: String
    let mimeType: String?
}
