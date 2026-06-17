import Foundation

nonisolated struct NativeEditorCollaborationDocument: Equatable, Sendable {
    static let pageDocumentPrefix = "page"
    static let yjsFragmentName = "default"
    static let statelessPageUpdatedType = "page.updated"

    let pageID: String

    init(pageID: String) {
        self.pageID = pageID
    }

    init?(documentName: String) {
        let components = documentName.split(separator: ".", omittingEmptySubsequences: false)
        guard
            components.count == 2,
            components[0] == Self.pageDocumentPrefix,
            components[1].isEmpty == false
        else {
            return nil
        }

        pageID = String(components[1])
    }

    var name: String {
        "\(Self.pageDocumentPrefix).\(pageID)"
    }

    var fragmentName: String {
        Self.yjsFragmentName
    }
}
