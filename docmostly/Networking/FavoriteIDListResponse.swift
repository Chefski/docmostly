import Foundation

nonisolated struct FavoriteIDListResponse: Decodable, Sendable {
    let items: [String]

    init(from decoder: Decoder) throws {
        if let response = try? PaginatedResponse<String>(from: decoder) {
            items = response.items
            return
        }

        items = try [String](from: decoder)
    }
}
