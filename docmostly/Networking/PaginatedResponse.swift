import Foundation

nonisolated struct PaginatedResponse<Item: Decodable & Sendable>: Decodable, Sendable {
    let items: [Item]
    let meta: PaginationMeta
}
