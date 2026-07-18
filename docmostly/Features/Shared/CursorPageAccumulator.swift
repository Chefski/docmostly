import Foundation

nonisolated struct CursorPageAccumulator<Item: Decodable & Identifiable & Sendable>: Sendable
where Item.ID: Hashable & Sendable {
    private(set) var items: [Item] = []
    private(set) var nextCursor: String?
    private(set) var hasNextPage = false

    mutating func replace(with response: PaginatedResponse<Item>) {
        items = Self.deduplicated(response.items)
        updatePagination(using: response.meta, requestedCursor: nil)
    }

    mutating func append(
        _ response: PaginatedResponse<Item>,
        requestedCursor: String
    ) {
        var seenIDs = Set(items.map(\.id))
        items.append(contentsOf: response.items.filter { seenIDs.insert($0.id).inserted })
        updatePagination(using: response.meta, requestedCursor: requestedCursor)
    }

    mutating func remove(id: Item.ID) -> (item: Item, index: Int)? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        return (items.remove(at: index), index)
    }

    mutating func restore(_ item: Item, at index: Int) {
        guard items.contains(where: { $0.id == item.id }) == false else { return }
        items.insert(item, at: min(max(index, 0), items.endIndex))
    }

    private mutating func updatePagination(
        using meta: PaginationMeta,
        requestedCursor: String?
    ) {
        let candidateCursor = meta.hasNextPage ? meta.nextCursor : nil
        nextCursor = candidateCursor == requestedCursor ? nil : candidateCursor
        hasNextPage = nextCursor != nil
    }

    private static func deduplicated(_ items: [Item]) -> [Item] {
        var seenIDs: Set<Item.ID> = []
        return items.filter { seenIDs.insert($0.id).inserted }
    }
}
