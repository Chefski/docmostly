import Foundation
import SwiftData

nonisolated enum StoredDocumentUpdateOrigin: String, Codable, Sendable {
    case local
    case remote
    case migration
}

@Model
final class StoredDocumentUpdate {
    var schemaVersion: Int = DocumentStoreKey.currentSchemaVersion
    var serverBaseURL: String = ""
    var userID: String = ""
    var workspaceID: String = ""
    var pageID: String = ""
    var sequence: Int64 = 0
    var clock: Int64 = 0
    var originRaw: String = StoredDocumentUpdateOrigin.local.rawValue
    var digest: String = ""
    var payload: Data?
    var isPushed: Bool = false
    var committedAt: Date = Date.now

    init(
        key: DocumentStoreKey,
        sequence: Int64,
        clock: Int64,
        origin: StoredDocumentUpdateOrigin,
        digest: String,
        payload: Data,
        isPushed: Bool,
        committedAt: Date = Date.now
    ) {
        schemaVersion = key.schemaVersion
        serverBaseURL = key.serverBaseURL
        userID = key.userID
        workspaceID = key.workspaceID
        pageID = key.pageID
        self.sequence = sequence
        self.clock = clock
        originRaw = origin.rawValue
        self.digest = digest
        self.payload = payload
        self.isPushed = isPushed
        self.committedAt = committedAt
    }

    var origin: StoredDocumentUpdateOrigin {
        StoredDocumentUpdateOrigin(rawValue: originRaw) ?? .local
    }
}
