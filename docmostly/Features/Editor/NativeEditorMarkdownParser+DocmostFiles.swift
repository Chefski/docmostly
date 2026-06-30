import Foundation

extension NativeEditorMarkdownParser {
    static func docmostAttachmentID(from source: String) -> String? {
        let pathComponents = markdownLinkPath(from: source)
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        let filesIndex: Array<String>.Index?
        if let apiIndex = pathComponents.firstIndex(of: "api"),
           pathComponents.indices.contains(pathComponents.index(after: apiIndex)),
           pathComponents[pathComponents.index(after: apiIndex)] == "files" {
            filesIndex = pathComponents.index(after: apiIndex)
        } else if pathComponents.first == "files" {
            filesIndex = pathComponents.startIndex
        } else {
            filesIndex = nil
        }

        guard let filesIndex else { return nil }

        let attachmentIndex = pathComponents.index(after: filesIndex)
        guard pathComponents.indices.contains(attachmentIndex) else { return nil }

        let filenameIndex = pathComponents.index(after: attachmentIndex)
        guard pathComponents.indices.contains(filenameIndex) else { return nil }

        let attachmentID = pathComponents[attachmentIndex]
        guard attachmentID.isEmpty == false else { return nil }
        return attachmentID.removingPercentEncoding ?? attachmentID
    }

    static func markdownLinkPath(from source: String) -> String {
        let pathSource: String
        if let components = URLComponents(string: source), components.scheme != nil {
            pathSource = components.path.isEmpty ? "" : components.path
        } else {
            pathSource = source
        }

        return pathSource.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? pathSource
    }
}
