import Foundation

nonisolated struct OfflinePageLabel: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(pageId: String, name: String) {
        id = Self.localID(pageId: pageId, name: name)
        self.name = name
    }

    static func localID(pageId: String, name: String) -> String {
        "offline-label-\(pageId)-\(name)"
    }
}
