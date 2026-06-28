import Foundation
import SwiftData

@Model
final class QueuedOfflineMutation {
    var id: String = ""
    var cacheServerBaseURL: String = ""
    var cacheUserID: String = ""
    var kindRaw: String = ""
    var coalescingKey: String?
    var payloadData: Data = Data()
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var replayOrder: Int = 0
    var attemptCount: Int = 0
    var lastErrorMessage: String?

    init(
        id: String = UUID().uuidString,
        payload: OfflineMutationPayload,
        scope: CacheScope,
        payloadData: Data,
        replayOrder: Int,
        createdAt: Date = Date.now
    ) {
        self.id = id
        cacheServerBaseURL = scope.serverBaseURL
        cacheUserID = scope.userID
        kindRaw = payload.kind.rawValue
        coalescingKey = payload.coalescingKey
        self.payloadData = payloadData
        self.replayOrder = replayOrder
        self.createdAt = createdAt
        updatedAt = createdAt
    }
}
