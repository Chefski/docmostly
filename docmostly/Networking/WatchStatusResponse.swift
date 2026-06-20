import Foundation

nonisolated struct WatchStatusResponse: Decodable, Hashable, Sendable {
    let watching: Bool
}
