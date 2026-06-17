import Foundation

nonisolated struct DocmostAttachmentLink: Identifiable, Hashable, Sendable {
    let id: String
    let fileName: String
    let path: String

    func url(serverURLString: String) -> URL? {
        guard let baseURL = URL(string: serverURLString) else { return nil }
        return URL(string: path, relativeTo: baseURL)?.absoluteURL
    }
}
