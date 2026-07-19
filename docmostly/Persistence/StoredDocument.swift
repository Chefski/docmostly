import Foundation
import SwiftData

@Model
final class StoredDocument {
    var schemaVersion: Int = DocumentStoreKey.currentSchemaVersion
    var serverBaseURL: String = ""
    var userID: String = ""
    var workspaceID: String = ""
    var pageID: String = ""
    var snapshot: Data?
    var recoverySnapshot: Data?
    var snapshotSequence: Int64 = 0
    var nextSequence: Int64 = 1
    var localClock: Int64 = 0
    var remoteClock: Int64 = 0
    var migrationVersion: Int = 0
    var retainedDraftTitle: String?
    var retainedDraftData: Data?
    var retainedDraftUpdatedAt: Date?
    var compactedAt: Date?
    var updatedAt: Date = Date.now

    init(key: DocumentStoreKey) {
        schemaVersion = key.schemaVersion
        serverBaseURL = key.serverBaseURL
        userID = key.userID
        workspaceID = key.workspaceID
        pageID = key.pageID
    }
}
