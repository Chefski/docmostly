import Foundation
import SwiftData

@Model
final class StoredDocumentPeerState {
    var schemaVersion: Int = DocumentStoreKey.currentSchemaVersion
    var serverBaseURL: String = ""
    var userID: String = ""
    var workspaceID: String = ""
    var pageID: String = ""
    var peerID: String = "collaboration"
    var advertisedRemoteClock: Int64 = 0
    var pulledRemoteClock: Int64 = 0
    var pushedLocalSequence: Int64 = 0
    var lastConnectedAt: Date?
    var updatedAt: Date = Date.now

    init(key: DocumentStoreKey, peerID: String = "collaboration") {
        schemaVersion = key.schemaVersion
        serverBaseURL = key.serverBaseURL
        userID = key.userID
        workspaceID = key.workspaceID
        pageID = key.pageID
        self.peerID = peerID
    }
}
