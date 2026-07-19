import Foundation

nonisolated struct DocumentStoreKey: Codable, Hashable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let serverBaseURL: String
    let userID: String
    let workspaceID: String
    let pageID: String

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        serverBaseURL: String,
        userID: String,
        workspaceID: String,
        pageID: String
    ) {
        self.schemaVersion = schemaVersion
        self.serverBaseURL = serverBaseURL
        self.userID = userID
        self.workspaceID = workspaceID
        self.pageID = pageID
    }
}
