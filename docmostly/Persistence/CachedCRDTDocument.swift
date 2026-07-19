import Foundation
import SwiftData

@Model
final class CachedCRDTDocument {
    var cacheServerBaseURL: String = ""
    var cacheUserID: String = ""
    var pageId: String = ""
    var stateUpdate: Data = Data()
    var updatedAt: Date = Date.now

    init(pageId: String, stateUpdate: Data, scope: CacheScope) {
        cacheServerBaseURL = scope.serverBaseURL
        cacheUserID = scope.userID
        self.pageId = pageId
        self.stateUpdate = stateUpdate
    }

    func update(stateUpdate: Data) {
        self.stateUpdate = stateUpdate
        updatedAt = .now
    }
}
