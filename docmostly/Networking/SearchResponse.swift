import Foundation

nonisolated struct SearchResponse: Decodable, Sendable {
    let items: [DocmostSearchResult]
}
