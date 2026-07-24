import Foundation

nonisolated struct EmojiCatalogItem: Identifiable, Hashable, Sendable {
    let emoji: String
    let name: String

    var id: String { emoji }
}

nonisolated struct EmojiCatalogSection: Identifiable, Hashable, Sendable {
    let name: String
    let items: [EmojiCatalogItem]

    var id: String { name }
}
