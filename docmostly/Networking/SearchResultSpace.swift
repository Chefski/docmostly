import Foundation

nonisolated struct SearchResultSpace: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String?
    let icon: String?
}
