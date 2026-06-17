import Foundation

nonisolated struct PaginationMeta: Decodable, Sendable {
    let limit: Int
    let hasNextPage: Bool
    let hasPrevPage: Bool
    let nextCursor: String?
    let prevCursor: String?
}
